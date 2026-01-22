# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that zypper configuration is customized for MicroOS
# fate#321764
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "consoletest";
use testapi;
use version_utils qw(is_community_jeos is_jeos);
use serial_terminal qw(select_serial_terminal);

my $zypp_conf;

sub run {
    select_serial_terminal();
    my $ret = script_run('test -f /etc/zypp/zypp.conf');
    $zypp_conf = !$ret ? '/etc/zypp/zypp.conf' : '/usr/etc/zypp/zypp.conf';
    unless (is_community_jeos()) {
        assert_script_run 'grep -E -x "^solver.onlyRequires ?= ?true" ' . $zypp_conf;
        assert_script_run 'grep -E -x "^rpm.install.excludedocs ?= ?yes" ' . $zypp_conf;
    }
    assert_script_run sprintf('grep -E -x "^multiversion ?=%s" ' . $zypp_conf, is_jeos ? ' ?provides:multiversion\(kernel\)' : '');
}

sub post_fail_hook {
    upload_logs $zypp_conf;
}

1;
