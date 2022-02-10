# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: transactional-update
# Summary: Host configuration operations (e.g. disable grub timeout,
#              kernel params, etc)
#
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional qw(process_reboot);
use bootloader_setup qw(change_grub_config);

sub run {
    select_console 'root-console';

    # GRUB Configuration
    my $disable_grub_timeout = get_var('DISABLE_GRUB_TIMEOUT');
    my $extrabootparams = get_var('EXTRABOOTPARAMS');
    change_grub_config('=\"[^\"]*', "& $extrabootparams", 'GRUB_CMDLINE_LINUX_DEFAULT') if $extrabootparams;
    change_grub_config('=.*', '=-1', 'GRUB_TIMEOUT') if $disable_grub_timeout;

    if ($disable_grub_timeout or $extrabootparams) {
        record_info('GRUB', script_output('cat /etc/default/grub'));
        assert_script_run('transactional-update grub.cfg');
        process_reboot(trigger => 1);
    }

    # Placeholder for other configurations we might need (not related to grub)
}

sub test_flags {
    return {no_rollback => 1};
}

1;
