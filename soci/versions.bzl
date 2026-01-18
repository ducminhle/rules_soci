"""Version constants for SOCI, Crane, and Regctl"""

# Default versions
DEFAULT_SOCI_VERSION = "0.12.1"
DEFAULT_CRANE_VERSION = "0.20.7"
DEFAULT_REGCTL_VERSION = "0.11.1"

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

# Crane (from go-containerregistry) versions
# https://github.com/google/go-containerregistry/releases
CRANE_VERSIONS = {
    "0.20.7": {
        "linux_amd64": {
            "url": "https://github.com/google/go-containerregistry/releases/download/v0.20.7/go-containerregistry_Linux_x86_64.tar.gz",
            "sha256": "8ef3564d264e6b5ca93f7b7f5652704c4dd29d33935aff6947dd5adefd05953e",
        },
        "linux_arm64": {
            "url": "https://github.com/google/go-containerregistry/releases/download/v0.20.7/go-containerregistry_Linux_arm64.tar.gz",
            "sha256": "b04ee6e4904d9219c76383f5b73521a63f69ecc93c0b1840846eebfd071a6355",
        },
    }
}
