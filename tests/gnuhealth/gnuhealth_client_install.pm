# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: gnuhealth client installation and startup
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use testapi;
use version_utils 'is_leap';

sub run {
    my ($self) = @_;
    my $gnuhealth = get_var('GNUHEALTH_CLIENT', is_leap('<15.0') ? 'tryton' : 'gnuhealth-client');
    set_var('GNUHEALTH_CLIENT', $gnuhealth);
    ensure_installed $gnuhealth;
}

sub test_flags {
    return {fatal => 1};
}

1;
