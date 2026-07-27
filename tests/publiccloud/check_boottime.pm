# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check the public cloud instance boot time against a threshold
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Data::Dumper;
use Mojo::Util 'trim';
use publiccloud::utils qw(is_azure);
use publiccloud::ssh_interactive qw(select_host_console);

sub systemd_time_to_second
{
    my $str_time = trim(shift);

    if ($str_time !~ /^(?<check_hour>(?<hour>\d{1,2})\s*h\s*)?(?<check_min>(?<min>\d{1,2})\s*min\s*)?((?<sec>\d{1,2}\.\d{1,3})s|(?<ms>\d+)ms)$/) {
        record_info("WARN", "Unable to parse systemd time '$str_time'", result => 'fail');
        return -1;
    }
    my $sec = $+{sec} // $+{ms} / 1000;
    $sec += $+{min} * 60 if (defined($+{check_min}));
    $sec += $+{hour} * 3600 if (defined($+{check_hour}));
    return $sec;
}

sub extract_analyze_time {
    my $str_time = shift;
    my $res = {};
    # Pick the line that actually holds the timing, not blindly the first line:
    # ssh_script_output may prepend an SSH login banner / MOTD, which would
    # otherwise leave us parsing an empty or non-timing line (poo#203817).
    ($str_time) = grep { /Startup finished in/i } split(/\r?\n/, $str_time);
    return undef unless defined($str_time);
    $str_time =~ s/Startup finished in\s*//i;
    $str_time =~ s/=(.+)$/+$1 (overall)/;
    for my $time (split(/\s*\+\s*/, $str_time)) {
        $time = trim($time);
        my ($time, $type) = $time =~ /^(.+)\s*\((\w+)\)$/;
        $res->{$type} = systemd_time_to_second($time);
        return undef if ($res->{$type} == -1);
    }
    foreach (qw(kernel initrd userspace overall)) { return undef unless exists($res->{$_}); }
    return $res;
}

sub extract_blame_time {
    my $str_time = shift;
    my $ret = {};
    for my $line (split(/\r?\n/, $str_time)) {
        $line = trim($line);
        # Only <time> <service> lines are blame entries; skip anything else
        # (e.g. an SSH login banner / MOTD prepended to the output, poo#203817).
        my ($time, $service) = $line =~ /^(\S+)\s+(\S+)$/;
        next unless defined($service);
        my $sec = systemd_time_to_second($time);
        next unless ($sec >= 0);
        $ret->{$service} = $sec;
    }
    return $ret;
}

sub do_systemd_analyze_time {
    my ($instance, %args) = @_;
    my $timeout = $args{timeout} // 300;
    my $start_time = time();
    my $output = "";
    my $finished = 0;
    my @ret;

    # Poll systemd-analyze until the system has actually finished booting.
    # On a freshly-launched Public Cloud instance SSH becomes reachable while
    # late boot units (e.g. cloud-init) are still running, so systemd-analyze
    # reports "Bootup is not yet finished (...FinishTimestampMonotonic=0)" and
    # exits non-zero (poo#203817). "Startup finished in" only appears once boot
    # is complete, so it is our readiness signal. Break out on the successful
    # match *before* sleeping so a result arriving near the timeout is not
    # discarded, and gate success on the match rather than on elapsed time.
    while (time() - $start_time < $timeout) {
        # calling systemd-analyze time
        $output = $instance->ssh_script_output(cmd => 'systemd-analyze time', proceed_on_failure => 1);
        if ($output =~ /Startup finished in/i) {
            $finished = 1;
            last;
        }
        sleep 5;
    }
    unless ($finished) {
        record_info("WARN", "Unable to get systemd-analyze in ${timeout}s.\nLast output:" . $output, result => 'fail');
        return (0, 0);
    }
    # log time
    $instance->ssh_script_run("uptime");

    push @ret, extract_analyze_time($output);

    $output = $instance->ssh_script_output(cmd => 'systemd-analyze blame', proceed_on_failure => 1);
    push @ret, extract_blame_time($output);

    return @ret;
}

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
    my ($systemd_analyze, $systemd_blame) = do_systemd_analyze_time($instance, %args);
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
