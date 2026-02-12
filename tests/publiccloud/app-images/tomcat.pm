# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Tomcat image smoke test in public cloud
#
# Maintainer: QE-C team <qa-c@suse.de>

use base 'consoletest';
use testapi;
use utils;
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::utils 'pc_data_url';


sub run {
    my ($self, $args) = @_;
    select_host_console();

    my $instance = $args->{my_instance};

    # 1. Check that the Tomcat service is up and running
    $instance->ssh_script_retry(
        "sudo systemctl is-active tomcat",
        fail_message => "Tomcat service is not active",
        retry => 5,
        delay => 60
    );

    # 2. Get the status of the default welcome page
    $instance->ssh_script_retry(
        "curl -f http://localhost:8080",
        fail_message => "Tomcat cannot be reached",
        retry => 5,
        delay => 60
    );

    # 3. Try a different example .war page.
    $instance->ssh_assert_script_run(
        'sudo curl -sL '
          . pc_data_url('publiccloud/hello-suse.war')
          . ' -o /usr/share/tomcat/webapps/hello-suse.war'
    );
    $instance->ssh_script_retry(
        "curl -f -s http://localhost:8080/hello-suse/ | grep \"Hello\ SUSE\"",
        retry => 10,
        delay => 60,
        fail_message => "Sample application is not working properly"
    );
}

1;
