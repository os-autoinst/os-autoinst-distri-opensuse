# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check no more updates are available in the queue after they have
#   been previously applied
# Maintainer: mkravec <mkravec@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'ensure_serialdev_permissions';

sub run {
    select_console 'root-console';
    ensure_serialdev_permissions;
    # pkcon returns non-zero code (5 'Nothing useful was done.')
    # so don't validate exit code and just match
    script_run "pkcon get-updates | tee /dev/$serialdev", 0;
    die "pkcon get-updates seems to contain updates, whereas was just updated" unless wait_serial('There are no updates');
}

sub test_flags {
    return {fatal => 1};
}

1;
