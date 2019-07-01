# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple clamav test for SLE FIPS and openSUSE
# Author: Wei Jiang <wjiang@suse.com>
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: TC1595169, poo#46880

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_jeos is_opensuse);

sub run {
    select_console 'root-console';
    assert_screen('fail-here');
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

    # Clean up
    script_run 'rm -f test.hdb';
}

sub post_run_hook {
    assert_script_run("swapoff /var/lib/swap/swapfile") if is_jeos && !(is_opensuse && check_var('ARCH', 'aarch64'));
}

1;
