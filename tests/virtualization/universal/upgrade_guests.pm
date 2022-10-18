# XEN regression tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh zypper
# Summary: Upgrade all guests to their latest state
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use warnings;
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use qam 'ssh_add_test_repositories';
use utils;
use virt_autotest::common;

sub run {
    my ($self) = @_;
    # Use serial terminal, unless defined otherwise. The unless will go away once we are certain this is stable
    select_serial_terminal unless get_var('_VIRT_SERIAL_TERMINAL', 1) == 0;

    script_run("mkdir /root/update_guests");
    foreach my $guest (keys %virt_autotest::common::guests) {
        # Remove test repositories. Those will be added in patch_guests again, here we want to upgrade the guests to the latest released version.
        script_run("ssh root\@$guest rm -f '/etc/zypp/repos.d/SUSE_Maintenance*' '/etc/zypp/repos.d/TEST*' '/tmp/dup*' ");
        # Update all guests at once to save some time.
        # Note: read from /dev/null to prevent ssh from being stopped.
        # Try update three times - this sometimes helps to prevent failures due to infrastructure problems
        assert_script_run("ssh root\@$guest 'zypper ref; (zypper -n dup || zypper -n dup || zypper -n dup)' </dev/null >/root/update_guests/$guest.txt 2>&1 & true");
    }
    assert_script_run("wait", timeout => 2400);    # this can take some time (max 40 minutes)

    # Make sure there are no phantom zypper processes present anymore
    script_retry("! ssh root\@$_ ps | grep zypper", delay => 5, retry => 60) foreach (keys %virt_autotest::common::guests);
}

sub post_fail_hook {
    my $self = shift;
    # Collect logs on failure
    script_run('tar -cf /root/update_logs.tar /root/update_guests');
    upload_logs('/root/update_logs.tar');
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

