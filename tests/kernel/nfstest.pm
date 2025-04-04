
# SUSE's openQA tests#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: run nfstest testsuite
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use Utils::Logging "export_logs_basic";

sub install_nfstest {
    zypper_call("in git-core tcpdump");
    my $nfstest_git = get_var("NFSTEST_GIT", "https://gitlab.suse.de/MMoese/nfstest.git");
    assert_script_run("git -c http.sslVerify=false clone $nfstest_git");
}

sub setup_ssh_keys {
    my $server = get_var('SERVER_NODE', 'server-node00');
    my $client = get_var('CLIENT_NODE', 'client-node00');

    # create a ssh key if we don't have one
    script_run('[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -b 2048 -t rsa -q -N "" -f /root/.ssh/id_rsa');

    # distribute the ssh key to the machines
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$server");
    script_run("/usr/bin/clear");
    exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$client");
    script_run("/usr/bin/clear");
}

sub nfstest {
    my $nfstest_server = get_var('SERVER_NODE', 'server-node00');
    my $nfstest_export = get_var('NFSTEST_SHARE', "/nfs/shared_nfs4");

    install_nfstest;

    script_run("cd nfstest");
    script_run('export PYTHONPATH=$PWD');
    script_run("cd test");

    my @testcases = split /\s+/, get_required_var('NFSTEST_TESTCASES');
    foreach my $testcase (@testcases) {
        record_info("$testcase");
        script_run("./nfstest_$testcase --server $nfstest_server --export $nfstest_export --xunit-report --xunit-report-file=$testcase.xml", timeout => 360);
        parse_extra_log('XUnit', "$testcase.xml");
    }
}

sub run {
    barrier_wait("NFS_NFSTEST_START");

    select_serial_terminal;
    my $role = get_required_var('ROLE');
    setup_ssh_keys if get_var('NFSTEST_SSH');
    nfstest if $role eq "nfs_client";

    barrier_wait("NFS_NFSTEST_END");
}

1;
