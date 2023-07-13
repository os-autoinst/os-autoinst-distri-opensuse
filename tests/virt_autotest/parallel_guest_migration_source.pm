# GUEST MIGRATION TEST SOURCE MODULE
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Guest migration test source module.
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
package parallel_guest_migration_source;

use base "parallel_guest_migration_base";
use strict;
use warnings;
use POSIX 'strftime';
use testapi;
use upload_system_log;
use lockapi;
use mmapi;
use virt_autotest::utils qw(is_kvm_host is_xen_host check_host_health check_guest_health is_fv_guest is_pv_guest);
use virt_utils qw(collect_host_and_guest_logs cleanup_host_and_guest_logs enable_debug_logging);
use utils qw(script_retry);
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

    $self->prepare_guest;
    barrier_wait('GUEST_PREPARATION_SOURCE_DONE');

    script_run("echo -e \"Wait destination prepare_guest ends\\n\"") while ($self->get_test_run_progress !~ /prepare_guest_end/i);
    barrier_wait('GUEST_PREPARATION_DESTINATION_DONE');

    $self->prepare_log;
    barrier_wait('LOG_PREPARATION_DONE');

    $self->guest_migration_test;
}

=head2 prepare_host

Prepare host for guest migration test, including checking architecture, operating
system, virtualization, network, pacakge, user/group id, shared storage and security.
Please refer to the following documentation:
https://susedoc.github.io/doc-sle/main/single-html/SLES-virtualization/#sec-libvirt-admin-migrate
=cut

sub prepare_host {
    my $self = shift;

    $self->set_test_run_progress;
    $self->check_host_architecture;
    $self->check_host_os;
    $self->check_host_virtualization;
    $self->check_host_package;
    $self->check_host_uid;
    $self->check_host_gid;
    $self->config_host_shared_storage(role => 'server');
    $self->config_host_security;
}

=head2 prepare_guest

Prepare guest for migration test, including initialization, clock, storage, console, 
network and passwordless ssh connection. Please refer to the following documentation: 
https://susedoc.github.io/doc-sle/main/single-html/SLES-virtualization/#sec-libvirt-admin-migrate
=cut

sub prepare_guest {
    my $self = shift;

    $self->set_test_run_progress(token => 'start');
    my $guest = $self->guest_under_test(role => 'src');
    $self->initialize_test_result;
    unless (get_var('SKIP_GUEST_INSTALL', '')) {
        $self->save_guest_asset(guest => $guest);
        virt_autotest::domain_management_utils::remove_guest(guest => $guest);
    }
    else {
        $self->restore_guest_asset(guest => $guest);
    }
    $self->config_guest_clock(guest => $guest);
    $self->config_guest_storage(guest => $guest);
    virt_autotest::domain_management_utils::create_guest(guest => $guest, start => 0);
    $self->config_guest_console(guest => $guest);
    $self->check_guest_network_config(guest => $guest);
    $self->create_guest_network;
    $self->start_guest(guest => $guest);
    virt_autotest::domain_management_utils::show_guest();
    $self->initialize_guest_matrix(role => 'src');
    $self->config_ssh_pubkey_auth(addr => $guest, overwrite => 0, host => 0);
    $self->set_test_run_progress(token => 'end');
}

=head2 prepare_log

Enable virtualization debug logging, check host and guest health.
=cut

sub prepare_log {
    my $self = shift;

    $self->set_test_run_progress;
    enable_debug_logging();
    check_host_health();
    my @guest_under_test = split(/ /, get_required_var('GUEST_UNDER_TEST'));
    foreach (@guest_under_test) {
        check_guest_health($_);
    }
    virt_autotest::domain_management_utils::shutdown_guest(guest => get_required_var('GUEST_UNDER_TEST'));
}

=head2 guest_migration_test

Do guest migration test in loop for all guests and tests. Source and destination
hosts collaborate with each other during test run by employing barriers, including
DO_GUEST_MIGRATION_DONE_counter and DO_GUEST_MIGRATION_READY_counter. Subroutines
pre_guest_migration, do_guest_migration and post_guest_migration do main actual
works. Collect log for failure immediately and do log cleanup after each test if 
INTERVAL_LOG is set (1).
=cut

sub guest_migration_test {
    my $self = shift;

    $self->set_test_run_progress;
    my @guest_migration_test = split(/,/, get_var('GUEST_MIGRATION_TEST', ''));
    my $full_test_matrix = is_kvm_host ? $parallel_guest_migration_base::guest_migration_matrix{kvm} : $parallel_guest_migration_base::guest_migration_matrix{xen};
    @guest_migration_test = keys(%$full_test_matrix) if (scalar @guest_migration_test == 0);
    my $localip = get_required_var('LOCAL_IPADDR');
    my $peerip = get_required_var('PEER_IPADDR');
    my $localuri = virt_autotest::domain_management_utils::construct_uri();
    my $peeruri = virt_autotest::domain_management_utils::construct_uri(host => $peerip);
    my $counter = 0;

    foreach my $guest (keys %parallel_guest_migration_base::guest_matrix) {
        while (my ($testindex, $test) = each(@guest_migration_test)) {
            my $ret = 0;
            my $command = $full_test_matrix->{$test};
            $command =~ s/guest/$guest/g;
            $command =~ s/srcuri/$localuri/g;
            $command =~ s/dsturi/$peeruri/g;
            $command =~ s/dstip/$peerip/g;
            $command =~ /(xl|virsh)/i;
            my $virttool = $1;
            my $offline = $test =~ /offline/i;

            record_info("Start $test on $guest", "Migration command is $command");
            my $test_start_time = time();
            my $test_stop_time = $test_start_time;
            $self->pre_guest_migration(guest => $guest, virttool => $virttool, first => ($testindex == 0 ? 1 : 0));
            $ret = $self->do_guest_migration(guest => $guest, test => $test, command => $command, offline => $offline);
            collect_host_and_guest_logs($guest, '', '', "_$guest" . "_$test") if ($ret != 0 and get_var('INTERVAL_LOG', ''));

            barrier_wait("DO_GUEST_MIGRATION_DONE_$counter");

            barrier_wait("DO_GUEST_MIGRATION_READY_$counter");
            $counter += 1;
            $test_stop_time = time();
            $parallel_guest_migration_base::test_result{$guest}{$command}{test_time} = strftime("\%H:\%M:\%S", gmtime($test_stop_time - $test_start_time));
            record_info("End $test on $guest", "Total test time is $parallel_guest_migration_base::test_result{$guest}{$command}{test_time}");
            $virttool = $testindex < scalar @guest_migration_test - 1 ? $guest_migration_test[$testindex + 1] =~ /(xl|virsh)/i && $1 : 'virsh';
            $self->post_guest_migration(guest => $guest, virttool => $virttool, last => ($testindex == scalar @guest_migration_test - 1 ? 1 : 0));
            cleanup_host_and_guest_logs if (get_var('INTERVAL_LOG', ''));
        }
    }
}

=head2 pre_guest_migration

Transform guest to xen-xl form at the first test run if it is xl migration test.
Perform basic administration on guest if GUEST_ADMINISTRATION is set (1). Update
guest information by calling initialize_guest_matrix. 
=cut

sub pre_guest_migration {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{first} //= 0;
    die("Guest to be tested must be given") if (!$args{guest});

    if ($args{first} == 1) {
        if ($args{virttool} eq 'xl') {
            virt_autotest::domain_management_utils::remove_guest(guest => $args{guest});
            virt_autotest::domain_management_utils::create_guest(guest => $args{guest}, virttool => $args{virttool}, start => 0);
        }
        $self->start_guest(guest => $args{guest}, virttool => $args{virttool});
    }
    if (get_var('GUEST_ADMINISTRATION', '')) {
        $self->do_guest_administration(guest => $args{guest}, virttool => $args{virttool});
        virt_autotest::domain_management_utils::remove_guest(guest => $args{guest});
        virt_autotest::domain_management_utils::create_guest(guest => $args{guest}, virttool => $args{virttool}, start => 0);
        $self->start_guest(guest => $args{guest}, virttool => $args{virttool});
    }
    $self->initialize_guest_matrix(role => 'src', guest => $args{guest});
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
    die("Guest and test/command to be executed must be given") if (!$args{guest} or !$args{test} or !$args{command});

    virt_autotest::domain_management_utils::shutdown_guest(guest => $args{guest}) if ($args{offline} == 1);
    my $ret = $args{test} =~ /manual_postcopy/i ? $self->virsh_migrate_manual_postcopy(guest => $args{guest}, command => $args{command}) : script_run($args{command}, timeout => 120);
    if ($ret != 0) {
        record_info("Failed $args{test} migration", "Guest migration failed with $args{command}", result => 'fail');
        save_screenshot;
    }
    else {
        $parallel_guest_migration_base::test_result{$args{guest}}{$args{command}}{status} = 'PASSED';
        record_info("Passed $args{test} migration", "Guest migration succeeded with $args{command}");
    }
    return $ret;
}

=head2 post_guest_migration

Restore guest after current migration test finishes and prepare for the next test.
Only re-create guest if the current test is not the last one for the guest.
=cut

sub post_guest_migration {
    my ($self, %args) = @_;
    $args{guest} //= '';
    $args{virttool} //= 'virsh';
    $args{last} //= 0;
    die("Guest to be tested must be given") if (!$args{guest});

    virt_autotest::domain_management_utils::remove_guest(guest => $args{guest});
    if ($args{last} == 0) {
        virt_autotest::domain_management_utils::create_guest(guest => $args{guest}, virttool => $args{virttool}, start => 0);
        $self->start_guest(guest => $args{guest}, virttool => $args{virttool});
    }
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
