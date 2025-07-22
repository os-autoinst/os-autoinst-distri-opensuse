# Shotwell tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: shotwell
# Summary: Import and display pictures into shotwell
# Maintainer: Zhaocong Jia <zcjia@suse.com> Grace Wang <grace.wang@suse.com>

use base "x11test";
use testapi;

# Case 1503962 - Shotwell: Import image files

sub run {
    my $self = shift;
    my @pictures = qw(shotwell_test.jpg shotwell_test.png);

    $self->start_shotwell();

    # Import two test pictures into the library
    $self->import_pictures(\@pictures);

    # Display the first picture
    send_key "alt-home";
    send_key "ret";
    assert_screen 'shotwell-display-picture';
    send_key "esc";
    send_key "ctrl-q";    # Quit shotwell

    # Clean shotwell's library then remove the test pictures
    $self->clean_shotwell();
}

1;
