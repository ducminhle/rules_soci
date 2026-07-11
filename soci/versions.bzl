"""Version constants for SOCI"""

# Default versions
DEFAULT_SOCI_VERSION = "0.14.1"
DEFAULT_CRANE_VERSION = "0.21.7"

# SOCI snapshotter versions
# https://github.com/awslabs/soci-snapshotter/releases
SOCI_VERSIONS = {
    "0.14.1": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.14.1/soci-snapshotter-0.14.1-linux-amd64.tar.gz",
            "sha256": "1a8dba2a14c1ba8b65e0b935ef697e22eb8324759961a65296e656dd724d9441",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.14.1/soci-snapshotter-0.14.1-linux-arm64.tar.gz",
            "sha256": "c01ecb402ac7930bcfcf6571f76da541d7054626337d7211dac0b11a9bd05ddc",
        },
    },
    "0.14.0": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.14.0/soci-snapshotter-0.14.0-linux-amd64.tar.gz",
            "sha256": "c21e0fa776699919706b18e226837278f66dfc7b9a8509a32a043afe4b5efbbc",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.14.0/soci-snapshotter-0.14.0-linux-arm64.tar.gz",
            "sha256": "ba6816af489428ff636f06986243b9fba5ca61b7c4fe9acfaa112763ed80a39d",
        },
    },
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
}

# crane (from google/go-containerregistry), used by soci_push to push the
# SOCI-converted OCI-layout directory without needing containerd/nerdctl.
# Hashes below are the real sha256 values from each release's checksums.txt
# (https://github.com/google/go-containerregistry/releases) -- to bump the
# version, download that release's checksums.txt and copy the matching lines.
CRANE_VERSIONS = {
    "0.21.7": {
        "linux_amd64": {
            "url": "https://github.com/google/go-containerregistry/releases/download/v0.21.7/go-containerregistry_Linux_x86_64.tar.gz",
            "sha256": "1a57bc98207fa1c0d04bf760699099e26f8383499bfd55b99c1b919a928a7230",
        },
        "linux_arm64": {
            "url": "https://github.com/google/go-containerregistry/releases/download/v0.21.7/go-containerregistry_Linux_arm64.tar.gz",
            "sha256": "b6ee979d9411dfb05ce35ab9e156fe5de7def11a230764a7856ffa2eb971fa88",
        },
        "darwin_amd64": {
            "url": "https://github.com/google/go-containerregistry/releases/download/v0.21.7/go-containerregistry_Darwin_x86_64.tar.gz",
            "sha256": "63a7dd15168d4dcac37933c7f6745438f2943d5898a1cf7896ad3341d8519bf2",
        },
        "darwin_arm64": {
            "url": "https://github.com/google/go-containerregistry/releases/download/v0.21.7/go-containerregistry_Darwin_arm64.tar.gz",
            "sha256": "1858c55dcd6053fe869bcb0c4ec20666383ddce445ad0f7e15e1e506b1f7fe52",
        },
    },
}
