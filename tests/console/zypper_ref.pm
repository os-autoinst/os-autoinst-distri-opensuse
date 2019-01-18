# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure zypper can refresh repos and enable them if the install
# medium used was a dvd
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

    # see FATE#325541
    zypper_call 'mr -e -l'
        if is_sle('15+')
        and get_var('ISO_1', '') =~ /SLE-.*-Packages-.*\.iso/;

    zypper_call '--gpg-auto-import-keys ref';
}

sub test_flags {
    return {milestone => 1};
}

1;
