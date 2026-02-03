"""Push SOCI-enabled images to container registries.
"""

load(":image.bzl", "SociImageInfo")

def _soci_push_impl(ctx):
    """Push SOCI-enabled image to registry using crane"""

    soci_marker = ctx.file.soci_image
    crane_toolchain = ctx.toolchains["@rules_soci//soci:crane_toolchain_type"]
    crane = crane_toolchain.crane_info.binary

    push_script = ctx.actions.declare_file(ctx.label.name + "_push.sh")

    # Get repo_tags from soci_image provider if not specified
    use_tags_file = False
    tags_file = None

    if ctx.attr.repo_tags:
        # Explicitly provided tags
        image_refs = ctx.attr.repo_tags
    else:
        # Auto-detect from soci_image
        soci_image_info = ctx.attr.soci_image[SociImageInfo]

        # Check if soci_image used a file
        if hasattr(soci_image_info, "repo_tags_file") and soci_image_info.repo_tags_file:
            use_tags_file = True
            tags_file = soci_image_info.repo_tags_file
            image_refs = []
        else:
            image_refs = soci_image_info.repo_tags

        if not image_refs and not tags_file:
            fail("No repo_tags found. Specify repo_tags in soci_push or soci_image")

    # Build script based on whether we use file or list
    if use_tags_file:
        # Read tags from file at runtime - export once, push multiple times
        script_content = '''#!/usr/bin/env bash
set -euo pipefail

CRANE="$PWD/{crane}"
TAGS_FILE="{tags_file}"

# Read first tag to export image
FIRST_TAG=$(head -n1 "$TAGS_FILE")

if [ -z "$FIRST_TAG" ]; then
    echo "Error: Tags file is empty"
    exit 1
fi

echo "Exporting image: $FIRST_TAG"

# Export from containerd once
TEMP=$(mktemp -d)
trap "rm -rf $TEMP" EXIT

if ! ctr image export "$TEMP/image.tar" "$FIRST_TAG" 2>/dev/null; then
    echo "Error: Image not found in containerd. Run: bazel build {soci_target}"
    exit 1
fi

# Push to all tags from file
while IFS= read -r ref; do
    [ -z "$ref" ] && continue

    echo "Pushing: $ref"

    if "$CRANE" push "$TEMP/image.tar" "$ref"; then
        echo "✓ Pushed successfully: $ref"
    else
        echo "Error: Push failed for $ref. Make sure you're logged in: docker login"
        exit 1
    fi
done < "$TAGS_FILE"
'''.format(
            crane = crane.short_path,
            tags_file = tags_file.short_path,
            soci_target = "//" + ctx.label.package + ":" + ctx.label.name.replace("_push", ""),
        )

        runfiles_files = [soci_marker, crane, tags_file]

    else:
        # Static list of tags
        push_commands = ""
        for ref in image_refs:
            push_commands += '''
echo "Pushing: {ref}"

# Export from containerd
TEMP=$(mktemp -d)
trap "rm -rf $TEMP" EXIT

if ! ctr image export "$TEMP/image.tar" "{ref}" 2>/dev/null; then
    echo "Error: Image not found in containerd. Run: bazel build {soci_target}"
    exit 1
fi

# Push with crane
if "$CRANE" push "$TEMP/image.tar" "{ref}"; then
    echo "✓ Pushed successfully"
else
    echo "Error: Push failed. Make sure you're logged in: docker login"
    exit 1
fi

'''.format(
                ref = ref,
                soci_target = "//" + ctx.label.package + ":" + ctx.label.name.replace("_push", ""),
            )

        script_content = '''#!/usr/bin/env bash
set -euo pipefail

CRANE="$PWD/{crane}"

{push_commands}
'''.format(
            crane = crane.short_path,
            push_commands = push_commands,
        )

        runfiles_files = [soci_marker, crane]

    ctx.actions.write(
        output = push_script,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = runfiles_files)

    return [DefaultInfo(executable = push_script, runfiles = runfiles)]

soci_push = rule(
    implementation = _soci_push_impl,
    executable = True,
    attrs = {
        "soci_image": attr.label(
            mandatory = True,
            allow_single_file = True,
            providers = [SociImageInfo],
            doc = "SOCI marker file from soci_image rule",
        ),
        "repo_tags": attr.string_list(
            default = [],
            doc = "List of image references to push. If not specified, uses repo_tags from soci_image.",
        ),
    },
    toolchains = ["@rules_soci//soci:crane_toolchain_type"],
    doc = """Push SOCI-enabled image to registry.

Uses crane for authentication (reads ~/.docker/config.json automatically).

Example (auto-detect from soci_image):
    soci_image(
        name = "app_soci",
        image = ":app_tarball",
        repo_tags = [
            "docker.io/user/app:v1",
            "docker.io/user/app:latest",
        ],
    )

    soci_push(
        name = "push",
        soci_image = ":app_soci",
        # repo_tags automatically inherited from app_soci
    )

Example (override tags):
    soci_push(
        name = "push_prod",
        soci_image = ":app_soci",
        repo_tags = ["docker.io/user/app:prod"],  # Only push prod tag
    )

Usage:
    docker login docker.io
    bazel run //:push
""",
)
