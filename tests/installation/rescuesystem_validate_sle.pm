# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    # Check that there is access to the local hard disk
    type_string "mount /dev/vda2 /mnt && cat /mnt/etc/SuSE-release > /dev/$serialdev\n";
    wait_serial("SUSE Linux Enterprise Server", 10) || die "Not SLES found";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
