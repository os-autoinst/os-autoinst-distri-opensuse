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

sub run {
    my ($self, $args) = @_;
    my $instance = $args->{my_instance};
    my $provider = $args->{my_provider};

    # Print and record the boot ID
    record_info('uptime', $instance->ssh_script_output('uptime'));
    my $prev_boot = $instance->ssh_script_output("cat /proc/sys/kernel/random/boot_id");

    # Suspend the instance and wait until it is no longer reachable via SSH
    $provider->suspend_instance($instance);
    script_retry('nc -vz -w 1 ' . $instance->public_ip . ' 22', expect => '1',
        retry => 12, delay => 15, fail_message => 'Instance did not suspend. It is still reachable via SSH');

    # Resume the instance and wait until it is reachable via SSH
    $provider->resume_instance($instance);
    script_retry('nc -vz -w 1 ' . $instance->public_ip . ' 22', retry => 12, delay => 15, fail_message => 'Instance did not resumed. It is not reachable via SSH.');
    script_run('ssh -O exit ' . $instance->username . '@' . $instance->public_ip);
    script_run("ssh-keyscan ".$instance->public_ip." | tee ~/.ssh/known_hosts /home/$testapi::username/.ssh/known_hosts");

    # Print the uptime and check the boot ID
    record_info('uptime', $instance->ssh_script_output('uptime'));
    my $next_boot = $instance->ssh_script_output("cat /proc/sys/kernel/random/boot_id");
    die("Instance probably rebooted as the boot ID now different: '$prev_boot'!='$next_boot'") if ($prev_boot ne $next_boot);
}

1;
