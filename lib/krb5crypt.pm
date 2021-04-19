# Copyright © 2019 SUSE LLC
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
# Summary: Public variables and functions for krb5 cryptographic testing
# Maintainer: Ben Chou <bchou@suse.com>

package krb5crypt;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use utils;

use base 'consoletest';

our @EXPORT = qw(
  $dom_kdc
  $ip_kdc
  $dom_server
  $ip_server
  $dom_client
  $ip_client
  $dom
  $pass_db
  $adm
  $pass_a
  $tst
  $pass_t
  $nfs_expdir
  $nfs_mntdir
  $nfs_fname

  krb5_init
);

our $dom_kdc    = 'kdc.example.com';
our $ip_kdc     = '10.0.2.31';
our $dom_server = 'server.example.com';
our $ip_server  = '10.0.2.32';
our $dom_client = 'client.example.com';
our $ip_client  = '10.0.2.33';

our $dom     = 'EXAMPLE.COM';
our $pass_db = 'DB_phrase';      # Database password
our $adm     = 'joe/admin';
our $pass_a  = 'Admin_pass';     # Admin user password
our $tst     = 'tester';
our $pass_t  = 'Tester_pass';    # Test user password

# NFSv4 authentication with krb5 testing
our $nfs_expdir = '/tmp/nfsdir';
our $nfs_mntdir = '/tmp/mntdir';
our $nfs_fname  = 'foo';

# Common codes for krb5 server and client setup
sub krb5_init {
    script_run("kinit -p $adm |& tee /dev/$serialdev", 0);
    wait_serial(qr/Password.*\Q$adm\E/) || die "Matching output failed";
    enter_cmd "$pass_a";
    script_output "echo \$?", sub { m/^0$/ };

    validate_script_output "klist", sub {
        m/
            Ticket\scache.*\/root\/kcache.*
            Default\sprincipal.*\Q$adm\E\@\Q$dom\E.*
            krbtgt\/\Q$dom\E\@\Q$dom\E.*
            renew\suntil.*/sxx
    };

    validate_script_output "kadmin -p $adm -q listprincs -w $pass_a", sub {
        m/\Q$adm\E\@\Q$dom\E/;
    };
}
