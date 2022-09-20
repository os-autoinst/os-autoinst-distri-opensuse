# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox: Externally handled content (Case#1436064)
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open url
# "http://mirror.bej.suse.com/dist/install/SLP/SLE-12-SP3-Server-GM/x86_64/dvd1/"
# and check
# - Search for "license.tar.gz"
# - Select open "license.tar.gz"
# - Check if file is handled correctly
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    $self->start_firefox_with_profile;
    $self->firefox_open_url('http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-GM/x86_64/DVD1/');

    assert_screen('firefox-extcontent-pageloaded');

    send_key "/";
    sleep 1;
    enter_cmd "license.tar.gz";

    assert_screen ['firefox-extcontent-opening', 'firefox-extcontent-downloaded'], 30;
    # If firefox does not prompt us with the opening window we need to double click the downloaded file
    if (match_has_tag 'firefox-extcontent-downloaded') {
        assert_and_dclick('firefox-extcontent-downloaded');
    } else {
        send_key "alt-o";
        sleep 1;
        send_key "ret";
    }

    assert_screen(is_sle('15+') ? 'firefox-extcontent-nautils' : 'firefox-extcontent-archive_manager');

    send_key "ctrl-q";

    $self->exit_firefox;
}
1;
