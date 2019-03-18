# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: server hostname setup and check
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    set_hostname(get_var('HOSTNAME', 'susetest'));
    if (script_run("ip addr show br0 | grep DOWN") == 0) {
        record_soft_failure('bsc#1061051');
        systemctl('reload network');
        systemctl('status network');
        save_screenshot;
        systemctl('restart network');
        systemctl('status network');
        save_screenshot;
        assert_script_run "ip addr show br0 | grep UP";
        save_screenshot;
    }
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
