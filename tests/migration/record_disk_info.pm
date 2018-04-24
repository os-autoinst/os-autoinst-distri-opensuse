# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Record the disk usage before migration
# Maintainer: Qingming Su <qmsu@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration 'record_disk_info';

sub run {
    select_console 'root-console';

    # The disk space usage info would be helpful to debug upgrade failure
    # with disk exhausted error
    record_disk_info;
}

1;
