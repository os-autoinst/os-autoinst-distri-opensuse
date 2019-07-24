# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: check freshclam and clamscan against some fake virus samples
# - refresh the database using freshclam
# - change user vscan to root in clamd.conf (clamd runs as root)
# - start clamd and freshclam using systemctl
# - check that clamscan is able to recognize a fake vim virus
# - check that clamscan is able to recognize an EICAR virus pdf, txt and zip format
# - check that clamdscan is able to recognize an EICAR virus pdf, txt and zip format
# Author: Wei Jiang <wjiang@suse.com>
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: TC1595169, poo#46880

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_jeos is_opensuse);

sub scan_and_parse {
    my $re       = 'm/(eicar_test_files\/eicar.(pdf|txt|zip): Eicar-Test-Signature FOUND\n)+(\n.*)+Infected files: 3(\n.*)+/';
    my $cmd      = shift;
    my $log_file = "$cmd.log";

    script_run "$cmd -i --log=$log_file eicar_test_files", 120;
    validate_script_output("cat $log_file", sub { $re });
    script_run "rm -f $log_file";
}

sub run {
    select_console 'root-console';
    zypper_call('in clamav');
    # Initialize and download ClamAV database which needs time
    assert_script_run('freshclam', 700);

    # clamd takes a lot of memory at startup so a swap partition is needed on JeOS
    # But openSUSE aarch64 JeOS has already a swap and BTRFS does not support swapfile
    if (is_jeos && !(is_opensuse && check_var('ARCH', 'aarch64'))) {
        assert_script_run("mkdir -p /var/lib/swap");
        assert_script_run("dd if=/dev/zero of=/var/lib/swap/swapfile bs=1M count=512");
        assert_script_run("mkswap /var/lib/swap/swapfile");
        assert_script_run("swapon /var/lib/swap/swapfile");
        my $swaps = script_output("cat /proc/swaps");
        die "Swapfile was not created succesfully" unless ($swaps =~ "swapfile");
    }

    # Verify the database
    assert_script_run 'sigtool -i /var/lib/clamav/main.cvd';
    assert_script_run 'sigtool -i /var/lib/clamav/bytecode.cvd';
    assert_script_run 'sigtool -i /var/lib/clamav/daily.cvd';

    # Clamd start timeout sometimes. The default systemd timeout is 90s,
    # override it with a longer duration in runtime.
    my $runtime_dir = '/run/systemd/system/clamd.service.d';
    assert_script_run "mkdir -p $runtime_dir";
    assert_script_run "echo -e \'[Service]\\nTimeoutSec=400\' > $runtime_dir/override.conf";
    systemctl('daemon-reload');

    # Start the deamons
    script_run("sed -i 's/User vscan/User root/g' /etc/clamd.conf");
    systemctl('start clamd', timeout => 400);
    systemctl('start freshclam');

    # Create md5, sha1 and sha256 Hash-based signatures
    # Assume /usr/bin/vim is an virus program and add its
    # signature to viruses database, then scan the virus
    for my $alg (qw(md5 sha1 sha256)) {
        assert_script_run "sigtool --$alg /usr/bin/vim > test.hdb";
        type_string "clamscan -d test.hdb  /usr/bin/vim | tee /dev/$serialdev\n";
        die "Virus scan result was not expected" unless (wait_serial qr/vim\.UNOFFICIAL FOUND.*Known viruses: 1/ms);
    }

    # test 3 different file formats containing the EICAR signature
    assert_script_run "mkdir eicar_test_files";
    my $rel_path;
    for my $ext (qw(pdf txt zip)) {
        $rel_path = "eicar_test_files/eicar.$ext";
        assert_script_run("curl -o $rel_path " . data_url("$rel_path"));
    }

    scan_and_parse "clamscan";
    scan_and_parse "clamdscan";

    # Clean up
    script_run "rm -f test.hdb";
    script_run "rm -rf eicar_test_files/";
}

sub post_run_hook {
    assert_script_run("swapoff /var/lib/swap/swapfile") if is_jeos && !(is_opensuse && check_var('ARCH', 'aarch64'));
}

1;
