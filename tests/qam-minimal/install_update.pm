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

    if (!get_var('INCIDENT_REPO')) {
        die "no repository with update";
    }

    capture_state('before');

    my $repo = get_var('INCIDENT_REPO');
    zypper_call("ar -f $repo test-minimal");

    zypper_call("ref");

    zypper_call('in -l -t patch ' . get_var('INCIDENT_PATCH'), exitcode => [0, 102, 103], log => 'zypper.log');

    capture_state('between', 1);

    prepare_system_reboot;
    type_string "reboot\n";
    $self->wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
