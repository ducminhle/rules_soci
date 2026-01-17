"""SOCI toolchain definitions.

This file only contains provider definitions and toolchain rules.
Version management is in versions.bzl, repository setup is in repositories.bzl.
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
