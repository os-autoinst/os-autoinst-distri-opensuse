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
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox;

    # html
    send_key "alt-d";
    type_string "/usr/share/w3m/w3mhelp.html\n";
    $self->firefox_check_popups;
    assert_screen('firefox-local_files-html', 60);

    # wav
    send_key "alt-d";
    type_string "/usr/share/sounds/alsa/test.wav\n";
    $self->firefox_check_popups;
    assert_screen('firefox-local_files-wav', 60);
    send_key "esc";

    # so
    send_key "alt-d";
    type_string "/usr/lib/libnss3.so\n";
    $self->firefox_check_popups;
    assert_screen('firefox-local_files-so', 60);
    send_key "esc";

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
