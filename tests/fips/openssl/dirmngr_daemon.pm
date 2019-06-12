# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test dirmngr daemon and valid/revoked certificate
#
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#52430, poo#52937, tc#1729313

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub dirmngr_daemon {

    select_console 'root-console';

    my $myca_dir = "/home/linux/myca";

    # Create dirmngr required testing folder
    assert_script_run('mkdir -p /etc/dirmngr/trusted-certs');
    assert_script_run('mkdir -p /var/{run,log}/dirmngr /var/cache/dirmngr/crls.d /var/lib/dirmngr/extra-certs');

    # Create an empty ldapservers.conf
    assert_script_run "touch /etc/dirmngr/ldapservers.conf";

    # Crete dirmngr config file
    assert_script_run("echo 'log-file /var/log/dirmngr/dirmngr.log' > /etc/dirmngr/dirmngr.conf");

    # Copy trusted CA certificates to /etc/dirmngr/trusted-certs
    assert_script_run("cp $myca_dir/ca/root-ca.crt.der /etc/dirmngr/trusted-certs");

    # Start dirmngr as daemon
    validate_script_output("dirmngr --daemon --disable-ldap", sub { m/DIRMNGR_INFO=.*DIRMNGR_INFO;/ });

    # Load CRL
    assert_script_run("dirmngr-client --load-crl $myca_dir/crl/root-ca.crl.der");

    # Verify certificate ( test2.crt.der certificate is valid)
    if (script_run("dirmngr-client --validate $myca_dir/certs/test2.crt.der 2>&1 | tee -a /tmp/cert2.out") == 0) {
        assert_script_run("grep -o \'dirmngr-client: certificate is valid\' /tmp/cert2.out");
    }
    else {
        die "dirmngr-client did not exit with return 0";
    }

    # Verify certificate ( test1.crt.der certificate is revoked)
    if (script_run("dirmngr-client --validate $myca_dir/certs/test1.crt.der 2>&1 | tee -a /tmp/cert1.out") == 1) {
        assert_script_run("grep -o \'dirmngr-client: validation of certificate failed: Certificate revoked\' /tmp/cert1.out");
    }
    else {
        die "dirmngr-client did not exit with return 1";
    }
}

sub run {

    my ($self) = @_;

    # Test Dirmngr daemon
    $self->dirmngr_daemon();
}

1;
