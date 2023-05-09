# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package qa_run;
# Summary: base class for qa_automation tests in openQA
# Maintainer: QE Core <qe-core@suse.de>

use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use registration 'add_suseconnect_product';
use repo_tools qw(add_qa_head_repo add_qa_web_repo);
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle package_version_cmp);

sub test_run_list {
    return ('_reboot_off', @{get_var_array('QA_TESTSUITE', get_var('QA_TESTSET', '') =~ s/[^_]*_//r)});
}

sub system_status {
    my $self = shift;
    my $log = shift || "/tmp/system-status.log";
    my @klst = ("kernel", "cpuinfo", "memory", "iptables", "repos", "dmesg", "journalctl");
    my %cmds = (
        kernel => "uname -a",
        cpuinfo => "cat /proc/cpuinfo",
        memory => "free -m",
        iptables => "iptables -L -n --line-numbers",
        repos => "zypper repos -u",
        dmesg => "dmesg",
        journalctl => "journalctl -xn 100 -o short-precise"
    );
    foreach my $key (@klst) {
        my $cmd = "echo '=========> $key <=========' >> $log; ";
        $cmd .= "$cmds{$key} >> $log; ";
        $cmd .= "echo '' >> $log";
        script_run($cmd, 40);
    }
    return $log;
}


sub system_login {
    my $self = shift;
    select_serial_terminal;
}

# Call test_run_list and write the result into /root/qaset/config
sub qaset_config {
    my $self = shift;
    my @list = $self->test_run_list();
    return unless @list;
    assert_script_run("mkdir -p /root/qaset");
    my $testsuites = "\n\t" . join("\n\t", @list) . "\n";
    assert_script_run("echo 'SQ_TEST_RUN_LIST=($testsuites)' > /root/qaset/config");

    # If running the systemd testsuite we need to workaround several issues
    if (index($testsuites, "systemd") != -1) {
        if (is_sle('>=15')) {
            # poo88597 We need an executable boot.local to avoid failing rc-local service test for sle15+
            my $boot_local = "/etc/init.d/boot.local";
            assert_script_run("echo '#!/bin/sh' > $boot_local");
            assert_script_run("chmod +x $boot_local");
        }

        # Reset the failed state of all units so that only new failures are recorded
        assert_script_run("systemctl reset-failed");

        # In order for mdmonitor.service to be running,
        # create a RAID 1 array made of 2 loop devices with size 50 Mb each
        create_raid_loop_device(raid_type => 1, device_num => 2, file_size => 50);
    }
}

# Add qa head repo for kernel testing. If QA_SERVER_REPO is set,
# remove all existing zypper repos first
sub prepare_repos {
    my $self = shift;
    my $qa_server_repo = get_var('QA_SERVER_REPO', '');
    my $qa_sdk_repo = get_var('QA_SDK_REPO', '');
    quit_packagekit;
    if ($qa_server_repo) {
        # Remove all existing repos and add QA_SERVER_REPO
        script_run('for ((i = $(zypper lr| tail -n+5 |wc -l); i >= 1; i-- )); do zypper -n rr $i; done; unset i', 300);
        zypper_call("--no-gpg-checks ar -f '$qa_server_repo' server-repo");
        if ($qa_sdk_repo) {
            zypper_call("--no-gpg-checks ar -f '$qa_sdk_repo' sle-sdk");
        }
    }

    add_qa_head_repo;
    add_qa_web_repo;
    add_suseconnect_product('sle-module-python2') if is_sle('>15') && is_sle('<15-sp4') && get_var('FLAVOR') !~ /-Updates$|-Incidents/;
    my $python_packages = is_sle('<15-sp4') ? 'python-base python-xml' : '';
    zypper_call("in qa_testset_automation qa_tools ${python_packages}");
}

# Create qaset/config file, reset qaset, and start testrun
sub start_testrun {
    my $self = shift;
    $self->qaset_config();
    # workaround dashboard query https://sd.suse.com/servicedesk/customer/portal/1/SD-62274
    assert_script_run('rm /usr/share/qa/qaset/libs/msg_queue.sh');
    assert_script_run("/usr/share/qa/qaset/qaset reset");
    assert_script_run("/usr/share/qa/qaset/run/kernel-all-run.openqa");
}

# Check whether DONE file exists every $sleep secs in the background
sub wait_testrun {
    my $self = shift;
    my %args = @_;
    my $timeout = $args{timeout} || 180 * 60;
    my $sleep = $args{sleep} || 30;
    my $fdone = '/var/log/qaset/control/DONE';
    my $pattern = "TESTRUN_FINISHED";
    my $code = int(rand(999999));
    my $redir = (is_serial_terminal) ? "" : " >> /dev/$serialdev";
    my $cmd = "code=$code; while [[ ! -f $fdone ]]; do sleep $sleep; done; echo \"$pattern-\$code\" $redir";
    enter_cmd("bash -c '$cmd' &");
    # Set a high timeout value for wait_serial
    # so that it will wait until test run finished or
    # MAX_JOB_TIME(can be set on openQA webui) reached
    my $ret = wait_serial("$pattern-$code", $timeout);
    if (is_serial_terminal()) {
        # Print new terminal prompt for script_run
        send_key 'ret';
    }
    return $ret ? 1 : 0;
}


# Save the output of $cmd into $file and upload it
# qa_testset_automation validation test
sub run {
    my $self = shift;
    $self->system_login();
    $self->prepare_repos();

    $self->start_testrun();
    my $testrun_finished = $self->wait_testrun(timeout => 70 * 60);

    # Upload test logs
    my $tarball = "/tmp/qaset.tar.bz2";
    assert_script_run("tar cjf '$tarball' -C '/var/log/' 'qaset'", timeout => 300);
    upload_logs($tarball, timeout => 600);
    my $log = $self->system_status();
    upload_logs($log, timeout => 100);

    # JUnit xml report
    if (is_sle('<15-sp4')) {
        assert_script_run("python2 /usr/share/qa/qaset/bin/junit_xml_gen.py -n 'regression' -d -o /tmp/junit.xml /var/log/qaset");
        parse_junit_log("/tmp/junit.xml");
    }

    unless ($testrun_finished) {
        die "Test run didn't finish within time limit";
    }

    # Switch back to root-console
    select_console('root-console');
}

1;
