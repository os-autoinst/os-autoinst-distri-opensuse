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
use qesapdeployment qw(qesap_upload_logs qesap_ansible_cmd);
use base 'trento';


sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    qesap_ansible_cmd(cmd => 'crm status', provider => $prov, filter => 'vmhana01');
    qesap_ansible_cmd(cmd => 'SAPHanaSR-showAttr', provider => $prov, filter => 'vmhana01');

    qesap_ansible_cmd(cmd => "su - hdbadm -c 'HDB stop'", provider => $prov, filter => 'vmhana02');

    qesap_ansible_cmd(cmd => 'crm status', provider => $prov, filter => 'vmhana01');
    qesap_ansible_cmd(cmd => 'SAPHanaSR-showAttr', provider => $prov, filter => 'vmhana01');

    my $cypress_test_dir = "/root/test/test";
    enter_cmd "cd " . $cypress_test_dir;
    $self->cypress_test_exec($cypress_test_dir, 'stop_primary', 900);
}

sub post_fail_hook {
    my ($self) = shift;
    select_serial_terminal;
    qesap_upload_logs();
    if (!get_var('TRENTO_EXT_DEPLOY_IP')) {
        trento::az_delete_group;
    }
    trento::destroy_qesap();
    $self->SUPER::post_fail_hook;
}

1;
