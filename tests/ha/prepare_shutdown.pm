# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: crmsh
# Summary: Do some actions prior to the shutdown
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run {
    # We need to stop the cluster stack to avoid fencing during shutdown
    assert_script_run("crm cluster stop");
}

1;
