# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: executes a crash scenario on cloud provider.

use Mojo::Base 'publiccloud::basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use publiccloud::instance;
use publiccloud::ssh_interactive;
use sles4sap::crash;

sub run {
    my ($self) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $region = get_var('PUBLIC_CLOUD_REGION');
    my $instance = crash_get_instance(provider => $provider, region => $region);
    my $username = crash_get_username(provider => $provider);

    select_host_console();
    crash_softrestart(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600), instance => $instance);

    my $max_rounds = 5;
    for my $round (1 .. $max_rounds) {
        record_info("PATCH $round START", "zypper patch round $round");
        my $ret = $instance->ssh_script_run(
            cmd => 'sudo zypper -n patch',
            timeout => 600,
            ssh_opts => '-E /var/tmp/ssh_sut.log -o ServerAliveInterval=2',
            username => $username,
            ignore_timeout_failure => 1
        );
        record_info("PATCH $round END", "Output:\n$ret");
        last if ($ret == 0);
        if ($ret == 103) {
            record_info("PATCH $round RE-RUN", "Package manager updated, retrying");
            next;
        }
        die "Patching failed unexpectedly" if $ret =~ /exit code \d+/;
        die "Exceeded $max_rounds patch attempts" if $round == $max_rounds;
    }

    crash_softrestart(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600), instance => $instance);
    select_serial_terminal;
    wait_serial(qr/\#/, timeout => 600);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $region = get_required_var('PUBLIC_CLOUD_REGION');
    crash_cleanup(provider => $provider, region => $region);
    $self->SUPER::post_fail_hook;
}

1;
