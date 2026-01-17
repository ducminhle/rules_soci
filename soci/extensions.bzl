"""Bzlmod extension for SOCI toolchain registration"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load(":versions.bzl", "SOCI_VERSIONS", "DEFAULT_VERSION")

def _soci_toolchain_impl(ctx):
    """Extension implementation for SOCI toolchain"""

    toolchains = {}

    for mod in ctx.modules:
        for toolchain in mod.tags.toolchain:
            version = toolchain.version or DEFAULT_VERSION
            name = toolchain.name

            if version not in SOCI_VERSIONS:
                fail("SOCI version {} not supported. Available versions: {}".format(
                    version,
                    ", ".join(SOCI_VERSIONS.keys())
                ))

            toolchains[name] = {
                "version": version,
                "soci_info": SOCI_VERSIONS[version],
            }

    # Create toolchain repositories
    for name, info in toolchains.items():
        _create_toolchain_repos(name, info["version"], info["soci_info"])

    return ctx.extension_metadata(
        reproducible = True,
        generated_repositories = ["soci_toolchains"],
        root_module_direct_deps = [],
        root_module_direct_dev_deps = [],
    )

def _create_toolchain_repos(name, version, soci_info):
    """Create toolchain repositories for all platforms"""

    platforms = [
        ("linux", "amd64"),
        ("linux", "arm64"),
    ]

    for os, arch in platforms:
        platform_name = "{}_{}".format(os, arch)
        repo_name = "soci_{}_{}".format(name, platform_name)

        release_info = soci_info.get(platform_name)
        if not release_info:
            continue

        http_archive(
            name = repo_name,
            urls = [release_info["url"]],
            sha256 = release_info["sha256"],
            strip_prefix = release_info.get("strip_prefix", ""),
            build_file_content = _BUILD_FILE_CONTENT,
        )

_BUILD_FILE_CONTENT = """
load("@rules_soci//soci/private:toolchain.bzl", "soci_toolchain")

filegroup(
    name = "soci_binary",
    srcs = ["soci"],
    visibility = ["//visibility:public"],
)

soci_toolchain(
    name = "soci_toolchain",
    soci = ":soci_binary",
)
"""

_toolchain = tag_class(
    attrs = {
        "name": attr.string(
            doc = "Name for this toolchain",
            default = "soci",
        ),
        "version": attr.string(
            doc = "SOCI version to use",
            default = DEFAULT_VERSION,
        ),
    },
)

soci = module_extension(
    implementation = _soci_toolchain_impl,
    tag_classes = {
        "toolchain": _toolchain,
    },
)
