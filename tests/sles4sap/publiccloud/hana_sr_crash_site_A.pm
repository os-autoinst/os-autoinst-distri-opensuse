# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HANA SR - Crash OS on site A
# Stop database on Site A by by crashing OS and forcing reboot.
# Do takeover on Site B
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    my $hana_start_timeout = bmwqemu::scale_timeout(600);
    my $site_a = $run_args->{site_a};

    $self->select_serial_terminal;

    # Switch to control Site A (currently PROMOTED)
    $self->{my_instance} = $site_a;
    my $cluster_status = $self->run_cmd(cmd => "crm status");
    record_info("Cluster status", $cluster_status);
    # Check initial state: 'site A' = primary mode
    die("Site A '$site_a->{instance_id}' is NOT in MASTER mode.") if
      $self->get_promoted_hostname() ne $site_a->{instance_id};

    record_info("Stop DB", "Running 'proc-systrigger' on Site A ('$site_a->{instance_id}')");
    $self->stop_hana(method => "crash");
    $self->{my_instance}->wait_for_ssh(username => 'cloudadmin');

    record_info("Takeover check");
    $self->check_takeover();

    record_info("Replication", "Enabling replication on Site A (DEMOTED)");
    $self->enable_replication();

    record_info("Site A start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");
}

1;
