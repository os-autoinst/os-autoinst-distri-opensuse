# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: gnome-tweaks gnome-tweak-tool
# Summary: GNOME Tweak Tool
# - Launch gnome-tweaks and check
# - In case of fail, try gnome-tweak-tool
# - Open fonts dialog
# - Close gnome tweak tool
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = shift;
    $self->start_gnome_tweak_tool;

    assert_and_click "gnome-tweak-tool-fonts";
    assert_screen "gnome-tweak-tool-fonts-dialog";
    send_key "alt-f4";
}

1;
