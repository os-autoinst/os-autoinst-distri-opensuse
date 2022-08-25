# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1479221: Firefox: HTML5 Video
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - open test html5 video page
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    x11_start_program('xterm');
    script_run('cd ~/data/testwebsites');
    enter_cmd('python3 -m http.server 48080 &');
    assert_script_run 'curl --connect-timeout 5 --max-time 10 --retry 5 --retry-delay 0 --retry-max-time 40 http://localhost:48080/';
    $self->firefox_open_url('http://localhost:48080/html5_video');
    assert_screen('firefox-testvideo');
    $self->exit_firefox;
    enter_cmd('exit');
}
1;
