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

    qesap_ansible_cmd(cmd => $_, provider => $prov, $_) for ('pwd', 'uname -a', 'cat /etc/os-release');
    qesap_ansible_cmd(cmd => 'ls -lai /hana/', provider => $prov, filter => 'hana');
    qesap_ansible_cmd(cmd => $_, provider => $prov, filter => 'vmhana01'), for ('crm status', $crm_mon_cmd);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
