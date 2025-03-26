# SUSE's openQA tests
#
# Copyright 2021 - 2025 SUSE LLC
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
use Mojo::JSON 'j';
use List::Util 'sum';

sub has_wicked {
    # Check if the image is expected to have wicked
    return 0 if (is_sle_micro('5.3+'));

    # Helper to check (wrong SLES) version due to poo#128681
    my $version = get_var('VERSION');
    return 1 if check_version("<15-SP4", $version, qr/\d{2}(?:-sp\d)?/);
    return 0;
}

sub check_avc {
    my ($self) = @_;

    my $instance = $self->{my_instance};
    # Read the Access Vector Cache to check for SELinux denials
    my $avc = $instance->ssh_script_output(cmd => 'sudo ausearch -ts boot -m avc --format raw', proceed_on_failure => 1, ssh_opts => '-t -o ControlPath=none');
    record_info("AVC at boot", $avc);

    ## Gain better formatted logs and upload them for further investigation
    $instance->ssh_script_run(cmd => 'sudo ausearch -ts boot -m avc > ausearch.txt', ssh_opts => '-t -o ControlPath=none'); # ausearch fails if there are no matches
    assert_script_run("scp " . $instance->username() . "@" . $instance->public_ip . ":ausearch.txt ausearch.txt");
    upload_logs("ausearch.txt");

    # TODO: Uncomment once all ongoing issues are resolved. For now there will be only a record_info
    #die "SELinux access denials on first boot";
    my @avc = split(/\n/, $avc);
    for my $row (@avc) {
        $row =~ s/^\s+|\s+$//g;
        record_info("AVC denial", $row, result => 'fail') unless ($row eq '');
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();

    my $instance = $self->{my_instance} = $args->{my_instance};

    # On SLEM 5.2+ check that we don't have any SELinux denials. This needs to happen before anything else is ongoing
    $self->check_avc() unless (is_sle_micro('=5.1'));

    my $test_package = get_var('TEST_PACKAGE', 'jq');
    $instance->run_ssh_command(cmd => 'zypper lr -d', timeout => 600);
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-generator');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled transactional-update.timer');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-add-ssh-keys');

    # Ensure NetworkManager is used on SLEM 5.3+
    my $expected_network_service = has_wicked() ? 'wicked' : 'NetworkManager';
    $instance->ssh_assert_script_run("systemctl is-active $expected_network_service", fail_message => "$expected_network_service is not active");

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

    # SELinux tests
    my $getenforce = $instance->ssh_script_output('sudo getenforce');
    record_info("SELinux state", $getenforce);
    if (is_sle_micro('=5.1')) {
        die "SELinux should be disabled" unless ($getenforce =~ /Disabled/i);
    } elsif (is_sle_micro('=5.2')) {
        die "SELinux should be permissive" unless ($getenforce =~ /Permissive/i);
    } elsif (is_sle_micro('<5.4')) {
        die "SELinux should be permissive" unless ($getenforce =~ /Permissive/i);
    } else {
        die "SELinux should be enforcing" unless ($getenforce =~ /Enforcing/i);
    }
    $instance->run_ssh_command(cmd => 'sudo transactional-update -n setup-selinux');
    $instance->softreboot();

    record_info('timers', $instance->ssh_script_output(cmd => 'sudo systemctl list-timers --all'));
    $instance->ssh_assert_script_run(cmd => 'sudo systemctl is-active snapper-timeline.timer');
    $instance->ssh_assert_script_run(cmd => 'sudo systemctl is-enabled snapper-timeline.timer');
    $instance->ssh_assert_script_run(cmd => 'sudo systemctl is-active snapper-cleanup.timer');
    $instance->ssh_assert_script_run(cmd => 'sudo systemctl is-enabled snapper-cleanup.timer');

    # SElinux and logging tests
    $instance->run_ssh_command(cmd => 'sudo sestatus | grep enabled');
    $instance->run_ssh_command(cmd => 'sudo dmesg');
    $instance->run_ssh_command(cmd => 'sudo journalctl -p err');

    # volume size tests
    if (get_var('PUBLIC_CLOUD_ROOT_DISK_SIZE')) {
        my $size = get_var('PUBLIC_CLOUD_ROOT_DISK_SIZE');
        my $out = $instance->ssh_script_output(cmd => 'lsblk -J --tree -o SIZE,TYPE');
        record_info("LSBLK", "$out");
        my $disks = j $out;
        $disks = $disks->{blockdevices};
        my $count_size = 0;
        for (@$disks) {
            if (($_->{size} eq ($size . 'G')) && $_->{type} eq 'disk') {
                $count_size = sum(map { $_->{size} if (chop $_->{size} eq 'G') } @{$_->{children}});
            }
        }
        if (($count_size >= ($size - 3)) && ($count_size <= $size)) {
            record_info("Root disk partitions have sum of size: ", "$count_size");
        } else {
            die "Root disk hadn't been resized to excepted size";
        }
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 0};
}

1;
