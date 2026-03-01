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

Test module sets up environment for robot testing framework and executes test suite residing in 'HLQR' project.
Test suite patches SUTs with maintenance updates.

B<The key tasks performed by this module include:>

=over

=item * Prepare file and directory structure for robot framework test.

=item * Install robot framework, pabot and other required packages.

=item * Upload robot framework based 'HLQR' project into deployer VM

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

=item * B<HLQR_BRANCH> : Repository branch. Default: main

=item * B<HLQR_GIT_REPO> : Repository url. Mandatory setting.

=back
=cut

use parent 'sles4sap::sap_deployment_automation_framework::basetest';

use testapi;
use serial_terminal qw(select_serial_terminal);
use qam qw(get_test_repos);
use utils qw(write_sut_file);
use Utils::Git qw(git_clone);
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

    my $redirection_data = sles4sap::console_redirection::redirection_data_tools->new($run_args->{redirection_data});
    my %update_hosts = %{$redirection_data->get_sap_hosts};

    # Validate repository before getting project name
    assert_script_run('git ls-remote ' . get_required_var('HLQR_GIT_REPO'), quiet => 1);
    my ($project_name) = get_required_var('HLQR_GIT_REPO') =~ /\/([A-z0-9-_]+)(?:\.git)?$/;
    die 'Project name could not be extracted from repository url' unless $project_name;
    my $project_branch = get_var('HLQR_BRANCH', 'main');
    my $project_root_dir = "/tmp/$project_name";
    my $log_dir = "$project_root_dir/logs";
    my $test_dir = "$project_root_dir/tests";
    my $sut_ssh_key_path = '/home/azureadm/.ssh/sut_id_rsa';

    git_clone(get_required_var('HLQR_GIT_REPO'),
        branch => $project_branch,
        single_branch => 1,
        depth => 1,
        output_log_file => "/tmp/git_clone_$project_name.txt",
        target_dir => $project_root_dir
    );

    # Prepare test argument files
    my @arg_files;
    my $arg_index = 1;
    my $repo_mirror = get_required_var('INCIDENT_REPO');
    my $repo_mirror_host = get_required_var('REPO_MIRROR_HOST');
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
--variable
LOG_DIR:$log_dir
file_content
        record_info("$hostname ARGS", $file_content);
        write_sut_file("$test_dir/$hostname.args", $file_content);
        assert_script_run("ls $test_dir/$hostname.args");
        assert_script_run("cat $test_dir/$hostname.args");

        push(@arg_files, "--argumentfile$arg_index $test_dir/$hostname.args");
        $arg_index++;
    }

    assert_script_run("mkdir -p $log_dir");
    # Rsync the project to Deployer VM
    assert_script_run(join(' ', 'rsync -avz',
            "/tmp/$project_name",
            get_required_var('REDIRECT_DESTINATION_USER') . '@' . get_required_var('REDIRECT_DESTINATION_IP') . ':/tmp/'));

    # Connect to Deployer VM
    connect_target_to_serial;
    # Install pip if needed.
    assert_script_run('sudo zypper in python3-pip') if script_run('pip -V');
    # This installs all robot requirements inside python virtual environment
    assert_script_run("cd $project_root_dir");
    assert_script_run('python3 -m venv .venv');
    assert_script_run('export VIRTUAL_ENV_DISABLE_PROMPT=1');
    assert_script_run('source .venv/bin/activate');
    assert_script_run('.venv/bin/python3 -m pip install --upgrade pip');
    assert_script_run('pip install -r requirements.txt');

    # Fetch SUT SSH key from keyvault
    my $workload_rg = get_workload_resource_group(deployment_id => find_deployment_id());
    my $workload_key_vault = ${az_keyvault_list(resource_group => $workload_rg)}[0];
    sdaf_ssh_key_from_keyvault(key_vault => $workload_key_vault, target_file => $sut_ssh_key_path);

    my $pabot_cmd = join(' ', 'pabot',
        '--name "Patch and reboot all hosts"',
        "--processes " . scalar(@arg_files),    # number of processes to run in parallel
        '--exitonfailure',    # if test inside test suite fails, execution is stopped
        "--outputdir $log_dir",
        '--xunit xunit_result.xml',
        @arg_files,
        $test_dir
    );

    my $pabot_rc = script_run($pabot_cmd, timeout => 3600);
    assert_script_run("tar -cvzf /tmp/ibsm_patch_and_reboot.zip $log_dir/*");
    upload_logs('/tmp/ibsm_patch_and_reboot.zip');
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
