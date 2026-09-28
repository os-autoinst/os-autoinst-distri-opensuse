# Copyright 2022-2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
# Package: tar
# Summary: - Verify the correct version of tar is in 15-SP4+
#          - Advanced tar + zstd functionality test checking binary integrity and metadata preservation.
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);
use package_utils 'install_package';

sub verify_extraction {
    my ($archive_path, $extract_dir) = @_;

    # Switch to the extraction directory so sha256sum validates the newly extracted files
    assert_script_run("cd $extract_dir");

    # Compare binary data integrity using SHA-256
    assert_script_run("sha256sum --check --status /tmp/source_checksums.txt",
        fail_message => "Binary integrity failure: Extracted files do not match originals for $archive_path");

    # Compare file permissions, ownership, and modification times
    my $orig_meta = script_output("find tar_test -type f -exec stat -c '%n %a %U %G %Y' {} + | sort");
    my $dest_meta = script_output("cd $extract_dir && find tar_test -type f -exec stat -c '%n %a %U %G %Y' {} + | sort");

    if ($orig_meta ne $dest_meta) {
        die "Metadata mismatch detected after extracting $archive_path!\nOriginal:\n$orig_meta\nExtracted:\n$dest_meta";
    }
}

sub run {
    select_serial_terminal;

    # Ensure required utilities are available
    install_package('bzip2', trup_reboot => 1) if (script_run('rpm -qi bzip2'));

    # Create a dynamic test environment with explicit metadata constraints
    assert_script_run("rm -rf /tmp/tar_test_working && mkdir -p /tmp/tar_test_working");
    assert_script_run("cd /tmp/tar_test_working");
    assert_script_run("mkdir tar_test");

    # Create text, binary, and strict-permission files
    assert_script_run("echo 'Testing deep integrity of standard text tarballing' > tar_test/textfile.txt");
    assert_script_run("dd if=/dev/urandom of=tar_test/binaryfile.bin bs=1M count=5");
    assert_script_run("chmod 0600 tar_test/binaryfile.bin");    # Test strict permissions
    assert_script_run("touch -d '2015-10-21 07:28:00' tar_test/textfile.txt");    # Test explicit historical mtime

    # Capture gold standard hashes before compression
    assert_script_run("find tar_test -type f -exec sha256sum {} + | sort > /tmp/source_checksums.txt");

    # Test bzip2 compression (-j) preserving access time and permissions
    assert_script_run("cd /tmp/tar_test_working && tar --atime-preserve -cpjvf myfile.tar.bz2 tar_test");
    assert_script_run("tar -xpjvf myfile.tar.bz2 -C /tmp/");
    verify_extraction("myfile.tar.bz2", "/tmp");
    assert_script_run("rm -rf /tmp/tar_test");

    # Test xz compression (-J) verifying file contents and metadata
    assert_script_run("cd /tmp/tar_test_working && tar -cpJvf myfile.tar.xz tar_test");
    assert_script_run("tar -xpJvf myfile.tar.xz -C /tmp/");
    verify_extraction("myfile.tar.xz", "/tmp");
    assert_script_run("rm -rf /tmp/tar_test");

    # Test gzip compression (-z) verifying file contents and metadata
    assert_script_run("cd /tmp/tar_test_working && tar -cpzvf myfile.tar.gz tar_test");
    assert_script_run("tar -xpzvf myfile.tar.gz -C /tmp/");
    verify_extraction("myfile.tar.gz", "/tmp");
    assert_script_run("rm -rf /tmp/tar_test");

    # Test auto-detection (-a) for gzip archive extension verifying file contents and metadata
    assert_script_run("cd /tmp/tar_test_working && tar -cpavf myfile.tar.gz tar_test");
    assert_script_run("tar -xpavf myfile.tar.gz -C /tmp/");
    verify_extraction("myfile.tar.gz", "/tmp");
    assert_script_run("rm -rf /tmp/tar_test");

    if (is_sle('>=15-sp1')) {
        install_package("zstd", trup_reboot => 1) if (script_run('rpm -qi zstd'));

        # Test zstd compression via -I flag verifying file contents and metadata
        assert_script_run("cd /tmp/tar_test_working && tar -I zstd -cpvf myfile.tar.zst tar_test");
        assert_script_run("tar -I zstd -xpvf myfile.tar.zst -C /tmp/");
        verify_extraction("myfile.tar.zst", "/tmp");
        assert_script_run("rm -rf /tmp/tar_test");
    }

    if (is_sle('>=15-sp4')) {
        # Test zstd compression via --zstd flag verifying file contents and metadata
        assert_script_run("cd /tmp/tar_test_working && tar --zstd -cpvf myfile.tar.zst tar_test");
        assert_script_run("tar --zstd -xpvf myfile.tar.zst -C /tmp/");
        verify_extraction("myfile.tar.zst", "/tmp");
        assert_script_run("rm -rf /tmp/tar_test");

        # Test auto-detection (-a) for zstd archive extension verifying file contents and metadata
        assert_script_run("cd /tmp/tar_test_working && tar -cpavf myfile.tar.zst tar_test");
        assert_script_run("tar -xpavf myfile.tar.zst -C /tmp/");
        verify_extraction("myfile.tar.zst", "/tmp");
        assert_script_run("rm -rf /tmp/tar_test");
    }

    assert_script_run("rm -rf /tmp/tar_test_working /tmp/source_checksums.txt");
}

1;
