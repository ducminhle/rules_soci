<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Push SOCI-enabled images to container registries.

<a id="soci_push"></a>

## soci_push

<pre>
load("@rules_soci//soci/private:push.bzl", "soci_push")

soci_push(<a href="#soci_push-name">name</a>, <a href="#soci_push-repo_tags">repo_tags</a>, <a href="#soci_push-soci_image">soci_image</a>)
</pre>

Push SOCI-enabled image to registry using nerdctl.

Requires nerdctl to push both OCI image and SOCI indices to the registry.
nerdctl automatically reads Docker credentials from ~/.docker/config.json.

Example:
soci_image(
name = "app_soci",
image = ":app_tarball",
repo_tags = [
"325758001856.dkr.ecr.us-west-2.amazonaws.com/myapp:v1",
],
)

    soci_push(
        name = "push",
        soci_image = ":app_soci",
    )

**ATTRIBUTES**

| Name                                        | Description                                                                         | Type                                                                | Mandatory | Default |
| :------------------------------------------ | :---------------------------------------------------------------------------------- | :------------------------------------------------------------------ | :-------- | :------ |
| <a id="soci_push-name"></a>name             | A unique name for this target.                                                      | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required  |         |
| <a id="soci_push-repo_tags"></a>repo_tags   | List of image references to push. If not specified, uses repo_tags from soci_image. | List of strings                                                     | optional  | `[]`    |
| <a id="soci_push-soci_image"></a>soci_image | SOCI marker file from soci_image rule                                               | <a href="https://bazel.build/concepts/labels">Label</a>             | required  |         |
