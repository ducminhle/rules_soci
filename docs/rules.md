# rules_soci API Reference

## Table of Contents

- [soci_image](#soci_image)
- [soci_push](#soci_push)
- [soci_load](#soci_load)
- [Toolchain Extension](#toolchain-extension)

---

## soci_image

Convert an OCI image to SOCI format with lazy-loading indices.

### Synopsis

```starlark
load("@rules_soci//soci:defs.bzl", "soci_image")

soci_image(
    name = "my_app_soci",
    image = ":my_app",
    min_layer_size = 10485760,
    span_size = 4194304,
    platform = "linux/amd64",
)
```

### Attributes

#### name

(`Name`; required)

A unique name for this target.

#### image

(`Label`; required)

The OCI image to convert. Must be an output from `oci_image` or `oci_load` from rules_oci.

#### min_layer_size

(`Integer`; optional; default: `10485760`)

Minimum layer size in bytes to create SOCI indices for. Layers smaller than this are skipped.

**Recommendations:**
- Small layers (<5MB each): Use 1MB (`1048576`)
- Medium layers (5-50MB): Use 10MB (`10485760`) - default
- Large layers (>50MB): Use 20MB (`20971520`)

#### span_size

(`Integer`; optional; default: `4194304`)

Size of each span in the ztoc file, in bytes. This controls the granularity of lazy-loading.

**Recommendations:**
- Small images (<100MB): Use 1MB (`1048576`)
- Medium images (100MB-1GB): Use 4MB (`4194304`) - default
- Large images (>1GB): Use 8-16MB (`8388608` - `16777216`)

#### platform

(`String`; optional; default: `""`)

Target platform for the image in format `os/arch`. Common values:
- `linux/amd64`
- `linux/arm64`
- `linux/arm/v7`

If not specified, SOCI will attempt to detect the platform from the image.

### Outputs

Creates a directory containing SOCI artifacts:
- `*.soci.index` - SOCI index file
- `*.ztoc` - Zero-copy table of contents for each layer

### Example

```starlark
load("@rules_oci//oci:defs.bzl", "oci_image")
load("@rules_soci//soci:defs.bzl", "soci_image")

oci_image(
    name = "app",
    base = "@distroless_base",
    entrypoint = ["/app/server"],
    tars = [":app_layer"],
)

# Basic usage
soci_image(
    name = "app_soci",
    image = ":app",
)

# With custom parameters
soci_image(
    name = "app_soci_optimized",
    image = ":app",
    min_layer_size = 20971520,  # 20MB
    span_size = 8388608,        # 8MB
    platform = "linux/amd64",
)
```

---

## soci_push

Push SOCI artifacts to a container registry.

### Synopsis

```starlark
load("@rules_soci//soci:defs.bzl", "soci_push")

soci_push(
    name = "push_my_app_soci",
    image = ":my_app",
    soci_artifacts = ":my_app_soci",
    image_ref = "registry.io/myorg/myapp:v1.0.0",
)
```

### Attributes

#### name

(`Name`; required)

A unique name for this target.

#### image

(`Label`; required)

The original OCI image. This is used to ensure the image is pushed before SOCI artifacts.

#### soci_artifacts

(`Label`; required; accepts single file)

SOCI artifacts directory from `soci_image` rule.

#### image_ref

(`String`; required)

Full image reference including registry, repository, and tag.

Format: `[REGISTRY/]REPOSITORY[:TAG|@DIGEST]`

Examples:
- `docker.io/myorg/myapp:latest`
- `ghcr.io/myorg/myapp:v1.0.0`
- `123456789.dkr.ecr.us-west-2.amazonaws.com/myapp:prod`

### Usage

This rule creates an executable target. Run it with `bazel run`:

```bash
bazel run //:push_my_app_soci
```

### Prerequisites

Before running `soci_push`, ensure:

1. The OCI image has been pushed to the registry
2. You are authenticated to the registry
3. You have push permissions

```bash
# Example: Docker Hub
docker login

# Example: GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Example: AWS ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-west-2.amazonaws.com
```

### Example

```starlark
load("@rules_oci//oci:defs.bzl", "oci_image", "oci_push")
load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

oci_image(
    name = "app",
    base = "@distroless_base",
    entrypoint = ["/app/main"],
)

soci_image(
    name = "app_soci",
    image = ":app",
)

# Push OCI image first
oci_push(
    name = "push_app",
    image = ":app",
    repository = "ghcr.io/myorg/myapp",
    remote_tags = ["latest"],
)

# Then push SOCI artifacts
soci_push(
    name = "push_app_soci",
    image = ":app",
    soci_artifacts = ":app_soci",
    image_ref = "ghcr.io/myorg/myapp:latest",
)
```

**Usage:**

```bash
# Push image
bazel run //:push_app

# Push SOCI artifacts
bazel run //:push_app_soci
```

---

## soci_load

Load an OCI tarball and convert to SOCI format in one step.

### Synopsis

```starlark
load("@rules_soci//soci:defs.bzl", "soci_load")

soci_load(
    name = "imported_image_soci",
    tarball = "external_image.tar",
    platform = "linux/amd64",
)
```

### Attributes

#### name

(`Name`; required)

A unique name for this target.

#### tarball

(`Label`; required; accepts `.tar` or `.tar.gz`)

Path to an OCI image tarball. Can be a `.tar` or `.tar.gz` file.

#### min_layer_size

(`Integer`; optional; default: `10485760`)

Same as [soci_image.min_layer_size](#min_layer_size).

#### span_size

(`Integer`; optional; default: `4194304`)

Same as [soci_image.span_size](#span_size).

#### platform

(`String`; optional; default: `""`)

Same as [soci_image.platform](#platform).

### Example

```starlark
load("@rules_soci//soci:defs.bzl", "soci_load")

# Load and convert external tarball
soci_load(
    name = "third_party_soci",
    tarball = "@third_party_image//file",
    platform = "linux/amd64",
)

# With custom parameters
soci_load(
    name = "large_image_soci",
    tarball = "large_image.tar.gz",
    min_layer_size = 52428800,  # 50MB
    span_size = 16777216,       # 16MB
    platform = "linux/arm64",
)
```

---

## Toolchain Extension

Configure SOCI toolchain version in `MODULE.bazel`.

### Synopsis

```starlark
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    name = "soci",
    version = "0.12.1",
)
use_repo(soci, "soci_toolchains")
```

### Tag: toolchain

#### name

(`String`; optional; default: `"soci"`)

Name for the toolchain. Usually left as default.

#### version

(`String`; optional; default: `"0.12.1"`)

SOCI version to use. Available versions are listed in `soci/versions.bzl`.

**Supported versions:**
- `0.12.1` (default, recommended)

### Example

```starlark
module(name = "my_project", version = "1.0.0")

bazel_dep(name = "rules_soci", version = "0.1.0")

# Use specific SOCI version
soci = use_extension("@rules_soci//soci:extensions.bzl", "soci")
soci.toolchain(
    name = "soci",
    version = "0.12.1",
)
use_repo(soci, "soci_toolchains")
```

---

## Common Patterns

### Multi-platform Builds

```starlark
platforms = ["linux/amd64", "linux/arm64"]

[
    oci_image(
        name = "app_%s" % platform.replace("/", "_"),
        base = "@distroless_base",
        entrypoint = ["/app/main"],
    )
    for platform in platforms
]

[
    soci_image(
        name = "app_%s_soci" % platform.replace("/", "_"),
        image = ":app_%s" % platform.replace("/", "_"),
        platform = platform,
    )
    for platform in platforms
]
```

### CI/CD Pipeline

```starlark
# Build
oci_image(name = "app", ...)
soci_image(name = "app_soci", image = ":app")

# Push
oci_push(name = "push", image = ":app", ...)
soci_push(name = "push_soci", image = ":app", soci_artifacts = ":app_soci", ...)

# Alias for convenience
alias(name = "push_all", actual = select({
    "//conditions:default": ":push_soci",
}))
```

**Usage:**

```bash
bazel run //:push_all
```

### Optimizing Large Images

```starlark
soci_image(
    name = "large_app_soci",
    image = ":large_app",
    # Only index layers > 50MB
    min_layer_size = 52428800,
    # Larger spans for better performance
    span_size = 16777216,
    platform = "linux/amd64",
)
```

---

## Performance Tuning

### Choosing min_layer_size

| Image Type | Total Size | Layer Sizes | Recommended min_layer_size |
|------------|------------|-------------|---------------------------|
| Microservice | <100MB | 1-10MB | 1MB (`1048576`) |
| Web app | 100-500MB | 10-50MB | 10MB (`10485760`) |
| ML model | 500MB-2GB | 50-500MB | 20MB (`20971520`) |
| Data processing | >2GB | >500MB | 50MB (`52428800`) |

### Choosing span_size

| Image Size | Recommended span_size | Rationale |
|------------|--------------------|-----------|
| <100MB | 1MB (`1048576`) | Small metadata, faster builds |
| 100MB-1GB | 4MB (`4194304`) | Balanced |
| >1GB | 8-16MB (`8388608`-`16777216`) | Reduce metadata size |

### Build Time vs Runtime

- **Smaller spans** = Longer builds + Better lazy-loading
- **Larger spans** = Faster builds + Less granular loading

Choose based on your priorities:
- **Development**: Larger spans (faster builds)
- **Production**: Smaller spans (better performance)

---

## Troubleshooting

See [README.md#troubleshooting](../README.md#troubleshooting) for common issues and solutions.
