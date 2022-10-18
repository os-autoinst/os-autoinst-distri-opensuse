# SUSE's SLES4SAP openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: parted lvm2
# Summary: Try to reclaim some of the space from the system PV which
#           may be needed for SAP products
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $output = script_output q@parted /dev/sda print free | awk '/Free Space/ {print $3}' | tail -1@;
    $output =~ m/([0-9\.]+)([A-Z])B/i;
    my $free = $1;
    my $units = uc($2);
    if ($units eq 'T') {
        $free *= 1024;
    }
    elsif ($units ne 'G') {
        # Assume there's no space available if units are not T or G
        $free = 0;
    }
    # Only attempt to reclaim space from /dev/system/root if there's not enough free space available
    return if ($free >= 70);

    $output = script_output 'df -h --output=size,used,avail / | tail -1';
    my ($root_size, $root_used, $root_free) = split(/\s+/, $output);
    $root_size =~ s/([A-Z])$//i;
    $root_free =~ s/([A-Z])$//i;
    $units = $1;
    if ($units eq 'T') {
        $root_free *= 1024;
    }
    elsif ($units ne 'G') {
        # Assume there's not enough free space on /dev/system/root if units are not T or G
        $root_free = 0;
    }

    # Always leave at least 25Gb free on /dev/system/root for packages and Hana
    $root_free -= 25;
    $root_size -= $root_free if ($root_free > 0);
    if ($root_size >= ($root_used + 25)) {
        assert_script_run "lvresize --yes --force --resizefs --size -$root_size$units /dev/system/root";
    }
    $output = script_output q@pvscan | sed -n '/system/s/\[//p' | awk '(NSIZE=$6-$9+1) {print $2","NSIZE","$10}'@;
    my ($device, $newsize, $unit) = split(/,/, $output);
    $unit = substr($unit, 0, 1);

    # Do nothing else unless there's at least 1GB to reclaim in the LVM partition
    return unless ($unit eq 'G' or $unit eq 'T');

    # Set unit as GB, because adding TB is too much!
    if ($unit eq 'T') {
        $newsize *= 1024;
        $unit = 'G';
    }

    # We can have allocated space at the end of the PV, so we need to move it before
    my $script = 'reclaim_free_space_in_pv.sh';
    assert_script_run "curl -f -v " . autoinst_url . "/data/sles4sap/$script -o /tmp/$script; chmod +x /tmp/$script";
    assert_script_run "/tmp/$script $device", 300;

    # Resize the PV
    assert_script_run "pvresize -y --setphysicalvolumesize $newsize$unit $device";
    $device =~ s/([0-9]+)$//;
    my $partnum = $1;
    $newsize += 1;    # Just to be sure that the partition is bigger than the PV (+1G)
    my $resize_cmd = is_sle('15+') ? 'resizepart' : 'resize';
    assert_script_run "parted -s $device $resize_cmd $partnum $newsize${unit}i";    # Unit in parted must use the 'GiB' notation!

    # Sync all and reboot if needed
    enter_cmd "partprobe;sync;sync;";
    reset_consoles;
    $self->reboot if is_sle('<15');
}

1;
