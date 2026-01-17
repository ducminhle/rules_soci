# rules_soci

Bazel rules for converting OCI container images to SOCI (Seekable OCI) with lazy-loading indices.

## Quick Start

### Requirements

- Bazel 8.5.0+ and Bzlmod
- `nerdctl` (used to import, convert and push images) and `containerd` running
- Linux host (SOCI indices are only useful on Linux container runtimes)

### Installation (MODULE.bazel)

Add rules_soci to your module and enable the bzlmod extension to generate toolchains:

```starlark
bazel_dep(name = "rules_soci", version = "0.1.0")

# Configure SOCI extension
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    soci_version = "0.12.1",    # optional
)
use_repo(soci, "soci_toolchains")

# Register toolchains
register_toolchains("@soci_toolchains//:all")
```

## Usage

### Basic Example

```starlark
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_load")
load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

# Build OCI image (example)
oci_image(
    name = "app",
    base = "@distroless_base",
    entrypoint = ["/app"],
    cmd = ["--port=8080"],
)

oci_load(
    name = "app_load",
    image = ":app",
    repo_tags = ["docker.io/myuser/app:latest"],
)

filegroup(
    name = "app_tarball",
    srcs = [":app_load"],
    output_group = "tarball",
)

# Convert to SOCI format (nerdctl is used under the hood)
soci_image(
    name = "app_soci",
    image = ":app_tarball",
    repo_tags = [
        "docker.io/myuser/app:latest",
        "docker.io/myuser/app:v1.0.0",
    ],
)

# Push to registry using nerdctl (nerdctl reads credentials from ~/.docker/config.json)
soci_push(
    name = "soci_push",
    soci_image = ":app_soci",
)
```

### Build and Push

```bash
# Convert image to SOCI format
bazel build //:app_soci

# Ensure containerd is running and nerdctl can access it (may require sudo/root)
# Push (runs the generated push script via Bazel)
bazel run //:soci_push
```

If your registry requires authentication, either `docker login` or `nerdctl login` will populate the credentials that `nerdctl` reads.

## Rules

### `soci_image`

Converts an OCI image tarball to SOCI format using `nerdctl image convert --soci`.

Attributes:

- `image` (required): OCI image tarball from `oci_load` or similar
- `image_ref` (optional): fallback image reference to write into containerd
- `repo_tags` (optional): list of repository tags
- `repo_tags_file` (optional): label pointing to a file containing tags (one per line)
- `min_layer_size` (optional, default -1): Minimum layer size in bytes; `-1` lets SOCI/nerdctl use its default
- `span_size` (optional, default -1): Span size in bytes for ztoc; `-1` uses SOCI/nerdctl default

Example:

```starlark
soci_image(
    name = "app_soci",
    image = ":app_tarball",
    repo_tags = ["docker.io/myuser/app:latest"],
    min_layer_size = -1,  # use SOCI defaults
    span_size = -1,
)
```

### `soci_push`

Pushes SOCI-enabled images to a registry using `nerdctl`.

Attributes:

- `soci_image` (required): SOCI marker file from `soci_image` rule
- `repo_tags` (optional): List of image references to push. If not specified, inherited from `soci_image` or a tags file.

Example:

```starlark
soci_push(
    name = "push",
    soci_image = ":app_soci",
)

# Override tags
soci_push(
    name = "push_prod",
    soci_image = ":app_soci",
    repo_tags = ["docker.io/myuser/app:prod"],
)
```

## License

[Apache 2.0](./LICENSE)

## Credits

- [SOCI Snapshotter](https://github.com/awslabs/soci-snapshotter)
- [nerdctl / containerd](https://github.com/containerd/nerdctl)
- [rules_oci](https://github.com/bazel-contrib/rules_oci)
