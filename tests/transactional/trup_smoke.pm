# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic smoke test to verify all basic transactional update
#           operations work and system can properly boot.
# Maintainer: qa-c team <qa-c@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use transactional;
use Utils::Architectures qw(is_s390x);
use version_utils qw(is_sle_micro);
use serial_terminal;

sub action {
    my ($target, $text, $reboot) = @_;
    $reboot //= 1;
    record_info('TEST', $text);
    trup_call($target);
    check_reboot_changes if $reboot;
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    action('bootloader', 'Reinstall bootloader');
    action('grub.cfg', 'Regenerate grub.cfg');
    action('initrd', 'Regenerate initrd');
    action('kdump', 'Regenerate kdump');
    action('cleanup', 'Run cleanup', 0);
}

1;
