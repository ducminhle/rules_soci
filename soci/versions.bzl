"""SOCI version registry with SHA256 checksums"""

DEFAULT_VERSION = "0.12.1"

# NOTE: Update these SHA256 values by running:
# curl -L <URL> | sha256sum

SOCI_VERSIONS = {
    "0.12.1": {
        "linux_amd64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.1/soci-snapshotter-0.12.1-linux-amd64.tar.gz",
            "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "strip_prefix": "soci-snapshotter-0.12.1-linux-amd64",
        },
        "linux_arm64": {
            "url": "https://github.com/awslabs/soci-snapshotter/releases/download/v0.12.1/soci-snapshotter-0.12.1-linux-arm64.tar.gz",
            "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "strip_prefix": "soci-snapshotter-0.12.1-linux-arm64",
        },
    },
}

def get_soci_url(version, platform):
    """Get download URL for a specific SOCI version and platform

    Args:
        version: SOCI version string (e.g. "0.12.1")
        platform: Platform string (e.g. "linux_amd64")

    Returns:
        Dictionary with url, sha256, and strip_prefix
    """
    if version not in SOCI_VERSIONS:
        fail("Unknown SOCI version: {}. Available: {}".format(
            version,
            ", ".join(SOCI_VERSIONS.keys()),
        ))

    version_info = SOCI_VERSIONS[version]
    if platform not in version_info:
        fail("Platform {} not available for SOCI {}".format(platform, version))

    return version_info[platform]
