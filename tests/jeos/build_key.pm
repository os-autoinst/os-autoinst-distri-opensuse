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

sub run {
    # check that suse-build-key is installed
    my $zypper_output = script_output('zypper search suse-build-key');
    die 'suse-build-key is not installed' unless $zypper_output =~ /i\+(.*)suse-build-key/;

    assert_script_run('ls /usr/lib/rpm/gnupg/keys | grep suse_ptf_key.asc');

    # check that the key is not empty or has invalid content
    validate_script_output("cat /usr/lib/rpm/gnupg/keys/suse_ptf_key.asc", sub {
            /(----BEGIN PGP PUBLIC KEY BLOCK-----)\s*|(.*)(-----END PGP PUBLIC KEY BLOCK-----)/;
    });
}

1;
