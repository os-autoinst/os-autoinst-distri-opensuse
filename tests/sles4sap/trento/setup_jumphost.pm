# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use testapi;
use utils 'zypper_call';
use base 'trento';

use constant GITLAB_CLONE_LOG => '/tmp/gitlab_clone.log';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

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

    # Get the code for the Trento deployment
    my $gitlab_repo = get_var(TRENTO_GITLAB_REPO => 'gitlab.suse.de/qa-css/trento');

    # The usage of a variable with a different name is to
    # be able to overwrite the token when manually triggering
    # the setup_jumphost test.
    #
    # Note: this test is mostly only used to create
    # a HDD image; part of this test and the qcow2 image is this cloned repo.
    # The key is part of the cloned repo itself so TRENTO_GITLAB_TOKEN (for the moment)
    # cannot be changed as running init_jumphost
    my $gitlab_token = get_var(TRENTO_GITLAB_TOKEN => get_required_var('_SECRET_TRENTO_GITLAB_TOKEN'));

    my $gitlab_clone_cmd = 'https://git:' . $gitlab_token . '@' . $gitlab_repo;
    enter_cmd 'mkdir ${HOME}/test && cd ${HOME}/test';
    assert_script_run("git clone $gitlab_clone_cmd . | tee " . GITLAB_CLONE_LOG);

    # Cypress.io installation
    $self->cypress_install_container($self->cypress_version);
}

sub post_fail_hook {
    my ($self) = shift;
    # $self->select_serial_terminal;
    upload_logs(GITLAB_CLONE_LOG);
    upload_logs($self->PODMAN_PULL_LOG);
    $self->SUPER::post_fail_hook;
}

1;
