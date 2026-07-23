# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check the public cloud instance boot time against a threshold
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Data::Dumper;
use publiccloud::utils qw(is_azure);
use publiccloud::ssh_interactive qw(select_host_console);

=head2 check_system_boottime

    check_system_boottime($instance);

Check the system boot time, measured by C<systemd-analyze>, to be under a threshold.
Assign the threshold in seconds to PUBLIC_CLOUD_BOOTTIME_MAX in test settings.
The boot time is saved in a local json structure, then printed in the test's logs:
when the threshold is exceeded the job is stopped.
The routine is skipped when the threshold is undefined or zero.

=cut

sub check_system_boottime {
    my ($instance, %args) = @_;
    my $max_boot_time = get_var('PUBLIC_CLOUD_BOOTTIME_MAX');
    return unless ($max_boot_time);

    my $ret = {
        kernel_release => undef,
        kernel_version => undef,
        type => 'boottime',
        analyze => {},
        blame => {},
    };

    record_info("BOOT TIME", 'systemd_analyze');
    # first deployment analysis
    my ($systemd_analyze, $systemd_blame) = $instance->do_systemd_analyze_time(%args);
    die("failed to obtain boottime from systemd") unless ($systemd_analyze && $systemd_blame);

    $ret->{analyze}->{$_} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame} = $systemd_blame;
    my $boottime = $ret->{analyze}->{overall};

    # Collect kernel version
    $ret->{kernel_release} = $instance->ssh_script_output(cmd => 'uname -r', proceed_on_failure => 1);
    $ret->{kernel_version} = $instance->ssh_script_output(cmd => 'uname -v', proceed_on_failure => 1);

    $Data::Dumper::Sortkeys = 1;
    record_info("RESULTS", Dumper($ret));
    my $dir = "/var/log";
    my @logs = qw(cloudregister cloud-init.log cloud-init-output.log messages NetworkManager);
    $instance->upload_check_logs_tar(map { "$dir/$_" } @logs);

    # Boot time overall limit check
    if ($boottime > $max_boot_time) {
        if (is_azure()) {
            # Unreliable userspace boot time in Azure.
            record_soft_failure("bsc#1262587 - openQA publiccloud tests have anomalous-high boot-time from systemd-analyze");
        } else {
            # threshold exceeded
            die("System boot time overall $boottime is out of limit $max_boot_time");
        }
    }
}

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    check_system_boottime($args->{my_instance});
}

sub test_flags {
    return {fatal => 1};
}

1;
