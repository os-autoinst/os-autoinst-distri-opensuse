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
    select_console 'root-console';
    # "agama logs store" gathers output from dmesg, journalctl and y2logs.
    save_and_upload_log('agama logs store', "/tmp/agama_logs.tar.bz2");
    upload_traces();
}

sub post_run_hook {
    reset_consoles;
    $testapi::username = "bernhard";
    $testapi::password = 'nots3cr3t';
}

sub test_flags {
    return {fatal => 1};
}

sub upload_traces {
    my ($dest, $sources) = ("/tmp/traces.tar.gz", "test-results/");
    script_run("tar czf $dest $sources");
    upload_logs($dest, failok => 1);
}

1;
