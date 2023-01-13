# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that release notes come from RPM file during installation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    assert_screen('release-notes-button');
    send_key('ctrl-shift-alt-x');
    assert_screen('yast-xterm');
    enter_cmd "zgrep -oh \"Got release notes.*\" /var/log/YaST2/y2log*";
    assert_screen [qw(got-releasenotes-RPM got-releasenotes-URL)];
    unless (match_has_tag 'got-releasenotes-RPM') {
        die('Release notes source does NOT match expectations or not found in YaST logs, expected source: RPM');
    }
    enter_cmd "exit";
}

1;
