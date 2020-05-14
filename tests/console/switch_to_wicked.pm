# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Switch from NetworkManager to wicked.
# Maintainer: QA SLE Functional YaST <qa-sle-yast@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run 'systemctl disable NetworkManager --now';
    assert_script_run 'systemctl enable wicked --now';
    assert_script_run qq{systemctl status wickedd.service | grep \"active \(running\)\"};
}

1;
