# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Destroy SAP Landscape created with qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use qesapdeployment 'qesap_upload_logs';
use base 'trento';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->destroy_qesap();
}

sub post_fail_hook {
    my ($self) = shift;
    $self->select_serial_terminal;
    qesap_upload_logs();
    $self->destroy_qesap();
    $self->SUPER::post_fail_hook;
}

1;
