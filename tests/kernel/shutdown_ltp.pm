# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module simply shuts down the system allowing the storage volume (HDD_1) to be published.
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

sub run {
    my $self = shift;

    type_string "poweroff\n";
    assert_shutdown;
}

sub test_flags {
    return {fatal => 1};
}

1;
