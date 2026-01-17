"""SOCI toolchain registration helpers.

Note: In bzlmod (MODULE.bazel), you must register toolchains directly:

    register_toolchains("@soci_toolchains//:all")

Bazel will automatically select the correct toolchain for your platform.

The helper function below is only for WORKSPACE (legacy) builds.
"""

def register_soci_toolchains():
    """Register all SOCI toolchains.

    This function is only for WORKSPACE builds. In bzlmod (MODULE.bazel),
    you must call register_toolchains() directly as shown above.

    Example (WORKSPACE):
        load("@rules_soci//soci:repositories.bzl", "register_soci_toolchains")
        register_soci_toolchains()
    """
    native.register_toolchains("@soci_toolchains//:all")
