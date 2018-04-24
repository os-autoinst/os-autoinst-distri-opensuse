# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Remove LTSS product before migration
# Maintainer: Qingming Su <qmsu@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration 'remove_ltss';

sub run {
    select_console 'root-console';

    # Migration with LTSS is not possible, remove it before upgrade
    remove_ltss;
}

1;
