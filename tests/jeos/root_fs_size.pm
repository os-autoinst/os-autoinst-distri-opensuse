# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check root filesystem size
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run {
    assert_script_run 'df --output=size --block-size=G / | sed 1d | tr -d " " | grep ^24G$';
}

1;
