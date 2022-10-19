# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Destroy of qe-sap-deployment deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $ret = qesap_execute(cmd => 'ansible', cmd_options => '-d', verbose => 1, timeout => 300);
    die "'qesap.py ansible -d' return: $ret" if ($ret);
    $ret = qesap_execute(cmd => 'terraform', cmd_options => '-d', verbose => 1, timeout => 1200);
    die "'qesap.py terraform -d' return: $ret" if ($ret);
}

sub post_fail_hook {
    my ($self) = shift;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
