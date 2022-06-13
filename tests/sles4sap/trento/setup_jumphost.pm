# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

use constant GITLAB_CLONE_LOG => '/tmp/gitlab_clone.log';
use constant PODMAN_PULL_LOG => '/tmp/podman_pull.log';

=head2 crypress_install_container

Prepare whatever is needed to run cypress tests using container

=cut
sub cypress_install_container {
    my ($cypress_ver) = @_;

    record_info('INFO', 'Check podman');
    zypper_call('in podman') if (script_run 'which podman');
    assert_script_run('podman --version');
    assert_script_run('podman info --debug');
    assert_script_run('podman ps');
    assert_script_run('podman images');

    # Pull in advance the cypress container
    my $cypress_image = 'docker.io/cypress/included';
    assert_script_run('podman search --list-tags ' . $cypress_image);
    assert_script_run('df -h');
    my $podman_pull_cmd = 'time podman ' .
      '--log-level trace ' .
      'pull ' .
      '--quiet ' .
      $cypress_image . ':' . $cypress_ver .
      ' | tee ' . PODMAN_PULL_LOG;
    assert_script_run($podman_pull_cmd, 1800);
    assert_script_run('df -h');
    assert_script_run('podman images');
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Install needed tools
    my $helm_ver = get_var('TRENTO_HELM_VERSION', '3.8.2');

    if (script_run('which helm')) {
        assert_script_run('curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3');
        assert_script_run('chmod 700 get_helm.sh');
        assert_script_run('DESIRED_VERSION="v' . $helm_ver . '" ./get_helm.sh');
    }
    assert_script_run("helm version");

    # If 'az' is preinstalled, we test that version
    assert_script_run('az --version');

    # Get the code for the Trento deployment
    my $gitlab_repo = get_var('TRENTO_GITLAB_REPO', 'gitlab.suse.de/qa-css/trento');

    # The usage of a variable with a different name is to
    # be able to overwrite the token when triggering manually.
    #
    # Note: this test is mostly used to create a HDD image; part of it is this cloned repo.
    # The key is part of the cloned repo itself so TRENTO_GITLAB_TOKEN for the moment
    # cannot be changed as running init_jumphost
    my $gitlab_token = get_var('TRENTO_GITLAB_TOKEN', get_required_var('_SECRET_TRENTO_GITLAB_TOKEN'));

    my $gitlab_clone_cmd = 'https://git:' . $gitlab_token . '@' . $gitlab_repo;
    enter_cmd 'mkdir ${HOME}/test && cd ${HOME}/test';
    assert_script_run("git clone $gitlab_clone_cmd . | tee " . GITLAB_CLONE_LOG);

    # Cypress.io installation
    my $cypress_ver = get_var('TRENTO_CYPRESS_VERSION', '4.4.0');
    cypress_install_container($cypress_ver);
}

sub post_fail_hook {
    my ($self) = shift;
    # $self->select_serial_terminal;
    upload_logs(GITLAB_CLONE_LOG);
    upload_logs(PODMAN_PULL_LOG);
    $self->SUPER::post_fail_hook;
}

1;
