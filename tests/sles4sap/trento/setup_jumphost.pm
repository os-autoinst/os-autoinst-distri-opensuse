# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use trento;


sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Install needed tools
    my $helm_ver = get_var(TRENTO_HELM_VERSION => '3.8.2');

    if (script_run('which helm')) {
        assert_script_run('curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3');
        assert_script_run('chmod 700 get_helm.sh');
        assert_script_run('DESIRED_VERSION="v' . $helm_ver . '" ./get_helm.sh');
    }
    assert_script_run("helm version");

    # If 'az' is pre installed, we test that version
    assert_script_run('az --version');

    my $work_dir = '/root/test';
    enter_cmd "mkdir $work_dir";

    # Note about TRENTO_GITLAB_TOKEN: this test is mostly only used to create
    # a HDD image; part of this test and the qcow2 image is this cloned repo.
    # The key is part of the cloned repo itself so TRENTO_GITLAB_TOKEN (for the moment)
    # cannot be changed as running init_jumphost
    clone_trento_deployment($work_dir);

    # Cypress.io installation
    cypress_install_container();

    zypper_call 'rr "Public Cloud Devel"';
}

sub post_fail_hook {
    my ($self) = shift;
    upload_logs(PODMAN_PULL_LOG);
    $self->SUPER::post_fail_hook;
}

1;
