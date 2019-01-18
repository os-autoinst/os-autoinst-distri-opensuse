# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that disks have a GPT partition label
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;

# verify that the disks have a gpt partition label
sub run {
    assert_script_run("parted -mls | grep '^/dev/.*:gpt:'", fail_message => 'no gpt partition table found');
}

1;
