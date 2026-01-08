# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles entering passphrase for swap partition after grub.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::EnterPassphraseForSwapPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        enter_passphrase_base => $args->{enter_passphrase_base},
        tag_enter_passphrase_for_swap_partition => 'enter-passphrase-for-swap-partition',
        tag_enter_passphrase_for_swap_key_typed => 'enter-passphrase-for-swap-partition-key-typed',
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    assert_screen($self->{tag_enter_passphrase_for_swap_partition}, 60);
}

sub enter {
    my ($self) = @_;
    # Check ppc64le Power10 is able to type the password entirely
    send_key_until_needlematch($self->{tag_enter_passphrase_for_swap_key_typed}, 't', 3);
    send_key_until_needlematch($self->{tag_enter_passphrase_for_swap_partition}, 'backspace', 3);
    $self->{enter_passphrase_base}->enter();
}

1;
