# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Unlock encrypted partitions during bootup after the bootloader
#   passed, e.g. from plymouth
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils;
use testapi qw(get_var record_info);

sub run {
    if (get_var('ENCRYPT_ACTIVATE_EXISTING') and !get_var('ENCRYPT_FORCE_RECOMPUTE')) {
        record_info 'bsc#993247 https://fate.suse.com/321208', 'activated encrypted partition will not be recreated as encrypted';
        return;
    }
    unlock_if_encrypted(check_typed_password => 1);
}

1;

