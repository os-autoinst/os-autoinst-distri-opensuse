# GUEST MIGRATION TEST DESTINATION MODULE
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Guest migration test destination module.
#
# Main features:
# Prepare host for guest migration test.
# Prepare guest for migration test.
# Prepare logs for test run.
# Perform guest migration test together with destination host in
# collaborative manner.
# Perform basci administration on guest if necessary.
# Do logs collecting and cleanup for each failure if necessary.
#
# Test suite level settings to control test behavior:
# GUEST_LIST specifies guest to be tested or empty.
# GUEST_MIGRATION_TEST specifies migration test to be executed or empty.
# EXTERNAL_SHARED_STORAGE indicates a common nfs server is available
# and its nfs share is ready mounted locally.
# SKIP_GUEST_INSTALL indicates whether guest is installed directly
# locally instead of transferred to the host.
# GUEST_ADMINISTRATION indicates whether do basic administration on
# guest before and after migration test.
# INTERVAL_LOG indicates whether each failed test invokes immediate
# logs collecting for the failure.
# REGRESSION indicates MU incidents testing activity.
#
# Maintainer: Wayne Chen <wchen@suse.com>, qe-virt <qe-virt@suse.de>
package parallel_guest_migration_destination;

use base "parallel_guest_migration_base";
use strict;
use warnings;
use POSIX 'strftime';
use testapi;
use upload_system_log;
use lockapi;
use mmapi;
use virt_autotest::utils qw(is_kvm_host is_xen_host check_host_health check_guest_health is_fv_guest is_pv_guest add_guest_to_hosts);
use virt_utils qw(collect_host_and_guest_logs cleanup_host_and_guest_logs enable_debug_logging);
use virt_autotest::domain_management_utils qw(construct_uri create_guest remove_guest shutdown_guest show_guest check_guest_state);

=head2 run_test

Execute entire test flow from initialization, preparation, to guest migration.
=cut

sub run_test {
    my $self = shift;

    $self->set_test_run_progress;
    barrier_wait('READY_TO_GO');

    $self->do_local_initialization;
    barrier_wait('LOCAL_INITIALIZATION_DONE');

    $self->do_peer_initialization;
    barrier_wait('PEER_INITIALIZATION_DONE');

    $self->prepare_host;
    barrier_wait('HOST_PREPARATION_DONE');

    script_run("echo -e \"Wait source prepare_guest ends\\n\"") while ($self->get_test_run_progress !~ /prepare_guest_end/i);
    barrier_wait('GUEST_PREPARATION_SOURCE_DONE');

    $self->prepare_guest;
    barrier_wait('GUEST_PREPARATION_DESTINATION_DONE');

    $self->prepare_log;
    barrier_wait('LOG_PREPARATION_DONE');

    $self->guest_migration_test;
}

=head2 prepare_host

Prepare host for guest migration test, including virtualization, package and security.
=cut

sub prepare_host {
    my $self = shift;

    $self->set_test_run_progress;
    $self->check_host_virtualization;
    $self->check_host_package;
    $self->config_host_security;
}

=head2 prepare_guest

Prepare host for migration test, including initialization, shared storage and network.
=cut

sub prepare_guest {
    my $self = shift;

    $self->set_test_run_progress(token => 'start');
    $self->config_host_shared_storage(role => 'client');
    $self->guest_under_test(role => 'dst');
    $self->initialize_test_result;
    $self->initialize_guest_matrix(role => 'dst');
    $self->create_guest_network;
    $self->set_test_run_progress(token => 'end');
}

=head2 prepare_log

Enable virtualization debug logging and check host health.
=cut

sub prepare_log {
    my $self = shift;

    $self->set_test_run_progress;
    enable_debug_logging();
    check_host_health();
}

=head2 guest_migration_test

Do guest migration test in loop for all guests and tests. Source and destination
hosts collaborate with each other during test run by employing barriers, including
DO_GUEST_MIGRATION_DONE_counter and DO_GUEST_MIGRATION_READY_counter. Subroutines
check_migration_result, test_after_migration and do_guest_migration do main actual
works. Collect log for failure immediately and do log cleanup after each test if
INTERVAL_LOG is set (1).
=cut

sub guest_migration_test {
    my $self = shift;

    $self->set_test_run_progress;
    my @guest_migration_test = split(/,/, get_var('GUEST_MIGRATION_TEST'));
    my $full_test_matrix = is_kvm_host ? $parallel_guest_migration_base::guest_migration_matrix{kvm} : $parallel_guest_migration_base::guest_migration_matrix{xen};
    @guest_migration_test = keys(%$full_test_matrix) if (scalar @guest_migration_test == 0);
    my $localip = get_required_var('LOCAL_IPADDR');
    my $peerip = get_required_var('PEER_IPADDR');
    my $localuri = virt_autotest::domain_management_utils::construct_uri();
    my $peeruri = virt_autotest::domain_management_utils::construct_uri(host => $peerip);
    my $migration = $self->check_host_os(role => 'dst');
    my $counter = 0;
    my $nextcounter = $counter + 1;

    foreach my $guest (keys %parallel_guest_migration_base::guest_matrix) {
        foreach my $test (@guest_migration_test) {
            my $ret = 0;
            my $command = $full_test_matrix->{$test};
            $command =~ s/guest/$guest/g;
            $command =~ s/srcuri/$localuri/g;
            $command =~ s/dsturi/$peeruri/g;
            $command =~ s/dstip/$peerip/g;
            $command =~ /(xl|virsh)/i;
            my $virttool = $1;
            my $offline = $test =~ /offline/i;
            my $persistent = ($command =~ /persistent/i | $virttool eq 'xl');
            my $test_start_time = time();
            my $test_stop_time = $test_start_time;

            record_info("Start $test on $guest", "Migration command is $command");

            barrier_wait("DO_GUEST_MIGRATION_DONE_$counter");
            $self->create_barrier(signal => "DO_GUEST_MIGRATION_DONE_$nextcounter");
            $ret = $self->check_migration_result(guest => $guest, virttool => $virttool, peer => $peerip, offline => $offline);
            if ($ret == 0) {
                $ret = $self->test_after_migration(guest => $guest, virttool => $virttool, persistent => $persistent, offline => $offline);
                $ret |= $self->do_guest_migration(guest => $guest, test => $test, command => $command, offline => $offline, cando => ($migration == 0 ? 1 : 0));
                collect_host_and_guest_logs($guest, '', '', "_$guest" . "_$test") if ($ret != 0 and get_var('INTERVAL_LOG', ''));
            }
            $test_stop_time = time();
            $parallel_guest_migration_base::test_result{$guest}{$command}{test_time} = strftime("\%H:\%M:\%S", gmtime($test_stop_time - $test_start_time));
            record_info("End $test on $guest", "Total test time is $parallel_guest_migration_base::test_result{$guest}{$command}{test_time}");
            virt_autotest::domain_management_utils::remove_guest(guest => $guest) if ($ret != 0 or !($command =~ /undefinesource/i) or $offline == 1 or ($ret == 0 and $migration != 0));

            barrier_wait("DO_GUEST_MIGRATION_READY_$counter");
            $self->create_barrier(signal => "DO_GUEST_MIGRATION_READY_$nextcounter");
            $counter = $nextcounter;
            $nextcounter += 1;
            cleanup_host_and_guest_logs if (get_var('INTERVAL_LOG', ''));
        }
    }
}

=head2 check_migration_result

Check migration result by obtaining guest state and wait for ssh connection.
=cut

sub check_migration_result {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{peer} //= '';
    $args{offline} //= 0;
    die("Guest to be checked must be given") if (!$args{guest});

    my $ret1 = 1;
    my $ret2 = 1;
    $self->initialize_guest_matrix(role => 'dst', guest => $args{guest});
    virt_autotest::domain_management_utils::show_guest(guest => $args{guest}, virttool => $args{virttool});
    my $guest_state = virt_autotest::domain_management_utils::check_guest_state(guest => $args{guest}, virttool => $args{virttool});
    if (!$guest_state) {
        record_info("Guest $args{guest} migration failed", "Guest $args{guest} can not be migrated successfully from $args{peer}", result => 'fail');
    }
    else {
        if ($args{offline} == 1) {
            $ret1 = $args{virttool} eq 'virsh' ? $self->start_guest(guest => $args{guest}, wait => 0) : 1;
            if ($args{virttool} eq 'xl') {
                record_info("xl does not support offline migration", "Guest $args{guest} can not be migrated offline by using xl migrate", result => 'fail');
            }
            else {
                $ret1 |= $self->wait_guest(guest => $args{guest}, checkip => 0);
            }
        }
        else {
            $ret1 = $self->wait_guest(guest => $args{guest}, checkip => 0);
        }

        $ret2 = $self->wait_guest(guest => $args{guest}) if ($ret1 != 0 and !($args{offline} == 1 and $args{virttool} eq 'xl') and ($parallel_guest_migration_base::guest_matrix{$args{guest}}{staticip} ne 'yes'));
        if ($ret1 == 0) {
            record_info("Guest $args{guest} migration succeeded", "Guest $args{guest} migration from $args{peer} succeeded");
        }
        elsif ($ret2 == 0) {
            record_info("Guest $args{guest} migration succeeded with changed ip", "Guest $args{guest} migration from $args{peer} succeeded but with changed ip address", result => 'softfail');
        }
        elsif ($ret2 != 0) {
            record_info("Guest $args{guest} migration failed", "Guest $args{guest} in wrong state after migration from $args{peer}", result => 'fail');
        }
    }
    return $ret1 == 0 ? $ret1 : $ret2;
}

=head2 test_after_migration

Config passwordless ssh connection to guest, test network accessibility and disk 
read/write in guest, perform basic administration on guest if GUEST_ADMINISTRATION
is set (1).
=cut

sub test_after_migration {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{persistent} //= 1;
    $args{offline} //= 0;
    die("Guest to be checked must be given") if (!$args{guest});

    my $ret = 0;
    $ret |= $self->config_ssh_pubkey_auth(addr => $args{guest}, overwrite => 0, host => 0);
    if ($ret == 0) {
        check_guest_health($args{guest});
        $ret = $self->test_guest_network(guest => $args{guest});
        $ret |= $self->test_guest_storage(guest => $args{guest});
    }

    if (get_var('GUEST_ADMINISTRATION', '') and $args{persistent} == 1) {
        $ret |= $self->do_guest_administration(guest => $args{guest}, virttool => $args{virttool});
        $ret |= $self->wait_guest_ssh(guest => $args{guest});
    }
    return $ret;
}

=head2 do_guest_migration

Do the actual guest migration test. Call virsh_migrate_manual_postcopy if test is
manual postcopy. Record test result accordingly.
=cut

sub do_guest_migration {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{test} //= '';
    $args{command} //= '';
    $args{offline} //= 0;
    $args{cando} //= 1;
    die("Guest and test/command to be executed must be given") if (!$args{guest} or !$args{test} or !$args{command});

    my $ret = 1;
    if ($args{cando} == 1) {
        virt_autotest::domain_management_utils::shutdown_guest(guest => $args{guest}) if ($args{offline} == 1);
        $ret = $args{test} =~ /manual_postcopy/i ? $self->virsh_migrate_manual_postcopy(guest => $args{guest}, command => $args{command}) : script_run($args{command}, timeout => 120);

        if ($ret != 0) {
            record_info("Failed $args{test} migration", "Failed to migration back with $args{command}", result => 'fail');
            save_screenshot;
        }
        else {
            $parallel_guest_migration_base::test_result{$args{guest}}{$args{command}}{status} = 'PASSED';
            record_info("Passed $args{test} migration", "Guest migration back succeeded with $args{command}");
        }
    }
    else {
        $ret = 0;
        $parallel_guest_migration_base::test_result{$args{guest}}{$args{command}}{status} = 'SKIPPED';
        record_info("SKIPPED $args{test} migration", "Guest migration back with $args{command} skipped");
    }
    return $ret;
}

=head2 post_fail_hook

Do post_fail_hook task and wait for peer test run to finish as normal if it also
fails.
=cut

sub post_fail_hook {
    my $self = shift;

    $self->set_test_run_progress;
    $self->SUPER::post_fail_hook;
    barrier_wait('POST_FAIL_HOOK_DONE') if ($self->check_peer_test_run eq 'FAILED');
}

1;
