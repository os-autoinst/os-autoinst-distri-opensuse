# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check that suse build key is installed and the key exists
# Maintainer: Ciprian Cret <ccret@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use version_utils "is_opensuse";

sub run {
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
