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
use publiccloud::utils qw(is_azure is_gce);
use publiccloud::ssh_interactive qw(select_host_console);
use version_utils qw(package_version_cmp);
use Utils::SystemdAnalyze qw(extract_analyze_time extract_blame_time);

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
        # List all jobs and the failed units to support debug the issue
        record_info("list-jobs", $instance->ssh_script_output(cmd => 'systemctl list-jobs --no-pager', proceed_on_failure => 1));
        record_info("failed units", $instance->ssh_script_output(cmd => 'systemctl --failed --no-pager', proceed_on_failure => 1));
        return (0, 0);
    }
    # log time
    $instance->ssh_script_run("uptime");

    push @ret, extract_analyze_time($output);

    $output = $instance->ssh_script_output(cmd => 'systemd-analyze blame', proceed_on_failure => 1);
    push @ret, extract_blame_time($output);

    return @ret;
}

=head2 is_first_boot

    is_first_boot($instance);

Return true the first time this is called for a given instance, tracked via a marker file left on the instance (the journal is volatile on public cloud images, so C<journalctl --list-boots> cannot be used to detect earlier boots).

=cut

sub is_first_boot {
    my ($instance) = @_;
    my $marker = '/root/openqa_boottime_seen';
    return 0 if ($instance->ssh_script_run(cmd => "sudo test -e $marker", proceed_on_failure => 1) == 0);
    $instance->ssh_script_run(cmd => "sudo touch $marker", proceed_on_failure => 1);
    return 1;
}

=head2 check_system_boottime

    check_system_boottime($instance);

Wait for the instance to finish booting (via C<systemd-analyze time>) and
record the timing, acting as a readiness gate for whatever runs after this
module (poo#203817, poo#204852, poo#205311). When C<PUBLIC_CLOUD_BOOTTIME_MAX>
is set, also fail the job if the measured boot time exceeds it. Diagnostic
logs are collected only on the first boot.

=cut

sub check_system_boottime {
    my ($instance, %args) = @_;
    my $max_boot_time = get_var('PUBLIC_CLOUD_BOOTTIME_MAX');
    my $first_boot = is_first_boot($instance);

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
    unless ($systemd_analyze && $systemd_blame) {
        # Boot never finished. A known reason is that guestregister.service is still running,
        # but that is only a symptom and has more than one root cause:
        #  * bsc#1264275 is registration issue.
        #  * bsc#1277388 on GCE is the dual-stack gcemetadata stall
        my $cloudregister = $instance->ssh_script_output(cmd => 'sudo cat /var/log/cloudregister', proceed_on_failure => 1);
        if ($cloudregister =~ /(?:Could not announce system|already taken|Unprocessable Entity).*\(422\)/) {
            record_soft_failure("bsc#1264275 - SCC returned 422");
            return;
        }
        if (is_gce() && $instance->ssh_script_output(cmd => 'sudo systemctl list-jobs', proceed_on_failure => 1) =~ /guestregister\.service\s+start\s+running/) {
            my $gcever = trim($instance->ssh_script_output(cmd => q(rpm -q --qf '%{VERSION}' python-gcemetadata), proceed_on_failure => 1));
            if ($gcever =~ /^\d+(?:\.\d+)*$/ && package_version_cmp($gcever, '1.1.2') < 0) {
                record_soft_failure("bsc#1277388 - dual-stack gcemetadata stall");
                return;
            }
        }
        die("failed to obtain boottime from systemd");
    }

    $ret->{analyze}->{$_} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame} = $systemd_blame;
    my $boottime = $ret->{analyze}->{overall};

    # Collect kernel version
    $ret->{kernel_release} = $instance->ssh_script_output(cmd => 'uname -r', proceed_on_failure => 1);
    $ret->{kernel_version} = $instance->ssh_script_output(cmd => 'uname -v', proceed_on_failure => 1);

    $Data::Dumper::Sortkeys = 1;
    record_info("RESULTS", Dumper($ret));
    if ($first_boot) {
        my $dir = "/var/log";
        my @logs = qw(cloudregister cloud-init.log cloud-init-output.log messages NetworkManager);
        $instance->upload_check_logs_tar(map { "$dir/$_" } @logs);
    }

    # Boot time overall limit check, only when a threshold is configured
    return unless ($max_boot_time);
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
    return {fatal => 0};
}

1;
