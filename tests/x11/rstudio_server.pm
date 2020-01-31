# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Basic test of RStudio Server
# Maintainer: Dan Čermák <dcermak@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use rstudio;

sub run() {
    mouse_hide(1);
    ensure_installed('rstudio-server');

    x11_start_program('xterm');
    become_root();
    assert_script_run("systemctl start rstudio-server");
    wait_still_screen(1);
    send_key("alt-f4");

    # open R Studio in the browser and don't verify that Firefox actually
    # started via a needle
    x11_start_program("firefox http://localhost:8787", valid => 0);

    # login
    assert_and_click("rstudio_server-login-username");
    # username
    type_string('bernhard');
    # password
    send_key('tab');
    type_password;
    send_key('ret');

    # reject saving the password for bernhard but don't fail in case this doesn't show up
    # definitely check that we're logged in
    assert_screen([qw(rstudio_server-firefox-save-password-prompt rstudio_server-logged-in)]);
    if (match_has_tag('rstudio_server-firefox-save-password-prompt')) {
        click_lastmatch();
        assert_screen('rstudio_server-logged-in');
    }

    rstudio_help_menu(rstudio_mode => "server");

    rstudio_sin_x_plot(rstudio_mode => "server");

    rstudio_create_and_test_new_project(rstudio_mode => "server");

    # log out at last and close firefox
    assert_and_click("rstudio_server-sign-out");
    assert_screen("rstudio_server-login-username");
    send_key('alt-f4');

    # optionally click away the close all tabs window
    assert_screen([qw(rstudio_server-firefox_quit-and-close-tabs generic-desktop)]);
    if (match_has_tag('rstudio_server-firefox_quit-and-close-tabs')) {
        click_lastmatch();
        assert_screen('generic-desktop');
    }
}

sub post_run_hook() {
    rstudio_cleanup_project();
}

1;
