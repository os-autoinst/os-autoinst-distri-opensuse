# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Verify CONFIG_STACKPROTECTOR_STRONG in the running kernel.
# Ported from tests/security/check_kernel_config/CC_STACKPROTECTOR_STRONG.pm

import os
import platform

import pytest

OPTION = "CONFIG_STACKPROTECTOR_STRONG=y"


def _kernel_config_path():
    """Return the kernel configuration file, overridable with KERNEL_CONFIG."""
    return os.environ.get("KERNEL_CONFIG", "/boot/config-" + platform.release())


@pytest.fixture(scope="module")
def kernel_config():
    path = _kernel_config_path()
    assert os.path.isfile(path), "Kernel configuration {} not found".format(path)
    with open(path) as f:
        return f.read().splitlines()


def test_kernel_config_is_readable(kernel_config):
    """The kernel configuration of the running kernel must be available."""
    assert kernel_config, "Kernel configuration {} is empty".format(_kernel_config_path())


@pytest.mark.skipif(platform.machine() == "s390x", reason="not enabled on s390x")
def test_stackprotector_strong_is_enabled(kernel_config):
    """The strong stack protector must be enabled to harden against stack buffer overflows."""
    found = [line for line in kernel_config if line.startswith("CONFIG_STACKPROTECTOR")]
    assert OPTION in kernel_config, (
        "{} is not set, found: {}".format(OPTION, found)
    )


@pytest.mark.skipif(platform.machine() != "s390x", reason="only checked on s390x")
def test_stackprotector_strong_is_absent_on_s390x(kernel_config):
    """The feature is not included on s390x, the option must not be set there."""
    assert OPTION not in kernel_config, (
        "The kernel parameter is wrongly configured on s390x: {} is set".format(OPTION)
    )


if __name__ == "__main__":
    pytest.main([__file__])
