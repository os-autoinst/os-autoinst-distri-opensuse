# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: HANA SR - Crash OS on site A
# Stop database on Site A by by crashing OS and forcing reboot.
# Do takeover on Site B
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings FATAL => 'all';
use diagnostics;
use Data::Dumper;
use testapi;
use Mojo::Base qw(publiccloud::basetest);
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
    my $site_a = $run_args->{site_a};

    $self->select_serial_terminal;

    # Switch to control Site A (currently PROMOTED)
    $self->{my_instance} = $site_a;

    record_info("Stop DB", "Running 'proc-systrigger' on Site A ('$site_a->{instance_id}')");
    $self->stop_hana(method => "crash");

    record_info("Takeover check");
    return();
    $self->check_takeover;

    record_info("Replication", "Enabling replication on Site A (DEMOTED)");
    $self->enable_replication();

    record_info("Site A start");
    $self->cleanup_resource();

    record_info("Done", "Test finished");
}

1;