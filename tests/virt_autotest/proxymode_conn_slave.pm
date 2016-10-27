# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

use base "proxymodeapi";

sub run() {
    my $self         = shift;
    my $ipmi_machine = get_var("IPMI_HOSTNAME");

    $self->restart_host();
    $self->connect_slave();
    $self->check_prompt_for_boot();
}

sub test_flags {
    return {important => 1};
}

1;

