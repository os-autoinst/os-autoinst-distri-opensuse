# SUSE's openQA tests
#
# Copyright © 2018-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: libreoffice-writer
# Summary: Case 1503978 - LibreOffice: pyuno bridge
# - Launch oowriter
# - Open tools menu and select option "Run macros"
# - On macro selector, choose python samples
# - Run create table and check
# - Quit libreoffice without saving
# Maintainer: Grace Wang <gwang@suse.com>
# Tags: poo#34141

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;

    # get version of libreoffice
    x11_start_program('xterm');
    my $old_version = script_output('zypper se -i -s -x libreoffice|grep 6.4.5', proceed_on_failure => 1);
    send_key 'alt-f4';

    # Open LibreOffice
    $self->libreoffice_start_program('oowriter');

    # Make sure the tip of the day window disappear
    wait_still_screen(3, 7);
    # Open the tools and navigate to macro selector
    assert_and_click 'ooffice-writer-tools';
    assert_and_click 'ooffice-tools-macros';
    send_key 'right';
    assert_and_click 'ooffice-writer-tools-run-macros';

    if ($old_version) {
        # navigate to the python samples item
        assert_screen 'ooffice-writer-mymacros';
        send_key 'down';
        assert_and_click 'ooffice-writer-libreofficemacros';
        wait_still_screen(2);
        type_string "py\n";

        assert_and_click 'ooffice-python-samples';
        wait_still_screen(2);
        send_key_until_needlematch 'ooffice-table-sample', 'down', 5, 1;
    }
    else {
        # navigate to the Table sample item
        assert_screen 'ooffice-writer-mymacros';
        assert_and_click 'ooffice-writer-libreofficemacros';
        wait_still_screen(2);
        type_string "table\n";
        assert_screen 'ooffice-table-sample';
    }
    send_key 'tab';

    # run create table
    send_key 'ret';
    assert_screen 'ooffice-verify-table';

    # exit ooffice-writer without saving created table
    send_key 'ctrl-q';
    assert_and_click 'ooffice-writer-dont-save';
}

1;
