# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Update grub for XEN test
# - Replace <unit0> with <unit1> in line of initial with <GRUB_SERIAL_COMMAND=> in /etc/default/grub, using sed.
# - Add <parameter> into /etc/default/grub, using sed.
# - regenerate /boot/grub2/grub.cfg with grub2-mkconfig
# - upload configuration
# Maintainer: An Long <lan@suse.com>

use warnings;
use strict;
use base "opensusebasetest";
use testapi;
use utils;
use bootloader_setup qw(replace_grub_cmdline_settings add_grub_cmdline_settings);

sub run {
    my $self = shift;

    my $xen_boot_args = get_var('XEN_BOOT_ARGS', 'ucode=scan dom0_max_vcpus=8 dom0_mem=8G,max:8G');

    unless (get_var('KEEP_XEN_SERIAL')) {
        replace_grub_cmdline_settings('unit=0', 'unit=1', search => '^GRUB_SERIAL_COMMAND=');
    }
    add_grub_cmdline_settings($xen_boot_args, update_grub => 1, search => '^GRUB_CMDLINE_XEN_DEFAULT=');
}

1;
