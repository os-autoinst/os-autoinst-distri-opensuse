# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: MozillaThunderbird
# Summary: Thunderbird installation
# - Go to text console
# - Stop packagekit
# - Install MozillaThunderbird
# - Go to graphic console
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    select_console 'root-console';

    quit_packagekit;
    zypper_call("in MozillaThunderbird", exitcode => [0, 102, 103]);

    select_console 'x11';
}

sub test_flags {
    return {milestone => 1};
}

1;

