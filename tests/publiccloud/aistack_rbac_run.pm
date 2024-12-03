use Mojo::Base 'publiccloud::basetest';
use strict;
use warnings;
use testapi;
use utils;
use publiccloud::utils;
use version_utils;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $args) = @_;

    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    # Get Open WebUI ip address, add it to /etc/hosts, and verify connectivity
    my $ipaddr = get_var('OPENWEBUI_IP');
    my $host_name = get_var('OPENWEBUI_HOSTNAME');
    assert_script_run("echo \"$ipaddr $host_name\" | sudo tee -a /etc/hosts > /dev/null");
    record_info("Added $ipaddr to /etc/hosts with hostname $host_name: " . script_output("cat /etc/hosts"));

    my $curl_cmd = "curl -v -k https://$host_name";
    my $curl_result = script_run($curl_cmd);
    if ($curl_result == 0) {
        record_info("Successfully connected to the open-webui service at $curl_cmd \n");
    } else {
        die "Unable to connect to the open-webui service at $curl_cmd\n";
    }

    # Get Open WebUI tests and admin credentials
    my $rbac_tests_url = data_url("aistack/open-webui-rbac-tests.tar.gz");
    my $admin_email = get_var('OPENWEBUI_ADMIN_EMAIL');
    my $admin_password = get_var('OPENWEBUI_ADMIN_PWD');
    record_info("Got Open WebUI admin credentials: $admin_email and $admin_password");

    # Prepare and call tests
    zypper_call("in python311");
    assert_script_run("curl -O " . $rbac_tests_url);
    assert_script_run("mkdir -p open-webui-rbac-tests && tar -xzvf open-webui-rbac-tests.tar.gz -C open-webui-rbac-tests && cd open-webui-rbac-tests");
    assert_script_run("python3.11 -m venv myenv");
    assert_script_run("source myenv/bin/activate");
    assert_script_run("pip3 install -r requirements.txt");
    assert_script_run("cp .env.example .env");
    assert_script_run("export EMAIL='" . $admin_email . "' PASSWORD='" . $admin_password . "'");
    record_info("Set env variables EMAIL = $admin_email and PASSWORD = $admin_password to be used in tests");
    assert_script_run("pytest -vv --ENV remote tests");
}

1;
