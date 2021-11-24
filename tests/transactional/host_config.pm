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

sub run {
    select_console 'root-console';

    # GRUB Configuration
    my $disable_grub_timeout = get_var('DISABLE_GRUB_TIMEOUT');
    my $extrabootparams = get_var('EXTRABOOTPARAMS');
    assert_script_run("sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=-1/' /etc/default/grub") if $disable_grub_timeout;
    assert_script_run("sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*/& $extrabootparams/' /etc/default/grub") if $extrabootparams;

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
