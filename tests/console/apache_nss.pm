# SUSE's Apache+NSS tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Enable NSS module for Apache2 server
# - calls setup_apache2 with mode = NSS (lib/apachetest.pm)
# Maintainer: Ben Chou <BChou@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use apachetest;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    setup_apache2(mode => 'NSS');
}

1;
