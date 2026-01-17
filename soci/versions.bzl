"""Version constants for SOCI"""

# Default versions
DEFAULT_SOCI_VERSION = "0.12.1"

# SOCI snapshotter versions
# https://github.com/awslabs/soci-snapshotter/releases
SOCI_VERSIONS = {
    "0.12.1": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.1/soci-snapshotter-0.12.1-linux-amd64.tar.gz",
            "sha256": "32518cdcd13ed099a5f201f32e10c917aa2958a4c196af5990b7bef37ac38b5d",
            # "strip_prefix": "soci-snapshotter-0.12.1-linux-amd64",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.1/soci-snapshotter-0.12.1-linux-arm64.tar.gz",
            "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            # "strip_prefix": "soci-snapshotter-0.12.1-linux-arm64",
        },
    },
}
