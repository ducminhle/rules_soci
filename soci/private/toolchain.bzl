"""SOCI + crane toolchain definitions.
This file only contains provider definitions and toolchain rules.
Version management is in versions.bzl, repository setup is in repositories.bzl
(for soci) and crane_repositories.bzl (for crane).
"""

# ============================================================================
# Providers
# ============================================================================
SociToolchainInfo = provider(
    doc = "Information about the SOCI toolchain",
    fields = {
        "soci_bin": "The SOCI binary executable",
        "target_tool": "Tool metadata",
    },
)

CraneInfo = provider(
    doc = "Information about how to invoke the crane executable.",
    fields = {
        "binary": "Executable crane binary",
        "version": "Crane version",
    },
)

# ============================================================================
# SOCI Toolchain
# ============================================================================
def _soci_toolchain_impl(ctx):
    """Implementation of soci_toolchain rule"""
    toolchain_info = platform_common.ToolchainInfo(
        soci_info = SociToolchainInfo(
            soci_bin = ctx.executable.soci,
            target_tool = ctx.attr.soci,
        ),
    )
    return [toolchain_info]

soci_toolchain = rule(
    implementation = _soci_toolchain_impl,
    attrs = {
        "soci": attr.label(
            doc = "The SOCI binary",
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
    doc = "Defines a SOCI toolchain for converting images to SOCI format",
)

# ============================================================================
# Crane Toolchain
# ============================================================================
# Same shape as @rules_oci//oci:toolchain.bzl's crane_toolchain -- a thin
# wrapper so soci_push can depend on a hermetically-downloaded crane binary
# instead of assuming `crane` is already on the host PATH.
def _crane_toolchain_impl(ctx):
    """Implementation of crane_toolchain rule"""
    binary = ctx.executable.crane

    default = DefaultInfo(
        files = depset([binary]),
        runfiles = ctx.runfiles(files = [binary]),
    )

    crane_info = CraneInfo(
        binary = binary,
        version = ctx.attr.version,
    )

    toolchain_info = platform_common.ToolchainInfo(
        crane_info = crane_info,
        default = default,
    )

    return [
        default,
        toolchain_info,
    ]

crane_toolchain = rule(
    implementation = _crane_toolchain_impl,
    attrs = {
        "crane": attr.label(
            doc = "A hermetically downloaded crane executable for the target platform.",
            executable = True,
            cfg = "exec",
            allow_single_file = True,
            mandatory = True,
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Version of the crane binary",
        ),
    },
    doc = "Defines a crane toolchain, used by soci_push to push SOCI-enabled images without relying on a pre-installed crane.",
)
