# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

# verify that the disks have a gpt partition label
sub run() {
    assert_script_run("parted -ml | grep '^/dev/.*:gpt:'", fail_msg => 'no gpt partition table found');
}

1;
