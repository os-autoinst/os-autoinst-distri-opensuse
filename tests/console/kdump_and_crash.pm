# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run 'crash' utility on a kernel memory dump
# Maintainer: Michal Nowak <mnowak@suse.com>, Yi Xu <yxu@suse.com>

use base "opensusebasetest";
use base "console_yasttest";
use strict;
use testapi;
use utils;
use kdump_utils;

sub run() {
    my ($self) = @_;
    select_console('root-console');

    # preparation for crash test
    prepare_for_kdump;
    activate_kdump;

    # restart to activate kdump
    script_run 'reboot', 0;
    $self->wait_boot;
    reset_consoles;
    select_console 'root-console';

    # often kdump could not be enabled: bsc#1022064
    return 1 unless kdump_is_active;
    do_kdump;
    # wait for system's reboot
    $self->wait_boot;
    reset_consoles;
    select_console 'root-console';

    # all but PPC64LE arch's vmlinux images are gzipped
    my $suffix = check_var('ARCH', 'ppc64le') ? '' : '.gz';
    my $crash_cmd = "echo exit | crash `ls -1t /var/crash/*/vmcore | head -n1` /boot/vmlinux-`uname -r`$suffix";
    assert_script_run "$crash_cmd", 600;
    validate_script_output "$crash_cmd", sub { m/PANIC/ }, 600;
}

1;

# vim: set sw=4 et:
