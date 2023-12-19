# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh open-vm-tools
# Summary: Simple vmware client testing with updated open-vm-tools
# Maintainer: Michael Grifalconi <mgrifalconi@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use virt_autotest::common;

sub run {
    my ($self) = @_;

    # Note: This test module will be deprecated, and the following test code has been moved to tests/virt_autotest/esxi_open_vm_tools.pm
    script_retry "ssh root\@$_ zypper -n in open-vm-tools", delay => 30, retry => 6 foreach (keys %virt_autotest::common::guests);

    assert_script_run "ssh root\@$_ /usr/bin/vmware-checkvm | grep 'good'" foreach (keys %virt_autotest::common::guests);

    assert_script_run "ssh root\@$_ systemctl restart vmtoolsd.service" foreach (keys %virt_autotest::common::guests);
    assert_script_run "ssh root\@$_ systemctl status vmtoolsd.service | grep 'Started open-vm-tools'" foreach (keys %virt_autotest::common::guests);

    assert_script_run "ssh root\@$_ /usr/bin/vmtoolsd -v | grep 'VMware Tools daemon, version'" foreach (keys %virt_autotest::common::guests);

    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level set vmtoolsd debug" foreach (keys %virt_autotest::common::guests);
    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level get vmtoolsd | grep 'vmtoolsd.level = debug'" foreach (keys %virt_autotest::common::guests);

    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level set vmtoolsd message" foreach (keys %virt_autotest::common::guests);
    assert_script_run "ssh root\@$_ vmware-toolbox-cmd logging level get vmtoolsd | grep 'vmtoolsd.level = message'" foreach (keys %virt_autotest::common::guests);

}

sub post_run_hook () {
    # The test is considered over, this step ensures virtual machine guest is unlocked by removing the 'lock_guest' file via SSH,
    # it is called at the conclusion of a test run.
    script_run("ssh root\@$_ rm lock_guest") foreach (keys %virt_autotest::common::guests);
}

1;
