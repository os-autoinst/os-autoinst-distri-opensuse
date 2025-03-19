# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Cleanup and shutdown after installing or running the LTP
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;
use LTP::utils;
use power_action_utils 'power_action';
use upload_system_log;
use qam;

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
    check_kernel_taint($self, has_published_assets() ? 1 : 0);

    if (get_var('LTP_COMMAND_FILE')) {
        record_info('ver_linux', script_output("\$LTPROOT/ver_linux", proceed_on_failure => 1));
    }

    upload_system_logs();

    power_action('poweroff');
}

sub test_flags {
    return {fatal => 1};
}

1;
