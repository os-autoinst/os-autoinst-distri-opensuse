# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento restore stopped HANA DB
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'script_retry';
use sles4sap::qesap::qesapdeployment;
use trento;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # "hana[0]" is more generic than vmhana01.
    my $primary_host = '"hana[0]"';

    # Print cluster status at the beginning, just as reference
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
    # vmhana01 hard-coded in place of the generic Ansible filter from $primary_host.
    # The Ansible generic filter is only valid for Ansible, here it is crm.
    # # From SLE16 SAPHanaSR package will be deprecated and SAPHanaSR-angi takes it place
    # # Then something like the following will be necessary to integrate to the code hereafter
    # # my $rsc_name = get_var('USE_SAP_HANA_SR_ANGI') ? "SAPHanaCtl" : "SAPHana";
    # # qesap_ansible_cmd(cmd => "sudo crm resource refresh rsc_${rsc_name}_HDB_HDB00 vmhana01", provider => $prov, filter => $primary_host);
    qesap_ansible_cmd(cmd => "sudo crm resource refresh rsc_SAPHana_HDB_HDB00 vmhana01",
        provider => $prov,
        filter => $primary_host);
    cluster_wait_status($primary_host, sub { ((shift =~ m/.+DEMOTED.+SOK/) && (shift =~ m/.+PROMOTED.+PRIM/)); });

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd $cypress_test_dir";
    cypress_test_exec(cypress_test_dir => $cypress_test_dir,
        test_tag => 'restore_cluster',
        timeout => bmwqemu::scale_timeout(900));
    trento_support();
    trento_collect_scenarios('test_hana_restore_stopped');
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support();
        trento_collect_scenarios('test_hana_restore_stopped_fail');
        az_delete_group();
    }
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
