# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Test module for performing database events on secondary HANA database site.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/hana_sr_test_secondary.pm - Tests the secondary (replica) HANA database node.

=head1 DESCRIPTION

This module tests the resilience and recovery of the secondary (replica) HANA
database node in a System Replication setup. It simulates a failure on the
secondary node by performing an action such as 'stop', 'kill', or 'crash'.

After the action is performed, the module waits for the node to recover and
verifies that the HANA database starts correctly and that the node remains in
replication (secondary) mode without being promoted to primary. It also checks
the overall cluster health after the event.

This module is typically scheduled by C<hana_sr_schedule_replica_tests.pm>, which
passes the specific action to perform via the C<$run_args> hashref.

=head1 SETTINGS

=over

=item B<DB_ACTION>

Specifies the action to be performed on the secondary HANA database. Valid options
are 'stop', 'kill', or 'crash'. This variable can be used to run the test standalone,
but it is typically overridden by the parameters passed from the scheduling module.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::sles4sap_publiccloud_basetest';
use testapi;
use sles4sap::sles4sap_publiccloud;
use serial_terminal 'select_serial_terminal';
use Time::HiRes 'sleep';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    my @hana_sites = get_hana_site_names();
    croak("$hana_sites[1] is missing or undefined in run_args") if (!$run_args->{$hana_sites[1]});

    my $hana_start_timeout = bmwqemu::scale_timeout(600);
    # $site_b = $instance of secondary instance located in $run_args->{$instances}
    my $site_b = $run_args->{$hana_sites[1]};
    my $sbd_delay = 0;
    select_serial_terminal;

    # Switch to control Site B (currently replica mode)
    $self->{my_instance} = $site_b;
    my $cluster_status = $self->run_cmd(cmd => 'crm status');
    record_info('Cluster status', $cluster_status);
    # Check initial state: 'site B' = replica mode
    die("Site B '$site_b->{instance_id}' is NOT in replication mode.") if
      $self->get_promoted_hostname() eq $site_b->{instance_id};

    # Stop DB
    # check variable DB_ACTION in case of separate usage of the test.
    my $db_action = get_var('DB_ACTION', $run_args->{hana_test_definitions}{$self->{name}});
    croak('Database action unknown or not defined.') if ($db_action !~ /^(stop|kill|crash)$/);

    if (($db_action eq 'crash')) {
        # SBD delay related setup in case of crash OS to prevent cluster starting too quickly after reboot
        $self->setup_sbd_delay_publiccloud();
        record_info('Crash DB', "Crashing OS on Site B ('$site_b->{instance_id}')");
    }
    else {
        # 'stopp' is not a typo - 'ing' is appended later
        my $action = $db_action eq 'stop' ? 'stopp' : $db_action;
        record_info(ucfirst($db_action) . ' DB', ucfirst($action) . "ing Site B ('$site_b->{instance_id}')");
    }

    # Calculate SBD delay sleep time
    $sbd_delay = $self->sbd_delay_formula if $db_action eq 'crash';

    $self->stop_hana(method => $db_action);

    # SBD delay is active only after reboot
    if ($db_action eq 'crash' || $db_action eq 'stop') {
        record_info('SBD SLEEP', "Waiting $sbd_delay sec for SBD delay timeout.");
        # sleep needs to be a little longer than sbd start delay
        sleep($sbd_delay + 30);
        $self->wait_for_pacemaker();
    }

    # wait for DB to start with resources
    $self->is_hana_online(wait_for_start => 'true');
    my $hana_started = time;
    while (time - $hana_started > $hana_start_timeout) {
        last if $self->is_hana_resource_running();
        sleep 30;
    }

    # Check if DB started as primary
    die("Site B '$site_b->{instance_id}' did NOT start in replication mode.")
      if $self->get_promoted_hostname() eq $site_b->{instance_id};

    # Cleanup the resource and check cluster
    $self->cleanup_resource();
    $self->wait_for_cluster(wait_time => 60, max_retries => 10);
    $self->display_full_status();

    record_info("Done", "Test finished");
}

1;
