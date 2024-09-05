# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB entry edition.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubEntryEditionPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        number_kernel_line => $args->{number_kernel_line} // 4,
        max_interval => $args->{number_kernel_line},
        key_boot => 'ctrl-x'
    }, $class;
}

sub move_cursor_to_end_of_kernel_line {
    my ($self) = @_;
    for (1 .. $self->{number_kernel_line}) { send_key('down') }
    wait_screen_change { send_key('end') };
    wait_still_screen(1);
}

sub type {
    my ($self, $args) = @_;
    type_string(" @$args ", max_interval => $self->{max_interval});
    wait_still_screen(1);
    save_screenshot();
}

sub boot {
    my ($self) = @_;
    wait_screen_change { send_key($self->{key_boot}) };
}

1;
