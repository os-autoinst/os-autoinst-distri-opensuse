# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles entering passphrase for root partition after grub welcome.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::EnterPassphraseForRootPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        enter_passphrase_base => $args->{enter_passphrase_base},
        tag_enter_passphrase_for_root_partition => 'enter-passphrase-for-root-partition',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_enter_passphrase_for_root_partition}, 60);
}

sub enter { shift->{enter_passphrase_base}->enter() }

1;
