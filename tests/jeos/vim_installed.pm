# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my $check_vim  = "zypper -q info vim | grep 'Installed:' | cut -d' ' -f2";
    my $check_data = "zypper -q info vim-data | grep -v '^\$'";

    validate_script_output $check_vim,  sub { /^Yes$/ };
    validate_script_output $check_data, sub { /^package .* not found\.$/ };
}

1;
