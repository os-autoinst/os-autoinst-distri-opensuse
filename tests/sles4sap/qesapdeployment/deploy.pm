# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my ($self) = @_;
    my @ret = qesap_execute(cmd => 'terraform', verbose => 1, timeout => 1800);
    die "'qesap.py terraform' return: $ret[0]" if ($ret[0]);
    my $inventory = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    upload_logs($inventory, failok => 1);
    my @remote_ips = qesap_remote_hana_public_ips;
    record_info 'Remote IPs', join(' - ', @remote_ips);
    foreach my $host (@remote_ips) {
        die 'Timed out while waiting for ssh to be available in the CSP instances' if qesap_wait_for_ssh(host => $host) == -1;
    }
    @ret = qesap_execute(cmd => 'ansible', cmd_options => '--profile', verbose => 1, timeout => 3600);
    if ($ret[0])
    {
        if (qesap_ansible_log_find_missing_sudo_password($ret[1])) {
            record_info('DETECTED ANSIBLE MISSING SUDO PASSWORD ERROR');
            @ret = qesap_execute(cmd => 'ansible', cmd_options => '--profile', verbose => 1, timeout => 3600);
            if ($ret[0])
            {
                qesap_cluster_logs();
                die "'qesap.py ansible' return: $ret[0]";
            }
            record_info('ANSIBLE RETRY PASS');
        }
        elsif (qesap_ansible_log_find_timeout($ret[1])) {
            record_info('DETECTED ANSIBLE TIMEOUT ERROR');
            $self->clean_up();
            @ret = qesap_execute(cmd => 'terraform', verbose => 1, timeout => 1800);
            die "'qesap.py terraform' return: $ret[0]" if ($ret[0]);
            @ret = qesap_execute(cmd => 'ansible', cmd_options => '--profile', verbose => 1, timeout => 3600);
            if ($ret[0])
            {
                qesap_cluster_logs();
                die "'qesap.py ansible' return: $ret[0]";
            }
            record_info('ANSIBLE RETRY PASS');
        }
        else
        {
            qesap_cluster_logs();
            die "'qesap.py ansible' return: $ret[0]";
        }
    }
}
sub clean_up {
    my ($self) = @_;
    my @cmds_list;
    # Only run the Ansible deregister if the inventory is present
    push(@cmds_list, 'ansible') if (!script_run 'test -f ' . qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER')));

    # Terraform destroy can be executed in any case
    push(@cmds_list, 'terraform');

    for my $command (@cmds_list) {
        record_info('Cleanup', "Executing $command cleanup");
        my @clean_up_cmd_rc = qesap_execute(verbose => '--verbose', cmd => $command, cmd_options => '-d', timeout => 1200);
        if ($clean_up_cmd_rc[0] == 0) {
            diag(ucfirst($command) . " cleanup attempt #  PASSED.");
            record_info("Clean $command", ucfirst($command) . ' cleanup PASSED.');
            last;
        }
        else {
            diag(ucfirst($command) . " cleanup attempt #  FAILED.");
            sleep 10;
            record_info('Cleanup FAILED', "Cleanup $command FAILED", result => 'fail');
            $self->{result} = "fail";
        }
    }
}


sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    my $inventory = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300) unless (script_run("test -e $inventory"));
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
