"""SOCI image conversion using `soci convert --standalone`.

This rule converts OCI images to SOCI format without touching containerd:
1. Runs `soci convert --standalone --format oci-dir` directly on the OCI
   image layout tarball/directory produced by rules_oci.
2. Outputs an OCI-layout directory that contains the original image plus
   the SOCI index (SOCI Index Manifest v2), ready to be pushed with
   `crane push` (see push.bzl).

No nerdctl, no containerd daemon, no sudo. This also means the action is
sandboxable/remote-cacheable, so the old `no-cache`/`no-remote` execution
requirements are gone.

NOTE: the `image` attribute MUST be an OCI-layout tarball or directory
(e.g. `oci_tarball(format = "oci", ...)` or the directory produced
directly by `oci_image`). Docker-style tarballs (`docker save`,
`oci_tarball(format = "docker", ...)`) are NOT compatible with
`soci convert --standalone` -- see soci-snapshotter docs on standalone mode.
"""

SociImageInfo = provider(
    doc = "Information about a SOCI-converted image",
    fields = {
        "soci_layout": "Directory (OCI image layout) containing the SOCI-converted image",
        "repo_tags": "List of repository tags to use when pushing this image",
        "repo_tags_file": "File containing tags (if using stamped tags), one per line",
    },
)

def _soci_image_impl(ctx):
    """Convert OCI image to SOCI using `soci convert --standalone`."""

    toolchain = ctx.toolchains["@rules_soci//soci:toolchain_type"]
    soci_info = toolchain.soci_info
    soci_bin = soci_info.soci_bin

    # Get image input (OCI-layout tarball or directory)
    image = ctx.attr.image
    image_files = image[DefaultInfo].files.to_list()

    if not image_files:
        fail("No files found in image target: {}".format(ctx.attr.image.label))

    if len(image_files) != 1:
        fail("Expected single tarball/directory from image rule, got {} files".format(len(image_files)))

    image_input = image_files[0]
    if not image_input.is_directory and not (image_input.path.endswith(".tar") or image_input.path.endswith(".tar.gz")):
        fail("Image must be an OCI-layout .tar, .tar.gz, or directory: {}".format(image_input.path))

    # Output: an OCI-layout directory containing the SOCI-converted image
    soci_layout = ctx.actions.declare_directory(ctx.label.name + "_soci_layout")

    # Build `soci convert --standalone` arguments
    convert_args = ["--standalone", "--format", "oci-dir"]

    # Only add span_size if user explicitly provided it (not default -1)
    if ctx.attr.span_size > 0:
        convert_args.append("--span-size")
        convert_args.append(str(ctx.attr.span_size))

    # Only add min_layer_size if user explicitly provided it (not default -1)
    if ctx.attr.min_layer_size > 0:
        convert_args.append("--min-layer-size")
        convert_args.append(str(ctx.attr.min_layer_size))

    if ctx.attr.all_platforms:
        convert_args.append("--all-platforms")
    elif ctx.attr.platform:
        convert_args.append("--platform")
        convert_args.append(ctx.attr.platform)

    convert_args_str = " ".join(convert_args)

    # Determine repo_tags to carry through to soci_push (not used for conversion itself,
    # standalone mode never talks to a registry or daemon).
    repo_tags_list = []
    repo_tags_from_file = False
    tags_file = None

    if ctx.attr.repo_tags and len(ctx.attr.repo_tags) > 0:
        repo_tags_list = ctx.attr.repo_tags
    elif hasattr(ctx.attr, "repo_tags_file") and ctx.attr.repo_tags_file:
        repo_tags_from_file = True
        tags_file = ctx.file.repo_tags_file
    elif ctx.attr.image_ref:
        repo_tags_list = [ctx.attr.image_ref]
    else:
        repo_tags_list = ["bazel-soci/{}:latest".format(ctx.label.name)]

    # Create conversion script
    script = ctx.actions.declare_file(ctx.label.name + "_convert.sh")

    script_content = """#!/usr/bin/env bash
    set -euo pipefail

    SOCI_BIN="{soci_bin}"
    IMAGE_INPUT="{image_input}"
    OUT_DIR="{out_dir}"

    if [ ! -x "$SOCI_BIN" ]; then
        echo "Error: soci binary not found or not executable: $SOCI_BIN"
        exit 1
    fi

    # Bazel tree artifacts / sandbox inputs may be read-only. soci standalone may
    # need a writable local OCI store while converting, so always use a private
    # writable temp area.
    ACTION_TMP="$(mktemp -d "${{TMPDIR:-/tmp}}/soci-convert.XXXXXX")"
    trap 'rm -rf "$ACTION_TMP"' EXIT

    export TMPDIR="$ACTION_TMP/tmp"
    export HOME="$ACTION_TMP/home"
    export XDG_CACHE_HOME="$ACTION_TMP/cache"

    mkdir -p "$TMPDIR" "$HOME" "$XDG_CACHE_HOME"

    WORK_INPUT="$IMAGE_INPUT"

    if [ -d "$IMAGE_INPUT" ]; then
        WORK_INPUT="$ACTION_TMP/input_oci"
        mkdir -p "$WORK_INPUT"

        echo "Copying OCI layout directory to writable temp input: $WORK_INPUT"
        cp -aL "$IMAGE_INPUT"/. "$WORK_INPUT"/
        chmod -R u+rwX "$WORK_INPUT"
    fi

    echo "Converting to SOCI (standalone mode): $IMAGE_INPUT"

    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"

    echo "Running: $SOCI_BIN convert {convert_args} $WORK_INPUT $OUT_DIR"
    if ! "$SOCI_BIN" convert {convert_args} "$WORK_INPUT" "$OUT_DIR"; then
        echo "Error: SOCI standalone conversion failed"
        exit 1
    fi

    if [ ! -f "$OUT_DIR/index.json" ]; then
        echo "Error: no index.json found in output OCI layout: $OUT_DIR"
        exit 1
    fi

    echo "✓ SOCI conversion complete: $OUT_DIR"
    """.format(
            soci_bin = soci_bin.path,
            image_input = image_input.path,
            out_dir = soci_layout.path,
            convert_args = convert_args_str,
        )


    ctx.actions.write(
        output = script,
        content = script_content,
        is_executable = True,
    )

    ctx.actions.run(
        executable = script,
        inputs = [image_input, soci_bin],
        outputs = [soci_layout],
        mnemonic = "SociConvert",
        progress_message = "Converting %{label} to SOCI (standalone)",
        env = {
            "HOME": "/tmp",
            "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        },
        # Standalone mode is hermetic (no containerd/registry state to worry
        # about), so this is safe to cache/execute remotely unlike the old
        # nerdctl-based action.
    )

    return [
        DefaultInfo(files = depset([soci_layout])),
        OutputGroupInfo(
            soci_layout = depset([soci_layout]),
        ),
        SociImageInfo(
            soci_layout = soci_layout,
            repo_tags = repo_tags_list,
            repo_tags_file = tags_file if repo_tags_from_file else None,
        ),
    ]

_soci_image_rule = rule(
    implementation = _soci_image_impl,
    attrs = {
        "image": attr.label(
            mandatory = True,
            doc = "OCI-layout image tarball or directory (e.g. oci_tarball(format = \"oci\", ...) or oci_image output)",
        ),
        "image_ref": attr.string(
            default = "",
            doc = "Fallback image reference used for the default repo tag",
        ),
        "repo_tags": attr.string_list(
            default = [],
            doc = "List of repository tags, consumed by soci_push",
        ),
        "repo_tags_file": attr.label(
            default = None,
            allow_single_file = True,
            doc = "File containing repository tags (one per line), consumed by soci_push",
        ),
        "min_layer_size": attr.int(
            default = -1,
            doc = "Minimum layer size in bytes. If not set (default -1), soci uses its own default and processes all layers.",
        ),
        "span_size": attr.int(
            default = -1,
            doc = "Span size in bytes for ztoc. If not set (default -1), soci uses its own default (typically 4MB).",
        ),
        "all_platforms": attr.bool(
            default = False,
            doc = "Convert all platforms of a multi-platform image",
        ),
        "platform": attr.string(
            default = "",
            doc = "Convert only the specified platform, e.g. linux/amd64",
        ),
    },
    toolchains = ["@rules_soci//soci:toolchain_type"],
    doc = """Convert OCI image to SOCI format using `soci convert --standalone`.

Unlike the old nerdctl-based rule, this does NOT load the image into a
containerd content store. It operates purely on the OCI-layout
tarball/directory on disk and produces a new OCI-layout directory
(SOCI Index Manifest v2) that can be pushed with `crane push` via the
`soci_push` rule in push.bzl.
""",
)

def soci_image(
        name,
        image,
        image_ref = "",
        repo_tags = None,
        repo_tags_file = None,
        min_layer_size = -1,
        span_size = -1,
        all_platforms = False,
        platform = ""):
    """Convert OCI image to SOCI format using `soci convert --standalone`.

    Args:
        name: Target name.
        image: OCI-layout image tarball or directory.
        image_ref: Fallback image reference for the default repo tag.
        repo_tags: List of repository tags.
        repo_tags_file: Label of a file containing repository tags, one per line.
        min_layer_size: Minimum layer size in bytes (-1 = use SOCI default).
        span_size: Span size in bytes (-1 = use SOCI default).
        all_platforms: Convert all platforms of a multi-platform image.
        platform: Convert only the specified platform, e.g. linux/amd64.

    Returns:
        The configured rule target created by this macro. The target provides
        an OCI-layout directory output and the SociImageInfo provider.
    """
    if repo_tags == None:
        repo_tags = []

    if repo_tags_file != None and len(repo_tags) > 0:
        fail("soci_image: specify only one of repo_tags or repo_tags_file, not both")

    return _soci_image_rule(
        name = name,
        image = image,
        image_ref = image_ref,
        repo_tags = repo_tags,
        repo_tags_file = repo_tags_file,
        min_layer_size = min_layer_size,
        span_size = span_size,
        all_platforms = all_platforms,
        platform = platform,
    )
