use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my ($self, $args) = @_;
    $self->select_serial_terminal;

    assert_script_run 'echo "Hello World!"';
    
    #########################
    # Install needed tools
    if (script_run("which helm") != 0) {
        assert_script_run("curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash");
    }
    # If 'az' is preinstalled, we test that version
    if (script_run("which az") != 0) {
	add_suseconnect_product(get_addon_fullname('pcm'), (is_sle('=12-sp5') ? '12' : undef));
	add_suseconnect_product(get_addon_fullname('phub')) if is_sle('=12-sp5');
	zypper_call('in azure-cli jq python3-susepubliccloudinfo');
    }
    assert_script_run('az --version');

    ######################
    # Get the test code
    my $test_repo = 'gitlab.suse.de/qa-css/trento';
    my $test_token_user = 'https://git:<TOKEN>' . $test_repo;
    enter_cmd "mkdir test && cd test";
    assert_script_run("git clone $test_token_user .");
 
    ######################
    # az login
    set_var 'PUBLIC_CLOUD_PROVIDER' => 'AZURE';
    my $provider = $self->provider_factory();
    #sleep 600;
}

sub cleanup {
}

1;
