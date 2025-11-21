# SUSE's openQA tests
#
# Copyright 2021 - 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic test of SLE Micro in public cloud
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use publiccloud::utils qw(is_byos is_azure is_ec2 registercloudguest zypper_remote_call);
use publiccloud::ssh_interactive 'select_host_console';
use utils qw(zypper_call systemctl);
use version_utils qw(is_sle_micro check_version);
use Mojo::JSON 'j';
use List::Util 'sum';

# Check for Access Vector Cache (AVC) denials and uploads them
sub report_avc {
    my ($self) = @_;

    my $instance = $self->{my_instance};
    # Read the AVC to check for SELinux denials
    my $avc = $instance->ssh_script_output(cmd => 'sudo ausearch -ts boot -m avc --format raw', proceed_on_failure => 1, ssh_opts => '-t -o ControlPath=none');

    ## Gain better formatted logs and upload them for further investigation
    $instance->ssh_script_run(cmd => 'sudo ausearch -ts boot -m avc > ausearch.txt', ssh_opts => '-t -o ControlPath=none'); # ausearch fails if there are no matches
    assert_script_run("scp " . $instance->username() . "@" . $instance->public_ip . ":ausearch.txt ausearch.txt");
    upload_logs("ausearch.txt");

    ## Report all found AVCs
    my @avc = split(/\n/, $avc);
    for my $row (@avc) {
        $row =~ s/^\s+|\s+$//g;
        record_info("AVC denial", $row, result => 'fail') if ($row);
    }
    # On SLEM 6.0+ we aim for no AVC denials
    die "AVC denials detected" if ($avc && is_sle_micro('>=6.0'));
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal();

    my $instance = $self->{my_instance} = $args->{my_instance};
    # On SLEM 5.2+ check that we don't have any SELinux denials. This needs to happen before anything else is ongoing
    $self->report_avc();

    my $test_package = get_var('TEST_PACKAGE', 'socat');
    $instance->zypper_remote_call(cmd => 'zypper lr -d', timeout => 600) unless get_var('PUBLIC_CLOUD_IGNORE_UNREGISTERED');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-generator');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled transactional-update.timer');
    $instance->run_ssh_command(cmd => 'systemctl is-enabled issue-add-ssh-keys');

    # Test Networking. On SLEM6+ it needs to be NetworkManager. On <SLEM6 it must be either wicked or NetworkManager but never both at the same time
    if (is_sle_micro('<6.0')) {
        my $nm_active = $instance->ssh_script_run("systemctl is-active NetworkManager") == 0;
        my $wicked_active = $instance->ssh_script_run("systemctl is-active wicked") == 0;

        die "Neither wicked nor NetworkManager are active" unless ($nm_active || $wicked_active);
        if ($nm_active && $wicked_active) {
            if (is_azure || is_ec2) {
                record_soft_failure("bsc#1248284 - NetworkManager and wicked active at the same time");
            } else {
                die "wicked and NetworkManager cannot be active at the same time";
            }
        }

        my $nm_enabled = $instance->ssh_script_run("systemctl is-enabled NetworkManager") == 0;
        my $wicked_enabled = $instance->ssh_script_run("systemctl is-enabled wicked") == 0;

        die "Neither wicked nor NetworkManager are enabled" unless ($nm_enabled || $wicked_enabled);
        if ($nm_enabled && $wicked_enabled) {
            if (is_azure || is_ec2) {
                record_soft_failure("bsc#1248284 - NetworkManager and wicked enabled at the same time");
            } else {
                die "wicked and NetworkManager cannot be enabled at the same time";
            }
        }
    } else {
        $instance->ssh_assert_script_run("systemctl is-active NetworkManager", fail_message => "NetworkManager is not active");
        $instance->ssh_assert_script_run("systemctl is-enabled NetworkManager", fail_message => "NetworkManager is not enabled");

        $instance->ssh_assert_script_run("! systemctl is-active wicked", fail_message => "wicked must not be active");
        $instance->ssh_assert_script_run("! systemctl is-enabled wicked", fail_message => "wicked must be disabled");
    }

    # dump list of packages
    $instance->run_ssh_command(cmd => 'rpm -qa | sort');

    unless (get_var('PUBLIC_CLOUD_IGNORE_UNREGISTERED')) {
        # package installation test
        my $ret = $instance->run_ssh_command(cmd => 'rpm -q ' . $test_package, rc_only => 1);
        unless ($ret) {
            die("Testing package \'$test_package\' is already installed, choose a different package!");
        }
        $instance->run_ssh_command(cmd => 'sudo transactional-update -n pkg install ' . $test_package, timeout => 600);
        $instance->softreboot();
        $instance->run_ssh_command(cmd => 'rpm -q ' . $test_package);
    }

    # cockpit test
    if (is_sle_micro('=6.2')) {
        # On SLEM 6.2 cockpit is enabled. It's under discussion if this is correct, see bsc#1252729
        $instance->run_ssh_command(cmd => 'systemctl is-enabled cockpit.socket');
        $instance->run_ssh_command(cmd => 'curl --no-progress-meter http://localhost:9090');
        $instance->run_ssh_command(cmd => 'systemctl is-active cockpit.service');
    } else {
        # expected not-active
        $instance->run_ssh_command(cmd => '! curl --no-progress-meter localhost:9090');
        $instance->run_ssh_command(cmd => 'sudo systemctl enable --now cockpit.socket');
        $instance->run_ssh_command(cmd => '! systemctl is-active cockpit.service');
        $instance->run_ssh_command(cmd => 'curl --no-progress-meter http://localhost:9090');
        $instance->run_ssh_command(cmd => 'systemctl is-active cockpit.service');
    }

    unless (get_var('PUBLIC_CLOUD_IGNORE_UNREGISTERED')) {
        # additional tr-up tests
        $instance->run_ssh_command(cmd => 'sudo transactional-update -n up', timeout => 360);
        $instance->softreboot();
    }

    # SELinux tests
    my $getenforce = $instance->ssh_script_output('sudo getenforce');
    record_info("SELinux state", $getenforce);
    if (is_sle_micro('=5.2')) {
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
