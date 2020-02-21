# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479221: Firefox: HTML5 Video
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open "youtube.com/html5" and check result
# - Open "youtube.com/watch?v=Z4j5rJQMdOU" and check result
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;
    $self->firefox_open_url('youtube.com/watch?v=Z4j5rJQMdOU');
    assert_and_click('firefox-flashplayer-video_loaded');
    assert_screen("firefox-testvideo");
    $self->exit_firefox;
}
1;
