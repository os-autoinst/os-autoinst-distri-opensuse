# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: plasma-browser-integration MozillaFirefox
# Summary: Test plasma-browser-integration in firefox
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    ensure_installed 'plasma-browser-integration';

    # If the host was just installed, a logout would be necessary. Work around that.
    x11_start_program('qdbus-qt5 org.kde.kded5 /kded org.kde.kded5.loadModule browserintegrationreminder', valid => 0);

    # Start without parameters, otherwise the reminder does not trigger. Add a space to avoid autocomplete.
    x11_start_program(' firefox', valid => 0);
    # Unfortunately that would result in a 100s delay waiting for a still screen here as
    # the default start page is animated, so skip handling the dialog. It's not expected here anyway.
    # $self->firefox_check_default();
    $self->firefox_check_popups();

    # Click on the reminder, it might take a while to appear
    assert_and_click('plasma-browser-integration-reminder');
    # Click "Add to Firefox". Longer timeout as loading can take a while
    assert_and_click('plasma-browser-integration-install', timeout => 180);
    # Confirm installation
    assert_and_click('plasma-browser-integration-install-confirm');
    # Ack the "has been added" popup
    assert_and_click('plasma-browser-integration-install-gotit');

    # Open just the YT player, the whole /watch page is too big and dynamic
    $self->firefox_open_url('https://www.youtube.com/embed/A3FjpB4JdvM');

    # Play the video
    assert_and_click('plasma-browser-integration-video-play');

    # Open the MPRIS dialog, needs some tries as the video causes load
    my $counter = 3;
    while ($counter-- > 0) {
        assert_and_click('plasma-mpris-playing');
        last if check_screen('plasma-mpris-pause', 20);
    }

    $counter = 3;
    while ($counter-- > 0) {
        # Pause using the button in the applet
        assert_and_click('plasma-mpris-pause');
        # Verify that the applet noticed that
        last if check_screen('plasma-mpris-paused', 5);
    }
    assert_screen('plasma-mpris-paused');
    # Verify that the video is paused and unpause it
    assert_and_click('plasma-browser-integration-video-unpause');
    # Verify that the applet noticed that
    assert_screen('plasma-mpris-playing');

    # Close firefox again. Can't use exit_firefox_common here as it expects xterm.
    send_key_until_needlematch([qw(firefox-save-and-quit generic-desktop)], 'alt-f4', 4, 30);
    if (match_has_tag('firefox-save-and-quit')) {
        # confirm "save&quit"
        send_key('ret');
        assert_screen('generic-desktop');
    }
}

1;
