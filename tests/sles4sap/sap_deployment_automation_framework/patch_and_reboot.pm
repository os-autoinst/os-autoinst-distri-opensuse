# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Prepare and execute robot framework test suite performing patching and rebooting SUT

=head1 NAME

sles4sap/sap_deployment_automation_framework/patch_and_reboot.pm - Execute robot framework 'patch and reboot' test.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=head1 DESCRIPTION

Test module sets up environment for robot testing framework and executes test suite. Test suite patches SUTs with
maintenance updates.

B<The key tasks performed by this module include:>

=over

=item * Prepare file and directory structure for robot framework test.

=item * Install robot framework, pabot and other required packages.

=item * Download robot script into deployer VM

=item * Fetch private key required for accessing SUTs

=item * Prepare pabot argument files for each SUT node

=item * Execute robot script using pabot

=item * Collect logs and assert pabot results

=back

=head1 openQA SETTINGS

=over

=item * B<INCIDENT_REPO> : Incident repository URL

=item * B<IS_MAINTENANCE> : Define if test scenario includes applying maintenance updates

=item * B<REPO_MIRROR_HOST> : IBSm repository hostname

=back
=cut

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use qam qw(get_test_repos);
use utils qw(write_sut_file);
use sles4sap::azure_cli;
use sles4sap::sap_deployment_automation_framework::naming_conventions;
use sles4sap::console_redirection;
use sles4sap::console_redirection::redirection_data_tools;
use sles4sap::sap_deployment_automation_framework::deployment qw(get_workload_resource_group sdaf_ssh_key_from_keyvault);
use sles4sap::sap_deployment_automation_framework::deployment_connector qw(find_deployment_id);
use sles4sap::sap_deployment_automation_framework::basetest qw(sdaf_ibsm_teardown);

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    unless (get_var('IS_MAINTENANCE')) {
        # Just a safeguard for case the module is in schedule without 'IS_MAINTENANCE' openQA setting being set
        record_info('MAINTENANCE OFF', 'openQA setting "IS_MAINTENANCE" is disabled, skipping IBSm setup');
        return;
    }
    connect_target_to_serial;
    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my %update_hosts = %{$redirection_data->get_sap_hosts};

    my $root_dir = '/tmp/robot';
    my $log_dir = "$root_dir/logs";
    my $test_dir = "$root_dir/patch_and_reboot";
    my $sut_ssh_key_path = '/home/azureadm/.ssh/sut_id_rsa';

    # Ensure there is no log file and recreate dirs
    assert_script_run("rm -Rf $log_dir $test_dir");
    assert_script_run("mkdir -p $log_dir $test_dir");

    # Install pip and robot fw if needed.
    assert_script_run('sudo zypper in python3-pip') if script_run('pip -V');
    # This installs all robot requirements
    # Pabot is for executing test suites in parallel
    assert_script_run('pip install --upgrade robotframework-sshlibrary robotframework-pabot==5.1.0');

    my $cmd_robot_fetch = join(' ', 'curl', '-v', '-fL',
        data_url("sles4sap/sap_deployment_automation_framework/robot_tests/patch_and_reboot.robot"),
        '-o', "$test_dir/patch_and_reboot.robot"
    );
    assert_script_run($cmd_robot_fetch);
    # Path to robot binaries installed by pip
    assert_script_run('export PATH=$PATH:/home/azureadm/.local/bin');

    # Fetch SUT SSH key from keyvault
    my $workload_rg = get_workload_resource_group(deployment_id => find_deployment_id());
    my $workload_key_vault = ${az_keyvault_list(resource_group => $workload_rg)}[0];
    sdaf_ssh_key_from_keyvault(key_vault => $workload_key_vault, target_file => $sut_ssh_key_path);

    my @arg_files;
    my $arg_index = 1;
    my $repo_mirror = get_required_var('INCIDENT_REPO');
    my $repo_mirror_host = get_required_var('REPO_MIRROR_HOST');
    # Prepare test argument files
    for my $hostname (keys %update_hosts) {
        my $file_content = <<"file_content";
--name  Patch host "$hostname"
--variable
HOST_IP:$update_hosts{$hostname}{ip_address}
--variable
HOSTNAME:$hostname
--variable
KEYFILE:$sut_ssh_key_path
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
        "--processes " . scalar(@arg_files),    # number of processes to run in parallel
        '--exitonfailure',    # if test inside test suite fails, executiion is stopped
        '--xunit xunit_result.xml',
        @arg_files,
        $test_dir
    );
    assert_script_run("cd $log_dir");
    my $pabot_rc = script_run($pabot_cmd, timeout => 3600);

    assert_script_run("tar -cvzf $log_dir/ibsm_patch_and_reboot.zip $log_dir/*");
    upload_logs("$log_dir/ibsm_patch_and_reboot.zip");
    # Robot logs - uploaded as log files
    my @robot_logs = split("\n", script_output("ls $log_dir | grep ssh_"));
    record_info('Log upload', "Uploading robot log files:\n" . join("\n", @robot_logs));
    upload_logs("$log_dir/$_", log_name => "$_.txt") foreach @robot_logs;
    # List of log files to collect
    my @robot_assets = split("\n", script_output("ls $log_dir | grep .htm"));
    record_info('Asset upload', "Uploading robot log files:\n" . join("\n", @robot_assets));
    upload_asset($_) foreach @robot_assets;
    parse_extra_log(XUnit => "$log_dir/xunit_result.xml");

    disconnect_target_from_serial;
    record_info('IBSm Destroy', 'Destroying IBSm peering to release resources as soon as possible.');
    sdaf_ibsm_teardown();
    die 'Robot test suite failed. Check logs for details.' if $pabot_rc;
}

1;
