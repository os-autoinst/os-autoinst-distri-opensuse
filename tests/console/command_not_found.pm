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
use utils;
use version_utils qw(is_sle sle_version_at_least);
use registration qw(add_suseconnect_product remove_suseconnect_product);

# test for regression of bug http://bugzilla.suse.com/show_bug.cgi?id=952496
sub run {
    my ($self) = @_;
    # select user-console; for one we want to be sure cnf works for a user, 2nd assert_script_run does not work in root-console
    select_console 'user-console';

    if (check_var('DESKTOP', 'textmode')) {    # command-not-found is part of the enhanced_base pattern, missing in textmode
        assert_script_sudo "zypper -n in command-not-found";
    }

    my $not_installed_pkg = (is_sle && sle_version_at_least '15') ? 'wireshark' : 'xosview';
    my $cnf_cmd = "echo \"\$(cnf $not_installed_pkg 2>&1 | tee /dev/stderr)\" | grep -q \"zypper install $not_installed_pkg\"";

    if (is_sle && sle_version_at_least '15') {
        $self->{run_post_hook} = script_run($cnf_cmd);
        select_console 'root-console';
        record_soft_failure 'https://fate.suse.com/323424';
        add_suseconnect_product("sle-module-desktop-applications");
        select_console 'user-console';
    }
    assert_script_run $cnf_cmd if $self->{run_post_hook};    # Run command if not yet executed (workaround for SLE 15)
    save_screenshot;
}

sub post_run_hook {
    # deativate desktop applications module on sle 15 if was activated
    return unless shift->{run_post_hook};

    select_console 'root-console';
    remove_suseconnect_product("sle-module-desktop-applications");
    select_console 'user-console';
}

1;
# vim: set sw=4 et:
