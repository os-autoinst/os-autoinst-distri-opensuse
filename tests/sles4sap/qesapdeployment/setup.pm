# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Setup and install more tools in the running jumphost image for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use qesapdeployment;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # 'az' and 'terraform' are preinstalled in the PcTools qcow2, we test their version
    assert_script_run('az --version');
    assert_script_run('terraform --version');

    # test ansible installed by pip
    assert_script_run('ansible --version');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    $self->qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
