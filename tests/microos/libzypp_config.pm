# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that zypper configuration is customized for MicroOS
# fate#321764
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "consoletest";
use testapi;
use version_utils qw(is_community_jeos is_jeos is_sle_micro is_microos);
use serial_terminal qw(select_serial_terminal);
use Utils::Logging 'tar_and_upload_log';

my $zypp_conf_dir;

sub run {
    select_serial_terminal();
    $zypp_conf_dir = (is_sle_micro || is_jeos) ? '/etc/zypp/' : '/usr/etc/zypp/';
    unless (is_community_jeos()) {
        assert_script_run 'grep -E -R -x "^solver.onlyRequires ?= ?true" ' . $zypp_conf_dir;
        assert_script_run 'grep -E -R -x "^rpm.install.excludedocs ?= ?yes" ' . $zypp_conf_dir;
    }
    assert_script_run sprintf('grep -E -R -x "^multiversion ?=%s" ' . $zypp_conf_dir, is_jeos ? ' ?provides:multiversion\(kernel\)' : '');
}

sub post_fail_hook {
    my @dirs = ('/usr/etc/zypp', '/etc/zypp');
    my @backup_dirs;
    foreach my $dir (@dirs) {
        push @backup_dirs, $dir if !script_run("test -d $dir");
    }
    tar_and_upload_log("@backup_dirs", "/tmp/zypp_conf_dir.tar.bz2", gzip => 1);
}

1;
