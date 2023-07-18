## Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: base class for Agama tests
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::agama::agama_base;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use y2_base 'save_upload_y2logs';
use Utils::Logging 'save_and_upload_log';
use utils 'ensure_serialdev_permissions';
use serial_terminal qw(select_serial_terminal);

sub pre_run_hook {
    $testapi::password = 'linux';
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    y2_base::save_upload_y2logs($self, skip_logs_investigation => 1);
    save_and_upload_log('journalctl -u agama-auto', "/tmp/agama-auto-log.txt");
}

sub post_run_hook {
    reset_consoles;
    $testapi::username = "bernhard";
    $testapi::password = 'nots3cr3t';
    select_serial_terminal();
    ensure_serialdev_permissions;
}

sub test_flags {
    return {fatal => 1};
}

1;
