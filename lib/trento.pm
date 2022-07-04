# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for Trento tests
# Maintainer: QE-SAP <qe-sap@suse.de>

## no critic (RequireFilenameMatchesPackage);

=encoding utf8

=head1 NAME

Trento test lib

=head1 COPYRIGHT

Copyright 2017-2020 SUSE LLC
SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE SAP <qe-sap@suse.de>

=cut

package trento;

use strict;
use warnings;
use testapi;
use mmapi 'get_current_job_id';
use utils qw(script_retry);
use File::Basename qw(basename);
use Exporter 'import';

our @EXPORT = qw(
  get_resource_group
  get_vm_name
  get_acr_name
  az_get_vm_ip
  VM_USER
  SSH_KEY
  cypress_install_container
  CYPRESS_LOG_DIR
  PODMAN_PULL_LOG
  cypress_exec
  cypress_test_exec
  cypress_log_upload
);

# Exported constants
use constant VM_USER => 'cloudadmin';
use constant SSH_KEY => '/root/.ssh/id_rsa';
use constant CYPRESS_LOG_DIR => '/root/result';
use constant PODMAN_PULL_LOG => '/tmp/podman_pull.log';

# Lib internal constants
use constant TRENTO_AZ_PREFIX => 'openqa-trento';
# Parameter 'registry_name' must conform to
# the following pattern: '^[a-zA-Z0-9]*$'.
# Azure does not support dash or underscore in ACR name
use constant TRENTO_AZ_ACR_PREFIX => 'openqatrentoacr';
use constant CYPRESS_IMAGE_TAG => 'goofy';

=head1 DESCRIPTION 

Package with common methods and default or constant  values for Trento tests

=head2 Methods

=head3 get_resource_group

Return a string to be used as cloud resource group.
It contains the JobId
=cut

sub get_resource_group {
    my $job_id = get_current_job_id();
    return TRENTO_AZ_PREFIX . "-rg-$job_id";
}

=head3 get_vm_name

Return a string to be used as cloud VM name.
It contains the JobId
=cut

sub get_vm_name {
    my $job_id = get_current_job_id();
    return TRENTO_AZ_PREFIX . "-vm-$job_id";
}

=head3 get_acr_name

Return a string to be used as cloud ACR name.
It contains the JobId
=cut

sub get_acr_name {
    return TRENTO_AZ_ACR_PREFIX . get_current_job_id();
}

=head3 az_get_vm_ip

Return the running VM public IP
=cut

sub az_get_vm_ip {
    my $az_cmd = 'az vm show -d ' .
      '-g ' . get_resource_group() . ' ' .
      '-n ' . get_vm_name() . ' ' .
      '--query "publicIps" ' .
      '-o tsv';
    return script_output($az_cmd, 180);
}

=head3 az_delete_group

Delete the resource group associated to this JobID and all its content
=cut

sub az_delete_group {
    script_run('echo "Delete all resources"');
    my $az_cmd = 'az group delete ' .
      '--resource-group ' . get_resource_group() .
      ' --yes';
    script_retry($az_cmd, timeout => 600, retry => 5, delay => 60);
}

=head3 az_vm_ssh_cmd

Compose I<ssh> command for remote execution on the VM machine.
The function optionally accept the VM public IP.
If not provided, the IP is calculated on the fly with an I<az> query,
take care that is a time consuming I<az> query.

=over 2

=item B<CMD_ARG> - String of the command to be executed remotely

=item B<VM_IP_ARG> - Public IP of the remote machine where to execute the command

=back
=cut

sub az_vm_ssh_cmd {
    my ($self, $cmd_arg, $vm_ip_arg) = @_;
    record_info('REMOTE', "cmd:$cmd_arg");

    # undef comparision operator
    my $vm_ip = $vm_ip_arg // az_get_vm_ip();
    return 'ssh' .
      ' -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR' .
      ' -i ' . SSH_KEY . ' ' .
      VM_USER . '@' . $vm_ip .
      ' -- ' . $cmd_arg;
}

=head3 k8s_logs

Get all relevant info out from the cluster

=over 2

=item B<CMD_ARG> - String of the command to be executed remotely

=item B<VM_IP_ARG> - Public IP of the remote machine where to execute the command

=back
=cut

sub k8s_logs {
    my $self = shift;
    my (@pods_list) = @_;
    my $machine_ip = az_get_vm_ip;

    return unless ($machine_ip);

    my $kubectl_pods = script_output($self->az_vm_ssh_cmd('kubectl get pods', $machine_ip), 180);
    # for each pod that I'm interested to inspect
    for my $s (@pods_list) {
        # for each running pod from 'kubectl get pods'
        foreach my $row (split(/\n/, $kubectl_pods)) {
            # name of the file where we will eventually dump the log
            my $describe_txt = "pod_describe_$s.txt";
            my $log_txt = "pod_log_$s.txt";
            # if the running pod is one of the ones I'm interested in...
            if ($row =~ m/trento-server-$s/) {
                # extract this pod name
                my $pod_name = (split /\s/, $row)[0];

                # get the description
                my $kubectl_describe_cmd = $self->az_vm_ssh_cmd("kubectl describe pods/$pod_name > $describe_txt", $machine_ip);
                script_run($kubectl_describe_cmd, 180);
                upload_logs($describe_txt);

                # get the log
                my $kubectl_logs_cmd = $self->az_vm_ssh_cmd("kubectl logs $pod_name > $log_txt", $machine_ip);
                script_run($kubectl_logs_cmd, 180);
                upload_logs($log_txt);
            }
        }
    }
    script_run('ls -lai *.txt', 180);
}

=head3 podman_self_check

Perform some generic checks related to the podman installation itself
and the relevant parameters of the current machine environment.
=cut

sub podman_self_check {
    record_info('PODMAN', 'Check podman');
    assert_script_run('which podman');
    assert_script_run('podman --version');
    assert_script_run('podman info --debug');
    assert_script_run('podman ps');
    assert_script_run('podman images');
    assert_script_run('df -h');
}

=head3 cypress_install_container

Prepare whatever is needed to run cypress tests using container

=over 1

=item B<CYPRESS_VER> - String used as tag for the cypress/included image.

=back
=cut

sub cypress_install_container {
    my ($self, $cypress_ver) = @_;
    podman_self_check();

    # list all the available cypress images
    my $cypress_image = 'docker.io/cypress/included';
    assert_script_run('podman search --list-tags ' . $cypress_image);

    # Pull in advance the cypress container
    my $podman_pull_cmd = 'time podman ' .
      '--log-level trace ' .
      'pull ' .
      '--quiet ' .
      $cypress_image . ':' . $cypress_ver .
      ' | tee ' . PODMAN_PULL_LOG;
    assert_script_run($podman_pull_cmd, 1800);
    assert_script_run('df -h');
    assert_script_run('podman images');
}

=head3 cypress_log_upload

Upload to openQA the relevant logs

=over 1

=item B<LOG_FILTER> - List of strings. List of file extensions (dot needed) 

=back
=cut

sub cypress_log_upload {
    my ($self, @log_filter) = @_;
    my $find_cmd = 'find ' . CYPRESS_LOG_DIR . ' -type f \( -iname \*' . join(' -o -iname \*', @log_filter) . ' \)';

    upload_logs("$_") for split(/\n/, script_output($find_cmd));
}

=head3 cypress_exec

Execute a cypress command within the container 

=over 5

=item B<CYPRESS_TEST_DIR> - String of the path where the cypress Trento code is available.
It is the I<test> folder within the path used by L<setup_jumphost>

=item B<CMD> - String of cmd to be used as main argument for the cypress
executable call. 

=item B<TIMEOUT> - Integer used as timeout for the cypress command execution

=item B<LOG_PREFIX> - String of the command to be executed remotely

=item B<FAILOK> - Integer boolean value. 0:test marked as failure if the podman/cypress
return not 0 exit code. 1:all not 0 podman/cypress exit code are ignored. SoftFail reported.

=back
=cut

sub cypress_exec {
    my ($self, $cypress_test_dir, $cmd, $timeout, $log_prefix, $failok) = @_;
    my $ret = 0;

    record_info('CY EXEC', 'Cypress exec:' . $cmd);
    my $cypress_ver = get_var(TRENTO_CYPRESS_VERSION => '4.4.0');
    my $image_name = "docker.io/cypress/included:$cypress_ver";
    # container is executed with --name to simplify the log retrieve.
    # To do so, we need to rm present container with the same name
    script_run('podman rm ' . CYPRESS_IMAGE_TAG . ' || echo "No ' . CYPRESS_IMAGE_TAG . ' to delete"');
    my $cypress_run_cmd = 'podman run ' .
      '-it --name ' . CYPRESS_IMAGE_TAG . ' ' .
      '-v ' . CYPRESS_LOG_DIR . ':/results ' .
      "-v $cypress_test_dir:/e2e -w /e2e " .
      '-e "DEBUG=cypress:*" ' .
      '--entrypoint=\'[' .
      '"/bin/sh", "-c", ' .
      '"/usr/local/bin/cypress ' . $cmd .
      ' 2>/results/cypress_' . $log_prefix . '_log.txt"' .
      ']\' ' . $image_name .
      ' | tee cypress_' . $log_prefix . '_result.txt';
    $ret = script_run($cypress_run_cmd, $timeout);
    if ($ret != 0) {
        # look for SIGTERM
        script_run('podman logs -t ' . CYPRESS_IMAGE_TAG);
        $self->result("fail");
    }
    if ($failok) {
        record_soft_failure("Cypress exit code:$ret at $log_prefix") if ($ret);
        $ret = 0;
    }
    die "Cypress exec error at '$cmd'" unless ($ret == 0);
}

=head3 cypress_test_exec

Execute a set of cypress tests.
Execute, one by one, all tests in all .js files in the provided folder. 

=over 3 

=item B<CYPRESS_TEST_DIR> - String of the path where the cypress Trento code is available.
It is the I<test> folder within the path used by L<setup_jumphost>

=item B<TEST_TAG> - String of the test subfolder within I<$cypress_test_dir/cypress/integration>
Also used as tag for each test result file

=item B<TIMEOUT> - Integer used as timeout for the internal L<cypress_exec> call

=back
=cut

sub cypress_test_exec {
    my ($self, $cypress_test_dir, $test_tag, $timeout) = @_;
    my $ret = 0;

    my $test_file_list = script_output("find $cypress_test_dir/cypress/integration/$test_tag -type f -iname \"*.js\"");

    for (split(/\n/, $test_file_list)) {
        # compose the JUnit .xml file name, starting from the .js filename
        my $test_filename = basename($_);
        my $test_result = 'test_result_' . $test_tag . '_' . $test_filename;
        $test_result =~ s/js$/xml/;
        my $test_cmd = 'run' .
          ' --spec \"cypress/integration/' . $test_tag . '/' . $test_filename . '\"' .
          ' --reporter junit' .
          ' --reporter-options \"mochaFile=/results/' . $test_result . ',toConsole=true\"';
        record_info('CY INFO', "test_filename:$test_filename test_result:$test_result test_cmd:$test_cmd");

        # execute the test: force $failok=1 to keep the execution going.
        # Any cypress test failure will be reported during the XUnit parsing
        $self->cypress_exec($cypress_test_dir, $test_cmd, $timeout, $test_tag, 1);

        # parsing the results
        my $find_cmd = 'find ' . $self->CYPRESS_LOG_DIR . ' -type f -iname "' . $test_result . '"';
        parse_extra_log("XUnit", $_) for split(/\n/, script_output($find_cmd));

        # upload all logs at once
        $self->cypress_log_upload(qw(.txt .mp4));
    }
}

1;
