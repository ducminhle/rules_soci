"""SOCI image conversion using soci convert.

This rule converts OCI images to SOCI format by:
1. Loading the image tarball into containerd
2. Running soci convert to create SOCI indices
3. Outputting a marker file to track the conversion
"""

load(":toolchain.bzl", "SociToolchainInfo")

SociImageInfo = provider(
    doc = "Information about a SOCI-converted image",
    fields = {
        "repo_tags": "List of repository tags for this image",
        "repo_tags_file": "File containing tags (if using stamped tags)",
    },
)

def _soci_image_impl(ctx):
    """Convert OCI image to SOCI using containerd + soci convert"""

    # Get SOCI toolchain
    toolchain = ctx.toolchains["@rules_soci//soci:toolchain_type"]
    soci_info = toolchain.soci_info
    soci_bin = soci_info.soci_bin

    # Get image tarball
    image = ctx.attr.image
    image_files = image[DefaultInfo].files.to_list()

    if not image_files:
        fail("No files found in image target: {}".format(ctx.attr.image.label))

    if len(image_files) != 1:
        fail("Expected single tarball from image rule, got {} files".format(len(image_files)))

    image_tar = image_files[0]
    if not (image_tar.path.endswith(".tar") or image_tar.path.endswith(".tar.gz")):
        fail("Image must be a .tar or .tar.gz file: {}".format(image_tar.path))

    # Output marker file
    marker = ctx.actions.declare_file(ctx.label.name + ".soci-converted")

    # Build soci convert arguments
    convert_args = []
    if ctx.attr.span_size > 0:
        convert_args.append("--span-size")
        convert_args.append(str(ctx.attr.span_size))
    if ctx.attr.min_layer_size > 0:
        convert_args.append("--min-layer-size")
        convert_args.append(str(ctx.attr.min_layer_size))

    # Determine image references
    repo_tags_list = []
    repo_tags_from_file = False
    tags_file = None

    if ctx.attr.repo_tags and len(ctx.attr.repo_tags) > 0:
        # First tag is the primary destination
        repo_tags_list = ctx.attr.repo_tags
        dest_ref = repo_tags_list[0]
        image_ref = dest_ref + "-based"
        # Additional tags to create
        additional_tags = repo_tags_list[1:]
    elif hasattr(ctx.attr, "repo_tags_file") and ctx.attr.repo_tags_file:
        # Tags will be read from the provided file at execution time
        repo_tags_from_file = True
        tags_file = ctx.file.repo_tags_file
        dest_ref = ""  # will be set in the runtime script from the file
        image_ref = ""
        additional_tags = None
    elif ctx.attr.image_ref:
        repo_tags_list = [ctx.attr.image_ref]
        image_ref = ctx.attr.image_ref
        dest_ref = ctx.attr.image_ref
        additional_tags = []
    else:
        default_tag = "bazel-soci/{}:latest".format(ctx.label.name)
        repo_tags_list = [default_tag]
        image_ref = default_tag
        dest_ref = default_tag
        additional_tags = []

    # Create conversion script
    script = ctx.actions.declare_file(ctx.label.name + "_convert.sh")

    # Build additional tag commands
    tag_commands = ""
    if repo_tags_from_file:
        # When using file, we read tags at runtime and apply them
        tag_commands = (
            'tail -n +2 "$TAGS_FILE" | while read -r tag; do\n' +
            '  [ -z "$tag" ] && continue\n' +
            '  ctr image tag "$DEST_REF" "$tag" >/dev/null 2>&1 || true\n' +
            'done\n' +
            'echo "Tagged from file."\n'
        )
    else:
        if additional_tags:
            for tag in additional_tags:
                tag_commands += 'ctr image tag "$DEST_REF" "{}" >/dev/null 2>&1\n'.format(tag)
            tag_commands += 'echo "Tagged: {}"\n'.format(", ".join(additional_tags))

    # Build script content - different templates for file vs list
    if repo_tags_from_file:
        script_content = """#!/usr/bin/env bash
set -euo pipefail

SOCI="{soci_bin}"
IMAGE_TAR="{image_tar}"
MARKER="{marker}"
TAGS_FILE="{tags_file}"

# Read tags from file
DEST_REF=$(head -n1 "$TAGS_FILE" | tr -d "\\n")
IMAGE_REF="${{DEST_REF}}-based"

echo "Tags file: $TAGS_FILE -> primary: $DEST_REF"
echo "Converting to SOCI: $DEST_REF"

# Check containerd
if ! command -v ctr >/dev/null 2>&1; then
    echo "Error: containerd not found. Install: https://github.com/containerd/containerd/releases"
    exit 1
fi

# Import image
ctr image import "$IMAGE_TAR" >/dev/null 2>&1 || {{
    echo "Error: Failed to import image from $IMAGE_TAR"
    echo "Debugging info:"
    ctr image ls || true
    echo "Image tar exists: $([ -f "$IMAGE_TAR" ] && echo yes || echo no)"
    exit 1
}}

LOADED_IMAGE=$(ctr image ls -q | grep -v "^sha256:" | head -n1 || echo "")
if [ -z "$LOADED_IMAGE" ]; then
    echo "Error: No image found after import"
    exit 1
fi

# Tag for conversion
if [ "$LOADED_IMAGE" != "$IMAGE_REF" ]; then
    ctr image tag "$LOADED_IMAGE" "$IMAGE_REF" >/dev/null 2>&1 || true
fi

# Run soci convert
echo "Running: soci convert {convert_args} $IMAGE_REF $DEST_REF"
if "$SOCI" convert {convert_args} "$IMAGE_REF" "$DEST_REF"; then
    echo "✓ SOCI conversion complete: $DEST_REF"
else
    exit_code=$?
    if [ $exit_code -eq 1 ]; then
        echo "⚠ Warning: No layers met size threshold (min-layer-size: {min_layer_size})"
    else
        echo "Error: SOCI conversion failed"
        exit $exit_code
    fi
fi

# Verify
if ctr image ls -q | grep -q "$DEST_REF"; then
    echo "$DEST_REF" > "$MARKER"
else
    echo "Warning: Image not found after conversion"
    echo "converted" > "$MARKER"
fi

# Create additional tags
{tag_commands}

# Cleanup temp tags
if [ "$IMAGE_REF" != "$DEST_REF" ]; then
    ctr image rm "$IMAGE_REF" >/dev/null 2>&1 || true
fi
if [ "$LOADED_IMAGE" != "$IMAGE_REF" ] && [ "$LOADED_IMAGE" != "$DEST_REF" ]; then
    ctr image rm "$LOADED_IMAGE" >/dev/null 2>&1 || true
fi
""".format(
            soci_bin = soci_bin.path,
            image_tar = image_tar.path,
            marker = marker.path,
            tags_file = tags_file.path,
            convert_args = " ".join(convert_args),
            min_layer_size = ctx.attr.min_layer_size,
            tag_commands = tag_commands,
        )
    else:
        script_content = """#!/usr/bin/env bash
set -euo pipefail

SOCI="{soci_bin}"
IMAGE_TAR="{image_tar}"
MARKER="{marker}"
IMAGE_REF="{image_ref}"
DEST_REF="{dest_ref}"

echo "Converting to SOCI: $DEST_REF"

# Check containerd
if ! command -v ctr >/dev/null 2>&1; then
    echo "Error: containerd not found. Install: https://github.com/containerd/containerd/releases"
    exit 1
fi

# Import image
ctr image import "$IMAGE_TAR" >/dev/null 2>&1 || {{
    echo "Error: Failed to import image from $IMAGE_TAR"
    echo "Debugging info:"
    ctr image ls || true
    echo "Image tar exists: $([ -f "$IMAGE_TAR" ] && echo yes || echo no)"
    exit 1
}}

LOADED_IMAGE=$(ctr image ls -q | grep -v "^sha256:" | head -n1 || echo "")
if [ -z "$LOADED_IMAGE" ]; then
    echo "Error: No image found after import"
    exit 1
fi

# Tag for conversion
if [ "$LOADED_IMAGE" != "$IMAGE_REF" ]; then
    ctr image tag "$LOADED_IMAGE" "$IMAGE_REF" >/dev/null 2>&1 || true
fi

# Run soci convert
echo "Running: soci convert {convert_args} $IMAGE_REF $DEST_REF"
if "$SOCI" convert {convert_args} "$IMAGE_REF" "$DEST_REF"; then
    echo "✓ SOCI conversion complete: $DEST_REF"
else
    exit_code=$?
    if [ $exit_code -eq 1 ]; then
        echo "⚠ Warning: No layers met size threshold (min-layer-size: {min_layer_size})"
    else
        echo "Error: SOCI conversion failed"
        exit $exit_code
    fi
fi

# Verify
if ctr image ls -q | grep -q "$DEST_REF"; then
    echo "$DEST_REF" > "$MARKER"
else
    echo "Warning: Image not found after conversion"
    echo "converted" > "$MARKER"
fi

# Create additional tags
{tag_commands}

# Cleanup temp tags
if [ "$IMAGE_REF" != "$DEST_REF" ]; then
    ctr image rm "$IMAGE_REF" >/dev/null 2>&1 || true
fi
if [ "$LOADED_IMAGE" != "$IMAGE_REF" ] && [ "$LOADED_IMAGE" != "$DEST_REF" ]; then
    ctr image rm "$LOADED_IMAGE" >/dev/null 2>&1 || true
fi
""".format(
            soci_bin = soci_bin.path,
            image_tar = image_tar.path,
            marker = marker.path,
            image_ref = image_ref,
            dest_ref = dest_ref,
            convert_args = " ".join(convert_args),
            min_layer_size = ctx.attr.min_layer_size,
            tag_commands = tag_commands,
        )

    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    # Run conversion
    run_inputs = [image_tar, soci_bin]
    if repo_tags_from_file:
        run_inputs.append(tags_file)

    ctx.actions.run(
        executable = script,
        inputs = run_inputs,
        outputs = [marker],
        mnemonic = "SociConvert",
        progress_message = "Converting %{label} to SOCI",
        execution_requirements = {
            "no-cache": "1",
            "no-remote": "1",
        },
    )

    return [
        DefaultInfo(files = depset([marker])),
        OutputGroupInfo(
            marker = depset([marker]),
        ),
        SociImageInfo(
            repo_tags = repo_tags_list,
            repo_tags_file = tags_file if repo_tags_from_file else None,
        ),
    ]

_soci_image_rule = rule(
    implementation = _soci_image_impl,
    attrs = {
        "image": attr.label(
            mandatory = True,
            doc = "OCI image tarball from oci_tarball or oci_load",
        ),
        "image_ref": attr.string(
            default = "",
            doc = "Fallback image reference for containerd (used if repo_tags not provided)",
        ),
        "repo_tags": attr.string_list(
            default = [],
            doc = """List of repository tags (e.g., ["docker.io/myrepo/app:v1"]).

The first tag is used as the final destination reference.
The conversion process uses a temporary tag (first_tag + "-based") during conversion.
""",
        ),
        "repo_tags_file": attr.label(
            default = None,
            allow_single_file = True,
            doc = """
            A text file (label) containing repository tags, one per line.
            The first line is used as the primary destination tag; subsequent
            lines will be created as additional tags. This allows stamping.
            """,
        ),
        "min_layer_size": attr.int(
            default = 10485760,  # 10MB
            doc = """Minimum layer size (in bytes) to create SOCI index for.

Layers smaller than this will be skipped. Default: 10MB (10485760 bytes).
Adjust this based on your use case:
- Larger values: fewer indices, faster conversion, less lazy-loading benefit
- Smaller values: more indices, slower conversion, more lazy-loading benefit
""",
        ),
        "span_size": attr.int(
            default = 4194304,  # 4MB
            doc = """Span size (in bytes) for ztoc generation.

This controls the granularity of lazy loading. Default: 4MB (4194304 bytes).
- Smaller spans: more granular loading, more metadata overhead
- Larger spans: less granular loading, less metadata overhead
""",
        ),
    },
    toolchains = ["@rules_soci//soci:toolchain_type"],
    doc = """Convert an OCI image to SOCI format for lazy loading.

This rule takes an OCI image tarball (typically from oci_tarball) and converts it to
SOCI format by creating seekable indices (ztoc) for large layers. The resulting image
can be pushed to a registry and used with soci-snapshotter for lazy loading.

Example:
    load("@rules_oci//oci:defs.bzl", "oci_image", "oci_tarball")
    load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

    oci_image(
        name = "app",
        base = "@distroless_base",
        entrypoint = ["/app"],
    )

    oci_load(
        name = "app_load",
        image = ":app",
        repo_tags = ["app:v1"],
    )

    filegroup(
        name = "app_tarball",
        srcs = [":app_load"],
        output_group = "tarball",
    )

    soci_image(
        name = "app_soci",
        image = ":app_tarball",
        repo_tags = ["docker.io/myuser/app:v1", "docker.io/myuser/app:latest"],
    )

    soci_push(
        name = "app_soci_push",
        soci_image = ":app_soci",
        # Automatically pushes all repo_tags from app_soci
    )

Usage:
    bazel build //:app_soci     # Convert to SOCI
    bazel run //:app_soci_push  # Push to registry
""",
)


def soci_image(name, image, image_ref = "", repo_tags = None, min_layer_size = 10485760, span_size = 4194304):
    """Convert an OCI image to SOCI format for lazy loading.

    Takes an OCI image tarball and converts it to SOCI format by creating seekable indices
    (ztoc) for large layers. The resulting image can be pushed to a registry and used with
    soci-snapshotter for lazy loading.

    The `repo_tags` parameter is flexible and accepts either a list of strings or a label
    to a tags file (for stamped builds).

    Example:
        load("@rules_oci//oci:defs.bzl", "oci_image", "oci_tarball")
        load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

        oci_image(
            name = "app",
            base = "@distroless_base",
            entrypoint = ["/app"],
        )

        oci_load(
            name = "app_load",
            image = ":app",
            repo_tags = ["app:v1"],
        )

        filegroup(
            name = "app_tarball",
            srcs = [":app_load"],
            output_group = "tarball",
        )

        soci_image(
            name = "app_soci",
            image = ":app_tarball",
            repo_tags = ["docker.io/myuser/app:v1", "docker.io/myuser/app:latest"],
        )

        soci_push(
            name = "app_soci_push",
            soci_image = ":app_soci",
        )

    Usage:
        bazel build //:app_soci     # Convert to SOCI
        bazel run //:app_soci_push  # Push to registry

    For stamped tags (via file):
        soci_image(
            name = "app_soci",
            image = ":app_tarball",
            repo_tags = ":stamped_tags",
        )

    Args:
        name: A unique name for this target.
        image: OCI image tarball from oci_tarball or oci_load.
        image_ref: Fallback image reference for containerd.
        repo_tags: Repository tags (list or label to tags file).
        min_layer_size: Minimum layer size in bytes. Default: 10485760 (10MB).
        span_size: Span size in bytes for ztoc. Default: 4194304 (4MB).
    """
    if repo_tags == None:
        repo_tags = []

    # Detect if repo_tags is a label (stamped file) or a list
    if type(repo_tags) == "list":
        return _soci_image_rule(
            name = name,
            image = image,
            image_ref = image_ref,
            repo_tags = repo_tags,
            min_layer_size = min_layer_size,
            span_size = span_size,
        )
    else:
        # Treat as a label to a tags file
        return _soci_image_rule(
            name = name,
            image = image,
            image_ref = image_ref,
            repo_tags_file = repo_tags,
            min_layer_size = min_layer_size,
            span_size = span_size,
        )
