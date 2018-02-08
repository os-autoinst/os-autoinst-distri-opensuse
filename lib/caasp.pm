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
use utils qw(power_action assert_shutdown_and_restore_system);

our @EXPORT
  = qw(handle_simple_pw process_reboot trup_call write_detail_output get_admin_job update_scheduled export_cluster_logs get_delayed_worker rpmver check_reboot_changes trup_install);

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

    script_run 'supportconfig -i psuse_caasp -B supportconfig', 120;
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

# Process reboot with an option to trigger it
sub process_reboot {
    my $trigger = shift // 0;
    power_action('reboot', observe => !$trigger, keepconsole => 1);

    # No grub bootloader on xen-pv
    # grub2 needle is unreliable (stalls during timeout) - poo#28648

    assert_screen 'linux-login-casp', 180;
    select_console 'root-console';
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
        }
        else {
            die "Confirmation dialog not shown";
        }
    }
    wait_serial 'trup-0-' if $check == 1;
    wait_serial 'trup-1-' if $check == 2;
}

# Reboot if there's a diff between the current FS and the new snapshot
sub check_reboot_changes {
    # rebootmgr has to be turned off as prerequisity for this to work
    script_run "rebootmgrctl set-strategy off";

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

# Function for writing custom text boxes for the test job
# After fixing poo#17462 it should be replaced by record_info from testlib
sub write_detail_output {
    my ($self, $title, $output, $result) = @_;

    $result =~ /^(ok|fail|softfail)$/ || die "Result value: $result not allowed.";

    my $filename = $self->next_resultname('txt');
    my $detail   = {
        title  => $title,
        result => $result,
        text   => $filename,
    };
    push @{$self->{details}}, $detail;

    open my $fh, '>', bmwqemu::result_dir() . "/$filename";
    print $fh $output;
    close $fh;

    # Set overall result for the job
    if ($result eq 'fail') {
        $self->{result} = $result;
    }
    elsif ($result eq 'ok') {
        $self->{result} ||= $result;
    }
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

1;
