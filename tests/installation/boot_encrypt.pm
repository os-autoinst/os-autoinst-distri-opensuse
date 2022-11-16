# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Unlock encrypted partitions during bootup after the bootloader
#   passed, e.g. from plymouth
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils;
use testapi qw(check_var get_var record_info);

sub run {
    unlock_if_encrypted(check_typed_password => 1);
}

1;

