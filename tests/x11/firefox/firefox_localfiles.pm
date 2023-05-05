# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1436075 Firefox: Open local file with various types
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open "/usr/share/w3m/w3mhelp.html" and check result
# - Open "/usr/share/sounds/alsa/test.wav" and check result
# - open "/usr/lib64/libnss3.so" and check result
# - Exit firefox
# Maintainer: wnereiz <wnereiz@github>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    # html
    $self->firefox_open_url('/usr/share/w3m/w3mhelp.html', assert_loaded_url => 'firefox-urls_protocols-local');

    # wav
    $self->firefox_open_url('/usr/share/sounds/alsa/test.wav', assert_loaded_url => 'firefox-local_files-wav');
    send_key 'esc';

    # so
    $self->firefox_open_url('/usr/lib64/libnss3.so', assert_loaded_url => 'firefox-local_files-so');
    send_key "esc";

    $self->exit_firefox;
}
1;
