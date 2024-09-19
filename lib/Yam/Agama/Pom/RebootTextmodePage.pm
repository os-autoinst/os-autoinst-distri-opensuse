# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen for textmode display.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::RebootTextmodePage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {}, $class;
}

sub reboot {
    my ($self) = @_;
    enter_cmd 'reboot';
}

1;
