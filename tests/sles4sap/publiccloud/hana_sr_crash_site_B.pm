# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HANA SR - Crash OS on site B
# Stop database on Site B by crashing OS and forcing reboot.
# Do takeover on Site A
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings FATAL => 'all';
use diagnostics;
use Data::Dumper;
use testapi;
use base 'publiccloud::basetest';;
use Mojo::JSON;
use Mojo::File qw(path);
use sles4sap_publiccloud;
use publiccloud::utils;

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->{instances} = $run_args->{instances};
    my $hana_start_timeout = bmwqemu::scale_timeout(600);
    my $site_b = $run_args->{site_b};

    $self->select_serial_terminal;

    # Switch to control Site B (currently PROMOTED)
    $self->{my_instance} = $site_b;
    my $cluster_status = $self->run_cmd(cmd=>"crm status");
    record_info( "Cluster status", $cluster_status );

    # Check initial state: 'site B' = primary mode
    die("Site B '$site_b->{instance_id}' is NOT in MASTER mode.") if
        $self->get_promoted_hostname() ne $site_b->{instance_id};

    record_info("Crash OS", "Running 'proc-systrigger' on Site B ('$site_b->{instance_id}')");
    $self->stop_hana(method => "crash");
    $self->{my_instance}->wait_for_ssh(username=>'cloudadmin');

    record_info("Takeover check");
    $self->check_takeover();

    record_info("Replication", "Enabling replication on Site B (DEMOTED)");
    $self->enable_replication();

    record_info("Site B start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");
}

1;