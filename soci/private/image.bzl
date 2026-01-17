"""SOCI image conversion rules"""

load(":toolchain.bzl", "SociToolchainInfo")

def _soci_image_impl(ctx):
    """Convert an OCI image to SOCI format"""

    # Get toolchain
    toolchain = ctx.toolchains["@rules_soci//soci:toolchain_type"]
    soci_info = toolchain.soci_info
    soci_bin = soci_info.soci_bin

    # Get input image
    image = ctx.attr.image
    image_files = image[DefaultInfo].files.to_list()

    if not image_files:
        fail("No files found in image target: {}".format(ctx.attr.image.label))

    # Find image file (directory or tarball)
    image_file = None
    for f in image_files:
        if f.is_directory or f.path.endswith(".tar") or f.path.endswith(".tar.gz"):
            image_file = f
            break

    if not image_file:
        fail("Could not find image directory or tarball in target: {}".format(
            ctx.attr.image.label
        ))

    # Declare outputs
    out_dir = ctx.actions.declare_directory(ctx.label.name)

    # Build arguments
    args = ctx.actions.args()
    args.add("create")
    args.add(image_file.path)

    # Optional parameters
    if ctx.attr.min_layer_size > 0:
        args.add("--min-layer-size", str(ctx.attr.min_layer_size))

    if ctx.attr.span_size > 0:
        args.add("--span-size", str(ctx.attr.span_size))

    if ctx.attr.platform:
        args.add("--platform", ctx.attr.platform)

    # Output directory
    args.add("--output-dir", out_dir.path)

    # Run SOCI
    ctx.actions.run(
        executable = soci_bin,
        arguments = [args],
        inputs = [image_file],
        outputs = [out_dir],
        mnemonic = "SociCreate",
        progress_message = "Creating SOCI index for %{label}",
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [
        DefaultInfo(files = depset([out_dir])),
        OutputGroupInfo(
            soci_artifacts = depset([out_dir]),
        ),
    ]

soci_image = rule(
    implementation = _soci_image_impl,
    attrs = {
        "image": attr.label(
            mandatory = True,
            doc = "OCI image target from oci_image or oci_load",
        ),
        "min_layer_size": attr.int(
            default = 10485760,  # 10MB
            doc = "Minimum layer size in bytes to index",
        ),
        "span_size": attr.int(
            default = 4194304,  # 4MB
            doc = "Span size for ztoc in bytes",
        ),
        "platform": attr.string(
            default = "",
            doc = "Target platform (e.g. linux/amd64)",
        ),
    },
    toolchains = ["@rules_soci//soci:toolchain_type"],
    doc = """Convert an OCI image to SOCI format.

This rule takes an OCI image (from oci_image or oci_load) and creates
SOCI lazy-loading indices for faster container startup.

Example:
    load("@rules_oci//oci:defs.bzl", "oci_image")
    load("@rules_soci//soci:defs.bzl", "soci_image")

    oci_image(
        name = "app",
        base = "@distroless_base",
        entrypoint = ["/app/main"],
    )

    soci_image(
        name = "app_soci",
        image = ":app",
        platform = "linux/amd64",
    )
""",
)

def _soci_load_impl(ctx):
    """Load a tarball and convert to SOCI in one step"""

    toolchain = ctx.toolchains["@rules_soci//soci:toolchain_type"]
    soci_info = toolchain.soci_info
    soci_bin = soci_info.soci_bin

    tarball = ctx.file.tarball
    out_dir = ctx.actions.declare_directory(ctx.label.name)

    args = ctx.actions.args()
    args.add("create")
    args.add(tarball.path)

    if ctx.attr.min_layer_size > 0:
        args.add("--min-layer-size", str(ctx.attr.min_layer_size))

    if ctx.attr.span_size > 0:
        args.add("--span-size", str(ctx.attr.span_size))

    if ctx.attr.platform:
        args.add("--platform", ctx.attr.platform)

    args.add("--output-dir", out_dir.path)

    ctx.actions.run(
        executable = soci_bin,
        arguments = [args],
        inputs = [tarball],
        outputs = [out_dir],
        mnemonic = "SociLoad",
        progress_message = "Loading and converting %{label} to SOCI",
    )

    return [DefaultInfo(files = depset([out_dir]))]

soci_load = rule(
    implementation = _soci_load_impl,
    attrs = {
        "tarball": attr.label(
            mandatory = True,
            allow_single_file = [".tar", ".tar.gz"],
            doc = "OCI image tarball to convert",
        ),
        "min_layer_size": attr.int(default = 10485760),
        "span_size": attr.int(default = 4194304),
        "platform": attr.string(default = ""),
    },
    toolchains = ["@rules_soci//soci:toolchain_type"],
    doc = """Load an OCI tarball and convert to SOCI format.

Example:
    load("@rules_soci//soci:defs.bzl", "soci_load")

    soci_load(
        name = "imported_soci",
        tarball = "image.tar",
        platform = "linux/amd64",
    )
""",
)
