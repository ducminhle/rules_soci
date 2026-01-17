"""Push SOCI-enabled images to container registries.
"""

load(":image.bzl", "SociImageInfo")

def _soci_push_impl(ctx):
    """Push SOCI-enabled image to registry using nerdctl"""

    soci_marker = ctx.file.soci_image

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
        # Read tags from file at runtime and push each
        script_content = '''#!/usr/bin/env bash
set -euo pipefail

TAGS_FILE="{tags_file}"

if [ ! -f "$TAGS_FILE" ]; then
    echo "Error: Tags file not found: $TAGS_FILE"
    exit 1
fi

# Check for nerdctl
if ! command -v nerdctl >/dev/null 2>&1; then
    echo "Error: nerdctl not found"
    echo "Install nerdctl: https://github.com/containerd/nerdctl/releases"
    exit 1
fi

echo "Using nerdctl for push"
echo "Pushing SOCI-enabled images..."
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    NERDCTL="nerdctl"
else
    if ! nerdctl ps >/dev/null 2>&1; then
        echo "Warning: nerdctl requires sudo to access containerd"
        echo "You may need to run: sudo bazel run {target}"
        NERDCTL="sudo nerdctl"
    else
        NERDCTL="nerdctl"
    fi
fi

# Push each tag
while IFS= read -r ref; do
    [ -z "$ref" ] && continue

    echo "Pushing: $ref"

    if ! $NERDCTL images --quiet "$ref" 2>/dev/null | grep -q .; then
        echo "Error: Image not found in containerd: $ref"
        echo "Run: bazel build {soci_target}"
        exit 1
    fi

    if $NERDCTL push "$ref"; then
        echo "✓ Pushed successfully: $ref"
    else
        echo "Error: Push failed for $ref"
        echo ""
        echo "Authentication troubleshooting:"
        echo ""
        echo "AWS ECR:"
        echo "  aws ecr get-login-password --region REGION | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com"
        echo ""
        echo "GCP: gcloud auth configure-docker REGION-docker.pkg.dev"
        echo "Azure: az acr login --name REGISTRY_NAME"
        echo "Docker Hub: docker login"
        exit 1
    fi

    echo ""
done < "$TAGS_FILE"

echo "✓ All images pushed successfully"
'''.format(
            tags_file = tags_file.short_path,
            soci_target = "//" + ctx.label.package + ":" + ctx.label.name.replace("_push", ""),
            target = "//" + ctx.label.package + ":" + ctx.label.name,
        )

        runfiles_files = [soci_marker, tags_file]
    else:
        # Static list of tags
        push_commands = []

        for ref in image_refs:
            # Use shell.quote to properly escape the ref
            from_shell = '''
echo "Pushing: $ref"

if ! $NERDCTL images --quiet "$ref" 2>/dev/null | grep -q .; then
    echo "Error: Image not found: $ref"
    echo "Run: bazel build {soci_target}"
    exit 1
fi

if $NERDCTL push "$ref"; then
    echo "✓ Pushed successfully: $ref"
else
    echo "Error: Push failed for $ref"
    exit 1
fi

echo ""
'''.format(soci_target = "//" + ctx.label.package + ":" + ctx.label.name.replace("_push", ""))

            # Set ref as a variable to avoid quoting issues
            push_commands.append('ref="{}"'.format(ref))
            push_commands.append(from_shell)

        script_content = '''#!/usr/bin/env bash
set -euo pipefail

# Check for nerdctl
if ! command -v nerdctl >/dev/null 2>&1; then
    echo "Error: nerdctl not found"
    echo "Install nerdctl: https://github.com/containerd/nerdctl/releases"
    exit 1
fi

echo "Using nerdctl for push"
echo "Pushing SOCI-enabled images..."
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    NERDCTL="nerdctl"
else
    if ! nerdctl ps >/dev/null 2>&1; then
        echo "Warning: nerdctl requires sudo to access containerd"
        NERDCTL="sudo nerdctl"
    else
        NERDCTL="nerdctl"
    fi
fi

{push_commands}

echo "✓ All images pushed successfully"
'''.format(
            push_commands = "\n".join(push_commands),
        )

        runfiles_files = [soci_marker]

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
    doc = """Push SOCI-enabled image to registry using nerdctl.

Requires nerdctl to push both OCI image and SOCI indices to the registry.
nerdctl automatically reads Docker credentials from ~/.docker/config.json.

Example:
    soci_image(
        name = "app_soci",
        image = ":app_tarball",
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
