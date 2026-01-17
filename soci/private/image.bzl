"""SOCI image conversion using nerdctl image convert --soci.

This rule converts OCI images to SOCI format by:
1. Loading the image tarball into containerd via nerdctl
2. Running nerdctl image convert --soci to create SOCI indices
3. Outputting a marker file to track the conversion
"""

SociImageInfo = provider(
    doc = "Information about a SOCI-converted image",
    fields = {
        "repo_tags": "List of repository tags for this image",
        "repo_tags_file": "File containing tags (if using stamped tags)",
    },
)

def _soci_image_impl(ctx):
    """Convert OCI image to SOCI using nerdctl image convert --soci"""

    # Get SOCI toolchain (we still need it for compatibility, but won't use soci binary)
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

    # Build nerdctl image convert arguments
    convert_args = ["--soci"]

    # Only add span_size if user explicitly provided it (not default -1)
    if ctx.attr.span_size > 0:
        convert_args.append("--soci-span-size")
        convert_args.append(str(ctx.attr.span_size))

    # Only add min_layer_size if user explicitly provided it (not default -1)
    if ctx.attr.min_layer_size > 0:
        convert_args.append("--soci-min-layer-size")
        convert_args.append(str(ctx.attr.min_layer_size))

    # Determine image references
    repo_tags_list = []
    repo_tags_from_file = False
    tags_file = None

    if ctx.attr.repo_tags and len(ctx.attr.repo_tags) > 0:
        repo_tags_list = ctx.attr.repo_tags
        dest_ref = repo_tags_list[0]
        additional_tags = repo_tags_list[1:]
    elif hasattr(ctx.attr, "repo_tags_file") and ctx.attr.repo_tags_file:
        repo_tags_from_file = True
        tags_file = ctx.file.repo_tags_file
        dest_ref = ""
        additional_tags = None
    elif ctx.attr.image_ref:
        repo_tags_list = [ctx.attr.image_ref]
        dest_ref = ctx.attr.image_ref
        additional_tags = []
    else:
        default_tag = "bazel-soci/{}:latest".format(ctx.label.name)
        repo_tags_list = [default_tag]
        dest_ref = default_tag
        additional_tags = []

    # Create conversion script
    script = ctx.actions.declare_file(ctx.label.name + "_convert.sh")

    # Convert args to string
    convert_args_str = " ".join(convert_args)

    # Build script content
    if repo_tags_from_file:
        script_content = """#!/usr/bin/env bash
set -euo pipefail

# Set HOME for nerdctl (required in Bazel sandbox)
export HOME="${{HOME:-/tmp}}"

# Set XDG_RUNTIME_DIR for rootless containerd if not set
if [ -z "${{XDG_RUNTIME_DIR:-}}" ]; then
    if [ -d "/run/user/$(id -u)" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    elif [ -d "$HOME/.local/share/containerd" ]; then
        export XDG_RUNTIME_DIR="$HOME/.local/share/containerd"
    else
        export XDG_RUNTIME_DIR="/tmp/run-$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR"
    fi
fi

# Add soci binary to PATH so nerdctl can find it
SOCI_DIR="$PWD/$(dirname {soci_bin})"
export PATH="$SOCI_DIR:$PATH"

IMAGE_TAR="{image_tar}"
MARKER="{marker}"
TAGS_FILE="{tags_file}"

# Read tags from file
DEST_REF=$(head -n1 "$TAGS_FILE" | tr -d "\\n\\r")

if [ -z "$DEST_REF" ]; then
    echo "Error: Tags file is empty"
    exit 1
fi

echo "Converting to SOCI: $DEST_REF"

# Check for nerdctl
if ! command -v nerdctl >/dev/null 2>&1; then
    echo "Error: nerdctl not found. Install: https://github.com/containerd/nerdctl/releases"
    exit 1
fi

# Import image
echo "Importing image..."
if ! nerdctl load -i "$IMAGE_TAR"; then
    echo "Error: Failed to import image"
    exit 1
fi

# Get loaded image - use actual name from nerdctl
LOADED_IMAGE=$(nerdctl images --format '{{{{.Repository}}}}:{{{{.Tag}}}}' | head -n1 || echo "")
if [ -z "$LOADED_IMAGE" ]; then
    echo "Error: No image found after import"
    nerdctl images
    exit 1
fi

echo "Loaded image: $LOADED_IMAGE"

# Run nerdctl image convert --soci
echo "Running: nerdctl image convert {convert_args} $LOADED_IMAGE $DEST_REF"
if ! nerdctl image convert {convert_args} "$LOADED_IMAGE" "$DEST_REF"; then
    echo "Error: SOCI conversion failed"
    exit 1
fi

echo "✓ SOCI conversion complete: $DEST_REF"

# Verify image exists
if nerdctl images --quiet "$DEST_REF" 2>/dev/null | grep -q .; then
    echo "$DEST_REF" > "$MARKER"
    echo "✓ Image verified: $DEST_REF"
else
    echo "Error: Image not found after conversion"
    exit 1
fi

# Create additional tags
tail -n +2 "$TAGS_FILE" | while read -r tag; do
    [ -z "$tag" ] && continue
    tag=$(echo "$tag" | tr -d "\\n\\r")
    nerdctl tag "$DEST_REF" "$tag" || true
    echo "  Tagged: $tag"
done

# Cleanup source image if different from dest
if [ "$LOADED_IMAGE" != "$DEST_REF" ]; then
    nerdctl rmi "$LOADED_IMAGE" >/dev/null 2>&1 || true
fi

echo "Done."
""".format(
            soci_bin = soci_bin.path,
            image_tar = image_tar.path,
            marker = marker.path,
            tags_file = tags_file.path,
            convert_args = convert_args_str,
        )
    else:
        # Build additional tag commands
        tag_commands = ""
        if additional_tags:
            for tag in additional_tags:
                tag_commands += 'nerdctl tag "$DEST_REF" "{}" || true\n'.format(tag)
                tag_commands += 'echo "  Tagged: {}"\n'.format(tag)

        script_content = """#!/usr/bin/env bash
set -euo pipefail

# Set HOME for nerdctl (required in Bazel sandbox)
export HOME="${{HOME:-/tmp}}"

# Set XDG_RUNTIME_DIR for rootless containerd if not set
if [ -z "${{XDG_RUNTIME_DIR:-}}" ]; then
    if [ -d "/run/user/$(id -u)" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    elif [ -d "$HOME/.local/share/containerd" ]; then
        export XDG_RUNTIME_DIR="$HOME/.local/share/containerd"
    else
        export XDG_RUNTIME_DIR="/tmp/run-$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR"
    fi
fi

# Add soci binary to PATH so nerdctl can find it
SOCI_DIR="$PWD/$(dirname {soci_bin})"
export PATH="$SOCI_DIR:$PATH"

IMAGE_TAR="{image_tar}"
MARKER="{marker}"
DEST_REF="{dest_ref}"

echo "Converting to SOCI: $DEST_REF"

# Check for nerdctl
if ! command -v nerdctl >/dev/null 2>&1; then
    echo "Error: nerdctl not found. Install: https://github.com/containerd/nerdctl/releases"
    exit 1
fi

# Import image
echo "Importing image..."
if ! nerdctl load -i "$IMAGE_TAR"; then
    echo "Error: Failed to import image"
    exit 1
fi

# Get loaded image - use actual name from nerdctl
LOADED_IMAGE=$(nerdctl images --format '{{{{.Repository}}}}:{{{{.Tag}}}}' | head -n1 || echo "")
if [ -z "$LOADED_IMAGE" ]; then
    echo "Error: No image found after import"
    exit 1
fi

echo "Loaded image: $LOADED_IMAGE"

# Run nerdctl image convert --soci
echo "Running: nerdctl image convert {convert_args} $LOADED_IMAGE $DEST_REF"
if ! nerdctl image convert {convert_args} "$LOADED_IMAGE" "$DEST_REF"; then
    echo "Error: SOCI conversion failed"
    exit 1
fi

echo "✓ SOCI conversion complete: $DEST_REF"

# Verify
if nerdctl images --quiet "$DEST_REF" 2>/dev/null | grep -q .; then
    echo "$DEST_REF" > "$MARKER"
    echo "✓ Image verified: $DEST_REF"
else
    echo "Error: Image not found after conversion"
    exit 1
fi

# Create additional tags
{tag_commands}

# Cleanup source image if different from dest
if [ "$LOADED_IMAGE" != "$DEST_REF" ]; then
    nerdctl rmi "$LOADED_IMAGE" >/dev/null 2>&1 || true
fi

echo "Done."
""".format(
            soci_bin = soci_bin.path,
            image_tar = image_tar.path,
            marker = marker.path,
            dest_ref = dest_ref,
            convert_args = convert_args_str,
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

    # Note: we need soci_bin because nerdctl calls soci internally

    ctx.actions.run(
        executable = script,
        inputs = run_inputs,
        outputs = [marker],
        mnemonic = "SociConvert",
        progress_message = "Converting %{label} to SOCI",
        env = {
            "HOME": "/tmp",
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        },
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
            doc = "Fallback image reference for containerd",
        ),
        "repo_tags": attr.string_list(
            default = [],
            doc = "List of repository tags",
        ),
        "repo_tags_file": attr.label(
            default = None,
            allow_single_file = True,
            doc = "File containing repository tags (one per line)",
        ),
        "min_layer_size": attr.int(
            default = -1,
            doc = "Minimum layer size in bytes. If not set (default -1), nerdctl will use SOCI's default and process all layers.",
        ),
        "span_size": attr.int(
            default = -1,
            doc = "Span size in bytes for ztoc. If not set (default -1), nerdctl will use SOCI's default (typically 4MB).",
        ),
    },
    toolchains = ["@rules_soci//soci:toolchain_type"],
    doc = """Convert OCI image to SOCI format using nerdctl image convert --soci.

By default, this rule does NOT set min_layer_size or span_size, allowing SOCI
to use its own defaults and process all layers.
""",
)

def soci_image(name, image, image_ref = "", repo_tags = None, min_layer_size = -1, span_size = -1):
    """Convert OCI image to SOCI format using nerdctl.

    Args:
        name: Target name
        image: OCI image tarball
        image_ref: Fallback image reference
        repo_tags: List of tags or label to tags file
        min_layer_size: Minimum layer size in bytes (-1 = use SOCI default)
        span_size: Span size in bytes (-1 = use SOCI default)

    Returns:
        The configured rule target created by this macro (the result of
        calling the underlying `_soci_image_rule`). The target provides a
        SOCI marker file and the `SociImageInfo` provider.
    """
    if repo_tags == None:
        repo_tags = []

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
        return _soci_image_rule(
            name = name,
            image = image,
            image_ref = image_ref,
            repo_tags_file = repo_tags,
            min_layer_size = min_layer_size,
            span_size = span_size,
        )
