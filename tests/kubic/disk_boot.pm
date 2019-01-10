# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot from disk and login into Kubic
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

use caasp "microos_login";

sub run {
    shift->wait_boot(bootloader_time => 300);
    microos_login;
}

sub test_flags {
    return {fatal => 1};
}

1;

