# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: parted systemd
# Summary: bsc#1089761, SUSE-RU-2018:2620-1
#
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
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
    record_info('OK', 'No partion labels found with name equal to primary|logical');

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

=head1 Description

Regression test for bsc#1089761. udev should not create
C</dev/disk/by-partlabel> symlinks for the generic partition names
C<primary> and C<logical>, which C<parted> assigns by default and which
often appear on many partitions at once.

The test first checks that a normal installation has no partitions with
these names. It then creates 101 GPT partitions called C<primary> and 10
called C<openqapart> on C</dev/vdb>, reboots, and checks that:

=over

=item * C<detect-part-label-duplicates.service> logged a warning about the
large number of partitions sharing a label,

=item * no by-partlabel symlinks exist for C<primary>, while all 10
C<openqapart> symlinks are created.

=back

Finally, it adds C<udev.no-partlabel-links=1> to the kernel command line,
reboots, and checks that no by-partlabel symlinks are created at all.

=head1 Requirements

The SUT needs a second disk at C</dev/vdb>, which the test overwrites. The
test changes the bootloader configuration and reboots twice.

=cut
