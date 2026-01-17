"""SOCI toolchain definition and provider"""

SociToolchainInfo = provider(
    doc = "Information about the SOCI toolchain",
    fields = {
        "soci_bin": "The SOCI binary executable",
        "target_tool": "Tool metadata",
    },
)

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
    doc = "Defines a SOCI toolchain",
)

def _toolchain_config_impl(ctx):
    """Create toolchain configurations for all platforms"""
    toolchains = []

    platform_configs = [
        ("linux", "x86_64", ctx.attr.linux_amd64),
        ("linux", "aarch64", ctx.attr.linux_arm64),
    ]

    for os, cpu, toolchain in platform_configs:
        if toolchain:
            toolchains.append({
                "os": os,
                "cpu": cpu,
                "toolchain": toolchain,
            })

    return [
        platform_common.ToolchainInfo(
            toolchains = toolchains,
        ),
    ]

toolchain_config = rule(
    implementation = _toolchain_config_impl,
    attrs = {
        "linux_amd64": attr.label(),
        "linux_arm64": attr.label(),
    },
)
