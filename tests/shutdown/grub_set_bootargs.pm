# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Remove quiet kernel option
# G-Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    select_console('root-console');
    script_run "source /etc/default/grub";
    script_run 'new_cmdline=`echo $GRUB_CMDLINE_LINUX_DEFAULT | sed \'s/\(^\| \)quiet\($\| \)/ /\'`';
    script_run
      'sed -i "s#GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\"#GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"#" /etc/default/grub';
    script_run 'grub2-mkconfig -o /boot/grub2/grub.cfg';
}

1;

# vim: set sw=4 et:
