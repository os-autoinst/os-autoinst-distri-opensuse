# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that zypper configuration is customized for CASP
# poo#321764
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    assert_script_run 'grep -x "solver.onlyRequires = true" /etc/zypp/zypp.conf';
    assert_script_run 'grep -x "rpm.install.excludedocs = yes" /etc/zypp/zypp.conf';
    assert_script_run 'grep -x "multiversion =" /etc/zypp/zypp.conf';
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
