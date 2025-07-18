# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Create filesystem and check content
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'haclusterbasetest';
use strict;
use warnings;
use utils qw(zypper_call write_sut_file);
use version_utils qw(is_sle);
use testapi;
use lockapi;
use hacluster;
use serial_terminal qw(select_serial_terminal);

my $num = 1;

sub configure_metadata {
    my (%conf, $operate) = @_;
    foreach my $key (keys %conf) {
        my $change_val = $operate eq 'increase' ? $conf{$key} + $num : $conf{$key} - $num;
        assert_script_run("crm sbd configure $key-timeout=$change_val");
    }
}

sub run {
    my $cluster_name = get_cluster_name;
    my %metadata_config;

    # Get origin disk_metadata configuration
    my $metadata_conf = script_output('crm sbd configure show disk_metadata');

    # Output of crm sbd configure show :
    # ==Dumping header on disk xxxxx
    # Header version     : 2.1
    # UUID               : xxxxxx-xxx-xxx-xx-xxxx
    # Number of slots    : 255
    # Sector size        : 512
    # Timeout (watchdog) : 15
    # Timeout (allocate) : 2
    # Timeout (loop)     : 1
    # Timeout (msgwait)  : 0
    # ==Header on disk xxxxxxx
    foreach my $line (split('\n', $metadata_conf)) {
        if ($_ =~ /Timeout\s+\((\w+)\)\s+\:\s+(\d+)/) {
            $metadata_config{$1} = $2;
        }
    }

    barrier_wait("CLUSTER_BEFORE_CHANGE_METADATA_$cluster_name");

    # Configure the metadata
    configure_metadata(%metadata, "increase") if (is_node(1));

    barrier_wait("CLUSTER_AFTER_CHANGE_METADATA_$cluster_name");

    # Check metadata
    foreach my $msg (split('\n', script_output('crm sbd configure show disk_metadata'))) {
        if ($_ =~ /Timeout\s+\((\w+)\)\s+\:\s+(\d+)/) {
            my $expected_val = $2 + $num;
            die "The metadata $1 is not changed as expected" if ($metadata_config{$1} ne $expected_val);
        }
    }

    barrier_wait("CLUSTER_CHECK_CHANGE_METADATA_$cluster_name");

    # Recover metadata configuration
    configure_metadata(%metadata, "reduce") if (is_node(1));
}

1;
