# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Test module for performing database stop using various methods on secondary HANA database site.
#
# Parameters:
# HA_SBD_START_DELAY (optional) - Sets SBD start delay in /etc/sysconfig/sbd
# DB_ACTION (optional) - Action to be done on the database to simulate failure - check lib/sles4sap_publiccloud "stop_hana" function

use strict;
use warnings FATAL => 'all';
use base 'sles4sap_publiccloud_basetest';
use testapi;
use sles4sap_publiccloud;
use serial_terminal 'select_serial_terminal';
use Time::HiRes 'sleep';

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;

    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);
    croak('site_b is missing or undefined in run_args') if (!$run_args->{site_b});

    my $hana_start_timeout = bmwqemu::scale_timeout(600);
    # $site_b = $instance of secondary instance located in $run_args->{$instances}
    my $site_b = $run_args->{site_b};
    my $sbd_delay;
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
    $self->{my_instance}->wait_for_ssh(username => 'cloudadmin');

    # SBD delay is active only after reboot
    if ($db_action eq 'crash' and $sbd_delay != 0) {
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

    record_info("Done", "Test finished");
}

1;
