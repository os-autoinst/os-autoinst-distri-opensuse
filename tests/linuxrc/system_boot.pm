# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;
use linuxrc;

#
# bsc#906990 [linuxrc] add "Boot Linux" to installation media
# Added in linuxrc-5.0.44
#

sub run() {
    my $self = shift;

    $self->linuxrc::wait_for_bootmenu();

    $self->linuxrc::boot_with_parameters("SystemBoot=1");
    assert_screen("linuxrc-system_boot-select-a-system-to-boot", 60);

    # Press [Enter] till the last dialog for booting appears
    send_key_until_needlematch "linuxrc-system-boot-kernel-options", "ret", 8;

    # Confirm booting
    diag "Booting the installed system now...";
    send_key "ret", 0;

    # Wait for the system to boot
    assert_screen("displaymanager", 60);
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;

# vim: set sw=4 et:
