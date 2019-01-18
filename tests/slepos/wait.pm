# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test, wait for other nodes
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use strict;
use warnings;
use base 'basetest';
use testapi;
use mmapi;

sub run {
    my $self = shift;

    wait_for_children;

    assert_script_run "save_poslogs " . get_var("SLEPOS") . ".tar.gz";
    upload_logs get_var("SLEPOS") . ".tar.gz";

    $self->result('ok');
}


sub test_flags {
    return {fatal => 1};
}

1;
