# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;
use hacluster '$crm_mon_cmd';

sub run {
    my ($self) = @_;
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');

    my $chdir = qesap_get_terraform_dir();
    assert_script_run("terraform -chdir=$chdir output");
    qesap_ansible_cmd(cmd => $_, provider => $prov) for ('pwd', 'uname -a', 'cat /etc/os-release');
    qesap_ansible_cmd(cmd => 'ls -lai /hana/', provider => $prov, filter => 'hana');
    my $cmr_status = qesap_ansible_script_output(cmd => 'crm status', provider => $prov, host => '"hana[0]"', root => 1);
    record_info("crm status", $cmr_status);
    qesap_ansible_cmd(cmd => $crm_mon_cmd, provider => $prov, filter => '"hana[0]"');
    qesap_cluster_logs();
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
