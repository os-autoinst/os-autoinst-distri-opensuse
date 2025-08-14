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
use x11utils 'default_gui_terminal';

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    x11_start_program(default_gui_terminal());
    script_run('cd ~/data/testwebsites');
    enter_cmd('python3 -m http.server 48080 &');
    # curl provides an adequate time window for the server to run
    assert_script_run 'curl --connect-timeout 5 --max-time 10 --retry-connrefused 5 --retry-delay 1 --retry-max-time 40 http://localhost:48080/';
    send_key 'alt-tab';    #Switch to firefox
    $self->firefox_open_url('http://localhost:48080/html5_video', assert_loaded_url => 'firefox-testvideo');
    $self->exit_firefox;
    send_key_until_needlematch("generic-desktop", "alt-f4", 6, 5);
}
1;
