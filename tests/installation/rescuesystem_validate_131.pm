# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that there is access to the local hard disk from rescue system
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    type_string "mount /dev/vda2 /mnt\n";
    type_string "cat /mnt/etc/SUSE-brand > /dev/$serialdev\n";
    wait_serial("VERSION = 13.1", 2) || die "Not SUSE-brand found";
}

sub test_flags {
    return {fatal => 1};
}

1;
