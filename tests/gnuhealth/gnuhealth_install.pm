# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gnuhealth stack installation
# Maintainer: Oliver Kurz <okurz@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run {
    my ($self) = @_;
    select_console 'x11';
    ensure_installed 'gnuhealth', timeout => 300;
}

sub test_flags {
    return {fatal => 1};
}

1;
