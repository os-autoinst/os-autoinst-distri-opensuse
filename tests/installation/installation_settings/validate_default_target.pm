# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module goes to install-shell to validate if the actual
# systemd target corresponds to the expected one.
# Then returns back to the installation console.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;
    my $expected_target = check_var('DESKTOP', 'textmode') ? "multi-user" : "graphical";

    $self->validate_default_target($expected_target);
}

1;
