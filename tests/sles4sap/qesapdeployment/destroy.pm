# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Destroy of qe-sap-deployment deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment;

sub run {
    select_serial_terminal;
    my @ansible_ret = qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    qesap_cluster_logs() if ($ansible_ret[0]);
    my @terraform_ret = qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1800);
    die "'qesap.py ansible -d' return: $ansible_ret[0]" if ($ansible_ret[0]);
    die "'qesap.py terraform -d' return: $terraform_ret[0]" if ($terraform_ret[0]);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
