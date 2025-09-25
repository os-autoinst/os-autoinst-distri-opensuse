# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run basic xen smoketest on a publiccloud test instance
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use utils;

sub run {
    # Check if we are using Xen hypervisor by searching for matching output in dmesg
    assert_script_run("sudo dmesg > /var/tmp/dmesg");
    assert_script_run("grep -e 'Hypervisor detected:.*Xen' /var/tmp/dmesg");
    assert_script_run("grep -i 'Booting paravirtualized kernel on Xen' /var/tmp/dmesg");
}

1;
