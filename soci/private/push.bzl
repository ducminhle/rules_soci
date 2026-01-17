"""SOCI push rule for uploading indices to registries"""

load(":toolchain.bzl", "SociToolchainInfo")

def _soci_push_impl(ctx):
    """Push SOCI artifacts to a registry"""

    toolchain = ctx.toolchains["@rules_soci//soci:toolchain_type"]
    soci_info = toolchain.soci_info
    soci_bin = soci_info.soci_bin

    image = ctx.attr.image
    soci_artifacts = ctx.file.soci_artifacts

    # Create push script
    push_script = ctx.actions.declare_file(ctx.label.name + "_push.sh")

    script_content = """#!/usr/bin/env bash
set -euo pipefail

SOCI_BIN="{soci_bin}"
SOCI_ARTIFACTS="{soci_artifacts}"
IMAGE_REF="{image_ref}"

echo "Pushing SOCI artifacts for $IMAGE_REF..."

# Push SOCI index
"$SOCI_BIN" push \\
    --ref "$IMAGE_REF" \\
    "$SOCI_ARTIFACTS"

echo "✓ Successfully pushed SOCI artifacts to $IMAGE_REF"
""".format(
        soci_bin = soci_bin.path,
        soci_artifacts = soci_artifacts.path,
        image_ref = ctx.attr.image_ref,
    )

    ctx.actions.write(
        output = push_script,
        content = script_content,
        is_executable = True,
    )

    runfiles = ctx.runfiles(
        files = [soci_bin, soci_artifacts],
        transitive_files = image[DefaultInfo].files,
    )

    return [
        DefaultInfo(
            executable = push_script,
            runfiles = runfiles,
        ),
    ]

soci_push = rule(
    implementation = _soci_push_impl,
    executable = True,
    attrs = {
        "image": attr.label(
            mandatory = True,
            doc = "OCI image target",
        ),
        "soci_artifacts": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "SOCI artifacts from soci_image",
        ),
        "image_ref": attr.string(
            mandatory = True,
            doc = "Full image reference (e.g. registry.io/myapp:tag)",
        ),
    },
    toolchains = ["@rules_soci//soci:toolchain_type"],
    doc = """Push SOCI indices to a container registry.

This rule creates an executable that pushes SOCI artifacts alongside
the OCI image to enable lazy-loading.

Example:
    load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

    soci_image(
        name = "app_soci",
        image = ":app",
    )

    soci_push(
        name = "push_soci",
        image = ":app",
        soci_artifacts = ":app_soci",
        image_ref = "myregistry.io/myapp:latest",
    )

Usage:
    bazel run //:push_soci
""",
)
