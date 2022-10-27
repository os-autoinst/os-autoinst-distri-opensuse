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
use base 'trento';

sub run {
    my ($self) = @_;
    if (get_var('TRENTO_EXT_DEPLOY_IP')) {
        return;
    }
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    select_serial_terminal;

    my $resource_group = $self->get_resource_group;
    my $acr_name = $self->get_acr_name;
    my $basedir = '/root/test';

    trento::deploy_vm($basedir);
    my %acr = trento::trento_acr_azure($basedir);
    trento::install_trento(work_dir => $basedir, acr => \%acr);

    trento::k8s_logs(qw(web runner));
}

sub post_fail_hook {
    my ($self) = @_;

    my $find_cmd = 'find . -type f -iname "*.log.txt"';
    upload_logs("$_") for split(/\n/, script_output($find_cmd));

    trento::k8s_logs(qw(web runner));
    $self->az_delete_group;

    $self->SUPER::post_fail_hook;
}

1;
