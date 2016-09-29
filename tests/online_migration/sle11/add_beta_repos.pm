# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: sle11 online migration testsuite
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;

sub add_beta_repo {
    my ($a, $repo) = @_;
    my $alias;
    if ($a ne '') {
        $alias = 'beta-' . $a;
    }
    else {
        $alias = 'beta';
    }

    my $script = "zypper ar -f " . get_var($repo) . " " . $alias . "\n";
    validate_script_output $script, sub { m/successfully added/ };
}

sub run() {
    my $self = shift;
    become_root;

    # add beta repo
    add_beta_repo('', 'BETA_REPO_0');

    # add addon beta repo
    if (get_var('ADDONS')) {
        foreach my $a (split /,/, get_var('ADDONS')) {
            if ($a eq "sdk") {
                type_string "clear\n";
                add_beta_repo($a, 'BETA_REPO_1');
            }
            if ($a eq "ha") {
                type_string "clear\n";
                add_beta_repo($a, 'BETA_REPO_2');
            }
            if ($a eq "geo") {
                type_string "clear\n";
                add_beta_repo($a, 'BETA_REPO_3');
            }
        }
    }
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
