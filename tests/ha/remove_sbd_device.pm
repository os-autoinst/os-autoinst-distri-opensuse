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

sub run {
    my $cluster_name = get_cluster_name;

    # get all sbd devices
    my @sbd_devices = split("\n", script_output("crm sbd configure show disk_metadata | grep 'Dumping header on disk' | awk ' {print \$5 } '"));

    my $remove_dev = shift @sbd_devices;

    if (is_node(1)) {
        assert_script_run("crm sbd device remove $remove_dev");
    }

    # Wait for one sbd device is removed
    barrier_wait("CLUSTER_DEL_SDB_DEVICE_$cluster_name");

    # Check the remove result
    if (script_run("crm sbd configure show disk_metadata | grep -F '$remove_dev'")) {
        record_info('SBD remove', "The SBD device $remove_dev is removed");
    }

    # Before remove a sbd device, we have two devices. So there should be on left.
    my $sbd_dev = shift @sbd_devices;
    assert_script_run("crm sbd configure show disk_metadata | grep -F '$sbd_device'");
}

1;
