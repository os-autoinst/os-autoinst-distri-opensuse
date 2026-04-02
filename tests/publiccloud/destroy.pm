# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This test will destroy.
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::utils;
use testapi;
use utils;

sub run {
    my ($self, $args) = @_;
    my $provider = $args->{my_provider};
    my $instance = $args->{my_instance};
    select_host_console(force => 1);

    upload_final_logs($instance);
    $provider->upload_boot_diagnostics();
    $provider->teardown();
}

sub upload_final_logs {
    my ($instance) = shift;

    my $ssh_sut_log = '/var/tmp/ssh_sut.log';
    assert_script_run("sudo chmod a+r " . $ssh_sut_log);
    upload_logs($ssh_sut_log, failok => 1, log_name => 'ssh_sut.txt');

    my @instance_logs = ('/var/log/cloudregister', '/etc/hosts', '/var/log/zypper.log', '/etc/zypp/credentials.d/SCCcredentials');
    for my $instance_log (@instance_logs) {
        $instance->ssh_script_run("sudo chmod a+r " . $instance_log, quiet => 1, ignore_timeout_failure => 1);
        $instance->upload_log($instance_log, failok => 1, log_name => $instance_log . ".txt");
    }
    $instance->upload_supportconfig_log();
}


sub test_flags {
    return {always_run => 1};
}

1;
