# rules_soci

Bazel rules for converting OCI container images to SOCI (Seekable OCI) with lazy-loading indices.

## Quick Start

### Requirements

- Bazel 9.1.0+ with Bzlmod enabled
- A Linux **execution** platform for `soci_image`. The SOCI CLI binary is
  Linux-only, so the conversion action (`soci convert --standalone`) must run
  on a Linux host or a Linux remote-execution worker. `soci_push` uses the
  cross-platform `crane` toolchain, which also runs on macOS.
- SOCI indices are only useful on Linux container runtimes (e.g. containerd
  with the SOCI snapshotter), but you do **not** need containerd, nerdctl, or
  `sudo` to build or push a SOCI image with these rules.

### Installation (MODULE.bazel)

Add `rules_soci` to your module and configure the bzlmod extension. The
extension generates two kinds of toolchains: the SOCI CLI toolchain and a
hermetic `crane` toolchain used by `soci_push`.

```starlark
bazel_dep(name = "rules_soci", version = "0.2.0")

# Configure SOCI + crane toolchains
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    soci_version = "0.14.1",    # optional, uses a built-in default
)
soci.crane_toolchain(
    crane_version = "0.21.7",   # optional, uses a built-in default
)
use_repo(
    soci,
    "soci_toolchains",
    "crane_linux_amd64",
    "crane_linux_arm64",
    "crane_darwin_amd64",
    "crane_darwin_arm64",
)

# Register the SOCI toolchain (the crane toolchains above are registered by
# the soci_toolchains repo automatically).
register_toolchains("@soci_toolchains//:all")
```

> The `crane_*` repos provide the `crane` binary per platform so that
> `soci_push` works without any pre-installed `crane`, `nerdctl`, or
> containerd on the machine running `bazel run`.

## Usage

### Basic Example

```starlark
load("@rules_oci//oci:defs.bzl", "oci_image")
load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

# Build an OCI image with rules_oci
oci_image(
    name = "app",
    base = "@ubuntu_base",
    entrypoint = ["/app/hello_app"],
    tars = [":hello_layer"],
)

# Convert the OCI image to a SOCI standalone layout.
# `image` can be an oci_image directory, an oci_load(format = "oci") tarball,
# or an oci_tarball(format = "oci", ...) tarball.
soci_image(
    name = "app_soci",
    image = ":app",
    repo_tags = [
        "docker.io/myuser/app:latest",
        "docker.io/myuser/app:v1.0.0",
    ],
)

# Push the SOCI-enabled layout to a registry using the hermetic crane toolchain.
soci_push(
    name = "app_push",
    soci_image = ":app_soci",
)
```

### Build and Push

```bash
# Convert image to a SOCI (standalone) OCI layout
bazel build //:app_soci

# Push the SOCI-enabled image to a registry
bazel run //:app_push
```

`crane` reads registry credentials from `~/.docker/config.json`, the same as
`docker`/`nerdctl` does. `bazel run //:app_push` runs one `crane push` call
per tag; the registry de-duplicates content by digest across tags.

## Rules

### `soci_image`

Converts an OCI image (directory or OCI-layout tarball) to SOCI format using
`soci convert --standalone`. This runs **directly on the OCI layout** and
produces a new OCI-layout directory that contains the original image plus the
SOCI index (SOCI Index Manifest v2). It does not load anything into
containerd and needs no daemon, so the action is hermetic and
cacheable/remote-executable.

**Input requirement:** `image` must be an OCI-layout tarball (`.tar` / `.tar.gz`)
or directory — for example the output of `oci_image`, or an
`oci_load(format = "oci", ...)` / `oci_tarball(format = "oci", ...)` tarball.
Docker-style tarballs (`docker save`, `oci_tarball(format = "docker", ...)`)
are **not** compatible with `soci convert --standalone`.

Attributes:

- `image` (required): OCI-layout tarball or directory.
- `image_ref` (optional): Fallback image reference used for the default repo
  tag when neither `repo_tags` nor `repo_tags_file` is set.
- `repo_tags` (optional): List of repository tags to push. Carried through to
  `soci_push`; not used during conversion (standalone mode never talks to a
  registry or daemon).
- `repo_tags_file` (optional): Label of a file containing tags (one per line),
  consumed by `soci_push`. May not be combined with `repo_tags`.
- `min_layer_size` (optional, default `-1`): Minimum layer size in bytes.
  `-1` means "do not pass `--min-layer-size`", so SOCI uses its built-in
  default of **10 MiB** (`10485760`). Only layers at least this large get a
  ztoc; smaller layers are skipped. See the troubleshooting note below.
- `span_size` (optional, default `-1`): Span size in bytes for ztoc. `-1`
  uses SOCI's built-in default (typically 4 MiB). Only passed to `soci` when
  set to a value > 0.
- `all_platforms` (optional, default `False`): Convert every platform of a
  multi-platform image index.
- `platform` (optional, default `""`): Convert only the given platform, e.g.
  `linux/amd64`. Ignored if `all_platforms` is set.

Example:

```starlark
soci_image(
    name = "app_soci",
    image = ":app",
    repo_tags = ["docker.io/myuser/app:latest"],
    min_layer_size = -1,   # use SOCI's built-in 10 MiB default
    span_size = -1,        # use SOCI's built-in default span size
    platform = "linux/amd64",
)
```

### `soci_push`

Pushes a SOCI-enabled OCI-layout directory to a registry using a **hermetic
crane toolchain** (`crane push`). No containerd, nerdctl, or pre-installed
`crane` is required; `crane` is resolved via `crane_toolchain`. Registry
credentials are still read from `~/.docker/config.json`.

Attributes:

- `soci_image` (required): SOCI-converted OCI-layout directory from a
  `soci_image` rule.
- `repo_tags` (optional): List of image references to push. If omitted, the
  tags are taken from the `soci_image` target (`repo_tags` or
  `repo_tags_file`).
- `push_index` (optional, default `False`): Pass `--index` to `crane push`.
  Required when the SOCI layout contains an image **index** with multiple
  images (e.g. when `soci_image` was built with `all_platforms = True`).

Example:

```starlark
soci_push(
    name = "push",
    soci_image = ":app_soci",
)

# Override destination tags
soci_push(
    name = "push_prod",
    soci_image = ":app_soci",
    repo_tags = ["docker.io/myuser/app:prod"],
)

# Multi-platform image index requires --index
soci_push(
    name = "push_multi",
    soci_image = ":app_soci_all_platforms",
    push_index = True,
)
```

## Troubleshooting

### `soci: no ztocs created, all layers either skipped or produced errors`

This happens when `soci convert --standalone` finds **no** layer large enough
to produce a ztoc. By default (`min_layer_size = -1`) SOCI skips layers
smaller than its built-in 10 MiB threshold; if every layer of the image is
below that size, no ztoc is created and the conversion fails.

Fixes:

- Ensure the image has at least one layer ≥ 10 MiB (for example a real base
  image such as Ubuntu), **or**
- Lower the threshold for this target:

  ```starlark
  soci_image(
      name = "app_soci",
      image = ":app",
      min_layer_size = 1048576,  # 1 MiB, instead of the 10 MiB default
  )
  ```

### `Docker` / `docker save` tarballs are not supported

`soci convert --standalone` only understands OCI-layout inputs. Use
`oci_image` directly, or `oci_load(format = "oci", ...)` /
`oci_tarball(format = "oci", ...)`. Passing a `format = "docker"` tarball
produces a clear error from the rule rather than from `soci`.

### `soci` only runs on Linux

The conversion step must execute on a Linux platform. On macOS you can still
build the rest of the graph, but `bazel build //:app_soci` requires a Linux
executor. Pushing via `soci_push`/`crane` works on macOS as well.

## License

[Apache 2.0](./LICENSE)

## Credits

- [SOCI Snapshotter](https://github.com/awslabs/soci-snapshotter)
- [go-containerregistry (crane)](https://github.com/google/go-containerregistry)
- [rules_oci](https://github.com/bazel-contrib/rules_oci)
