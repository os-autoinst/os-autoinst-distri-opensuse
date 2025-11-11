# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run stress-ng on NFS
#    Should run after nfs_client/server.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal;
use lockapi;
use utils;
use registration;
use version_utils 'is_sle';

sub server {
    barrier_wait('NFS_STRESS_NG_START');
    barrier_wait('NFS_STRESS_NG_END');

    script_run('nfsstat -s');
}

sub client {
    my $local_nfs3 = "/home/localNFS3";
    my $local_nfs4 = "/home/localNFS4";
    my $local_nfs3_async = "/home/localNFS3async";
    my $local_nfs4_async = "/home/localNFS4async";
    my $stressor_timeout = get_var('NFS_STRESS_NG_TIMEOUT') // 3;
    my $run_stress_ng = "stress-ng --verbose --sequential -1 --timeout $stressor_timeout --class filesystem";
    my @paths = ($local_nfs3, $local_nfs4, $local_nfs3_async, $local_nfs4_async);

    # in case this is SLE15 we need packagehub for stress-ng, let's enable it
    # in case this is SLE16+ we need QA repo
    if (is_sle('<16')) {
        add_suseconnect_product(get_addon_fullname('phub'));
    } elsif (is_sle('>16')) {
        add_qa_head_repo(priority => 100);
    }

    zypper_call("in stress-ng");

    select_user_serial_terminal;
    assert_script_run("stress-ng --class 'filesystem?'");

    barrier_wait('NFS_STRESS_NG_START');

    my $result = 0;
    foreach my $path (@paths) {
        assert_script_run('cd ' . $path);
        my $ret = script_run($run_stress_ng, timeout => $stressor_timeout * 100);

        if ($ret == 0) {
            record_info('stress-ng', "return: 0 (success), path: $path");
        } elsif ($ret == 2) {
            record_info('stress-ng', "return: 2 (stressor failed), path: $path", result => 'fail');
        } else {
            record_info('stress-ng', "return: $ret (other failure), path: $path", result => 'fail');
        }

        $result = $ret if ($ret > $result);
    }

    barrier_wait('NFS_STRESS_NG_END');

    if ($result != 0) {
        die "stress-ng reported failures (max exit code: $result)";
    }

    select_serial_terminal;
    script_run('nfsstat');
}

sub run {
    select_serial_terminal;

    my $role = get_required_var('ROLE');

    if ($role eq 'nfs_client') {
        client;
    } else {
        server;
    }
}

1;
