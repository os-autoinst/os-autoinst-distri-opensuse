## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Patch Agama on Live Medium using yupdate in order to copy
# integration test from GitHub.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base Yam::Agama::patch_agama_base;
use testapi qw(assert_script_run get_required_var select_console script_run);

sub run {
    select_console 'install-shell';
    my $agama_test = get_required_var("AGAMA_TEST");
    my ($repo, $branch) = split /#/, get_required_var('YUPDATE_GIT');
    my $destination = "/usr/share/agama/system-tests";

    script_run("curl -L -o dist.tar.gz https://github.com/$repo/releases/download/tag-$branch/dist.tar.gz");
    script_run("tar -xzf dist.tar.gz");
    script_run("mkdir -p $destination");
    script_run("cp dist/vendor.js $destination");
    script_run("cp dist/$agama_test* $destination");
}

1;
