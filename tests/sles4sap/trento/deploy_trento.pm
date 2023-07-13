# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deploy a Trento server
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use trento;

sub run {
    my ($self) = @_;
    if (get_var('TRENTO_EXT_DEPLOY_IP')) {
        return;
    }
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    select_serial_terminal;

    my $basedir = '/root/test';

    deploy_vm($basedir);
    my %acr = trento_acr_azure($basedir);
    install_trento(work_dir => $basedir, acr => \%acr);

    k8s_logs(qw(web runner));
    trento_support();
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;

    my $find_cmd = 'find . -type f -iname "*.log.txt"';
    upload_logs("$_") for split(/\n/, script_output($find_cmd));

    k8s_logs(qw(web runner));
    trento_support();
    az_delete_group();

    $self->SUPER::post_fail_hook;
}

1;
