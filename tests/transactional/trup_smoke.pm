# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic smoke test to verify all basic transactional update
#           operations work and system can properly boot.
# Maintainer: qa-c team <qa-c@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use transactional;


sub action {
    my ($target, $text, $reboot) = @_;
    $reboot //= 1;
    record_info('TEST', $text);
    trup_call($target);
    check_reboot_changes if $reboot;
}

sub run {
    my ($self) = @_;

    select_console 'root-console';

    action('bootloader', 'Reinstall bootloader');
    action('grub.cfg', 'Regenerate grub.cfg');
    action('initrd', 'Regenerate initrd');
    action('kdump', 'Regenerate kdump');
    action('cleanup', 'Run cleanup', 0);
}

1;
