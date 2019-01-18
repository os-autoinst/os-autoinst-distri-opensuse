# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gnuhealth client installation and startup
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use warnings;
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
