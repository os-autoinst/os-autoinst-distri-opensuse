# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-netconfig-{azure, ec2, gce}
# Summary: This test ensures the consistency of cloud-netconfig's
# functionality. The test shall be conducted on a VM in the cloud
# infrastructure of a supported CSP.
#
# Test that a VM can be suspended and resumed without successfully
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use Test::Assert qw(assert_equals assert_not_equals);
use testapi;
use utils qw(script_retry);
use version_utils qw(is_sle);
use publiccloud::utils qw(is_gce);

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    unless (is_gce()) {
        record_info('unsupported', 'Only GCE supports VM suspending. EC2 and Azure do hibernation but that is not supported.');
        return 1;
    }

    # Print and record the boot ID
    record_info('UPTIME', $instance->ssh_script_output('awk "{print \$1}" /proc/uptime'));
    my $prev_boot = $instance->ssh_script_output("cat /proc/sys/kernel/random/boot_id");

    # Save the current time for the journalctl print later
    $instance->ssh_assert_script_run('sudo chronyc -a makestep');
    my $start_time = $instance->ssh_script_output('date +"%Y-%m-%d %H:%M:%S"');
    my $start_time_s = time();

    # Suspend the instance and wait until it is no longer reachable via SSH
    $provider->suspend_instance($instance);
    $instance->wait_for_ssh(wait_stop => 1);

    # Resume the instance and wait until it is reachable via SSH
    $provider->resume_instance($instance);
    $instance->update_instance_ip();
    $instance->wait_for_ssh(scan_ssh_host_key => 1);

    # Print the journalctl messages happening during the hibernation period
    $instance->ssh_assert_script_run('sudo chronyc -a makestep');
    my $stop_time = $instance->ssh_script_output('date +"%Y-%m-%d %H:%M:%S"');
    my $stop_time_s = time();
    record_info('DURATION', 'The sleep & restore process took: ' . ($stop_time_s - $start_time_s) . ' seconds.');
    record_info('JOURNAL', $instance->ssh_script_output("sudo journalctl --since \"$start_time\" --until \"$stop_time\" --no-pager"));

    # Print the uptime and check the boot ID
    record_info('UPTIME', $instance->ssh_script_output('awk "{print \$1}" /proc/uptime'));
    my $next_boot = $instance->ssh_script_output("cat /proc/sys/kernel/random/boot_id");
    if ($prev_boot ne $next_boot) {
        record_info('JOURNAL-1', $instance->ssh_script_output("sudo journalctl -b -1 --no-pager"));
        die("Instance probably rebooted as the boot ID now different: '$prev_boot'!='$next_boot'");
    }
}

1;
