# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    qesap_execute(cmd => 'terraform', verbose => 1, timeout => 60 * 30);
    qesap_execute(cmd => 'ansible', verbose => 1, timeout => 60 * 30);
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    enter_cmd "cat $inventory";
    upload_logs($inventory);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 60 * 5);
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 60 * 15);
    $self->SUPER::post_fail_hook;
}

1;
