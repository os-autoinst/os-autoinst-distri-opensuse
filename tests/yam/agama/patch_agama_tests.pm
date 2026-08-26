## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Patch Agama on Live Medium using yupdate in order to copy
# integration test from GitHub.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::patch_agama_base';
use testapi qw(assert_script_run get_required_var select_console script_run assert_script_run script_output);

sub run {
    select_console 'install-shell';
    my ($repo, $branch) = split /#/, get_required_var('YUPDATE_GIT');
    my $agama_test = get_required_var("AGAMA_TEST");
    my $destination = "/usr/share/agama/system-tests";
    my $latest_commit_sha = script_output("curl -s 'https://api.github.com/repos/$repo/commits/$branch' | jq -r '.sha'");
    script_run("mkdir -p $destination");
    assert_script_run("curl -sfL https://github.com/$repo/releases/download/$branch/$latest_commit_sha.tar.gz | tar -xz",
        fail_message => "Error: CI build artifact (tarball) for $repo/$branch is not available yet. The CI run may still be in progress.");
    script_run("cp -t $destination dist/vendor.js dist/$agama_test* ");
}

1;
