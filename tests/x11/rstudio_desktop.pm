# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Basic test of RStudio Desktop
# Maintainer: Dan Čermák <dcermak@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use rstudio;

sub run {
    mouse_hide(1);
    ensure_installed('rstudio-desktop');

    x11_start_program('rstudio', target_match => 'rstudio_desktop-main-window');

    rstudio_help_menu(rstudio_mode => "desktop");

    rstudio_sin_x_plot(rstudio_mode => "desktop");

    rstudio_create_and_test_new_project(rstudio_mode => "desktop");

    # bye-bye
    send_key('alt-f4');
}

sub post_run_hook() {
    rstudio_cleanup_project();
}

1;
