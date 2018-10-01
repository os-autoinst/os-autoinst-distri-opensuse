# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436075 Firefox: Open local file with various types
# Maintainer: wnereiz <wnereiz@github>

use strict;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    # html
    $self->firefox_open_url('/usr/share/w3m/w3mhelp.html');
    assert_screen('firefox-local_files-html', 60);

    # wav
    $self->firefox_open_url('/usr/share/sounds/alsa/test.wav');
    assert_screen('firefox-local_files-wav', 60);

    # so
    $self->firefox_open_url('/usr/lib64/libnss3.so');
    assert_screen('firefox-local_files-so', 60);
    send_key "esc";

    $self->exit_firefox;
}
1;
