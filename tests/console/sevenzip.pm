# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: 7zip
# Summary: testsuite 7zip
# Maintainer: QE Core <qe-core@suse.com>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use package_utils 'install_package';

sub run {
    select_serial_terminal;

    # Install 7zip if it is not installed
    install_package('7zip', trup_apply => 1) if (script_run('rpm -q 7zip'));
    record_info("7zip package version", script_output("rpm -q 7zip"));

    # Prepare test directory.
    assert_script_run 'mkdir -p /tmp/7zip-test/input/nested';
    assert_script_run 'cd /tmp/7zip-test';

    # Create test files.
    assert_script_run 'printf "SUSE 7-Zip openQA test\n" > input/test25.txt';
    assert_script_run 'printf "test nested file\n" > input/nested/nested.txt';

    # 1. Create 7z archive.
    assert_script_run '7z a test.7z input/';

    # 2. List archive contents.
    my $listing = script_output '7z l test.7z';

    die 'Expected files not found in archive' unless $listing =~ "test25.txt" && $listing =~ "nested.txt";

    # 3. Test archive integrity.
    assert_script_run '7z t test.7z';

    # 4. Extract archive.
    assert_script_run 'mkdir extract';
    assert_script_run '7z x test.7z -oextract';

    # 5. Verify extracted file contents.
    assert_script_run 'cmp input/test25.txt extract/input/test25.txt';
    assert_script_run 'cmp input/nested/nested.txt extract/input/nested/nested.txt';

    # Explicitly verify the expected content.
    my $content = script_output 'cat extract/input/test25.txt';

    die "Unexpected content in test25.txt: $content" unless $content eq 'SUSE 7-Zip openQA test';

    # 6. Extract only test25.txt.
    assert_script_run 'mkdir single';
    assert_script_run '7z e test.7z -osingle input/test25.txt';

    assert_script_run 'test -f single/test25.txt';
    assert_script_run 'cmp input/test25.txt single/test25.txt';

    # Cleanup.
    assert_script_run 'rm -rf /tmp/7zip-test';
}
1;
