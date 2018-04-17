# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select 'snapshot' boot option from grub menu
# Maintainer: dmaiocchi <dmaiocchi@suse.com>

use strict;
use base "opensusebasetest";
use testapi;
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

sub run {
    my $self = shift;

    select_console 'root-console';
    type_string "reboot\n";
    reset_consoles;
    $self->handle_uefi_boot_disk_workaround if (get_var('MACHINE') =~ /aarch64/ && get_var('UEFI') && get_var('BOOT_HDD_IMAGE'));
    assert_screen 'grub2', 200;
    stop_grub_timeout;
    boot_into_snapshot;
}
sub test_flags {
    return {fatal => 1};
}
1;
