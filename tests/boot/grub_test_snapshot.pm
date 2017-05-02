# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select 'snapshot' boot option from grub menu
# Maintainer: okurz <okurz@suse.de>

use strict;
use base "basetest";
use testapi;
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

sub run {
    select_console 'root-console';
    type_string "reboot\n";
    reset_consoles;
    $self->wait_for_boot_menu(bootloader_time => 200);
    boot_into_snapshot;
}
sub test_flags {
    return {fatal => 1};
}
1;
# vim: set sw=4 et:
