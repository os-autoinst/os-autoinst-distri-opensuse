# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Update grub to show grub in com2 for XEN test
# - Replace <unit0> with <unit1> in line of initial with <GRUB_SERIAL_COMMAND=> in /etc/default/grub, using sed.
# - regenerate /boot/grub2/grub.cfg with grub2-mkconfig
# - upload configuration
# Maintainer: An Long <lan@suse.com>

use warnings;
use strict;
use base "opensusebasetest";
use testapi;
use utils;
use bootloader_setup 'replace_grub_cmdline_settings';

sub run {
    my $self = shift;

    replace_grub_cmdline_settings('unit=0', 'unit=1', update_grub => 1, search => '^GRUB_SERIAL_COMMAND=');
}

1;
