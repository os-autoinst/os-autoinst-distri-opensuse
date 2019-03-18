# SUSE's openQA tests
#
# Copyright Â© 2009-2013 Bernhard M. Wiedemann
# Copyright Â© 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Summary: select and boot RT in grub menu
# Maintainer: Martin Loviska <mloviska@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup 'boot_grub_item';

sub run() {
    my $self = shift;
    $self->boot_grub_item(2, 3);
    $self->wait_boot(bootloader_time => 120);
}

1;

# vim: set sw=4 et:
