# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check if release notes are available from URL during installation
# Maintainer: QA SLE YaST <qa-sle-yast@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use Utils::Backends;
use serial_terminal 'select_serial_terminal';

sub run {
    assert_screen('release-notes-button');
    select_console 'install-shell';
    enter_cmd "zgrep -oh \"Got release notes.*\" /var/log/YaST2/y2log*";
    assert_screen [qw(got-releasenotes-RPM got-releasenotes-URL)];
    unless (match_has_tag 'got-releasenotes-URL') {
        record_soft_failure('bsc#1190711 - Release notes source does NOT match expectations or not found in YaST logs, expected source: URL');
    }
    reset_consoles;
    select_console 'installation';
}

1;
