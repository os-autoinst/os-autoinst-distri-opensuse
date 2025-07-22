# Copyright 2015-2016 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Verify installed packages
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "consoletest";
use testapi;

sub run {
    # reuse console
    my $packages = get_var("VERIFY_PACKAGE_VERSIONS");
    assert_script_run("~$username/data/lsmfip --verbose --verify \$XDG_RUNTIME_DIR/install_packages.txt $packages | tee /dev/$serialdev");
}

1;
