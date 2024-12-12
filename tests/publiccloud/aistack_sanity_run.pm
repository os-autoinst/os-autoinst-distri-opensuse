use Mojo::Base 'publiccloud::basetest';
use strict;
use warnings;
use testapi;
use utils;
use publiccloud::utils;
use version_utils;
use transactional qw(process_reboot trup_install trup_shell trup_call);

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $args) = @_;

    my $instance = $self->{my_instance};
    my $provider = $self->{provider};

    my $sanity_tests_url = data_url("aistack/open-webui-sanity-tests.tar.gz");
    my $test_folder = "open-webui-sanity-tests";

    my $ipaddr = get_var('OPENWEBUI_IP');
    my $host_name = get_var('OPENWEBUI_HOSTNAME');
    
    my $admin_email = get_var('OPENWEBUI_ADMIN_EMAIL');
    my $admin_password = get_var('OPENWEBUI_ADMIN_PWD');

    assert_script_run("curl -O " . $sanity_tests_url);
    assert_script_run("mkdir " . $test_folder);
    assert_script_run("tar -xzvf open-webui-sanity-tests.tar.gz -C " . $test_folder);
    assert_script_run("python3.11 -m venv " . $test_folder . "/venv"); 
    assert_script_run("source " . $test_folder . "/venv/bin/activate");
    assert_script_run("pip3 install -r ./" . $test_folder . "/requirements.txt");
    assert_script_run("cp " . $test_folder . "/env.example " . $test_folder . "/.env");
    assert_script_run("pytest --URL='https://$host_name' --OPENWEBUI-ADMIN-EMAIL=$admin_email --OPENWEBUI-ADMIN-PWD=$admin_password $test_folder/tests/");
}

1;