# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Downloads y2logs ASSET_1 file, created by
# upload_y2logs_as_asset.pm in parent job.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;

sub run {
    select_console 'root-console';
    my $file_to_download = autoinst_url("/assets/other/" . get_required_var("ASSET_1"));
    assert_script_run("wget " . $file_to_download . " -O  " . "/tmp/y2logs.tar.bz2");
}
1;
