# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Disable GNOME Software wanting to auto-update the system
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    x11_start_program('xterm');
    type_string "gsettings set org.gnome.software download-updates false\n";
    save_screenshot;
    type_string "exit\n";
}

1;
