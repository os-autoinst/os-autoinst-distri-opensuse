# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate generated autoyast profile generated for autoyast installation when using whole disk as PV
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use warnings;
use base 'basetest';
use testapi;
use xml_utils;
use y2_module_consoletest;

#Xpath parser
my $xpc;

sub test_setup {
    select_console('root-console');
    my $profile_path = '/root/autoinst.xml';
    # Generate pofile if doesn't exist
    if (script_run("[ -e $profile_path ]")) {
        my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'clone_system');
        wait_serial("$module_name-0", 60) || die "'yast2 clone_system' exited with non-zero code";
    }
    my $autoinst = script_output("cat $profile_path");
    # get XPathContext
    $xpc = get_xpc($autoinst);
}

sub validate_disk_labels {
    my $errors = '';
    my $result_str;
    record_info 'Disk labels', 'Validate disk labels, should be set to none';
    for my $disk (qw(sdb sdc)) {
        $result_str = verify_option(xpc => $xpc, xpath => "//ns:partitioning/ns:drive[ns:device=\"/dev/$disk\"]/ns:disklabel", expected_val => 'none');
        $errors .= "/dev/$disk disk does NOT have disklabel set to none: $result_str\n" if $result_str;
    }
    return $errors;
}

sub validate_disk_as_lvm_vg {
    my $errors = '';
    record_info 'Test LVM', 'Validate lvm setup';
    my $result_str = verify_option(xpc => $xpc, xpath => '//ns:partitioning/ns:drive[ns:device="/dev/sdc"]/ns:disklabel', expected_val => 'none');
    $errors .= "/dev/sdb disk does NOT have disklabel set to none: $result_str\n" if $result_str;

    $result_str = verify_option(xpc => $xpc, xpath => '//ns:partitioning/ns:drive[ns:device="/dev/sdc"]/ns:partitions/ns:partition/ns:lvm_group', expected_val => 'system');
    $errors .= "No system lvm_group found for sdb device: $result_str\n" if $result_str;
    # Verify swap and /home are listed with correct mount points
    my %mounts = (swap => 'swap', home => '/home');
    while (my ($lv_name, $mount_path) = each %mounts) {
        $result_str = verify_option(xpc => $xpc, xpath => "//ns:partitioning/ns:drive[ns:device=\"/dev/system\"]/ns:partitions/ns:partition[ns:lv_name=\"$lv_name\"]/ns:mount", expected_val => $mount_path);
        $errors .= "No $lv_name logical volume found for in system volume group with mount at $mount_path: $result_str\n" if $result_str;
    }

    return $errors;
}

sub validate_disk_as_partition {
    my $errors = '';
    record_info 'Test disk as PV', 'Validate whole disk as partition';
    my $result_str = verify_option(xpc => $xpc, xpath => '//ns:partitioning/ns:drive[ns:device="/dev/sdb"]/ns:partitions/ns:partition/ns:mount', expected_val => '/');
    $errors .= "No mount point for / found for /dev/sdb: $result_str\n" if $result_str;
}

sub run {
    my $errors = '';
    test_setup;
    $errors .= validate_disk_as_lvm_vg;
    $errors .= validate_disk_labels;
    $errors .= validate_disk_as_partition;

    die("Test failed:\n$errors") if $errors;
}

1;
