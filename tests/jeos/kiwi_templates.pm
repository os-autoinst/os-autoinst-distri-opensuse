# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
