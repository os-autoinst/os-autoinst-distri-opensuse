# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Disable firewall in HA tests
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "hacluster";
use strict;
use testapi;

sub run() {
    assert_script_run
      "systemctl -q is-active SuSEfirewall2 && systemctl disable SuSEfirewall2; systemctl stop SuSEfirewall2";
}

sub test_flags {
    return {fatal => 1};
}

1;
