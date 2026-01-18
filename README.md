# rules_soci

Bazel rules for converting OCI container images to [SOCI (Seekable OCI)](https://github.com/awslabs/soci-snapshotter) images ([SOCI Index Manifest v2](https://github.com/awslabs/soci-snapshotter/blob/main/docs/soci-index-manifest-v2.md)) with lazy-loading indices.

## Quick Start
### Requirements

- Bazel 8.5.0+
- Bzlmod enabled
- [containerd](https://github.com/containerd/containerd) installed and running (for image conversion)
- Linux host (SOCI is Linux-only)

### Installation

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_soci", version = "0.1.0")

# Configure SOCI extension
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    soci_version = "0.12.1",    # Optional, defaults to 0.12.1
    crane_version = "0.20.7",   # Optional, defaults to 0.20.7
)
use_repo(soci, "soci_toolchains")

# Register toolchains
register_toolchains("@soci_toolchains//:all")
```

## Usage

### Basic Example

```starlark
load("@rules_oci//oci:defs.bzl", "oci_image")
load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

# Build OCI image
oci_image(
    name = "app",
    base = "@distroless_base",
    entrypoint = ["/app"],
    cmd = ["--port=8080"],
)

oci_load(
    name = "app_load",
    image = ":app",
    repo_tags = ["myapp:latest"],
)

filegroup(
    name = "app_tarball",
    srcs = [":app_load"],
    output_group = "tarball",
)

# Convert to SOCI format
soci_image(
    name = "app_soci",
    image = ":app_tarball",
    repo_tags = [
        "docker.io/myuser/app:latest",
        "docker.io/myuser/app:v1.0.0",
    ],
)

# Push to registry
soci_push(
    name = "soci_push",
    soci_image = ":app_soci",
    # repo_tags automatically inherited from app_soci
)
```

### BuildX Example
- [BuildX](./examples/buildx/)

### Build and Push

```bash
# Convert image to SOCI format
bazel build //:app_soci

# Push to registry (requires docker login)
docker login docker.io
bazel run //:soci_push
```

## Rules

### `soci_image`

Converts an OCI image tarball to SOCI format.

**Attributes:**

- `image` (required): OCI image tarball from `oci_load`
- `repo_tags` (optional): List of repository tags (e.g., `["docker.io/user/app:v1.0.0", "docker.io/user/app:latest"]`)
- `min_layer_size` (optional, default: 10MB): Minimum layer size in bytes to create SOCI index for
- `span_size` (optional, default: 4MB): Span size in bytes for ztoc generation

**Example:**

```starlark
soci_image(
    name = "app_soci",
    image = ":app_tarball",
    repo_tags = ["docker.io/myuser/app:latest"],
    min_layer_size = 10485760,  # 10MB
    span_size = 4194304,        # 4MB
)
```

### `soci_push`

Pushes SOCI-enabled images to a container registry.

**Attributes:**

- `soci_image` (required): SOCI marker file from `soci_image` rule
- `repo_tags` (optional): List of image references to push. If not specified, inherits from `soci_image`

**Example:**

```starlark
soci_push(
    name = "push",
    soci_image = ":app_soci",
)

# Override with specific tags
soci_push(
    name = "push_prod",
    soci_image = ":app_soci",
    repo_tags = ["docker.io/myuser/app:prod"],
)
```

## Advanced Configuration

### Multiple Tags

Create and push multiple tags in one go:

```python
soci_image(
    name = "app_soci",
    image = ":app_tarball",
    repo_tags = [
        "docker.io/myuser/app:latest",
        "docker.io/myuser/app:v1.0.0",
        "docker.io/myuser/app:stable",
    ],
)

soci_push(
    name = "push_all",
    soci_image = ":app_soci",
    # Pushes all three tags
)
```

### Performance Tuning

For large images (1GB+), adjust layer size thresholds:

```python
soci_image(
    name = "large_app_soci",
    image = ":large_app_tarball",
    min_layer_size = 52428800,  # 50MB - skip smaller layers
    span_size = 8388608,         # 8MB - larger spans for big layers
)
```

For more granular lazy loading:

```python
soci_image(
    name = "fine_grained_soci",
    image = ":app_tarball",
    min_layer_size = 5242880,   # 5MB - index more layers
    span_size = 1048576,        # 1MB - smaller spans
)
```

## How it Works

1. **Image Conversion**: `soci_image` loads your OCI tarball into containerd and runs `soci convert` to create SOCI indices (ztoc files) for layers larger than `min_layer_size`

2. **Multi-tagging**: Additional tags specified in `repo_tags` are created in containerd

3. **Push**: `soci_push` exports the SOCI-enabled image from containerd and uses `crane` to push it to the registry with authentication from `~/.docker/config.json`

## Troubleshooting

### containerd not found

```
Error: containerd not found
```

Install containerd:
- Ubuntu/Debian: `sudo apt install containerd`
- macOS: `brew install containerd` (note: SOCI only works on Linux)
- Or download from: https://github.com/containerd/containerd/releases

### Authentication failed

```
Error: unexpected status code 401 Unauthorized
```

Login to your registry first:
```bash
docker login docker.io
# or
docker login ghcr.io
```

### No layers converted

```
Warning: No layers met size threshold
```

All layers in your image are smaller than `min_layer_size`. Either:
- Lower `min_layer_size` value
- This is expected for small images - SOCI benefits larger images more

## Documentation

Generate API documentation:

```bash
# Update all docs
bazel run //docs:update

# Test docs are up-to-date
bazel test //docs:all
```

## Contributing

Contributions welcome! Please:

1. Run tests: `bazel test //...`
2. Update docs: `bazel run //docs:update`

## License

[Apache 2.0](./LICENSE)

## Credits

- [SOCI Snapshotter](https://github.com/awslabs/soci-snapshotter) by AWS
- [crane](https://github.com/google/go-containerregistry) by Google
- [rules_oci](https://github.com/bazel-contrib/rules_oci) for OCI image building
