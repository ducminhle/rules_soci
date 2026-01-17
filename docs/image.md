<!-- Generated with Stardoc: http://skydoc.bazel.build -->

SOCI image conversion using nerdctl image convert --soci.

This rule converts OCI images to SOCI format by:

1. Loading the image tarball into containerd via nerdctl
2. Running nerdctl image convert --soci to create SOCI indices
3. Outputting a marker file to track the conversion

<a id="SociImageInfo"></a>

## SociImageInfo

<pre>
load("@rules_soci//soci/private:image.bzl", "SociImageInfo")

SociImageInfo(<a href="#SociImageInfo-repo_tags">repo_tags</a>, <a href="#SociImageInfo-repo_tags_file">repo_tags_file</a>)
</pre>

Information about a SOCI-converted image

**FIELDS**

| Name                                                    | Description                                  |
| :------------------------------------------------------ | :------------------------------------------- |
| <a id="SociImageInfo-repo_tags"></a>repo_tags           | List of repository tags for this image       |
| <a id="SociImageInfo-repo_tags_file"></a>repo_tags_file | File containing tags (if using stamped tags) |

<a id="soci_image"></a>

## soci_image

<pre>
load("@rules_soci//soci/private:image.bzl", "soci_image")

soci_image(<a href="#soci_image-name">name</a>, <a href="#soci_image-image">image</a>, <a href="#soci_image-image_ref">image_ref</a>, <a href="#soci_image-repo_tags">repo_tags</a>, <a href="#soci_image-min_layer_size">min_layer_size</a>, <a href="#soci_image-span_size">span_size</a>)
</pre>

Convert OCI image to SOCI format using nerdctl.

**PARAMETERS**

| Name                                                 | Description                                         | Default Value |
| :--------------------------------------------------- | :-------------------------------------------------- | :------------ |
| <a id="soci_image-name"></a>name                     | Target name                                         | none          |
| <a id="soci_image-image"></a>image                   | OCI image tarball                                   | none          |
| <a id="soci_image-image_ref"></a>image_ref           | Fallback image reference                            | `""`          |
| <a id="soci_image-repo_tags"></a>repo_tags           | List of tags or label to tags file                  | `None`        |
| <a id="soci_image-min_layer_size"></a>min_layer_size | Minimum layer size in bytes (-1 = use SOCI default) | `-1`          |
| <a id="soci_image-span_size"></a>span_size           | Span size in bytes (-1 = use SOCI default)          | `-1`          |

**RETURNS**

The configured rule target created by this macro (the result of
calling the underlying `_soci_image_rule`). The target provides a
SOCI marker file and the `SociImageInfo` provider.
