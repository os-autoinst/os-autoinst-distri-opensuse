# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles GRUB entry edition.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::GrubEntryEditionPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        max_interval => $args->{max_interval},
        key_boot => 'ctrl-x'
    }, $class;
}

sub move_cursor_to_end_of_kernel_line {
    send_key_until_needlematch "linux-line-selected", "down", 26;
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
