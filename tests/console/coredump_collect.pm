
# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: collect all coredumps
# Maintainer: Ondřej Súkup <osukup@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;

sub run {
    my $self = shift;
    select_console 'root-console';
    $self->upload_coredumps;
}

1;
