# Copyright 2015-2016 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: test to import gpg keys
#    openSUSE maintenance updates in testing are signed by a different key,
#    so that key needs to be imported manually
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    if (my $keys = get_var("IMPORT_GPG_KEYS")) {
        assert_script_run(
            "rpm --import ~$username/data/$keys",
            timeout => 10,
            fail_message => 'Failed to import GPG keys'
        );
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
