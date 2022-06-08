# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use mmapi 'get_current_job_id';

use constant CYPRESS_LOG_DIR => '/root/result';
use constant TRENTO_AZ_PREFIX => 'openqa-trento';
use constant TRENTO_AZ_ACR_PREFIX => 'openqatrentoacr';

=head2 cypress_exec
Execute a cypress command

=cut
sub cypress_exec {
    my ($cypress_ver, $cypress_test_dir, $cmd, $timeout) = @_;
    record_info('INFO', 'Cypress exec:' . $cmd);
    my $cypress_run_cmd = "podman run -it " .
      "-v " . CYPRESS_LOG_DIR . ":/results " .
      "-v $cypress_test_dir:/e2e -w /e2e " .
      '-e "DEBUG=cypress:*" ' .
      '--entrypoint=\'[' .
      '"/bin/sh", "-c", ' .
      ' "/usr/local/bin/cypress ' . $cmd .
      ' 2>/results/log.txt"' .
      ']\' ' .
      'docker.io/cypress/included:' . $cypress_ver;
    assert_script_run($cypress_run_cmd, $timeout);
}

sub run {
    my ($self) = @_;
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    $self->select_serial_terminal;
    my $job_id = get_current_job_id();

    my $resource_group = TRENTO_AZ_PREFIX . "-rg-$job_id";
    my $machine_name = TRENTO_AZ_PREFIX . "-vm-$job_id";

    my $machine_ip = script_output("az vm show -d -g $resource_group -n $machine_name --query \"publicIps\" -o tsv", 180);

    my $ssh_remote_cmd = "ssh" .
      " -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR" .
      " -i /root/.ssh/id_rsa" .
      " cloudadmin@" . $machine_ip .
      " -- ";
    my $trento_web_password_cmd = $ssh_remote_cmd .
      " kubectl get secret trento-server-web-secret" .
      " -o jsonpath='{.data.ADMIN_PASSWORD}'" .
      "|base64 --decode";
    my $trento_web_password = script_output($trento_web_password_cmd);

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;
    assert_script_run("./cypress.env.py -u http://" . $machine_ip . " -p " . $trento_web_password . " -f Premium");
    assert_script_run('cat cypress.env.json');

    assert_script_run "mkdir " . CYPRESS_LOG_DIR;
    my $cypress_ver = get_var('TRENTO_CYPRESS_VERSION', '3.4.0');
    cypress_exec($cypress_ver, $cypress_test_dir, 'verify', 120);

    cypress_exec($cypress_ver, $cypress_test_dir, 'run', 600);
    script_run('find ' . CYPRESS_LOG_DIR . ' -type f');    # all files listed in the test log
    my $cypress_output = script_output 'find ' . CYPRESS_LOG_DIR . ' -type f -print';
    upload_logs($_) for grep(/(.txt|.xml)$/, split(/\n/, $cypress_output));
}

sub post_fail_hook {
    my ($self) = @_;
    my $job_id = get_current_job_id();
    my $resource_group = TRENTO_AZ_PREFIX . "-rg-$job_id";
    assert_script_run('az group list --query "[].name" -o tsv');
    assert_script_run("az group delete --resource-group $resource_group --yes", 1200);

    # the sleep is to give to the cypress test app
    # the time to complete the log write
    sleep 60;
    script_output('find ' . CYPRESS_LOG_DIR . ' -type f');
    my $cypress_output = script_output 'find ' . CYPRESS_LOG_DIR . ' -type f -print';
    upload_logs($_) for grep(/(.txt|.xml|.mp4)$/, split(/\n/, $cypress_output));
    $self->SUPER::post_fail_hook;
}

1;
