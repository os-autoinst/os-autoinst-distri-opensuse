# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: gnuhealth tryton client installation and startup
# Maintainer: Christopher Hofmann <cwh@suse.de>

use base 'x11test';
use strict;
use testapi;

sub run {
    my ($self) = @_;
    ensure_installed 'gnuhealth-client';
}

sub test_flags {
    return {fatal => 1};
}

1;
