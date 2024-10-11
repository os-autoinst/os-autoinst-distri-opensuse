# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles common grub screen actions, workaround for bsc#1231658.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuBaseBug1231658Page;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        key_edit_entry => 'e'
    }, $class;
}

sub edit_current_entry {
    my ($self) = @_;
    wait_screen_change { send_key($self->{key_edit_entry}) };
}

sub select_first_entry {
    # Edit grub2 entry to set console
    send_key 'e';

    my $grub_entry_edition = $testapi::distri->get_grub_entry_edition();
    $grub_entry_edition->move_cursor_to_end_of_kernel_line();
    assert_screen "linux-line-matched";
    type_string " console=tty";
    save_screenshot;
    send_key 'ctrl-x';
}

1;
