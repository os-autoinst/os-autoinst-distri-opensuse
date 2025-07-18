# SUSE's openQA tests
#
# Copyright 2020-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Host configuration operations
# * Configure virtio-terminal
# * Configure bootloader (disable timeout, extra kernel parameters)
# * Install SUSE CA certificates, if applicable
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use transactional qw(process_reboot);
use bootloader_setup qw(change_grub_config);
use utils qw(ensure_ca_certificates_suse_installed zypper_call ensure_serialdev_permissions);
use version_utils qw(is_bootloader_grub2 is_bootloader_sdboot is_bootloader_grub2_bls is_sle is_sle_micro);
use serial_terminal qw(select_serial_terminal prepare_serial_console);
use Utils::Architectures 'is_ppc64le';
use zypper qw(wait_quit_zypper);

sub run {
    select_console 'root-console';

    ensure_serialdev_permissions;
    prepare_serial_console;
    select_serial_terminal;

    # Bootloader configuration
    my $extrabootparams = get_var('EXTRABOOTPARAMS');
    my $keep_grub_timeout = get_var('KEEP_GRUB_TIMEOUT');

    if (is_bootloader_grub2) {
        if (is_ppc64le && (is_sle_micro('6.2+') || is_sle('15-SP7+'))) {
            # selfinstall jobs performs kexec before this module is scheduled
            # the paramater has to be defined in EXTRABOOTPARAMS as well
            if (!defined($extrabootparams) || $extrabootparams !~ /disable_ddw=1/) {
                $extrabootparams .= ' disable_ddw=1';
            }
            record_soft_failure('bsc#1239691 - 15-SP7 KOTD kernel crashes qemu during reboot on ppc64le when virtual machine has a PCI device');
        }
        change_grub_config('=\"[^\"]*', "& $extrabootparams", 'GRUB_CMDLINE_LINUX_DEFAULT') if $extrabootparams;
        $keep_grub_timeout or change_grub_config('=.*', '=-1', 'GRUB_TIMEOUT');

        if (!$keep_grub_timeout or $extrabootparams) {
            record_info('GRUB', script_output('cat /etc/default/grub'));
            # poo#87850 wait the zypper processes in background to finish and release the lock.
            wait_quit_zypper;
            assert_script_run('transactional-update grub.cfg');
            ensure_ca_certificates_suse_installed if get_var('HOST_VERSION');
            process_reboot(trigger => 1);
        }
    } elsif (is_bootloader_sdboot || is_bootloader_grub2_bls) {
        die 'EXTRABOOTPARAMS not implemented for this bootloader' if $extrabootparams;
        assert_script_run('bootctl set-timeout menu-force') unless $keep_grub_timeout;
    } else {
        die 'Unknown bootloader';
    }

    record_info('REPOS', script_output('zypper lr --url', proceed_on_failure => 1));

    prepare_serial_console if is_ppc64le;
}

sub test_flags {
    return {no_rollback => 1, fatal => 1, milestone => 1};
}

1;
