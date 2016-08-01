# LibreOffice tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# Case 1503827 - LibreOffice: Launch application components from system menu

# open desktop mainmenu and click office
sub open_mainmenu() {
    my $self = shift;

    wait_still_screen;
    send_key "alt-f1";
    assert_screen 'test-desktop_mainmenu-1';
    assert_and_click 'mainmenu-office';
    assert_screen 'mainmenu-office-components';
}

# enter 'Activities overview'
sub open_overview() {
    my $self = shift;

    wait_still_screen;
    send_key "super";
    assert_screen 'tracker-mainmenu-launched';
}

sub run() {
    my $self = shift;

    # launch components from mainmenu
    $self->open_mainmenu();
    assert_and_click 'mainmenu-office-lo';    #open lo
    assert_screen 'welcome-to-libreoffice';
    send_key "ctrl-q";                        #close lo

    $self->open_mainmenu();
    assert_and_click 'mainmenu-office-base';    #open base
    assert_screen 'oobase-select-database', 45;
    send_key "ret";
    assert_screen 'oobase-save-database';
    send_key "ret";
    assert_screen 'oobase-save-database-prompt';
    type_string "testdatabase";
    send_key "ret";
    assert_screen 'oobase-launched';
    send_key "ctrl-q";                          #close base

    # clean the test database file
    x11_start_program("xterm");
    assert_script_run "find /home/$username -name testdatabase.odb | xargs rm";
    send_key 'alt-f4';

    $self->open_mainmenu();
    assert_and_click 'mainmenu-office-calc';    #open calc
    assert_screen 'test-oocalc-1';
    send_key "ctrl-q";                          #close calc

    $self->open_mainmenu();
    assert_and_click 'mainmenu-office-draw';    #open draw
    assert_screen 'oodraw-launched';
    send_key "ctrl-q";                          #close draw

    $self->open_mainmenu();
    assert_and_click 'mainmenu-office-impress';    #open impress
    assert_screen 'ooimpress-launched';
    send_key "ctrl-q";                             #close impress

    $self->open_mainmenu();
    assert_and_click 'mainmenu-office-writer';     #open writer
    assert_screen 'test-ooffice-1';
    send_key "ctrl-q";                             #close writer

    # launch components from Activities overview
    $self->open_overview();
    type_string "base";                            #open base
    assert_screen 'overview-office-base';
    send_key "ret";
    assert_screen 'oobase-select-database', 45;
    send_key "ret";
    assert_screen 'oobase-save-database';
    send_key "ret";
    assert_screen 'oobase-save-database-prompt';
    type_string "testdatabase";
    send_key "ret";
    assert_screen 'oobase-launched';
    send_key "ctrl-q";                             #close base

    # clean the test database file
    x11_start_program("xterm");
    assert_script_run "find /home/$username -name testdatabase.odb | xargs rm";
    send_key 'alt-f4';

    $self->open_overview();
    type_string "calc";                            #open calc
    assert_screen 'overview-office-calc';
    send_key "ret";
    assert_screen 'test-oocalc-1';
    send_key "ctrl-q";                             #close calc

    $self->open_overview();
    type_string "draw";                            #open draw
    assert_screen 'overview-office-draw';
    send_key "ret";
    assert_screen 'oodraw-launched';
    send_key "ctrl-q";                             #close draw

    $self->open_overview();
    type_string "impress";                         #open impress
    assert_screen 'overview-office-impress';
    send_key "ret";
    assert_screen 'ooimpress-launched';
    send_key "ctrl-q";                             #close impress

    $self->open_overview();
    type_string "writer";                          #open writer
    assert_screen 'overview-office-writer';
    send_key "ret";
    assert_screen 'test-ooffice-1';
    assert_and_click 'ooffice-writing-area', 'left', 10;
    send_key "ctrl-q";                             #close writer
}

1;
# vim: set sw=4 et:
