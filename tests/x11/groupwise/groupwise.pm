# Groupwise tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Groupwise client check
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;

sub run() {
    select_console('root-console');
    pkcon_quit;

    # add repository and install groupwise
    zypper_call("ar http://download.suse.de/ibs/SUSE:/Factory:/Head:/Internal/standard/ groupwise_repo");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("in novell-groupwise-gwclient", exitcode => [0, 102, 103]);
    zypper_call("rr groupwise_repo");
    save_screenshot;

    select_console 'x11';
    x11_start_program('groupwise');
    send_key "alt-f4";
}

1;
