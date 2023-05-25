# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento unregister the secondary node
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment;
use trento;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $secondary_host = 'vmhana02';
    cluster_print_cluster_status($secondary_host);

    # Set secondary node in maintenance mode
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(cmd => "sudo crm configure property maintenance-mode=true",
        provider => $prov,
        filter => $secondary_host);
    cluster_wait_status_by_regex($secondary_host, qr/global.+true/, 900);

    # Stop hana instance
    cluster_hdbadm($secondary_host, 'HDB stop');
    cluster_wait_status_by_regex($secondary_host, qr/miky\s+SFAIL/, 900);

    # Unregistered the hana database and started
    my $cmd_unregister = join(' ', 'hdbnsutil',
        '-sr_unregister',
        '--name=miky');
    cluster_hdbadm($secondary_host, $cmd_unregister);
    cluster_hdbadm($secondary_host, 'HDB start');

    # Register the secondary node again with the primary node
    my $cmd_register = join(' ', 'hdbnsutil',
        '-sr_register',
        '--force_full_replica',
        '--remoteHost=vmhana01',
        '--remoteInstance=00',
        '--replicationMode=sync',
        '--name=miky');
    cluster_hdbadm($secondary_host, 'HDB stop');
    cluster_wait_status_by_regex($secondary_host, qr/miky\s+SFAIL/, 900);
    cluster_hdbadm($secondary_host, $cmd_register);
    cluster_hdbadm($secondary_host, 'HDB start');

    # Remove the cluster from maintenance mode
    qesap_ansible_cmd(cmd => "sudo crm configure property maintenance-mode=false",
        provider => $prov,
        filter => $secondary_host);
    cluster_wait_status_by_regex($secondary_host, qr/global.+false/, 900);
    cluster_wait_status_by_regex($secondary_host, qr/miky\s+SOK/, 900);
    qesap_ansible_cmd(cmd => "sudo crm resource cleanup msl_SAPHana_HDB_HDB00",
        provider => $prov,
        filter => $secondary_host);

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd $cypress_test_dir";
    cypress_test_exec($cypress_test_dir, 'unregister', bmwqemu::scale_timeout(1800));
    trento_support();
    trento_collect_scenarios('test_hana_unregister');
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support();
        trento_collect_scenarios('test_hana_unregister');
        az_delete_group();
    }
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
