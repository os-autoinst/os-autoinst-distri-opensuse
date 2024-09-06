# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::RebootPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_installation_complete => 'agama-install-finished',
        tag_reboot_button => 'reboot'
    }, $class;
}

sub expect_is_shown {
    my ($self, %args) = @_;
    assert_screen($self->{tag_installation_complete}, $args{timeout});
}

sub reboot {
    my ($self) = @_;
    assert_and_click($self->{tag_reboot_button});
}

1;
