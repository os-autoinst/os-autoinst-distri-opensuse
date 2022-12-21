# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento restore stopped HANA DB
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'script_retry';
use qesapdeployment;
use trento;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $primary_host = 'vmhana01';
    cluster_print_cluster_status($primary_host);

    # Register the stopped DB to the new promoted primary
    my $cmd = join(' ', 'hdbnsutil', '-sr_register',
        '--remoteHost=vmhana02',    # the newly promoted master
        '--remoteInstance=00',
        '--replicationMode=sync',
        '--operationMode=logreplay',
        '--name=goofy');    # goofy is the original primary site name, from hana_vars in data/sles4sap/qe_sap_deployment/trento_azure.yaml
    cluster_hdbadm($primary_host, $cmd);

    # Restart the stopped instance
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(cmd => "sudo crm resource refresh rsc_SAPHana_HDB_HDB00 $primary_host",
        provider => $prov,
        filter => $primary_host);
    cluster_wait_status($primary_host, sub { ((shift =~ m/.+DEMOTED.+SOK/) && (shift =~ m/.+PROMOTED.+PRIM/)); });

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd $cypress_test_dir";
    cypress_test_exec($cypress_test_dir, 'restore_cluster', bmwqemu::scale_timeout(900));
    trento_support('test_hana_restore_stopped');
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support('test_hana_restore_stopped');
        az_delete_group();
    }
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
