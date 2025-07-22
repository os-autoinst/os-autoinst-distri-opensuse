# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: glib2-tools
# Summary: Disable GNOME Software wanting to auto-update the system
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    x11_start_program('xterm');
    enter_cmd "gsettings set org.gnome.software download-updates false";
    save_screenshot;
    enter_cmd "exit";
}

1;
