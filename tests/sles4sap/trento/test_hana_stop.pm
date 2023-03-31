# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento stop secondary HANA test
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

    # "hana[0]" is more generic than vmhana01.
    # It is fine for cluster_print_cluster_status as
    #it only uses it for some qesap_ansible_cmd
    cluster_print_cluster_status('"hana[0]"');

    # Stop the primary DB
    my $primary_host = 'vmhana01';
    cluster_hdbadm('"hana[0]"', 'HDB stop');
    cluster_wait_status($primary_host, sub { ((shift =~ m/.+UNDEFINED.+SFAIL/) && (shift =~ m/.+PROMOTED.+PRIM/)); });

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd $cypress_test_dir";
    cypress_test_exec($cypress_test_dir, 'stop_primary', bmwqemu::scale_timeout(900));
    trento_support();
    trento_collect_scenarios('test_hana_stop');
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support();
        trento_collect_scenarios('test_hana_stop_fail');
        az_delete_group();
    }
    cluster_destroy();
    $self->SUPER::post_fail_hook;
}

1;
