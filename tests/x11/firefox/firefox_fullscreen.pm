# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479413: Firefox: Full Screen Browsing

# Summary: Case#1479413: Firefox: Full Screen Browsing
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;

    $self->start_firefox_with_profile;

    $self->firefox_open_url('file:///usr/share/w3m/w3mhelp.html');
    assert_screen('firefox-fullscreen-page');

    send_key "f11";
    assert_screen('firefox-fullscreen-enter', 90);

    sleep 1;
    send_key "f11";
    assert_screen('firefox-fullscreen-page', 90);

    $self->exit_firefox;
}
1;
