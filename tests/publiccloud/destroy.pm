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

    if ($instance) {
        eval {
            upload_final_logs($instance);
            $provider->finalize_logging($instance);
        };
        record_info('log upload failed', $@, result => 'fail') if $@;
    } else {
        record_info('Undef instance', 'The $instance object is not available. The logs will not be uploaded.');
    }

    if ($provider) {
        # Keep teardown() reachable even if boot diagnostics upload fails, to avoid leaking cloud resources.
        eval { $provider->upload_boot_diagnostics() };
        record_info('boot diagnostics failed', $@, result => 'fail') if $@;
        $provider->teardown();
    } else {
        die('The $provider object is not available. We are not able to destroy the testing infrastructure.');
    }
}

sub upload_final_logs {
    my ($instance) = shift;

    my $ssh_sut_log = '/var/tmp/ssh_sut.log';
    # script_run, not assert_script_run: the file may not exist if the instance never became SSH-reachable (poo#205743).
    script_run("sudo chmod a+r " . $ssh_sut_log);
    upload_logs($ssh_sut_log, failok => 1, log_name => 'ssh_sut.txt');

    my @instance_logs = ('/var/log/cloudregister', '/etc/hosts', '/var/log/zypper.log', '/etc/zypp/credentials.d/SCCcredentials');
    for my $instance_log (@instance_logs) {
        $instance->ssh_script_run("sudo chmod a+r " . $instance_log, quiet => 1, apply_graceful_timeout => 1);
        $instance->upload_log($instance_log, failok => 1, log_name => $instance_log . ".txt");
    }
    $instance->upload_supportconfig_log();
}


sub test_flags {
    return {always_run => 1};
}

1;
