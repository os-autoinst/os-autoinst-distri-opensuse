# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that zypper configuration is customized for MicroOS
# fate#321764
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use version_utils qw(is_jeos);

sub run {
    assert_script_run 'egrep -x "^solver.onlyRequires ?= ?true" /etc/zypp/zypp.conf';
    assert_script_run 'egrep -x "^rpm.install.excludedocs ?= ?yes" /etc/zypp/zypp.conf';
    assert_script_run sprintf('egrep -x "^multiversion ?=%s" /etc/zypp/zypp.conf', is_jeos ? ' ?provides:multiversion\(kernel\)' : '');
}

sub post_fail_hook {
    upload_logs '/etc/zypp/zypp.conf';
}

1;
