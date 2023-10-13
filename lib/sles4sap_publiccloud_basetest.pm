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

    my $res = sles4sap_cleanup(
        $self,
        cleanup_called => $self->{cleanup_called},
        network_peering_present => $self->{network_peering_present},
        ansible_present => $self->{ansible_present}
    );

    if ($res) {
        $self->{cleanup_called} = 1;
        $self->{network_peering_present} = 0;
        $self->{ansible_present} = 0;
    }

    $args->{my_provider}->terraform_applied(0)
      if ((defined $args)
        && (ref($args->{my_provider}) =~ /^publiccloud::(azure|ec2|gce)/)
        && (defined $self->{result})
        && ($self->{result} ne 'fail'));
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
