# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check that suse build key is installed and the key exists
# Maintainer: Ciprian Cret <ccret@suse.com>

use base "opensusebasetest";
use testapi;
use version_utils "is_opensuse";

sub run {
    select_console 'root-console';

    if (is_opensuse) {
        assert_script_run("rpm -qi openSUSE-build-key");
    }
    else {
        assert_script_run("rpm -qi suse-build-key");

        # check that the key is not empty or has invalid content
        validate_script_output("cat /usr/lib/rpm/gnupg/keys/suse_ptf_key.asc", sub {
                /(----BEGIN PGP PUBLIC KEY BLOCK-----)\s*|(.*)(-----END PGP PUBLIC KEY BLOCK-----)/;
        });
    }
}

1;
