# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "basetest";

use qam;
use testapi;

sub run {
    system_login;

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    capture_state('between-after');

    assert_script_run("zypper -n lr | grep test-minimal");

    assert_script_run("zypper ref");

    script_run("zypper -n patch --with-interactive -l; echo 'worked-patch-\$?' > /dev/$serialdev", 0);

    my $ret = wait_serial "worked-patch-\?-", 700;
    $ret =~ /worked-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102 || $1 == 103;

    script_run("zypper -n patch --with-interactive -l; echo 'worked-2-patch-\$?-' > /dev/$serialdev", 0);    # first one might only have installed "update-test-affects-package-manager"
    $ret = wait_serial "worked-2-patch-\?-", 1500;
    $ret =~ /worked-2-patch-(\d+)/;
    die "zypper failed with code $1" unless $1 == 0 || $1 == 102;

    capture_state('after', 1);

    set_var('SYSTEM_IS_UPDATED', 1);
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
