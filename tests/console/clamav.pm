# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple clamav test for SLE FIPS and openSUSE
# Maintainer: Wei Jiang <wjiang@suse.com>
# Tags: TC1595169

use base "consoletest";
use strict;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    zypper_call('in clamav');
    # Initialize and download ClamAV database which needs time
    assert_script_run('freshclam', 700);

    # Start the deamons
    systemctl('start clamd');
    systemctl('start freshclam');

    # Verify the database
    assert_script_run 'sigtool -i /var/lib/clamav/main.cvd';
    assert_script_run 'sigtool -i /var/lib/clamav/bytecode.cvd';
    assert_script_run 'sigtool -i /var/lib/clamav/daily.cvd';

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

1;
# vim: set sw=4 et:
