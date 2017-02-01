# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Online migration setup
# Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my ($self) = @_;
    $self->setup_online_migration;
}

sub test_flags() {
    return {fatal => 1, important => 1};
}

1;
# vim: set sw=4 et:
