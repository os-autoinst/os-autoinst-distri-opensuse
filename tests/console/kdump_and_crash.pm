# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run 'crash' utility on a kernel memory dump
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "console_yasttest";
use strict;
use testapi;
use utils;
use kdump_utils;
use version_utils qw(is_sle sle_version_at_least);
use registration;

sub run {
    my ($self) = @_;
    select_console('root-console');

    # preparation for crash test
    if (is_sle && sle_version_at_least('15')) {
        add_suseconnect_product('sle-module-desktop-applications');
        add_suseconnect_product('sle-module-development-tools');
    }
    prepare_for_kdump;
    activate_kdump;

    # restart to activate kdump
    power_action('reboot');
    $self->wait_boot;
    select_console 'root-console';

    # often kdump could not be enabled: bsc#1022064
    return 1 unless kdump_is_active;
    do_kdump;
    power_action('reboot', observe => 1, keepconsole => 1);
    # wait for system's reboot
    $self->wait_boot;
    select_console 'root-console';

    # all but PPC64LE arch's vmlinux images are gzipped
    my $suffix = get_var('OFW') ? '' : '.gz';
    assert_script_run 'find /var/crash/';
    my $crash_cmd = "echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`$suffix";
    assert_script_run "$crash_cmd", 600;
    validate_script_output "$crash_cmd", sub { m/PANIC/ }, 600;
}

1;

# vim: set sw=4 et:
