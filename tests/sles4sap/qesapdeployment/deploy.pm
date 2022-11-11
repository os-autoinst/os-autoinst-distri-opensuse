# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my $ret = qesap_execute(cmd => 'terraform', verbose => 1, timeout => 1800);
    die "'qesap.py terraform' return: $ret" if ($ret);
    $ret = qesap_execute(cmd => 'ansible', verbose => 1, timeout => 1800);
    die "'qesap.py ansible' return: $ret" if ($ret);
    my $inventory = qesap_get_inventory(get_required_var('PUBLIC_CLOUD_PROVIDER'));
    upload_logs($inventory);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    $self->SUPER::post_fail_hook;
}

1;
