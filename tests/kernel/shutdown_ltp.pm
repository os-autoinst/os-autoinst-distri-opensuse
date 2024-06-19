# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Cleanup and shutdown after installing or running the LTP
# Maintainer: QE Kernel <kernel-qa@suse.de>
# For usage see tests/kernel/run_ltp.pm and tests/kernel/install_ltp.pm

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;
use LTP::utils;
use power_action_utils 'power_action';
use upload_system_log;

sub export_to_json {
    my ($test_result_export) = @_;
    my $export_file = 'ulogs/result_array.json';

    if (!-d 'ulogs') {
        mkdir('ulogs');
    }
    bmwqemu::save_json_file($test_result_export, $export_file);
}

sub run {
    my ($self, $tinfo) = @_;

    if (defined $tinfo) {
        export_to_json($tinfo->test_result_export);
    }

    script_run('df -h');
    check_kernel_taint($self, 1);

    if (get_var('LTP_COMMAND_FILE')) {
        my $ver_linux_log = '/tmp/ver_linux_after.txt';
        script_run("\$LTPROOT/ver_linux > $ver_linux_log 2>&1");
        upload_logs($ver_linux_log, failok => 1);
    }

    upload_system_logs();

    power_action('poweroff');
}

sub test_flags {
    return {fatal => 1};
}

1;
