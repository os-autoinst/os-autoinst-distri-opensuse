# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


use base "basetest";

use strict;

use qam;
use testapi;

sub run {
    system_login;

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    if (!get_var('MINIMAL_TEST_REPO')) {
        die "no repository with update";
    }

    capture_state('before');

    my $repo = get_var('MINIMAL_TEST_REPO');
    assert_script_run("zypper -n ar -f '$repo' test-minimal");

    assert_script_run("zypper ref");
    script_run("zypper -n patch -r test-minimal ; echo 'worked-patch-\$?-' > /dev/$serialdev", 0);
    my $ret = wait_serial "worked-patch-\?-", 700;
    $ret =~ /worked-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102 || $1 == 103;

    capture_state('between', 1);
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
