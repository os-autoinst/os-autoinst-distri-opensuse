# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen for textmode display.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::RebootTextmodePage;
use strict;
use warnings;
use power_action_utils 'power_action';

sub new {
    my ($class, $args) = @_;
    return bless {}, $class;
}

sub reboot {
    my ($self) = @_;
    power_action('reboot', keepconsole => 1, first_reboot => 1);
}

1;
