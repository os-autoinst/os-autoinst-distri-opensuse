# Yomi's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Stop QEMU
# Maintainer: Alberto Planas <aplanas@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    script_run 'pkill -9 qemu';
    script_run 'rm hda.qcow2';
}

1;
