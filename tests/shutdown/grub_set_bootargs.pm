# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Remove quiet kernel option
# - On SLE12PS2 and aarch64, run commands and wait for screen change
# - Otherwise:
#   - Load grub variables from /etc/default/grub
#   - Remove "quiet" from $GRUB_CMDLINE_LINUX_DEFAULT
#   - If FIPS_ENABLED is set, add fips=1 to new grub command line
#   - If encryption is enabled, add "boot=<boot device>" to grub command line
#   - Apply all changes by running: "grub2-mkconfig -o /boot/grub2/grub.cfg"
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'y2_installbase';
use testapi;
use Utils::Architectures;
use serial_terminal qw(select_serial_terminal prepare_serial_console);

sub run {
    prepare_serial_console();
    select_serial_terminal();
    my @cmds;
    push @cmds, "source /etc/default/grub";
    push @cmds, 'new_cmdline=`echo $GRUB_CMDLINE_LINUX_DEFAULT | sed \'s/\(^\| \)quiet\($\| \)/ /\'`';
    if (get_var("FIPS_ENABLED")) {
        push @cmds, 'new_cmdline="$new_cmdline fips=1"';
        if (get_var("ENCRYPT") && !get_var("FULL_LVM_ENCRYPT")) {
            push @cmds, 'new_cmdline="$new_cmdline boot=$(df /boot | tail -1 | cut -d" " -f1)"';
        }
    }
    push @cmds, 'sed -i "s#GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\"#GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"#" /etc/default/grub';
    push @cmds, 'grub2-mkconfig -o /boot/grub2/grub.cfg';

    # Slow type for 12-SP2 aarch64 image creation test to try to avoid filling up the key event queue
    for my $cmd (@cmds) {
        if (is_aarch64 && check_var('VERSION', '12-SP2')) {
            enter_cmd $cmd . " ; echo cmd-\$? > /dev/$testapi::serialdev", wait_screen_change => 1;
            wait_serial "cmd-0";
        }
        else {
            script_run $cmd;
        }
    }
}

1;
