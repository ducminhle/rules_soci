"""Version constants for SOCI"""

# Default versions
DEFAULT_SOCI_VERSION = "0.13.0"

# SOCI snapshotter versions
# https://github.com/awslabs/soci-snapshotter/releases
SOCI_VERSIONS = {
    "0.13.0": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.13.0/soci-snapshotter-0.13.0-linux-amd64.tar.gz",
            "sha256": "8951d87d6d17d719f7155d89f25ce08e139c3b48ef3323ee8e347de2d8c2d555",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.13.0/soci-snapshotter-0.13.0-linux-arm64.tar.gz",
            "sha256": "dab5117cc50b0343521ae9f6dc691b4d3ab5f7eb19404d1f7c35524b48bcdad5",
        },
    },
    "0.12.1": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.1/soci-snapshotter-0.12.1-linux-amd64.tar.gz",
            "sha256": "32518cdcd13ed099a5f201f32e10c917aa2958a4c196af5990b7bef37ac38b5d",
            # "strip_prefix": "soci-snapshotter-0.12.1-linux-amd64",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.1/soci-snapshotter-0.12.1-linux-arm64.tar.gz",
            "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        },
    },
    "0.12.0": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.0/soci-snapshotter-0.12.0-linux-amd64.tar.gz",
            "sha256": "8107bc214e2021283427bf6c65b722581c798cd9b309f5d0ccb3b9d317c585de",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.0/soci-snapshotter-0.12.0-linux-arm64.tar.gz",
            "sha256": "46a44dc817fc847e0483f608079fb5f17d57e775c401f57dc787070cdd85a194",
        },
    },
}
