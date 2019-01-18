# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple reboot test on console
#    refactor common reboot and encrypt unlock functions to utils.pm
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use testapi;
use utils;
use power_action_utils 'power_action';
use strict;
use warnings;

sub run {
    my ($self) = @_;
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_console 'root-console';
    ensure_serialdev_permissions;
    check_console_font;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

