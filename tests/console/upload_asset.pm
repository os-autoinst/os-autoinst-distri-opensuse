# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Compresses files, as given in test data and upload the compressed file as asset.
# test data example:
# test_data:
#   asset_files: "/dir1/file1 /dir2/file2"
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler "get_test_suite_data";

sub run {
    select_console 'root-console';
    my $files_to_upload = get_test_suite_data()->{asset_files};
    assert_script_run("tar -cvf asset_files.tar $files_to_upload", fail_message => "Failed to compress file(s)");
    upload_asset("asset_files.tar");
}

1;

