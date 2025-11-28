# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Cleanup and shutdown after installing or running the LTP
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use base 'opensusebasetest';
use testapi;
use utils;
use lockapi 'barrier_wait';
use LTP::utils;
use power_action_utils 'power_action';
use upload_system_log;
use kernel;
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

    run_supportconfig;

    script_run('cat /proc/stat');
    script_run('df -h');
    check_kernel_taint($self, has_published_assets() ? 1 : 0);

    if (get_var('LTP_COMMAND_FILE')) {
        my $ver_linux_log = '/tmp/ver_linux_after.txt';
        script_run("\$LTPROOT/ver_linux > $ver_linux_log 2>&1");
        upload_logs($ver_linux_log, failok => 1);
    }

    upload_system_logs();
    check_kernel_package(get_kernel_flavor()) if get_var('INSTALL_LTP');

    my $done_barrier = get_var('LTP_DONE_BARRIER');
    if ($done_barrier) {
        record_info('LTP done', "Signaling barrier $done_barrier");
        barrier_wait($done_barrier);
    }

    # Also cleanup machine-id to avoid duplicate ipv6 link local address in mutli-machine setup.
    script_run('echo -n >/etc/machine-id');

    power_action('poweroff');
}

sub post_fail_hook {
    select_console('root-console');
    script_run('cat /proc/stat');
}

sub test_flags {
    return {fatal => 1};
}

1;
