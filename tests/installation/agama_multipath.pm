## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Confirm multipath during installation.
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "installbasetest";

use testapi;

sub run {
    assert_and_click('agama-multipath');
}

1;
