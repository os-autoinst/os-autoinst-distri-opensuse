use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;

    assert_script_run 'echo "Hello World!"';
    
    #########################################
    # Get the code for the Trento deployment
    enter_cmd 'cd ${HOME}/test';
    my $git_branch = get_var('TRENTO_GITLAB_BRANCH', 'master');
    assert_script_run("git checkout " . $git_branch);
    assert_script_run("git pull origin " . $git_branch);
    
    ######################
    # az login
    set_var 'PUBLIC_CLOUD_PROVIDER' => 'AZURE';
    my $provider = $self->provider_factory();
    #sleep 600;
    enter_cmd 'ls -lai ${HOME}/.ssh'
}

sub post_fail_hook {
    my ($self) = shift;
    # $self->select_serial_terminal;
    #upload_logs(GITLAB_CLONE_LOG);
    $self->SUPER::post_fail_hook;
}

1;
