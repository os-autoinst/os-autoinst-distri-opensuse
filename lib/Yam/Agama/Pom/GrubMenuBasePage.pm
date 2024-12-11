# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles common grub screen actions.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::GrubMenuBasePage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        key_edit_entry => 'e',
        key_cmd_entry => 'c'
    }, $class;
}

sub edit_current_entry {
    my ($self) = @_;
    wait_screen_change { send_key($self->{key_edit_entry}) };
}

sub cmd {
    my ($self) = @_;
    wait_screen_change { send_key($self->{key_cmd_entry}) };
}

sub select_first_entry {
    send_key("ret");
}

1;
