# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Remove quiet kernel option
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    select_console('root-console');
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
        if (check_var('ARCH', 'aarch64') && check_var('VERSION', '12-SP2')) {
            type_string $cmd . " ; echo cmd-\$? > /dev/$testapi::serialdev\n", wait_screen_change => 1;
            wait_serial "cmd-0";
        }
        else {
            script_run $cmd;
        }
    }
}

1;

