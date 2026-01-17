# rules_soci

Bazel rules for creating [SOCI (Seekable OCI)](https://github.com/awslabs/soci-snapshotter) images with lazy-loading indices.

## Quick Start

### Installation

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_soci", version = "0.1.0")

# Optional: specify SOCI version
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    name = "soci",
    version = "0.12.1",
)
use_repo(soci, "soci_toolchains")
```

### Usage

```starlark
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_push")
load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

# Build OCI image
oci_image(
    name = "app",
    base = "@distroless_base",
    entrypoint = ["/app/main"],
    tars = [":app_layer"],
)

# Convert to SOCI
soci_image(
    name = "app_soci",
    image = ":app",
    platform = "linux/amd64",
)

# Push image
oci_push(
    name = "push",
    image = ":app",
    repository = "myregistry.io/myapp",
)

# Push SOCI artifacts
soci_push(
    name = "push_soci",
    image = ":app",
    soci_artifacts = ":app_soci",
    image_ref = "myregistry.io/myapp:latest",
)
```

Build and push:

```bash
bazel run //:push
bazel run //:push_soci
```

## Rules

### soci_image

Convert an OCI image to SOCI format.

**Attributes:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `image` | `label` | required | OCI image target |
| `min_layer_size` | `int` | 10485760 (10MB) | Minimum layer size to index |
| `span_size` | `int` | 4194304 (4MB) | Span size for ztoc |
| `platform` | `string` | `""` | Target platform |

**Example:**

```starlark
soci_image(
    name = "myapp_soci",
    image = ":myapp",
    min_layer_size = 20971520,  # 20MB
    span_size = 8388608,        # 8MB
    platform = "linux/amd64",
)
```

### soci_push

Push SOCI artifacts to a registry.

**Attributes:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `image` | `label` | required | OCI image target |
| `soci_artifacts` | `label` | required | SOCI artifacts from soci_image |
| `image_ref` | `string` | required | Full image reference |

**Example:**

```starlark
soci_push(
    name = "push_myapp_soci",
    image = ":myapp",
    soci_artifacts = ":myapp_soci",
    image_ref = "ghcr.io/myorg/myapp:v1.0.0",
)
```

### soci_load

Load a tarball and convert to SOCI.

**Attributes:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `tarball` | `label` | required | OCI tarball (.tar or .tar.gz) |
| `min_layer_size` | `int` | 10485760 | Minimum layer size |
| `span_size` | `int` | 4194304 | Span size |
| `platform` | `string` | `""` | Target platform |

**Example:**

```starlark
soci_load(
    name = "imported_soci",
    tarball = "external_image.tar",
    platform = "linux/arm64",
)
```

## Configuration

### Toolchain Version

Specify SOCI version in MODULE.bazel:

```starlark
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    name = "soci",
    version = "0.12.1",  # or other supported version
)
```

### Supported Versions

- `0.12.1` (default, recommended)

### Platform Support

| Platform | Status |
|----------|--------|
| Linux AMD64 | ✅ Supported |
| Linux ARM64 | ✅ Supported |
| macOS Intel | ✅ Supported |
| macOS Apple Silicon | ✅ Supported |

## Examples

### Multi-platform Images

```starlark
# AMD64
oci_image(
    name = "app_amd64",
    base = "@distroless_base",
    entrypoint = ["/app/main"],
    tars = [":app_layer"],
)

soci_image(
    name = "app_amd64_soci",
    image = ":app_amd64",
    platform = "linux/amd64",
)

# ARM64
oci_image(
    name = "app_arm64",
    base = "@distroless_base",
    entrypoint = ["/app/main"],
    tars = [":app_layer"],
)

soci_image(
    name = "app_arm64_soci",
    image = ":app_arm64",
    platform = "linux/arm64",
)
```

### With Custom Parameters

```starlark
soci_image(
    name = "large_app_soci",
    image = ":large_app",
    min_layer_size = 52428800,  # 50MB - for very large layers
    span_size = 16777216,       # 16MB - for better lazy-loading
    platform = "linux/amd64",
)
```

## Performance

SOCI can significantly reduce container startup time:

- **Small images** (<100MB): Minimal benefit
- **Medium images** (100MB-1GB): 30-50% faster startup
- **Large images** (>1GB): 50-80% faster startup

### Tuning

- **min_layer_size**: Only index layers larger than this
  - Smaller = more indices = more storage
  - Larger = fewer indices = less benefit
  - Default 10MB works for most cases

- **span_size**: Granularity of lazy-loading chunks
  - Smaller = more granular = better lazy-loading = larger metadata
  - Larger = less granular = faster builds = smaller metadata
  - Default 4MB works for most cases

## Troubleshooting

### SHA256 Mismatch

If you get SHA256 errors, the version registry may need updating.

**Solution:** File an issue or update `soci/versions.bzl` manually:

```bash
curl -L <SOCI_URL> | sha256sum
```

### Platform Not Detected

**Verify platform:**

```bash
bazel info execution_platform
```

**Force specific platform:**

```bash
bazel build --platforms=@platforms//os:linux //:app_soci
```

### SOCI Binary Not Found

**Test toolchain:**

```bash
bazel query @soci_toolchains//...
```

## Development

### Repository Structure

```
rules_soci/
├── MODULE.bazel
├── soci/
│   ├── BUILD.bazel
│   ├── defs.bzl           # Public API
│   ├── extensions.bzl     # Bzlmod extension
│   ├── versions.bzl       # Version registry
│   └── private/
│       ├── BUILD.bazel
│       ├── toolchain.bzl  # Toolchain definition
│       ├── image.bzl      # soci_image rule
│       └── push.bzl       # soci_push rule
├── docs/
│   └── rules.md
└── examples/
    └── simple/
        ├── MODULE.bazel
        └── BUILD.bazel
```

### Adding New SOCI Versions

1. Update `soci/versions.bzl`:

```starlark
SOCI_VERSIONS = {
    "0.13.0": {
        "linux_amd64": {
            "url": "https://github.com/.../soci-snapshotter-0.13.0-linux-amd64.tar.gz",
            "sha256": "...",
            "strip_prefix": "soci-snapshotter-0.13.0-linux-amd64",
        },
        # ... other platforms
    },
}
```

2. Update DEFAULT_VERSION if needed

3. Test:

```bash
bazel test //...
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## License

Apache 2.0

## Credits

- [SOCI Snapshotter](https://github.com/awslabs/soci-snapshotter) by AWS
- Inspired by [rules_oci](https://github.com/bazel-contrib/rules_oci)
