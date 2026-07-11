<!-- Generated with Stardoc: http://skydoc.bazel.build -->

SOCI image conversion using `soci convert --standalone`.

This rule converts OCI images to SOCI format without touching containerd:
1. Runs `soci convert --standalone --format oci-dir` directly on the OCI
   image layout tarball/directory produced by rules_oci.
2. Outputs an OCI-layout directory that contains the original image plus
   the SOCI index (SOCI Index Manifest v2), ready to be pushed with
   `crane push` (see push.bzl).

No nerdctl, no containerd daemon, no sudo. This also means the action is
sandboxable/remote-cacheable, so the old `no-cache`/`no-remote` execution
requirements are gone.

NOTE: the `image` attribute MUST be an OCI-layout tarball or directory
(e.g. `oci_tarball(format = "oci", ...)` or the directory produced
directly by `oci_image`). Docker-style tarballs (`docker save`,
`oci_tarball(format = "docker", ...)`) are NOT compatible with
`soci convert --standalone` -- see soci-snapshotter docs on standalone mode.

<a id="SociImageInfo"></a>

## SociImageInfo

<pre>
load("@rules_soci//soci/private:image.bzl", "SociImageInfo")

SociImageInfo(<a href="#SociImageInfo-soci_layout">soci_layout</a>, <a href="#SociImageInfo-repo_tags">repo_tags</a>, <a href="#SociImageInfo-repo_tags_file">repo_tags_file</a>)
</pre>

Information about a SOCI-converted image

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="SociImageInfo-soci_layout"></a>soci_layout |  Directory (OCI image layout) containing the SOCI-converted image    |
| <a id="SociImageInfo-repo_tags"></a>repo_tags |  List of repository tags to use when pushing this image    |
| <a id="SociImageInfo-repo_tags_file"></a>repo_tags_file |  File containing tags (if using stamped tags), one per line    |


<a id="soci_image"></a>

## soci_image

<pre>
load("@rules_soci//soci/private:image.bzl", "soci_image")

soci_image(<a href="#soci_image-name">name</a>, <a href="#soci_image-image">image</a>, <a href="#soci_image-image_ref">image_ref</a>, <a href="#soci_image-repo_tags">repo_tags</a>, <a href="#soci_image-repo_tags_file">repo_tags_file</a>, <a href="#soci_image-min_layer_size">min_layer_size</a>, <a href="#soci_image-span_size">span_size</a>,
           <a href="#soci_image-all_platforms">all_platforms</a>, <a href="#soci_image-platform">platform</a>)
</pre>

Convert OCI image to SOCI format using `soci convert --standalone`.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="soci_image-name"></a>name |  Target name.   |  none |
| <a id="soci_image-image"></a>image |  OCI-layout image tarball or directory.   |  none |
| <a id="soci_image-image_ref"></a>image_ref |  Fallback image reference for the default repo tag.   |  `""` |
| <a id="soci_image-repo_tags"></a>repo_tags |  List of repository tags.   |  `None` |
| <a id="soci_image-repo_tags_file"></a>repo_tags_file |  Label of a file containing repository tags, one per line.   |  `None` |
| <a id="soci_image-min_layer_size"></a>min_layer_size |  Minimum layer size in bytes (-1 = use SOCI default).   |  `-1` |
| <a id="soci_image-span_size"></a>span_size |  Span size in bytes (-1 = use SOCI default).   |  `-1` |
| <a id="soci_image-all_platforms"></a>all_platforms |  Convert all platforms of a multi-platform image.   |  `False` |
| <a id="soci_image-platform"></a>platform |  Convert only the specified platform, e.g. linux/amd64.   |  `""` |

**RETURNS**

The configured rule target created by this macro. The target provides
  an OCI-layout directory output and the SociImageInfo provider.


