# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Install kiwi templates for JeOS
# Maintainer: Martin Loviska <mloviska@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_leap);
use utils qw(zypper_call);

sub run {
    select_console 'root-console';
    my $rpm = is_sle('<15-SP2') ? 'kiwi-templates-SLES15-JeOS' : 'kiwi-templates-JeOS';
    zypper_call "in $rpm";
    assert_script_run "rpm -ql $rpm";
}

1;
