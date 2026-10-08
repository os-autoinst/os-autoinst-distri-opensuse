# Copyright 2017-2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: kexec-tools systemd
# Summary:  [qa_automation] kexec testsuite
# Maintainer: QE Kernel <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_transactional);
use transactional qw(enter_trup_shell exit_trup_shell_and_reboot);

sub run {
    my $self = shift;
    select_serial_terminal;

    # Copy kernel image and rename it
    my $find_output = script_output('find /boot -maxdepth 1 -name "*$(uname -r)"', 600);
    record_info('Find output', $find_output);
    my @filtered = grep { /image|vmlinu/i } split /\n/, $find_output;
    my $kernel_orig = $filtered[0];
    (my $kernel_new = $kernel_orig) =~ s/-default$/-kexec/;
    enter_trup_shell if (is_transactional);
    assert_script_run("cp $kernel_orig $kernel_new");

    # Copy initrd image and rename it
    my $initrd_orig = script_output('find /boot -maxdepth 1 -name "initrd-$(uname -r)"', 120);
    (my $initrd_new = $initrd_orig) =~ s/-default$/-kexec/;
    assert_script_run("cp $initrd_orig $initrd_new");
    exit_trup_shell_and_reboot if is_transactional;

    # kernel cmdline parameter
    $_ = script_output("cat /proc/cmdline", 120);
    s/-default /-kexec /;
    s/ splash=silent//;
    my $cmdline = "$_ debug";

    # kexec -l
    assert_script_run("kexec -l $kernel_new --initrd=$initrd_new --command-line='$cmdline'");
    # kexec -e
    # don't use built-in systemctl api, see poo#31180
    select_console 'root-console';
    record_info('KEXEC', 'systemctl kexec');
    script_run("systemctl kexec", 0);
    save_screenshot;
    reset_consoles;
    $self->wait_boot_past_bootloader;
    select_serial_terminal;
    # Check kernel cmdline parameter
    my $result = script_output("cat /proc/cmdline", 120);
    print "Checking kernel boot parameter...\nCurrent:  $result\nExpected: $cmdline\n";
    if ($cmdline ne $result) {
        die "kexec failed";
    }
}

1;
