# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add test for command-not-found tool
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils 'is_sle';
use registration qw(add_suseconnect_product remove_suseconnect_product);

# test for regression of bug http://bugzilla.suse.com/show_bug.cgi?id=952496
sub run {
    my ($self) = @_;
    # select user-console; for one we want to be sure cnf works for a user, 2nd assert_script_run does not work in root-console
    select_console 'user-console';

    if (check_var('DESKTOP', 'textmode')) {    # command-not-found is part of the enhanced_base pattern, missing in textmode
        select_console 'root-console';
        zypper_call 'in command-not-found';
        select_console 'user-console';
    }

    my $not_installed_pkg = is_sle('15+') ? 'wireshark' : 'xosview';
    my $cnf_cmd           = qq{echo "\$(cnf $not_installed_pkg 2>&1 | tee /dev/stderr)" | grep -q "zypper install $not_installed_pkg"};

    save_screenshot;
    # Return if command execution was successful
    return unless script_run($cnf_cmd);

    # Soft-fail if command execution fails on sle 15
    if (is_sle '15+') {
        record_soft_failure 'https://fate.suse.com/323424';
        select_console 'root-console';
        add_suseconnect_product('sle-module-desktop-applications');
        zypper_call('ref');
        select_console 'user-console';
    }
    else {
        die "Command Not Found failed: $cnf_cmd";
    }

    assert_script_run($cnf_cmd);    # Run command
    save_screenshot;
}

1;
