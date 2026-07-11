"""SOCI + crane repository and toolchain registration helpers.

This file creates and registers:
  - SOCI toolchains
  - hermetic crane toolchains used by soci_push

For bzlmod, repository creation should happen from the module extension
(see extensions.bzl), and toolchains should be registered from MODULE.bazel.

For WORKSPACE, use register_soci_toolchains().
"""

_CRANE_RELEASE_URL = "https://github.com/google/go-containerregistry/releases/download/v{version}/{asset}"

# go-containerregistry release asset naming -> Bazel exec-platform constraints.
_CRANE_PLATFORMS = {
    "linux_amd64": struct(
        asset_os = "Linux",
        asset_arch = "x86_64",
        constraints = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
    ),
    "linux_arm64": struct(
        asset_os = "Linux",
        asset_arch = "arm64",
        constraints = ["@platforms//os:linux", "@platforms//cpu:arm64"],
    ),
    "darwin_amd64": struct(
        asset_os = "Darwin",
        asset_arch = "x86_64",
        constraints = ["@platforms//os:macos", "@platforms//cpu:x86_64"],
    ),
    "darwin_arm64": struct(
        asset_os = "Darwin",
        asset_arch = "arm64",
        constraints = ["@platforms//os:macos", "@platforms//cpu:arm64"],
    ),
}


def _crane_repository_impl(repository_ctx):
    version = repository_ctx.attr.version
    platform = _CRANE_PLATFORMS[repository_ctx.attr.platform]
    asset_name = "go-containerregistry_{}_{}.tar.gz".format(
        platform.asset_os,
        platform.asset_arch,
    )

    # Pull checksums.txt and look up the line for our asset, instead of
    # hardcoding a sha256 map that goes stale on every crane release.
    checksums_path = "checksums.txt"
    repository_ctx.download(
        url = _CRANE_RELEASE_URL.format(
            version = version,
            asset = "checksums.txt",
        ),
        output = checksums_path,
    )
    checksums = repository_ctx.read(checksums_path)

    sha256 = None
    for line in checksums.splitlines():
        line = line.strip()
        if line.endswith(asset_name):
            # checksums.txt lines look like: "<sha256>  <filename>"
            # (space- or tab-separated). In Starlark, str.split() requires a
            # separator, so split on whitespace manually and take the first
            # non-empty token.
            for word in line.replace("\t", " ").split(" "):
                if word != "":
                    sha256 = word
                    break
            break

    if not sha256:
        fail(
            "crane_repository: could not find a checksum for {} in v{} checksums.txt".format(
                asset_name,
                version,
            ),
        )

    repository_ctx.download_and_extract(
        url = _CRANE_RELEASE_URL.format(
            version = version,
            asset = asset_name,
        ),
        sha256 = sha256,
        output = ".",
    )

    repository_ctx.file(
        "BUILD.bazel",
        """load("@rules_soci//soci/private:toolchain.bzl", "crane_toolchain")

exports_files(["crane"])

crane_toolchain(
    name = "crane_toolchain_def",
    crane = "crane",
    version = "{version}",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "crane_toolchain",
    exec_compatible_with = {constraints},
    toolchain = ":crane_toolchain_def",
    toolchain_type = "@rules_soci//soci:crane_toolchain_type",
    visibility = ["//visibility:public"],
)
""".format(
            version = version,
            constraints = platform.constraints,
        ),
    )


_crane_repository = repository_rule(
    implementation = _crane_repository_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "crane / go-containerregistry release version, e.g. '0.21.7' without leading 'v'",
        ),
        "platform": attr.string(
            mandatory = True,
            values = _CRANE_PLATFORMS.keys(),
        ),
    },
    doc = "Downloads a single-platform crane release and wraps it in a crane_toolchain.",
)


def crane_repositories(name = "crane", version = "0.21.7"):
    """Creates one repository per supported platform, each holding a crane_toolchain.

    This function only creates repositories. It does not register toolchains.

    Args:
        name: Base repository name prefix.
        version: crane / go-containerregistry version, without the leading "v".
    """
    for platform_name in _CRANE_PLATFORMS.keys():
        _crane_repository(
            name = "{}_{}".format(name, platform_name),
            version = version,
            platform = platform_name,
        )


def crane_toolchain_labels(name = "crane"):
    """Returns the toolchain labels created by crane_repositories()."""
    return [
        "@{}_{}//:crane_toolchain".format(name, platform_name)
        for platform_name in _CRANE_PLATFORMS.keys()
    ]


def register_soci_toolchains(crane_version = "0.21.7"):
    """Register all SOCI + crane toolchains.

    This function is only for WORKSPACE builds.

    In bzlmod / MODULE.bazel, create the crane repositories from the soci
    module extension and register toolchains directly with register_toolchains().

    This registers:
      - SOCI toolchains via @soci_toolchains//:all
      - hermetic crane toolchains for supported linux/darwin x amd64/arm64
        platforms, so soci_push never needs crane pre-installed on the host.

    Example WORKSPACE usage:

        load("@rules_soci//soci:repositories.bzl", "register_soci_toolchains")

        register_soci_toolchains()

    Or pin a specific crane version:

        register_soci_toolchains(crane_version = "0.21.7")
    """
    native.register_toolchains("@soci_toolchains//:all")

    crane_repositories(version = crane_version)
    native.register_toolchains(*crane_toolchain_labels())
