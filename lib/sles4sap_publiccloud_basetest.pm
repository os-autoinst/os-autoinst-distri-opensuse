# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Base test providing cleanup, post fail and post run hooks for tests using qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

package sles4sap_publiccloud_basetest;

use Mojo::Base 'publiccloud::basetest';
use strict;
use warnings FATAL => 'all';
use Exporter 'import';
use testapi;
use qesapdeployment;
use sles4sap_publiccloud;
use publiccloud::utils;

our @EXPORT = qw(cleanup import_context);


sub cleanup {
    my ($self, $args) = @_;

    record_info('Cleanup',
        join(' ',
            'cleanup_called:', $self->{cleanup_called} // 'undefined',
            'network_peering_present:', $self->{network_peering_present} // 'undefined',
            'ansible_present:', $self->{ansible_present} // 'undefined'));
    # Do not run destroy if already executed
    return if ($self->{cleanup_called});
    $self->{cleanup_called} = 1;

    qesap_upload_logs();
    if ($self->{network_peering_present}) {
        delete_network_peering();
        $self->{network_peering_present} = 0;
    }

    my @cmd_list;
    # Only run the Ansible deregister if Ansible has been executed
    push(@cmd_list, 'ansible') if ($self->{ansible_present});

    # Terraform destroy can be executed in any case
    push(@cmd_list, 'terraform');

    for my $command (@cmd_list) {
        record_info('Cleanup', "Executing $command cleanup");
        # 3 attempts for both terraform and ansible cleanup
        for (1 .. 3) {
            my @cleanup_cmd_rc = qesap_execute(verbose => '--verbose', cmd => $command, cmd_options => '-d', timeout => 1200);
            if ($cleanup_cmd_rc[0] == 0) {
                diag(ucfirst($command) . " cleanup attempt # $_ PASSED.");
                record_info("Clean $command", ucfirst($command) . ' cleanup PASSED.');
                $self->{ansible_present} = 0 if ($command eq 'ansible');
                last;
            }
            else {
                diag(ucfirst($command) . " cleanup attempt # $_ FAILED.");
                sleep 10;
            }
            record_info('Cleanup FAILED', "Cleanup $command FAILED", result => 'fail') if $_ == 3 && $cleanup_cmd_rc[0];
            $self->{result} = "fail" if $_ == 3 && $cleanup_cmd_rc[0];
        }
    }
    $args->{my_provider}->terraform_applied(0) if ((defined $args) &&
        (ref($args->{my_provider}) =~ /^publiccloud::(azure|ec2|gce)/) &&
        (defined $self->{result}) && ($self->{result} ne 'fail'));
    record_info('Cleanup finished');
}

sub import_context {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});
    $self->{ansible_present} = 1 if ($run_args->{ansible_present});
    record_info('CONTEXT LOG', join(' ',
            'cleanup_called:', $self->{cleanup_called} // 'undefined',
            'instances:', $self->{instances} // 'undefined',
            'network_peering_present:', $self->{network_peering_present} // 'undefined',
            'ansible_present:', $self->{ansible_present} // 'undefined')
    );
}

sub post_fail_hook {
    my ($self) = @_;
    if (get_var('QESAP_NO_CLEANUP_ON_FAILURE')) {
        diag('Skip post fail', "Variable 'QESAP_NO_CLEANUP_ON_FAILURE' defined.");
        return;
    }
    $self->cleanup();
}

sub post_run_hook {
    my ($self) = @_;
    if ($self->test_flags()->{publiccloud_multi_module} or get_var('QESAP_NO_CLEANUP')) {
        diag('Skip post run', "Skipping post run hook. \n Variable 'QESAP_NO_CLEANUP' defined or test_flag 'publiccloud_multi_module' active");
        return;
    }
    $self->cleanup();
}

1;
