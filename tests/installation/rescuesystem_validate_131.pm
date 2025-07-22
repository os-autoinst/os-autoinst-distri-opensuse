# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that there is access to the local hard disk from rescue system
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "opensusebasetest";
use testapi;

sub run {
    enter_cmd "mount /dev/vda2 /mnt";
    enter_cmd "cat /mnt/etc/SUSE-brand > /dev/$serialdev";
    wait_serial("VERSION = 13.1", 2) || die "Not SUSE-brand found";
}

sub test_flags {
    return {fatal => 1};
}

1;
