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
        screen => 'agama-install-finished',
        button => 'reboot'
    }, $class;
}

sub expect_is_shown {
    my ($self) = @_;
    select_console('installation');
    assert_screen($self->{screen}, 60);
}

sub reboot {
    my ($self) = @_;
    assert_and_click($self->{button});
}

1;
