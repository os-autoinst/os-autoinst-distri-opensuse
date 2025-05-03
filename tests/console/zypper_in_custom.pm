# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Add module to install custom packages for testing
# Maintainer: Thomas Blume <Thomas.Blume@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils qw(is_transactional);
use transactional;

sub run {
    select_console 'root-console';

    my $custom_testrepo = get_var('PATCH_TEST_REPO', '');
    my $custom_packages = get_var('PACKAGES', '');
    if ($custom_packages) {
        if (is_transactional) {
            enter_trup_shell;
        }

        zypper_call "ar $custom_testrepo testrepo";
        zypper_call '--gpg-auto-import-keys ref';
        zypper_call "in --from testrepo $custom_packages";

        if (is_transactional) {
            exit_trup_shell;
        }
    }
}

1;
