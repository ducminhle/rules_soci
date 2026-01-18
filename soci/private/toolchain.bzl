"""SOCI, and Crane toolchain definitions.

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

CraneInfo = provider(
    doc = "Information about crane binary for pushing images",
    fields = {
        "binary": "The crane executable",
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

def _crane_toolchain_impl(ctx):
    """Crane toolchain implementation"""
    # Get the crane executable from files
    crane_files = ctx.files.crane
    if not crane_files:
        fail("crane attribute must provide files")

    toolchain_info = platform_common.ToolchainInfo(
        crane_info = CraneInfo(
            binary = crane_files[0],  # First file is the crane binary
        ),
    )
    return [toolchain_info]

crane_toolchain = rule(
    implementation = _crane_toolchain_impl,
    attrs = {
        "crane": attr.label(
            doc = "The crane binary",
            allow_files = True,  # Changed from executable = True
            cfg = "exec",
            mandatory = True,
        ),
    },
    doc = "Defines a crane toolchain for pushing images with automatic auth",
)
