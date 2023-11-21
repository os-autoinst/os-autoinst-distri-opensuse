# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: kernel-default-debuginfo yast2-kdump kdump crash mokutil
# Summary: Run 'crash' utility on a kernel memory dump
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use kdump_utils;
use serial_terminal 'select_serial_terminal';


sub run {
    select_serial_terminal;
    if (kdump_utils::configure_service(test_type => 'function') == 16) {
        record_info 'Not supported', 'Kdump is not supported in a PV DomU';
        return;
    }
    kdump_utils::check_function(test_type => 'function');
}

sub post_fail_hook {
    my ($self) = @_;

    send_key 'ctrl-z';
    script_run 'ls -lah /boot/';
    script_run 'tar -cvJf /tmp/crash_saved.tar.xz -C /var/crash .';
    upload_logs '/tmp/crash_saved.tar.xz';

    $self->SUPER::post_fail_hook;
}

1;
