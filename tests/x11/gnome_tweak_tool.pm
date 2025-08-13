# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-tweaks gnome-tweak-tool
# Summary: GNOME Tweak Tool
# - Launch gnome-tweaks and check
# - In case of fail, try gnome-tweak-tool
# - Open fonts dialog
# - Close gnome tweak tool
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use testapi;

sub run {
    my ($self) = shift;
    $self->start_gnome_tweak_tool;

    assert_and_click "gnome-tweak-tool-fonts";
    assert_screen "gnome-tweak-tool-fonts-dialog";
    send_key "alt-f4";
}

1;
