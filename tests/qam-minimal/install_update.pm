# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: QAM Minimal test in openQA
#    it prepares minimal instalation, boot it, install tested incident , try
#    reboot and update system with all released updates.
#
#    with QAM_MINIMAL=full it also installs gnome-basic, base, apparmor and
#    x11 patterns and reboot system to graphical login + start console and
#    x11 tests
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base "opensusebasetest";

use strict;

use utils;
use qam;
use testapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my $patch = get_required_var('INCIDENT_PATCH');

    capture_state('before');

    my $repo = get_required_var('INCIDENT_REPO');
    zypper_call("ar -f $repo test-minimal");

    zypper_call("ref");

    # test if is patch needed and record_info
    # record softfail on QAM_MINIMAL=small tests, or record info on others
    # if isn't patch neded, zypper call with install makes no sense
    if (is_patch_needed($patch)) {
        if (check_var('QAM_MINIMAL', 'small')) {
            record_soft_failure("Patch isn't needed on minimal installation poo#17412");
        }
        else {
            record_info('Not needed', q{Patch doesn't fix any package in minimal pattern});
        }
    }
    else {
        zypper_call("in -l -t patch $patch", exitcode => [0, 102, 103], log => 'zypper.log');

        save_screenshot;

        capture_state('between', 1);

        prepare_system_reboot;
        type_string "reboot\n";
        $self->wait_boot;
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
