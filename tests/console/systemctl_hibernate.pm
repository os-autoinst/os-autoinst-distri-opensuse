# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemctl hibernate
# Summary: Basic functional test for systemct hibernate
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use transactional;

sub run {
    my ($self) = @_;

    my $swap_path = "/var/lib/swap/swapfile";
    my $swap_size = script_output("free -g | awk '/^Mem:/{print \$2}'") || 4;

    select_serial_terminal;
    assert_script_run "mkdir /var/lib/swap";
    assert_script_run "touch $swap_path";
    assert_script_run "chattr +C $swap_path";
    assert_script_run "fallocate -l ${swap_size}G $swap_path";
    assert_script_run "chmod 600 $swap_path";
    assert_script_run "mkswap $swap_path";
    assert_script_run "swapon $swap_path";
    my $swap_id = script_output("findmnt -no UUID -T $swap_path");
    my $swap_offset = script_output("btrfs inspect-internal map-swapfile -r $swap_path");
    assert_script_run "pbl --add-option resume=UUID=$swap_id";
    assert_script_run "pbl --add-option resume_offset=$swap_offset";
    record_info('uuid', $swap_id);
    record_info('offset', $swap_offset);
    record_info('grub config', script_output('cat /etc/default/grub'));
    record_info('swapon', script_output('swapon --show'));
    trup_call "grub.cfg";
    process_reboot(trigger => 1);
    trup_shell "dracut -f --add resume";
    process_reboot(trigger => 1);
    systemctl 'hibernate';
}

1;
