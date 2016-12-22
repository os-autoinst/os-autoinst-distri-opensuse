# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Unlock encrypted partitions during bootup
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use base "installbasetest";
use utils;
use testapi qw(get_var record_soft_failure);

sub run() {
    if (get_var('ENCRYPT_ACTIVATE_EXISTING') and !get_var('ENCRYPT_FORCE_RECOMPUTE')) {
        if (sle_version_at_least('12-SP4') or sle_version_at_least('13')) {
            record_soft_failure('fate#321208: activating existing encrypted volume does *not* yield an encrypted system if not forcing');
        }
        return;
    }
    unlock_if_encrypted;
}

1;

# vim: set sw=4 et:
