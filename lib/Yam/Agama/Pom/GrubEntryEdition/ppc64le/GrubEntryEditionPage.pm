# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB entry edition for ppc64le.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubEntryEdition::ppc64le::GrubEntryEditionPage;
use strict;
use warnings;

use testapi;
use utils;

sub new {
    my ($class, $args) = @_;
    return bless {
        grub_entry_edition => $args->{grub_entry_edition},
        number_kernel_line => 3
    }, $class;
}

sub move_cursor_to_end_of_kernel_line {
    my ($self) = @_;
    $self->{grub_entry_edition}->move_cursor_to_end_of_kernel_line();
}

sub type {
    my ($self, $args) = @_;
    type_string(" @$args ", max_interval => utils::VERY_SLOW_TYPING_SPEED);
    wait_still_screen(1);
    save_screenshot();
}

sub boot {
    my ($self) = @_;
    $self->{grub_entry_edition}->boot();
}

1;
