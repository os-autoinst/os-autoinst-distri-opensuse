# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure the serial device can be used for os-autoinst testapi calls
#   as non-privileged user. This is a prerequisite for every test calling
#   commands from the testapi, for example "script_run".
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'consoletest';
use testapi;
use utils 'ensure_serialdev_permissions';
use strict;

sub run {
    ensure_serialdev_permissions;
}

sub test_flags {
    return {fatal => 1};
}

1;
