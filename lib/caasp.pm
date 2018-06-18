# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package caasp;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use mmapi;
use version_utils 'is_caasp';
use utils qw(power_action assert_shutdown_and_restore_system);

our @EXPORT = qw(
  trup_call trup_install rpmver process_reboot check_reboot_changes microos_login
  handle_simple_pw export_cluster_logs script_retry
  get_delayed_worker update_scheduled
  pause_until unpause);

# Return names and version of packages for transactional-update tests
sub rpmver {
    my $q = shift;
    my $d = get_var 'DISTRI';

    # package name | initial version
    my %rpm = (
        kubic => {
            fn => '5-2.1',
            in => '2.1',
        },
        caasp => {
            fn => '5-5.3.61',
            in => '5.3.61',
        });

    # Returns expected package version after installation / update
    if ($q eq 'in') {
        return $rpm{$d}{$q};
    }
    # Returns rpm path for initial installation
    else {
        return " update-test-trival/update-test-$q-$rpm{$d}{fn}.x86_64.rpm";
    }
}

# Export logs from cluster admin/workers
sub export_cluster_logs {
    script_run "journalctl > journal.log", 60;
    upload_logs "journal.log";

    script_run 'supportconfig -b -B supportconfig', 500;
    upload_logs '/var/log/nts_supportconfig.tbz';

    upload_logs('/var/log/transactional-update.log', failok => 1);
    upload_logs('/var/log/YaST2/y2log-1.gz') if get_var 'AUTOYAST';
}

# Weak password warning should be displayed only once - bsc#1025835
sub handle_simple_pw {
    return if get_var 'SIMPLE_PW_CONFIRMED';

    assert_screen 'inst-userpasswdtoosimple';
    send_key 'alt-y';
    set_var 'SIMPLE_PW_CONFIRMED', 1;
}

# Assert login prompt and login as root
sub microos_login {
    assert_screen 'linux-login-casp', 150;

    # Workers installed using autoyast have no password - bsc#1030876
    return if get_var('AUTOYAST');

    if (is_caasp 'VMX') {
        # FreeRDP is not sending 'Ctrl' as part of 'Ctrl-Alt-Fx', 'Alt-Fx' is fine though.
        my $key = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? 'alt-f2' : 'ctrl-alt-f2';
        # First attempts to select tty2 are ignored - bsc#1035968
        send_key_until_needlematch 'tty2-selected', $key, 10, 30;
    }

    select_console 'root-console';

    # Don't match linux-login-casp twice
    assert_script_run 'clear';
}

# Process reboot with an option to trigger it
sub process_reboot {
    my $trigger = shift // 0;
    power_action('reboot', observe => !$trigger, keepconsole => 1);

    # No grub bootloader on xen-pv
    # caasp - grub2 needle is unreliable (stalls during timeout) - poo#28648
    # kubic - will risk occasional failure because it disabled grub2 timeout
    if (is_caasp 'kubic') {
        assert_screen 'grub2';
        send_key 'ret';
    }
    microos_login;
}

# Optionally skip exit status check in case immediate reboot is expected
sub trup_call {
    my $cmd   = shift;
    my $check = shift // 1;
    $cmd .= " > /dev/$serialdev";
    $cmd .= " ; echo trup-\$?- > /dev/$serialdev" if $check;

    script_run "transactional-update $cmd", 0;
    if ($cmd =~ /pkg |ptf /) {
        if (wait_serial "Continue?") {
            send_key "ret";
            # Abort update of broken package
            if ($cmd =~ /\bup(date)?\b/ && $check == 2) {
                die 'Abort dialog not shown' unless wait_serial('Abort');
                send_key 'ret';
            }
        }
        else {
            die "Confirmation dialog not shown";
        }
    }
    # Check if trup passed
    wait_serial 'trup-0-' if $check == 1;
    # Broken package update fails
    wait_serial 'trup-1-' if $check == 2;
}

# Reboot if there's a diff between the current FS and the new snapshot
sub check_reboot_changes {
    my $change_expected = shift // 1;

    # Compare currently mounted and default subvolume
    my $time    = time;
    my $mounted = "mnt-$time";
    my $default = "def-$time";
    assert_script_run "mount | grep 'on / ' | egrep -o 'subvolid=[0-9]*' | cut -d'=' -f2 > $mounted";
    assert_script_run "btrfs su get-default / | cut -d' ' -f2 > $default";
    my $change_happened = script_run "diff $mounted $default";

    # If changes are expected check that default subvolume changed
    die "Error during diff" if $change_happened > 1;
    die "Change expected: $change_expected, happeed: $change_happened" if $change_expected != $change_happened;

    # Reboot into new snapshot
    process_reboot 1 if $change_happened;
}

# Install a pkg in Kubic
sub trup_install {
    # rebootmgr has to be turned off as prerequisity for this to work
    script_run "rebootmgrctl set-strategy off";
    my $package = shift;
    trup_call("pkg install $package");
    process_reboot 1;
    assert_script_run("rpm -qi $package");
}

sub get_controller_job {
    die "Don't know how to find current job id" if check_var 'STACK_ROLE', 'controller';

    my $parents = get_parents();
    for my $job_id (@$parents) {
        if (get_job_info($job_id)->{settings}->{STACK_ROLE} eq 'controller') {
            return $job_id;
        }
    }
}

# Get list of jobs in cluster
sub get_cluster_jobs {
    my @cluster_jobs;
    if (check_var 'STACK_ROLE', 'controller') {
        my $children = get_children();
        @cluster_jobs = keys %$children;
    }
    else {
        @cluster_jobs = @{get_job_info(get_controller_job)->{children}->{Parallel}};
    }
    return @cluster_jobs;
}

sub get_admin_job {
    die "Don't know how to find current job id" if check_var 'STACK_ROLE', 'admin';

    my @cluster_jobs = get_cluster_jobs;
    for my $job_id (@cluster_jobs) {
        if (get_job_info($job_id)->{settings}->{STACK_ROLE} eq 'admin') {
            return $job_id;
        }
    }
}

sub get_delayed_worker {
    my @cluster_jobs = get_cluster_jobs;
    for my $job_id (@cluster_jobs) {
        return $job_id if get_job_info($job_id)->{settings}->{DELAYED_WORKER};
    }
    return 0;
}

sub update_scheduled {
    # Don't update MicroOS tests
    return 0 unless get_var('STACK_ROLE');

    # Don't update staging
    return 0 if get_var('FLAVOR') =~ /Staging-?-DVD/;

    # Return update repository if it's set on controller node
    if (check_var('STACK_ROLE', 'controller')) {
        return get_var('INCIDENT_REPO');
    }
    else {
        return get_job_info(get_controller_job)->{settings}->{INCIDENT_REPO};
    }
}

# Repeat command until expected result or timeout
# script_retry 'ping -c1 -W1 machine', retry => 5
sub script_retry {
    my ($cmd, %args) = @_;
    my $ecode = $args{expect} // 0;
    my $retry = $args{retry} // 10;
    my $delay = $args{delay} // 30;

    my $ret;
    for (1 .. $retry) {
        type_string "# Trying $_ of $retry:\n";

        $ret = script_run "timeout 25 $cmd";
        last if defined($ret) && $ret == $ecode;

        die("Waiting for Godot: $cmd") if $retry == $_;
        sleep $delay;
    }
}

# All events ordered by execution
my %events = (
    support_server_ready     => 'Wait for dhcp, dns, ntp, ..',
    VELUM_STARTED            => 'Wait until velum starts to login there from controller',
    VELUM_CONFIGURED         => 'Velum has to be configured before autoyast installations start',
    NODES_ACCEPTED           => 'Wait until salt-keys are accepted to set password on autoyast nodes',
    REBOOT_FINISHED          => 'Re-login when system rebooted after update/reboot test',
    DELAYED_WORKER_INSTALLED => 'Wait until we have new node that we can add to existing cluster',
    DELAYED_NODES_ACCEPTED   => 'Wait until salt-keys are accepted to set password on autoyast nodes',
    CNTRL_FINISHED           => 'Wait on CaaSP nodes until controller finishes testing',
);

# CaaSP specific unpausing
sub unpause {
    my $event = shift;

    # Handle cluster failure on controller node
    if (uc($event) eq 'ALL') {
        foreach my $e (keys %events) {
            lockapi::mutex_create $e;
        }
    }
    else {
        lockapi::mutex_create $event;
    }
}

# CaaSP specific pausing
sub pause_until {
    my $event = shift;

    # Make sure mutex is documented here
    die "Event '$event' is unknown" unless exists $events{$event};

    # Mutexes created by child jobs (not controller)
    my $owner;
    $owner = get_admin_job      if $event eq 'VELUM_STARTED';
    $owner = get_delayed_worker if $event eq 'DELAYED_WORKER_INSTALLED';

    lockapi::mutex_wait($event, $owner, $events{$event});
}

1;
