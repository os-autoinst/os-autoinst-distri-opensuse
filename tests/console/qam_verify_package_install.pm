# Copyright 2015-2016 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Verify installed packages
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use Mojo::Base 'consoletest';
use testapi;

sub run {
    save_tmp_file("packages-list", get_var("VERIFY_PACKAGE_VERSIONS"));
    my $download_cmd = sprintf('curl -O "%s/files/%s"', autoinst_url, 'packages-list');
    assert_script_run($download_cmd);
    assert_script_run("~$username/data/lsmfip --verbose --verify \$XDG_RUNTIME_DIR/install_packages.txt \$(cat packages-list)");
}

1;
