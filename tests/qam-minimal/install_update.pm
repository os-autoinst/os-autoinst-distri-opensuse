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

use utils;
use qam;
use testapi;

sub run {
    prepare_system_reboot;
    system_login;

    script_run("while pgrep packagekitd; do pkcon quit; sleep 1; done");

    if (!get_var('MINIMAL_TEST_REPO')) {
        die "no repository with update";
    }

    capture_state('before');

    my $repo = get_var('MINIMAL_TEST_REPO');
    my $ret  = zypper_call("ar -f $repo test-minimal");
    die "zypper failed with code $ret" unless $ret == 0;

    $ret = zypper_call("ref");
    die "zypper failed with code $ret" unless $ret == 0;

    $ret = zypper_call(qq{in -l -y -t patch \$(zypper patches | awk -F "|" '/test-minimal/ { print \$2;}')});
    die "zypper failed with code $ret" unless grep { $_ == $ret } (0, 102, 103);

    capture_state('between', 1);
    prepare_system_reboot;
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
