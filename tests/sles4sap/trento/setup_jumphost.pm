use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

use constant GITLAB_CLONE_LOG => '/tmp/gitlab_clone.log';
use constant PODMAN_PULL_LOG => '/tmp/podman_pull.log';


sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;

    assert_script_run 'echo "Hello World!"';
    
    #########################
    # Install needed tools
    my $helm_ver = get_var('TRENTO_HELM_VERSION', '3.8.2');
    my $cypress_ver = get_var('TRENTO_CYPRESS_VERSION', '3.4.0');

    if (script_run('which helm') != 0) {
        assert_script_run('curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3');
        assert_script_run('chmod 700 get_helm.sh');
        assert_script_run('DESIRED_VERSION="v'.$helm_ver.'" ./get_helm.sh');
    }
    assert_script_run("helm version");

    # If 'az' is preinstalled, we test that version
    if (script_run('which az') != 0) {
	add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
	add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
	zypper_call('in azure-cli jq python3-susepubliccloudinfo');
    }
    assert_script_run('az --version');

    if (script_run('which podman') != 0) {
	zypper_call('in podman');
    }
    assert_script_run('podman --version');
    assert_script_run('podman info --debug');
    
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
    if (get_var 'TRENTO_GITLAB_BRANCH') {
	assert_script_run("git checkout " . get_var('TRENTO_GITLAB_BRANCH'));
    }

    # Pull in advance the cypress container
    my $cypress_image = 'docker.io/cypress/included';
    assert_script_run('podman search --list-tags '.$cypress_image);
    assert_script_run('podman pull --quiet '.$cypress_image.':'.$cypress_ver, 900);
 
    ######################
    # az login
    set_var 'PUBLIC_CLOUD_PROVIDER' => 'AZURE';
    my $provider = $self->provider_factory();
    #sleep 600;
}


1;
