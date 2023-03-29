# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run open-vm-tools testing against VMware ESXi
# Maintainer: Nan Zhang <nan.zhang@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use virt_autotest::common;
use virt_autotest::esxi_utils;
use Time::Local;
use Utils::Backends qw(is_qemu is_svirt);
use version_utils qw(is_sle);

my $ssh_vm;
my $scp_vm;
my $VM_POWER_ON = 'Powered on';
my $VM_POWER_OFF = 'Powered off';

sub run {
    if (is_svirt) {
        my $vm_name = console('svirt')->name;
        run_tests($vm_name);
    }
    elsif (is_qemu) {
        my $host_os_ver = get_var('DISTRI') . "s" . lc(get_var('VERSION') =~ s/-//r);
        foreach my $guest (keys %virt_autotest::common::guests) {
            run_tests($guest) if ($guest eq $host_os_ver || $guest eq "${host_os_ver}PV" || $guest eq "${host_os_ver}HVM");
        }
    }
}

sub run_tests {
    my $vm_name = shift;
    my $vm_id = esxi_vm_get_vmid($vm_name);
    my $vm_ip = esxi_vm_public_ip($vm_id);
    chomp($vm_ip);

    record_info('Guest Name', $vm_name);
    record_info('Guest ID', $vm_id);
    record_info('Guest IP', $vm_ip);

    die "The variable \$vm_id or \$vm_ip cannot be empty." if ($vm_id eq "" || $vm_ip eq "");

    if (is_svirt) {
        $ssh_vm = "";
    }
    elsif (is_qemu) {
        $ssh_vm = "ssh root\@$vm_name ";
        $scp_vm = "scp root\@$vm_name";
    }

    do_sanity_checks($vm_ip);
    do_power_mgmt_tests($vm_id, $vm_ip);
    do_networking_tests($vm_id, $vm_ip);
    do_clock_sync_tests($vm_name, $vm_id, $vm_ip);
}

sub do_sanity_checks {
    my $vm_ip = shift;

    assert_script_run($ssh_vm . "rpmquery open-vm-tools || zypper -n in open-vm-tools");
    assert_script_run($ssh_vm . "/usr/bin/vmware-checkvm | grep 'good'");

    assert_script_run($ssh_vm . 'systemctl status vmtoolsd');
    assert_script_run($ssh_vm . 'systemctl status vgauthd');
    assert_script_run($ssh_vm . 'systemctl restart vmtoolsd');

    assert_script_run($ssh_vm . "systemctl status vmtoolsd | grep 'Started open-vm-tools'");
    assert_script_run($ssh_vm . "/usr/bin/vmtoolsd -v | grep 'VMware Tools daemon, version'");

    assert_script_run($ssh_vm . 'vmware-toolbox-cmd logging level set vmtoolsd message');
    assert_script_run($ssh_vm . "vmware-toolbox-cmd logging level get vmtoolsd | grep 'vmtoolsd.level = message'");

    assert_script_run($ssh_vm . 'vmware-toolbox-cmd logging level set vmtoolsd debug');
    assert_script_run($ssh_vm . "vmware-toolbox-cmd logging level get vmtoolsd | grep 'vmtoolsd.level = debug'");
}

sub take_vm_power_ops {
    # $powerops:     this value is from the esxi server command 'vim-cmd vmsvc/'
    # $if_vm_state:  $VM_POWER_ON or $VM_POWER_OFF; check if it's the current vm power state
    my ($vm_id, $powerops, $if_vm_state) = @_;

    if (esxi_vm_power_getstate($vm_id) =~ m/$if_vm_state/) {
        if (esxi_vm_power_ops($vm_id, $powerops)) {
            return 0;
        } else {
            return 1;
        }
    } else {
        return undef;
    }
}

sub check_vm_power_state {
    # $powerops_ret:     return value from the subroutine esxi_vm_power_ops
    # $if_pingable:      1 or 0; check if the vm network is pingable or not
    # $expect_vm_state:  $VM_POWER_ON or $VM_POWER_OFF; expected vm power state after taking power action
    my ($vm_id, $vm_ip, $powerops, $powerops_ret, $if_pingable, $expect_vm_state) = @_;

    if ($powerops_ret) {
        wait_for_vm_network($vm_ip, $if_pingable);
    } elsif (!defined $powerops_ret) {
        return;
    } else {
        die "Not the correct VM state for guest $powerops.";
    }
    die "Failed to $powerops the guest." if (!esxi_vm_power_getstate($vm_id) =~ m/$expect_vm_state/);
}

sub wait_for_vm_network {
    my $vm_ip = shift;    # vm ip address
    my $if_pingable = shift;    # 1 or 0; check if the vm network is pingable or not
    my $times = shift // 9;    # the number of ping execution
    my $count = shift // 3;    # ping waits for the count
    my $interval = shift // 5;    # wait secs between each ping
    my ($cmd, $is_nw_up);

    # This ping command is used for waiting VM bootup or shutdown
    if ($if_pingable) {
        $cmd = "ping -c$count -i$interval $vm_ip";
    } else {
        $cmd = "! ping -c$count -i$interval $vm_ip";
    }

    # Monitor the networking after bring up/down the VM
    do {
        if (is_svirt) {
            $is_nw_up = console('svirt')->run_cmd($cmd);
        }
        elsif (is_qemu) {
            $is_nw_up = script_run($cmd);
        }
        $times--;
    } while ($times && $is_nw_up);
}

sub login_vm_console {
    reset_consoles;
    console('svirt')->start_serial_grab;
    select_console('sut');
    assert_screen('linux-login', 90);
    select_console('root-console');
}

sub get_epoch_time {
    my ($datetime, $epoch, $sec, $min, $hour, $mday, $mon, $year);
    $datetime = $_[0];

    my @datetime = reverse(split /-|:|\s|\//, $datetime);
    foreach (@datetime) {
        s/^0//;
        $epoch .= $_ . ",";
    }
    $epoch =~ s/,$//;
    ($sec, $min, $hour, $mday, $mon, $year) = split /,/, $epoch;
    $year -= 1900;
    $mon -= 1;
    $epoch = timelocal($sec, $min, $hour, $mday, $mon, $year);

    return $epoch;
}

sub init_guest_time {
    my $h_datetime = get_host_timestamp();
    # Get last day of the host time
    my ($last_day, $g_datetime);

    # Set the guest time by using the variable $last_day
    if (is_svirt) {
        $last_day = script_output("date -u -d '$h_datetime last day' +'\%F \%T'");
        $g_datetime = script_output("date -u -d '$last_day last day' +'\%F \%T'");
    }
    elsif (is_qemu) {
        $last_day = script_output(qq($ssh_vm "date -u -d '$h_datetime last day' +'\%F \%T'"));
        $g_datetime = script_output(qq($ssh_vm "date -u -s '$last_day' +'\%F \%T'"));
    }

    return $g_datetime;
}

sub get_diff_seconds {
    my $h_datetime = get_host_timestamp();
    my $g_datetime;

    if (is_svirt) {
        $g_datetime = script_output("date -u +'\%F \%T'");
    }
    elsif (is_qemu) {
        $g_datetime = script_output(qq($ssh_vm "date -u +'\%F \%T'"));
    }

    my $h_timesec = get_epoch_time($h_datetime);
    my $g_timesec = get_epoch_time($g_datetime);
    my $diff_secs = abs(int($g_timesec - $h_timesec));

    record_info('Host time', $h_datetime);
    record_info('Guest time after sync with host', $g_datetime);
    record_info('Diff secs', $diff_secs);

    return $diff_secs;
}

sub do_power_mgmt_tests {
    my ($vm_id, $vm_ip) = @_;
    my ($powerops, $powerops_ret);

    record_info('Power Manangement Tests');
    select_console('svirt') if (is_svirt);

    record_info('Guest Power Shutdown');
    $powerops = 'power.shutdown';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_ON);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 0, $VM_POWER_OFF);

    record_info('Guest Power On');
    $powerops = 'power.on';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_OFF);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 1, $VM_POWER_ON);

    record_info('Guest Power Reboot');
    $powerops = 'power.reboot';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_ON);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 1, $VM_POWER_ON);

    record_info('Guest Power Reset');
    $powerops = 'power.reset';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_ON);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 1, $VM_POWER_ON);

    record_info('Guest Power Off');
    $powerops = 'power.off';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_ON);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 0, $VM_POWER_OFF);
}

sub do_networking_tests {
    my ($vm_id, $vm_ip) = @_;
    my ($powerops, $powerops_ret);

    record_info('Networking Tests');
    # Boot up the VM if it's powered off
    $powerops = 'power.on';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_OFF);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 1, $VM_POWER_ON);

    my $vswitch_name = esxi_vm_network_binding($vm_id);
    record_info('VSwitch Name', $vswitch_name);

    login_vm_console() if (is_svirt);

    # Test network via assigned IPv4 address
    if (is_sle('15+')) {
        assert_script_run($ssh_vm . "ping -I $vm_ip -4 -c3 openqa.suse.de");
        assert_script_run($ssh_vm . "ping -I $vm_ip -4 -c3 www.suse.com");
    }
    else {
        assert_script_run($ssh_vm . "ping -I $vm_ip -c3 openqa.suse.de");
        assert_script_run($ssh_vm . "ping -I $vm_ip -c3 www.suse.com");
    }
}

sub do_clock_sync_tests {
    my ($vm_name, $vm_id, $vm_ip) = @_;
    my ($powerops, $powerops_ret, $g_init_time, $diff_secs);

    record_info('Clock Sync Tests');
    # Boot up the VM if it's powered off
    $powerops = 'power.on';
    $powerops_ret = take_vm_power_ops($vm_id, $powerops, $VM_POWER_OFF);
    check_vm_power_state($vm_id, $vm_ip, $powerops, $powerops_ret, 1, $VM_POWER_ON);

    select_console('sut') if (is_svirt && current_console() ne 'sut');

    # Set guest time with the last day of host time before enabling timesync service
    $g_init_time = init_guest_time();
    record_info('Guest current time before time sync enabled', $g_init_time);

    record_info('Enable clock sync tests');
    # Enable timesync service in guest VM
    if (script_output($ssh_vm . 'vmware-toolbox-cmd timesync status', proceed_on_failure => 1, timeout => 90) eq 'Disabled') {
        assert_script_run($ssh_vm . 'vmware-toolbox-cmd timesync enable', timeout => 90);
    }

    # Check the time difference between host and guest after timesync service enabled
    $diff_secs = get_diff_seconds();

    if ($diff_secs < 10) {
        record_info('Clock synchronization is successful.');
    } else {
        die 'Clock synchronization failed.';
    }

    record_info('Disable clock sync tests');
    # Disable timesync service in guest VM
    if (script_output($ssh_vm . 'vmware-toolbox-cmd timesync status', proceed_on_failure => 1, timeout => 90) eq 'Enabled') {
        assert_script_run($ssh_vm . 'vmware-toolbox-cmd timesync disable', timeout => 90);
    }

    # Set guest time with the last day of host time before disabling timesync service
    $g_init_time = init_guest_time();
    record_info('Set guest time after time sync disabled', $g_init_time);

    # Guest time will not be synced up with host after timesync service disabled
    $diff_secs = get_diff_seconds();

    if ($diff_secs > 86400 && $diff_secs < 86420) {
        record_info('Clock synchronization was disabled successfully.');
    } else {
        die 'Disabling clock synchronization failed.';
    }
}

sub post_fail_hook {
    select_console 'log-console';

    # Upload open-vm-tools backend service logs
    if (is_svirt) {
        upload_logs '/var/log/vmware-network.log';
        upload_logs '/var/log/vmware-vgauthsvc.log.0';
        upload_logs '/var/log/vmware-vmsvc-root.log';
        upload_logs '/var/log/vmware-vmtoolsd-root.log';
    }
    elsif (is_qemu) {
        assert_script_run($ssh_vm . "'cat /var/log/vmware-network.log' > vmware-network.log");
        assert_script_run($ssh_vm . "'cat /var/log/vmware-vgauthsvc.log.0' > vmware-vgauthsvc.log.0");
        assert_script_run($ssh_vm . "'cat /var/log/vmware-vmsvc-root.log' > vmware-vmsvc-root.log");
        assert_script_run($ssh_vm . "'cat /var/log/vmware-vmtoolsd-root.log' > vmware-vmtoolsd-root.log");

        upload_logs 'vmware-network.log';
        upload_logs 'vmware-vgauthsvc.log.0';
        upload_logs 'vmware-vmsvc-root.log';
        upload_logs 'vmware-vmtoolsd-root.log';
    }

    # Upload guest diagnostic information
    if (script_run($ssh_vm . '/usr/bin/vm-support') == 0) {
        my $vm_logs_tarball = script_output($ssh_vm . 'ls vm-*.tar.gz');
        assert_script_run("$scp_vm:~/$vm_logs_tarball .") if (is_qemu);
        upload_logs $vm_logs_tarball;
        assert_script_run($ssh_vm . "rm ~/$vm_logs_tarball") if (is_qemu);
    }
}

1;
