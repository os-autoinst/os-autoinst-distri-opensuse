# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Force the font DPI to 96, needed for Wayland
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'x11test';
use strict;
use testapi;

sub run {
    x11_start_program('kcmshell5 fonts');      # Start the fonts KCM
    assert_and_click 'kcm_fonts_force_dpi';    # Check force DPI checkbox (96 is preselected)
    send_key 'alt-o';                          # Save and close the dialog
}

1;
# vim: set sw=4 et:
