# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic test of SLE Micro in public cloud
#
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_byos registercloudguest);
use publiccloud::ssh_interactive 'select_host_console';
use utils qw(zypper_call systemctl);
use version_utils qw(is_sle_micro check_version);

sub has_wicked {
    # Check if the image is expected to have wicked
    return 0 if (is_sle_micro('5.3+'));

    # Helper to check (wrong SLES) version due to poo#128681
    my $version = get_var('VERSION');
    return 1 if check_version("<15-SP4", $version, qr/\d{2}(?:-sp\d)?/);
    return 0;
}

sub run {
    my ($self) = @_;

    select_serial_terminal();
    my $provider = $self->provider_factory();
    $provider->{username} = 'suse';
    my $instance = $self->{my_instance} = $provider->create_instance(check_guestregister => 0);
    my $test_package = get_var('TEST_PACKAGE', 'jq');
    registercloudguest($instance);
    $instance->run_ssh_command(cmd => 'zypper lr -d', timeout => 600);
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-generator');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled transactional-update.timer');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-add-ssh-keys');

    # Ensure NetworkManager is used on SLEM 5.3+
    unless (has_wicked()) {
        # Remove this softfailure after bsc#1211084 is resolved.
        # Currently the images still contain NetworkManager.
        if ($instance->ssh_script_run('systemctl is-active NetworkManager') != 0) {
            record_soft_failure("bsc#1211084 - Image uses wicked instead of NetworkManager");
        }
    } else {
        $instance->ssh_assert_script_run('systemctl is-active wicked', fail_message => "wicked is not active");
    }

    # package installation test
    my $ret = $instance->run_ssh_command(cmd => 'rpm -q ' . $test_package, rc_only => 1);
    unless ($ret) {
        die("Testing package \'$test_package\' is already installed, choose a different package!");
    }
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n pkg install ' . $test_package, timeout => 600);
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'rpm -q ' . $test_package);

    # cockpit test
    $instance->run_ssh_command(cmd => '! curl localhost:9090');
    $instance->run_ssh_command(cmd => 'sudo systemctl enable --now cockpit.socket');
    $instance->run_ssh_command(cmd => 'systemctl status cockpit.service | grep inactive');
    $instance->run_ssh_command(cmd => 'curl http://localhost:9090');
    $instance->run_ssh_command(cmd => 'systemctl status cockpit.service | grep active');

    # additional tr-up tests
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n up', timeout => 360);
    $instance->softreboot();
    $instance->run_ssh_command(cmd => 'sudo sestatus | grep disabled');
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n setup-selinux');
    $instance->softreboot();

    # SElinux and logging tests
    $instance->run_ssh_command(cmd => 'sudo sestatus | grep enabled');
    $instance->run_ssh_command(cmd => 'sudo dmesg');
    $instance->run_ssh_command(cmd => 'sudo journalctl -p err');
}

1;
