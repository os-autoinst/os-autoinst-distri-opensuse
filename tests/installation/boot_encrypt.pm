# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: splited wait_encrypt_prompt being a single step; harmonized once wait_encrypt_prompt obsoleted
# G-Maintainer: Max Lin <mlin@suse.com>

use strict;
use base "installbasetest";
use utils;

sub run() {
    unlock_if_encrypted;
}

1;

# vim: set sw=4 et:
