# SUSE's openQA tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for Trento tests

## no critic (RequireFilenameMatchesPackage);
package trento;

use strict;
use warnings;
use testapi;
use mmapi 'get_current_job_id';
use utils qw(script_retry);
use Carp qw(croak);
use Exporter 'import';

our @EXPORT = qw(
  TRENTO_AZ_PREFIX
  get_resource_group
  get_vm_name
  get_acr_name
  az_get_vm_ip
  VM_USER
  SSH_KEY
  cypress_install_container
  PODMAN_PULL_LOG
  CYPRESS_LOG_DIR
  cypress_exec
  cypress_test_exec
  cypress_log_upload
);

=head1 SYNOPSIS
Package with common methods and default values for Trento tests

=cut

use constant TRENTO_AZ_PREFIX => 'openqa-trento';
# Parameter 'registry_name' must conform to the following pattern: '^[a-zA-Z0-9]*$'.
use constant TRENTO_AZ_ACR_PREFIX => 'openqatrentoacr';


=head2 get_resource_group
Return a string to be used as cloud resource group.
It contains the JobId

=cut
sub get_resource_group {
    my $job_id = get_current_job_id();
    return TRENTO_AZ_PREFIX . "-rg-$job_id";
}


=head2 get_vm_name
Return a string to be used as cloud VM name.
It contains the JobId

=cut
sub get_vm_name {
    my $job_id = get_current_job_id();
    return TRENTO_AZ_PREFIX . "-vm-$job_id";
}


=head2 get_acr_name
Return a string to be used as cloud ACR name.
It contains the JobId

=cut
sub get_acr_name {
    return TRENTO_AZ_ACR_PREFIX . get_current_job_id();
}


=head2 az_get_vm_ip
Return the running VM IP

=cut
sub az_get_vm_ip {
    my $az_cmd = 'az vm show -d ' .
      '-g ' . get_resource_group() . ' ' .
      '-n ' . get_vm_name() . ' ' .
      '--query "publicIps" ' .
      '-o tsv';
    return script_output($az_cmd, 180);
}


=head2 az_delete_group
Delere resource group and so all its content

=cut
sub az_delete_group {
    script_run('echo "Delete all resources"');
    my $az_cmd = 'az group delete ' .
      '--resource-group ' . get_resource_group() .
      ' --yes';
    script_retry($az_cmd, timeout => 600, retry => 5, delay => 60);
}


use constant VM_USER => 'cloudadmin';
use constant SSH_KEY => '/root/.ssh/id_rsa';


=head2 az_vm_ssh_cmd
Compose ssh command for remote ssh execution on the VM machine
The function optionally accept the vm ip.
If it is not provided it is calculated on the fly with an az query,
take care that is a time consuming az query.
=cut
sub az_vm_ssh_cmd {
    my ($self, $cmd_arg, $vm_ip_arg) = @_;
    my $vm_ip;
    record_info('REMOTE', "cmd:$cmd_arg");
    if (defined $vm_ip_arg) {
        $vm_ip = $vm_ip_arg;
    }
    else {
        $vm_ip = az_get_vm_ip();
    }
    return 'ssh' .
      ' -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR' .
      ' -i ' . SSH_KEY . ' ' .
      VM_USER . '@' . $vm_ip .
      ' -- ' . $cmd_arg;
}


=head2 k8s_logs
Get all relevan tinfo out from the cluster
=cut
sub k8s_logs {
    my $self = shift;
    my (@pods_list) = @_;
    my $machine_ip = az_get_vm_ip;

    if ($machine_ip ne "") {
        my $kubectl_pods = script_output($self->az_vm_ssh_cmd('kubectl get pods', $machine_ip), 180);
        # for each pod that I'm interested to inspect
        for my $s (@pods_list) {
            # for each running pod from 'kubectl get pods'
            foreach my $row (split(/\n/, $kubectl_pods)) {
                # name of the file where we will eventually dump the log
                my $describe_txt = "pod_describe_$s.txt";
                my $log_txt = "pod_log_$s.txt";
                # if the running pod is one of them that I'm interested about...
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
}


=head2 podman_self_check
Perform some generic checks realted to the podman installation itself
and the relevant paramenters of the current machine environment.

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


use constant PODMAN_PULL_LOG => '/tmp/podman_pull.log';


=head2 crypress_install_container
Prepare whatever is needed to run cypress tests using container

=cut
sub cypress_install_container {
    my ($cypress_ver) = @_;
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


use constant CYPRESS_LOG_DIR => '/root/result';


=head2 cypress_log_upload
Upload to openQA the relevant logs
Optional argument array of strings with relevant file extensions
(dot needed)

=cut
sub cypress_log_upload {
    my $self = shift;
    my @log_filter = @_;
    my $find_cmd = 'find ' . CYPRESS_LOG_DIR . ' -type f \( -iname \*' . join(' -o -iname \*', @log_filter) . ' \)';

    upload_logs("$_") for split(/\n/, script_output($find_cmd));
}


=head2 cypress_exec
Execute a cypress command within the container 


=cut
sub cypress_exec {
    my ($self, $cypress_test_dir, $cmd, $timeout, $log_prefix, $failok) = @_;
    my $ret = 0;

    record_info('CY EXEC', 'Cypress exec:' . $cmd);
    my $cypress_ver = get_var('TRENTO_CYPRESS_VERSION', '4.4.0');
    my $container_name = "docker.io/cypress/included:$cypress_ver";
    # container is executed with --name to easy the log retrieve
    # to do so we need to rm eventually present container with that name
    script_run('podman rm goofy || echo "No Goofy to delete"');
    my $cypress_run_cmd = 'podman run ' .
      '-it --name goofy ' .
      "-v " . CYPRESS_LOG_DIR . ":/results " .
      "-v $cypress_test_dir:/e2e -w /e2e " .
      '-e "DEBUG=cypress:*" ' .
      '--entrypoint=\'[' .
      '"/bin/sh", "-c", ' .
      ' "/usr/local/bin/cypress ' . $cmd .
      ' 2>/results/cypress_' . $log_prefix . '_log.txt"' .
      ']\' ' . $container_name .
      ' | tee cypress_' . $log_prefix . '_result.txt';
    $ret = script_run($cypress_run_cmd, $timeout);
    if ($ret != 0) {
        record_soft_failure("Cypress exit code:$ret at $log_prefix");
        # look for SIGTERM
        script_run('podman logs -t goofy');
        $self->result("fail");
    }
    if ($failok) {
        $ret = 0;
    }
    croak "Cypress exec error at '$cmd'" unless ($ret == 0);
}

=head2 cypress_test_exec
Execute a cypress test 

=cut
sub cypress_test_exec {
    my ($self, $cypress_test_dir, $test_tag, $timeout, $failok) = @_;
    my $ret = 0;

    my $test_file_list = script_output("find $cypress_test_dir/cypress/integration/$test_tag -type f -iname \"*.js\"");

    my @arr;
    for (split(/\n/, $test_file_list)) {
        my $test_filename = +(split /\//, $_)[-1];
        my $test_result = 'test_result_' . $test_tag . '_' . $test_filename;
        $test_result =~ s/js$/xml/;
        my $test_cmd = 'run' .
          ' --spec \"cypress/integration/' . $test_tag . '/' . $test_filename . '\"' .
          ' --reporter junit' .
          ' --reporter-options \"mochaFile=/results/' . $test_result . ',toConsole=true\"';
        record_info('DEBUG', "test_filename:$test_filename test_result:$test_result test_cmd:$test_cmd");
        $self->cypress_exec($cypress_test_dir, $test_cmd, 900, $test_tag, 1);
        parse_extra_log("XUnit", $_) for split(/\n/, script_output('find ' . $self->CYPRESS_LOG_DIR . ' -type f -iname "' . $test_result . '"'));

        # look for and upload all logs at once
        $self->cypress_log_upload(('.txt', '.mp4'));
    }
}

1;
