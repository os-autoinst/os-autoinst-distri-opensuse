# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Setup peering between SUT VNET and IBSm VNET
# https://pabot.org/PabotLib.html

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use qam qw(get_test_repos);
use utils qw(write_sut_file);
use sles4sap::azure_cli;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' OpenQA setting being set
        record_info('MAINTENANCE OFF', 'OpenQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }
    connect_target_to_serial;
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my %database_hosts = %{$redirection_data->get_databases};

    my $root_dir = '/tmp/robot';
    my $log_dir = "$root_dir/logs";
    my $test_dir = "$root_dir/patch_and_reboot";

    # Ensure there is no log file and recreate dirs
    assert_script_run("rm -Rf $log_dir $test_dir");
    assert_script_run("mkdir -p $log_dir $test_dir");

    # Install pip and robot fw if needed.
    assert_script_run('sudo zypper in python3-pip') if script_run('pip -V');
    # This installs all robot requirements
    # Pabot is for executing test suites in parallel
    assert_script_run('pip install --upgrade robotframework-sshlibrary robotframework-pabot') if
      script_run('robot --version') && script_run('pabot --version');

    my $cmd_robot_fetch = join(' ', 'curl', '-v', '-fL',
        data_url("sles4sap/sap_deployment_automation_framework/robot_tests/patch_and_reboot.robot"),
        '-o', "$test_dir/patch_and_reboot.robot"
    );
    assert_script_run($cmd_robot_fetch);
    assert_script_run('export PATH=$PATH:/home/azureadm/.local/bin');

    my @arg_files;
    my $arg_index = 1;
    my $repo_mirror = get_required_var('INCIDENT_REPO');
    my $repo_mirror_host = get_required_var('REPO_MIRROR_HOST');
    # Prepare test argument files
    for my $hostname (keys %database_hosts) {
        my $file_content = <<"file_content";
--name  Patch host "$hostname"
--variable
HOST_IP:$database_hosts{$hostname}{ip_address}
--variable
HOSTNAME:$hostname
--variable
KEYFILE:/home/azureadm/.ssh/sut_id_rsa
--variable
REPO_MIRROR_HOST:$repo_mirror_host
--variable
INCIDENT_REPO:$repo_mirror
file_content
        record_info("$hostname ARGS", $file_content);
        write_sut_file("$test_dir/$hostname.args", $file_content);
        assert_script_run("ls $test_dir/$hostname.args");
        assert_script_run("cat $test_dir/$hostname.args");

        push(@arg_files, "--argumentfile$arg_index $test_dir/$hostname.args");
        $arg_index++;
    }
    my $pabot_cmd = join(' ', 'pabot',
        '--name "Patch and reboot all hosts"',
        "--processes " . scalar(@arg_files),
        '--xunit xunit_result.xml',
        @arg_files,
        $test_dir
    );
    assert_script_run("cd $log_dir");
    my $pabot_rc = script_run($pabot_cmd, timeout => 3600);

    assert_script_run("tar -cvzf $log_dir/ibsm_patch_and_reboot.zip $log_dir/*");
    upload_logs("$log_dir/ibsm_patch_and_reboot.zip");
    my $upload_url = data_url('log.html');
    $upload_url =~ s/data\///;

    record_info('url', $upload_url);
    upload_asset("$log_dir/log.html");
    upload_asset("$log_dir/report.html");
    parse_extra_log(XUnit => "$log_dir/xunit_result.xml");
    disconnect_target_from_serial;

    die 'Pabot dies, check logs' if $pabot_rc;
}

1;
