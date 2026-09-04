# LibreOffice tests
#
# Copyright 2016-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice libreoffice-base libreoffice-calc libreoffice-draw
# libreoffice-impress libreoffice-writer
# Summary: Case 1503827 - LibreOffice: Launch application components from system menu
# - Use Gnome Activities to launch LibreOffice Base, Calc, Draw, Impress and Writer
#   by clicking on the Icons
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use Mojo::Base 'x11test';
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);
use x11utils qw(default_gui_terminal close_gui_terminal);

sub select_base_and_cleanup {
    assert_screen 'oobase-select-database', 45;
    if (check_screen 'oobase-database-empty') {
        # this is for libreoffice 6.2.x
        send_key "tab";
        send_key "tab";
        send_key "up";
    }
    send_key "ret";
    assert_screen 'oobase-save-database';
    send_key "alt-f";    # "Finish" button
    assert_screen 'oobase-save-database-prompt';
    type_string "testdatabase";
    send_key "ret";
    assert_screen 'oobase-launched';
    send_key "ctrl-q";    #close base

    # clean the test database file
    x11_start_program(default_gui_terminal);
    assert_script_run "find /home/$username -name testdatabase.odb | xargs rm";
    close_gui_terminal;
}

sub run {
    my $self = shift;

    $self->libreoffice_start_program("oobase", from_overview => 1);
    select_base_and_cleanup;

    $self->libreoffice_start_program("oocalc", from_overview => 1);
    send_key "ctrl-q";    #close calc

    $self->libreoffice_start_program("oodraw", from_overview => 1);
    send_key "ctrl-q";    #close draw

    $self->libreoffice_start_program("ooimpress", from_overview => 1);

    assert_screen [qw(ooimpress-select-a-template ooimpress-select-template-nofocus ooimpress-launched)];
    if (match_has_tag 'ooimpress-select-a-template') {
        send_key 'alt-f4';    # close impress template window
        assert_screen 'ooimpress-launched';
    }
    send_key "ctrl-q";    #close impress

    $self->libreoffice_start_program("oowriter", from_overview => 1);
    assert_and_click('ooffice-writing-area', timeout => 10);
    send_key "ctrl-q";    #close writer
}

1;
