"""Push SOCI-enabled images to container registries using a hermetic crane toolchain.
"""

load(":image.bzl", "SociImageInfo")

def _soci_push_impl(ctx):
    """Push SOCI-enabled image (OCI layout dir) to registry using crane push"""

    crane_toolchain = ctx.toolchains["@rules_soci//soci:crane_toolchain_type"]
    crane_bin = crane_toolchain.crane_info.binary

    soci_image_info = ctx.attr.soci_image[SociImageInfo]
    soci_layout = soci_image_info.soci_layout

    push_script = ctx.actions.declare_file(ctx.label.name + "_push.sh")

    use_tags_file = False
    tags_file = None

    if ctx.attr.repo_tags:
        # Explicitly provided tags
        image_refs = ctx.attr.repo_tags
    elif hasattr(soci_image_info, "repo_tags_file") and soci_image_info.repo_tags_file:
        use_tags_file = True
        tags_file = soci_image_info.repo_tags_file
        image_refs = []
    else:
        image_refs = soci_image_info.repo_tags
        if not image_refs:
            fail("No repo_tags found. Specify repo_tags in soci_push or soci_image")

    index_flag = "--index" if ctx.attr.push_index else ""

    if use_tags_file:
        # Read every tag from the file and push each one individually.
        # `crane push` is content-addressed, so the registry dedupes layers by
        # digest -- pushing the same OCI layout to multiple tags is cheap and
        # works on crane versions that don't support `crane push --tags`.
        script_content = '''#!/usr/bin/env bash
set -euo pipefail

SOCI_LAYOUT="{soci_layout}"
TAGS_FILE="{tags_file}"
CRANE="{crane_bin}"

if [ ! -f "$TAGS_FILE" ]; then
    echo "Error: Tags file not found: $TAGS_FILE"
    exit 1
fi

if [ ! -x "$CRANE" ]; then
    echo "Error: crane binary not found or not executable: $CRANE"
    echo "(this should never happen -- crane is resolved hermetically via crane_toolchain)"
    exit 1
fi

echo "Using hermetic crane toolchain for push (no containerd/nerdctl/pre-installed crane required)"
echo "Pushing SOCI-enabled image from: $SOCI_LAYOUT"
echo ""

push_one() {{
    local ref="$1"
    echo "Pushing: $ref"
    if "$CRANE" push {index_flag} "$SOCI_LAYOUT" "$ref"; then
        echo "✓ Pushed successfully: $ref"
    else
        echo "Error: Push failed for $ref"
        echo "Check registry credentials in ~/.docker/config.json"
        exit 1
    fi
    echo ""
}}

while IFS= read -r ref; do
    ref=$(echo "$ref" | tr -d "\\n\\r")
    [ -z "$ref" ] && continue
    push_one "$ref"
done < "$TAGS_FILE"

echo "✓ All images pushed successfully"
'''.format(
            soci_layout = soci_layout.short_path,
            tags_file = tags_file.short_path,
            crane_bin = crane_bin.short_path,
            index_flag = index_flag,
        )

        runfiles_files = [soci_layout, tags_file, crane_bin]
    else:
        # Push every tag with its own `crane push` call.
        push_lines = ""
        for ref in image_refs:
            push_lines += '''
push_one "{ref}"
'''.format(ref = ref)

        script_content = '''#!/usr/bin/env bash
set -euo pipefail

SOCI_LAYOUT="{soci_layout}"
CRANE="{crane_bin}"

if [ ! -x "$CRANE" ]; then
    echo "Error: crane binary not found or not executable: $CRANE"
    echo "(this should never happen -- crane is resolved hermetically via crane_toolchain)"
    exit 1
fi

echo "Using hermetic crane toolchain for push (no containerd/nerdctl/pre-installed crane required)"
echo "Pushing SOCI-enabled image from: $SOCI_LAYOUT"
echo ""

push_one() {{
    local ref="$1"
    echo "Pushing: $ref"
    if "$CRANE" push {index_flag} "$SOCI_LAYOUT" "$ref"; then
        echo "✓ Pushed successfully: $ref"
    else
        echo "Error: Push failed for $ref"
        echo "Check registry credentials in ~/.docker/config.json"
        exit 1
    fi
    echo ""
}}

{push_lines}
echo "✓ All images pushed successfully"
'''.format(
            soci_layout = soci_layout.short_path,
            push_lines = push_lines,
            crane_bin = crane_bin.short_path,
            index_flag = index_flag,
        )

        runfiles_files = [soci_layout, crane_bin]

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
            providers = [SociImageInfo],
            doc = "SOCI-converted OCI-layout directory from soci_image rule",
        ),
        "repo_tags": attr.string_list(
            default = [],
            doc = "List of image references to push. If not specified, uses repo_tags from soci_image.",
        ),
        "push_index": attr.bool(
            default = False,
            doc = "Pass --index to crane push. Required if the soci_image OCI layout contains " +
                  "multiple images (e.g. produced with all_platforms = True on soci_image).",
        ),
    },
    toolchains = ["@rules_soci//soci:crane_toolchain_type"],
    doc = """Push a SOCI-enabled OCI-layout directory to a registry using a hermetic crane toolchain.

crane is resolved via crane_toolchain (see toolchain.bzl / crane_repositories.bzl) --
it does NOT need to be pre-installed on the machine running `bazel run`.
No containerd, no sudo, no local daemon.

Every tag is pushed with its own `crane push` call. crane is content-addressed,
so the registry dedupes layers by digest across tags -- this works on crane
versions that do not support `crane push --tags` and avoids a separate
`crane tag` step.

crane still reads registry credentials from ~/.docker/config.json, same as
nerdctl/docker did.

Example:
    soci_image(
        name = "app_soci",
        image = ":app_oci_tarball",  # oci_tarball(format = "oci", ...)
        repo_tags = [
            "325758001856.dkr.ecr.us-west-2.amazonaws.com/myapp:v1",
        ],
    )

    soci_push(
        name = "push",
        soci_image = ":app_soci",
    )
""",
)
