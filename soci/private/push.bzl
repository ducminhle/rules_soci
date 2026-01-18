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
    if ctx.attr.repo_tags:
        image_refs = ctx.attr.repo_tags
    else:
        # Auto-detect from soci_image
        soci_image_info = ctx.attr.soci_image[SociImageInfo]
        image_refs = soci_image_info.repo_tags
        if not image_refs:
            fail("No repo_tags found. Specify repo_tags in soci_push or soci_image")

    # Build push commands for each image ref
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
            soci_target = "//" + ctx.label.package + ":" + ctx.label.name.replace("_push", "_soci"),
        )

    script_content = '''#!/usr/bin/env bash
set -euo pipefail

CRANE="$PWD/{crane}"

{push_commands}
'''.format(
        crane = crane.short_path,
        push_commands = push_commands,
    )

    ctx.actions.write(
        output = push_script,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [soci_marker, crane])

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
