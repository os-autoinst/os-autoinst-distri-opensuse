# LibreOffice tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libreoffice libreoffice-base libreoffice-calc libreoffice-draw
# libreoffice-impress libreoffice-writer
# Summary: Case 1503827 - LibreOffice: Launch application components from system menu
# - Open menu button -> office menu
#   - Launch libreoffice and check
#   - Quit libreoffice
# - Open menu button -> office menu
#   - Launch office base and check
#   - Save a database named "testdatabase"
#   - Cleanup created database
#   - Quit libreoffice
# - Open menu button -> office menu
#   - Launch office calc and check
#   - Quit libreoffice
# - Open menu button -> office menu
#   - Launch office draw and check
#   - Quit libreoffice
# - Open menu button -> office menu
#   - Launch office impress and check
#   - Quit libreoffice
# - Open menu button -> office menu
#   - Launch office writer and check
#   - Quit libreoffice
# - Install libreoffice-base if necessary
# - Open gnome activities overview
#   - Type "base", send <ENTER> and check
#   - Save a database named "testdatabase"
#   - Cleanup created database
# - Open gnome activities overview
#   - Type "calc", send <ENTER> and check
#   - Uncheck "show tips on startup"
#   - Quit libreoffice
# - Open gnome activities overview
#   - Type "draw", send <ENTER> and check
#   - Quit libreoffice
# - Open gnome activities overview
#   - Type "impress", send <ENTER> and check
#   - Quit libreoffice
# - Open gnome activities overview
#   - Type "writer", send <ENTER> and check
#   - Click on writing area
#   - Quit libreoffice
# Maintainer: Zhaocong Jia <zcjia@suse.com>

use base "x11test";
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);
use x11utils qw(default_gui_terminal close_gui_terminal);

# open desktop mainmenu and click office
sub open_mainmenu {
    my $self = shift;

    wait_still_screen 3;
    send_key "alt-f1";
    assert_screen 'test-desktop_mainmenu-1';
    assert_and_click 'mainmenu-office';
    assert_screen 'mainmenu-office-components';
}

# enter 'Activities overview'
sub open_overview {
    wait_still_screen 3;
    send_key "super";
    assert_screen 'tracker-mainmenu-launched';
}

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

    if (!is_tumbleweed && is_sle('<15')) {
        # launch components from mainmenu
        $self->open_mainmenu();
        assert_and_click 'mainmenu-office-lo';    #open lo
        assert_screen 'welcome-to-libreoffice';
        send_key "ctrl-q";    #close lo

        $self->open_mainmenu();
        assert_and_click 'mainmenu-office-base';    #open base
        select_base_and_cleanup;

        $self->open_mainmenu();
        assert_and_click 'mainmenu-office-calc';    #open calc
        assert_screen 'test-oocalc-1';
        send_key "ctrl-q";    #close calc

        $self->open_mainmenu();
        assert_and_click 'mainmenu-office-draw';    #open draw
        assert_screen 'oodraw-launched';
        send_key "ctrl-q";    #close draw

        $self->open_mainmenu();
        assert_and_click 'mainmenu-office-impress';    #open impress
        assert_screen [qw(ooimpress-select-a-template ooimpress-select-template-nofocus ooimpress-launched)];
        if (match_has_tag 'ooimpress-select-template-nofocus') {
            assert_and_click 'ooimpress-select-template-nofocus';
            send_key 'alt-f4';
            assert_screen 'ooimpress-launched';
        }
        elsif (match_has_tag 'ooimpress-select-a-template') {
            send_key 'alt-f4';    # close impress template window
            assert_screen 'ooimpress-launched';
        }
        send_key "ctrl-q";    #close impress

        $self->open_mainmenu();
        assert_and_click 'mainmenu-office-writer';    #open writer
        assert_screen 'test-ooffice-1';
        send_key "ctrl-q";    #close writer
    }

    # launch components from Activities overview
    $self->open_overview();
    type_string "base";
    assert_screen([qw(base-install overview-office-base)]);
    # tag is base-install means libreoffice-base not installed
    if (match_has_tag 'base-install') {
        send_key 'esc';
        send_key 'esc';
        x11_start_program(default_gui_terminal());
        script_run("gsettings set org.gnome.desktop.session idle-delay 0", 0);    #value=0 means never blank screen
        become_root;
        zypper_call("in libreoffice-base", timeout => 900);
        script_run("gsettings set org.gnome.desktop.session idle-delay 900", 0);    #default value=900
        close_gui_terminal;
        $self->open_overview();
        type_string "base";
    }
    assert_screen 'overview-office-base';
    send_key "ret";
    select_base_and_cleanup;

    $self->open_overview();
    type_string "calc";    #open calc
    assert_and_click 'overview-office-calc';
    assert_screen 'test-oocalc-1', 60;
    if (!match_has_tag('ooffice-tip-of-the-day')) {
        # Sometimes the dialog does not appear immediately but after a short delay,
        # or is fading in slowly - poo#56510
        wait_still_screen 2;
        assert_screen 'test-oocalc-1';
    }
    if (match_has_tag('ooffice-tip-of-the-day')) {
        # Unselect "_S_how tips on startup", select "_O_k"
        send_key "alt-s";
        send_key "alt-o";
        while (match_has_tag('ooffice-tip-of-the-day')) {
            assert_screen 'test-oocalc-1';
        }
    }
    send_key "ctrl-q";    #close calc

    $self->open_overview();
    type_string "draw";    #open draw
    assert_screen 'overview-office-draw';
    send_key "ret";
    assert_screen 'oodraw-launched';
    send_key "ctrl-q";    #close draw

    $self->open_overview();
    type_string "impress";    #open impress
    assert_screen 'overview-office-impress';
    send_key "ret";
    assert_screen [qw(ooimpress-select-a-template ooimpress-select-template-nofocus ooimpress-launched)];
    if (match_has_tag 'ooimpress-select-template-nofocus') {
        assert_and_click 'ooimpress-select-template-nofocus';
        send_key 'alt-f4';
        assert_screen 'ooimpress-launched';
    }
    elsif (match_has_tag 'ooimpress-select-a-template') {
        send_key 'alt-f4';    # close impress template window
        assert_screen 'ooimpress-launched';
    }
    send_key "ctrl-q";    #close impress

    $self->open_overview();
    type_string "writer";    #open writer
    assert_screen 'overview-office-writer';
    send_key "ret";
    assert_screen 'test-ooffice-1';
    assert_and_click('ooffice-writing-area', timeout => 10);
    send_key "ctrl-q";    #close writer
}

1;
