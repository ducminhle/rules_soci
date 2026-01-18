<!-- Generated with Stardoc: http://skydoc.bazel.build -->

SOCI image conversion using soci convert.

This rule converts OCI images to SOCI format by:
1. Loading the image tarball into containerd
2. Running soci convert to create SOCI indices
3. Outputting a marker file to track the conversion

<a id="soci_image"></a>

## soci_image

<pre>
load("@rules_soci//soci/private:image.bzl", "soci_image")

soci_image(<a href="#soci_image-name">name</a>, <a href="#soci_image-image">image</a>, <a href="#soci_image-image_ref">image_ref</a>, <a href="#soci_image-min_layer_size">min_layer_size</a>, <a href="#soci_image-repo_tags">repo_tags</a>, <a href="#soci_image-span_size">span_size</a>)
</pre>

Convert an OCI image to SOCI format for lazy loading.

This rule takes an OCI image tarball (typically from oci_tarball) and converts it to
SOCI format by creating seekable indices (ztoc) for large layers. The resulting image
can be pushed to a registry and used with soci-snapshotter for lazy loading.

Example:
    load("@rules_oci//oci:defs.bzl", "oci_image", "oci_tarball")
    load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")

    oci_image(
        name = "app",
        base = "@distroless_base",
        entrypoint = ["/app"],
    )

    oci_load(
        name = "app_load",
        image = ":app",
        repo_tags = ["app:v1"],
    )

    filegroup(
        name = "app_tarball",
        srcs = [":app_load"],
        output_group = "tarball",
    )

    soci_image(
        name = "app_soci",
        image = ":app_tarball",
        repo_tags = ["docker.io/myuser/app:v1", "docker.io/myuser/app:latest"],
    )

    soci_push(
        name = "app_soci_push",
        soci_image = ":app_soci",
        # Automatically pushes all repo_tags from app_soci
    )

Usage:
    bazel build //:app_soci     # Convert to SOCI
    bazel run //:app_soci_push  # Push to registry

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="soci_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="soci_image-image"></a>image |  OCI image tarball from oci_tarball or oci_load   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="soci_image-image_ref"></a>image_ref |  Fallback image reference for containerd (used if repo_tags not provided)   | String | optional |  `""`  |
| <a id="soci_image-min_layer_size"></a>min_layer_size |  Minimum layer size (in bytes) to create SOCI index for.<br><br>Layers smaller than this will be skipped. Default: 10MB (10485760 bytes). Adjust this based on your use case: - Larger values: fewer indices, faster conversion, less lazy-loading benefit - Smaller values: more indices, slower conversion, more lazy-loading benefit   | Integer | optional |  `10485760`  |
| <a id="soci_image-repo_tags"></a>repo_tags |  List of repository tags (e.g., ["docker.io/myrepo/app:v1"]).<br><br>The first tag is used as the final destination reference. The conversion process uses a temporary tag (first_tag + "-based") during conversion.   | List of strings | optional |  `[]`  |
| <a id="soci_image-span_size"></a>span_size |  Span size (in bytes) for ztoc generation.<br><br>This controls the granularity of lazy loading. Default: 4MB (4194304 bytes). - Smaller spans: more granular loading, more metadata overhead - Larger spans: less granular loading, less metadata overhead   | Integer | optional |  `4194304`  |


<a id="SociImageInfo"></a>

## SociImageInfo

<pre>
load("@rules_soci//soci/private:image.bzl", "SociImageInfo")

SociImageInfo(<a href="#SociImageInfo-repo_tags">repo_tags</a>)
</pre>

Information about a SOCI-converted image

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="SociImageInfo-repo_tags"></a>repo_tags |  List of repository tags for this image    |


