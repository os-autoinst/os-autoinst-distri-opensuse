# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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

    # Open LibreOffice
    $self->libreoffice_start_program('oowriter');

    # Make sure the tip of the day window disappear
    wait_still_screen(3, 7);
    # Open the tools and navigate to macro selector
    assert_and_click 'ooffice-writer-tools';
    assert_and_click 'ooffice-tools-macros';
    send_key 'right';
    assert_and_click 'ooffice-writer-tools-run-macros';

    # navigate to the Table sample item
    assert_screen 'ooffice-writer-mymacros';
    assert_and_click 'ooffice-writer-libreofficemacros';
    wait_still_screen(2);
    type_string "table\n";
    assert_screen 'ooffice-table-sample';
    send_key 'tab';

    # run create table
    send_key 'ret';
    assert_screen 'ooffice-verify-table';

    # exit ooffice-writer without saving created table
    send_key 'ctrl-q';
    assert_and_click 'ooffice-writer-dont-save';
}

1;
