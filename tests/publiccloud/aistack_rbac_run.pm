# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Open WebUI RBAC tests

# Summary: This test creates a Python virtual env, install requirements, and run the
# Open WebUI RBAC tests with pytest, in the test environment created by create_aistack_env.
# Maintainer: Aline Werner <aline.werner@suse.com>
# Ticket: https://jira.suse.com/browse/SUSEAI-22

use Mojo::Base 'publiccloud::basetest';
use testapi;
use utils;
use publiccloud::utils;
use version_utils;
use transactional qw(trup_call);

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $args) = @_;

    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    # Get Open WebUI tests location and admin credentials
    my $rbac_tests_archive = get_required_var('OPENWEBUI_RBAC_TESTS_ARCHIVE');
    my $rbac_tests_url = data_url("aistack/" . $rbac_tests_archive);
    my $admin_email = get_var('OPENWEBUI_ADMIN_EMAIL');
    my $admin_password = get_var('OPENWEBUI_ADMIN_PWD');
    record_info("Got Open WebUI admin credentials: $admin_email and $admin_password.");
    assert_script_run("export OPENWEBUI_ADMIN_EMAIL=$admin_email OPENWEBUI_ADMIN_PWD=$admin_password");

    # Install requirements and call tests
    trup_call("pkg install python311");
    assert_script_run("curl -O " . $rbac_tests_url);
    assert_script_run("mkdir -p open-webui-rbac-tests && tar -xzvf $rbac_tests_archive -C open-webui-rbac-tests && cd open-webui-rbac-tests");
    assert_script_run("python3.11 -m venv myenv");
    assert_script_run("source myenv/bin/activate");
    assert_script_run("pip3 install -r requirements.txt");
    assert_script_run("cp .env.example .env");
    assert_script_run("pytest -vv --ENV remote tests");
    record_info("End of RBAC tests.");
}

1;
