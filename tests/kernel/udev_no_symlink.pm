# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: parted systemd
# Summary: bsc#1089761, SUSE-RU-2018:2620-1
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils 'power_action';


sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Normal SLES installation should not have partitions with name logical or primary
    assert_script_run('test $(grep -r "E:ID_PART_ENTRY_NAME=primary" /run/udev/data | wc -l) -eq 0');
    assert_script_run('test $(grep -r "E:ID_PART_ENTRY_NAME=logical" /run/udev/data | wc -l) -eq 0');
    record_info('OK', 'No partition labels found with name equal to primary|logical');

    # Prepare HDD
    zypper_call('-q in parted');
    my $udev_label = "/run/udev/links/*by-partlabel*{primary,logical}/*";
    my $udev_no_label = "/run/udev/links/*by-partlabel*/*";
    my $num_primary = 101;
    my $num_openqapart = 10;
    my $cnt;
    assert_script_run('parted -s /dev/vdb mklabel gpt');
    for ($cnt = 1; $cnt <= $num_primary; $cnt++) {
        assert_script_run(sprintf('parted -s /dev/vdb mkpart primary %dMiB %dMiB', $cnt, $cnt + 1));
    }
    for (; $cnt <= $num_primary + $num_openqapart; $cnt++) {
        assert_script_run(sprintf('parted -s /dev/vdb mkpart openqapart %dMiB %dMiB', $cnt, $cnt + 1));
    }
    record_info('INFO', "Created $num_primary partitions with name primary.\nCreated $num_openqapart partitions with name openqapart");

    # Check that no symlinks are created for LABEL primary and warning appear
    power_action('reboot');
    $self->wait_boot;
    select_serial_terminal;
    assert_script_run('journalctl -u detect-part-label-duplicates.service --no-pager | grep "Warning: a high number of partitions uses"');
    assert_script_run('test $(grep -r "E:ID_PART_ENTRY_NAME=primary" /run/udev/data | wc -l) -eq ' . $num_primary);
    assert_script_run('test $(grep -r "E:ID_PART_ENTRY_NAME=openqapart" /run/udev/data | wc -l) -eq ' . $num_openqapart);
    script_run('ls -laR ' . $udev_label);
    assert_script_run("test \$(ls -l ${udev_label} | wc -l) -eq 0");
    assert_script_run('test $(ls -l /run/udev/links/*by-partlabel*openqapart/* | wc -l) -eq ' . $num_openqapart);
    record_info('OK', 'No symlinks created for partitions with label "primary" and warning appeared');

    # Check that no symlinks are created at all with udev.no-partlabel-links kernel parameter
    add_grub_cmdline_settings('udev.no-partlabel-links=1', update_grub => 1);
    power_action('reboot');
    $self->wait_boot;
    select_serial_terminal;
    assert_script_run('test $(grep -r "E:ID_PART_ENTRY_NAME=primary" /run/udev/data | wc -l) -eq ' . $num_primary);
    assert_script_run('test $(grep -r "E:ID_PART_ENTRY_NAME=openqapart" /run/udev/data | wc -l) -eq ' . $num_openqapart);
    script_run('ls -laR ' . $udev_no_label);
    assert_script_run("test \$(ls -l ${udev_no_label} | wc -l) -eq 0");
    record_info('OK', 'No symlinks created with udev.no-partlabel-links enabled');
}

1;
