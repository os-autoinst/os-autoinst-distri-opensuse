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

    my $primary_host = 'vmhana01';

    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(
        cmd => 'crm status',
        provider => $prov,
        filter => $primary_host);
    qesap_ansible_cmd(cmd => 'SAPHanaSR-showAttr --format=script',
        provider => $prov,
        filter => $primary_host);

    # Stop the primary DB
    qesap_ansible_cmd(
        cmd => "su - hdbadm -c 'HDB stop'",
        provider => $prov,
        filter => $primary_host);

    my $_monitor_start_time = time();
    my $done;
    while ((time() - $_monitor_start_time <= 300) && (!$done)) {
        sleep 30;
        my $show_attr = qesap_ansible_script_output(
            cmd => 'SAPHanaSR-showAttr',
            provider => $prov,
            host => $primary_host,
            root => 1);

        my %status = ();
        for my $line (split("\n", $show_attr)) {
            $status{$1} = $line if ($line =~ m/^(vmhana\d+)/);
        }
        $done = (($status{vmhana01} =~ m/.*UNDEFINED.*SFAIL/) && ($status{vmhana02} =~ m/.*PROMOTED.*PRIM/));
        record_info("SAPHanaSR-showAttr",
            join("\n\n", "Output : $show_attr",
                'status{vmhana01} : ' . $status{vmhana01},
                'status{vmhana02} : ' . $status{vmhana02},
                "done : $done"));
    }
    die "Timeout waiting for hand over" if !$done;

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;
    cypress_test_exec($cypress_test_dir, 'stop_primary', 900);
    trento_support('test_hana_stop');
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        k8s_logs(qw(web runner));
        trento_support('test_hana_stop');
        az_delete_group();
    }
    destroy_qesap();
    $self->SUPER::post_fail_hook;
}

1;
