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

    # Crash test
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $vm_ip = crash_pubip(provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));

    my %usernames = (
        AZURE => 'cloudadmin',
        EC2 => 'ec2-user'
    );
    my $username = $usernames{$provider} or die "Unsupported cloud provider: $provider";
    my $instance = publiccloud::instance->new(public_ip => $vm_ip, username => $username);
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
        last if $ret =~ /Nothing to do|No updates found/;
        if ($ret =~ /SCRIPT_FINISHED.*-103-/) {
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
    if ($provider eq 'AZURE') {
        crash_destroy_azure();
    }
    elsif ($provider eq 'EC2') {
        crash_destroy_aws(region => get_required_var('PUBLIC_CLOUD_REGION'));
    }
    $self->SUPER::post_fail_hook;
}

1;
