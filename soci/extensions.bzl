"""Bzlmod extension for SOCI toolchains"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":versions.bzl",
     "SOCI_VERSIONS", "CRANE_VERSIONS",
     "DEFAULT_SOCI_VERSION", "DEFAULT_CRANE_VERSION")

def _toolchains_repo_impl(rctx):
    """Create toolchains repository"""
    soci_version = rctx.attr.soci_version
    soci_info = SOCI_VERSIONS[soci_version]

    platforms = [
        ("linux", "amd64", "x86_64"),
        ("linux", "arm64", "aarch64"),
    ]

    build_content = """
load("@rules_soci//soci/private:toolchain.bzl", "soci_toolchain", "crane_toolchain")

package(default_visibility = ["//visibility:public"])
"""

    for os, arch, cpu in platforms:
        platform_name = "{}_{}".format(os, arch)

        if soci_info.get(platform_name):
            build_content += """
soci_toolchain(
    name = "soci_toolchain_{platform}",
    soci = "@soci_{platform}//:soci_binary",
)

toolchain(
    name = "soci_{platform}",
    exec_compatible_with = ["@platforms//os:{os}", "@platforms//cpu:{cpu}"],
    toolchain = ":soci_toolchain_{platform}",
    toolchain_type = "@rules_soci//soci:toolchain_type",
)

crane_toolchain(
    name = "crane_toolchain_{platform}",
    crane = "@crane_{platform}//:crane",
)

toolchain(
    name = "crane_{platform}",
    exec_compatible_with = ["@platforms//os:{os}", "@platforms//cpu:{cpu}"],
    toolchain = ":crane_toolchain_{platform}",
    toolchain_type = "@rules_soci//soci:crane_toolchain_type",
)
""".format(platform=platform_name, os=os, cpu=cpu)

    rctx.file("BUILD.bazel", build_content)
    rctx.file("WORKSPACE", "")

_toolchains_repo = repository_rule(
    implementation = _toolchains_repo_impl,
    attrs = {"soci_version": attr.string(mandatory = True)},
)

def _soci_impl(ctx):
    """Extension implementation"""
    soci_version = DEFAULT_SOCI_VERSION
    crane_version = DEFAULT_CRANE_VERSION

    for mod in ctx.modules:
        for tag in mod.tags.toolchain:
            if tag.soci_version:
                soci_version = tag.soci_version
            if tag.crane_version:
                crane_version = tag.crane_version

    # Download binaries
    for platform in ["linux_amd64", "linux_arm64"]:
        # SOCI
        if platform in SOCI_VERSIONS[soci_version]:
            info = SOCI_VERSIONS[soci_version][platform]
            http_archive(
                name = "soci_{}".format(platform),
                urls = [info["url"]],
                sha256 = info["sha256"],
                strip_prefix = info.get("strip_prefix", ""),
                build_file_content = 'filegroup(name = "soci_binary", srcs = ["soci"], visibility = ["//visibility:public"])',
            )

        # Crane
        if platform in CRANE_VERSIONS[crane_version]:
            info = CRANE_VERSIONS[crane_version][platform]
            http_archive(
                name = "crane_{}".format(platform),
                urls = [info["url"]],
                sha256 = info["sha256"],
                build_file_content = 'exports_files(["crane"], visibility = ["//visibility:public"])',
            )

    _toolchains_repo(name = "soci_toolchains", soci_version = soci_version)

_toolchain_tag = tag_class(attrs = {
    "soci_version": attr.string(default = DEFAULT_SOCI_VERSION),
    "crane_version": attr.string(default = DEFAULT_CRANE_VERSION),
})

soci = module_extension(
    implementation = _soci_impl,
    tag_classes = {"toolchain": _toolchain_tag},
)
