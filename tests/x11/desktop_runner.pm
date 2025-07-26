# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test the desktop runner which is a prerequisite for many other
#   modules
# - Launch "true" and check if desktop is matched
# Maintainer: QE Core <qe-core@suse.de>

use base 'x11test';
use testapi;

sub run {
    my ($self) = @_;
    $self->check_desktop_runner;
}

1;
