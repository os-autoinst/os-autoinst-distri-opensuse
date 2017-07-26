# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Sanity checks of wicked
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils 'systemctl';

sub run {
    systemctl('stop wicked.service');
    assert_script_run('! systemctl is-active wicked.service');
    systemctl('is-active wickedd');
    assert_script_run('for dev in /sys/class/net/!(lo); do grep "down" $dev/operstate || (echo "device $dev is not down" && exit 1) ; done');
}

1;
