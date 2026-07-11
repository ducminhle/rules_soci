<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Push SOCI-enabled images to container registries using a hermetic crane toolchain.

<a id="soci_push"></a>

## soci_push

<pre>
load("@rules_soci//soci/private:push.bzl", "soci_push")

soci_push(<a href="#soci_push-name">name</a>, <a href="#soci_push-push_index">push_index</a>, <a href="#soci_push-repo_tags">repo_tags</a>, <a href="#soci_push-soci_image">soci_image</a>)
</pre>

Push a SOCI-enabled OCI-layout directory to a registry using a hermetic crane toolchain.

crane is resolved via crane_toolchain (see toolchain.bzl / crane_repositories.bzl) --
it does NOT need to be pre-installed on the machine running `bazel run`.
No containerd, no sudo, no local daemon.

Every tag is pushed with its own `crane push` call. crane is content-addressed,
so the registry dedupes layers by digest across tags -- this works on crane
versions that do not support `crane push --tags` and avoids a separate
`crane tag` step.

crane still reads registry credentials from ~/.docker/config.json, same as
nerdctl/docker did.

Example:
    soci_image(
        name = "app_soci",
        image = ":app_oci_tarball",  # oci_tarball(format = "oci", ...)
        repo_tags = [
            "325758001856.dkr.ecr.us-west-2.amazonaws.com/myapp:v1",
        ],
    )

    soci_push(
        name = "push",
        soci_image = ":app_soci",
    )

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="soci_push-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="soci_push-push_index"></a>push_index |  Pass --index to crane push. Required if the soci_image OCI layout contains multiple images (e.g. produced with all_platforms = True on soci_image).   | Boolean | optional |  `False`  |
| <a id="soci_push-repo_tags"></a>repo_tags |  List of image references to push. If not specified, uses repo_tags from soci_image.   | List of strings | optional |  `[]`  |
| <a id="soci_push-soci_image"></a>soci_image |  SOCI-converted OCI-layout directory from soci_image rule   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |


