"""Public API for rules_soci

This is the main entry point for users of rules_soci.
Load rules from here in your BUILD files:

    load("@rules_soci//soci:defs.bzl", "soci_image", "soci_push")
"""

load("//soci/private:image.bzl", _soci_image = "soci_image")
load("//soci/private:push.bzl", _soci_push = "soci_push")

# Re-export public rules
soci_image = _soci_image
soci_push = _soci_push

# Version info
VERSION = "0.1.0"
