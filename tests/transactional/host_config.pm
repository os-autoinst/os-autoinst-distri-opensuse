# SUSE's openQA tests
#
# Copyright 2020-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Host configuration operations (e.g. disable grub timeout,
#              kernel params, etc)
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use transactional qw(process_reboot);
use bootloader_setup qw(change_grub_config);
use utils qw(ensure_ca_certificates_suse_installed zypper_call);
use version_utils qw(is_bootloader_grub2 is_bootloader_sdboot);
use serial_terminal 'prepare_serial_console';

sub run {
    select_console 'root-console';

    # Bootloader configuration
    my $extrabootparams = get_var('EXTRABOOTPARAMS');
    my $keep_grub_timeout = get_var('KEEP_GRUB_TIMEOUT');

    if (is_bootloader_grub2) {
        change_grub_config('=\"[^\"]*', "& $extrabootparams", 'GRUB_CMDLINE_LINUX_DEFAULT') if $extrabootparams;
        $keep_grub_timeout or change_grub_config('=.*', '=-1', 'GRUB_TIMEOUT');

        if (!$keep_grub_timeout or $extrabootparams) {
            record_info('GRUB', script_output('cat /etc/default/grub'));
            assert_script_run('transactional-update grub.cfg');
            ensure_ca_certificates_suse_installed if get_var('HOST_VERSION');
            process_reboot(trigger => 1);
        }
    } elsif (is_bootloader_sdboot) {
        die 'EXTRABOOTPARAMS not implemented for this bootloader' if $extrabootparams;
        assert_script_run('bootctl set-timeout menu-force') unless $keep_grub_timeout;
    } else {
        die 'Unknown bootloader';
    }

    record_info('REPOS', script_output('zypper lr --url', proceed_on_failure => 1));

    prepare_serial_console;
}

sub test_flags {
    return {no_rollback => 1, fatal => 1, milestone => 1};
}

1;
