# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cloud-netconfig-{azure, ec2, gce}
# Summary: This test ensures the consistency of cloud-netconfig's
# functionality. The test shall be conducted on a VM in the cloud
# infrastructure of a supported CSP.
#
# Test that a VM can be suspended and resumed without successfully
#
# Maintainer: qa-c team <qa-c@suse.de>

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
        record_info('unsupported', 'The hibernation is currently supported only on GCE.');
        return 1;
    }
    if (is_gce() && is_sle('=15-SP7')) {
        record_soft_failure('bsc#1245571 - Latest SLES 15 SP7 Image does not suspend on Google Cloud');
        return 1;
    }

    # Print and record the boot ID
    record_info('UPTIME', $instance->ssh_script_output('awk "{print \$1}" /proc/uptime'));
    my $prev_boot = $instance->ssh_script_output("cat /proc/sys/kernel/random/boot_id");

    # Suspend the instance and wait until it is no longer reachable via SSH
    $provider->suspend_instance($instance);
    $instance->wait_for_ssh(wait_stop => 1);

    # Resume the instance and wait until it is reachable via SSH
    $provider->resume_instance($instance);
    $instance->wait_for_ssh(scan_ssh_host_key => 1, systemup_check => 0);

    # Print the uptime and check the boot ID
    record_info('UPTIME', $instance->ssh_script_output('awk "{print \$1}" /proc/uptime'));
    my $next_boot = $instance->ssh_script_output("cat /proc/sys/kernel/random/boot_id");
    die("Instance probably rebooted as the boot ID now different: '$prev_boot'!='$next_boot'") if ($prev_boot ne $next_boot);
}

1;
