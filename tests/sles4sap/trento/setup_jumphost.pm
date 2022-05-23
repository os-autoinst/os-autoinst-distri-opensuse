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
    if (script_run('which podman') != 0) {
	zypper_call('in podman');
    }
    assert_script_run('podman --version');
    assert_script_run('podman info --debug');
    assert_script_run('podman ps');
    assert_script_run('podman images');

    # Pull in advance the cypress container
    my $cypress_image = 'docker.io/cypress/included';
    assert_script_run('podman search --list-tags '.$cypress_image);
    assert_script_run('df -h');
    my $podman_pull_cmd = 'time podman '.
       '--log-level trace '.
       'pull '.
       '--quiet '.
       $cypress_image.':'.$cypress_ver.
       ' | tee ' . PODMAN_PULL_LOG;
    assert_script_run($podman_pull_cmd, 1800);
    assert_script_run('df -h');
    assert_script_run('podman images');
}

=head2 cypress_install_npm

Prepare whatever is needed to run cypress tests using npm

=cut
sub cypress_install_npm {
    my ($cypress_ver, $prj_dir) = @_;
    record_info('INFO', 'Check node and npm');
    if (script_run('which npm') != 0) {
	add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
	add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
	zypper_call('se nodejs');
	zypper_call('se npm');
	zypper_call('in npm-default');
    }
    assert_script_run('npm --version');
}

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;

    #########################
    # Install needed tools
    my $helm_ver = get_var('TRENTO_HELM_VERSION', '3.8.2');

    if (script_run('which helm') != 0) {
        assert_script_run('curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3');
        assert_script_run('chmod 700 get_helm.sh');
        assert_script_run('DESIRED_VERSION="v'.$helm_ver.'" ./get_helm.sh');
    }
    assert_script_run("helm version");

    # If 'az' is preinstalled, we test that version
    assert_script_run('az --version');

   
    #########################################
    # Get the code for the Trento deployment
    my $gitlab_repo = get_var('TRENTO_GITLAB_REPO', 'gitlab.suse.de/qa-css/trento');
    my $gitlab_token = get_required_var('_SECRET_TRENTO_GITLAB_TOKEN');
    # The usage of a variable with a different name is to
    # be able to overwrite the token when triggering manually
    if (get_var 'TRENTO_GITLAB_TOKEN') {
        $gitlab_token =  get_var('TRENTO_GITLAB_TOKEN');
    }
    my $gitlab_clone_cmd = 'https://git:' . $gitlab_token  . '@' . $gitlab_repo;
    enter_cmd 'mkdir ${HOME}/test && cd ${HOME}/test';
    assert_script_run("git clone $gitlab_clone_cmd . | tee " . GITLAB_CLONE_LOG);

    #########################################
    # Cypress.io installation
    my $cypress_ver = get_var('TRENTO_CYPRESS_VERSION', '3.4.0');
    cypress_install_container($cypress_ver);   
    #cypress_install_npm($cypress_ver, '${HOME}/test/test');   
}

sub post_fail_hook {
    my ($self) = shift;
    # $self->select_serial_terminal;
    upload_logs(GITLAB_CLONE_LOG);
    upload_logs(PODMAN_PULL_LOG);
    $self->SUPER::post_fail_hook;
}

1;
