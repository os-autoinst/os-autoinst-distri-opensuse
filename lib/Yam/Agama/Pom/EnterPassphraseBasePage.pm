# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles common actions when entering passphrase.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package Yam::Agama::Pom::EnterPassphraseBasePage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {}, $class;
}

sub enter {
    my ($self) = @_;
    type_password();
    send_key "ret";
}

1;
