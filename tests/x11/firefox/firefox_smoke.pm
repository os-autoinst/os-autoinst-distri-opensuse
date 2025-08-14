# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1479153 Firefox: Smoke Test
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox and handle popups
# - Exit firefox
# Maintainer: wnereiz <wnereiz@github>

use base "x11test";
use testapi;
use utils 'type_string_slow';
use version_utils 'is_tumbleweed';

sub run {
    my ($self) = @_;

    ## some w3m files will be used later in firefox tests.
    ensure_installed 'w3m' if is_tumbleweed;

    $self->start_clean_firefox;

    # Exit
    $self->exit_firefox;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
