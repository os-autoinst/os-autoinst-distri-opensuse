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
# Summary: Test dm-crypt cipher support with cryptsetup tool. Make sure
#          unsafe algorithms are not applicable in FIPS or non-FIPS mode.
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#39071

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    my $crypt_pass = "dm#*crypt";
    my $crypt_tmp  = "/tmp/foo";
    my $crypt_dev  = "foo";
    my $bench_log  = "/tmp/cryptsetup_benchmark.log";

    # To avoid run it with FIPS_ENV_MODE
    die "This case depends on kernel function and should not run in FIPS env mode, FIPS should be enabled with fips=1"
      if (get_var('FIPS_ENV_MODE'));

    # Get a benchmark with default cipher setups and verify
    my $ret = script_run("cryptsetup benchmark | tee $bench_log", 180);
    upload_logs("$bench_log");

    if (get_var('FIPS_ENABLED')) {
        foreach my $i ("serpent", "twofish") {
            my $check = script_run "grep '$i' $bench_log | egrep -v 'N\/A\\s+N\/A'";
            die "$i should not be supported anywhere!" if ($check eq 0);
        }
    }
    elsif ($ret) {
        die "Benchmark failed with return value $ret";
    }

    # Here we check the ciphers in the practice with LUKS support, since
    # cryptsetup benchmark does not support cipher+hash combination as a
    # parameter
    assert_script_run "dd if=/dev/urandom of=$crypt_tmp bs=4M count=3";

    my @check_list = (
        {name => "aes",     mode => "xts-plain64", hash => "sha1"},
        {name => "aes",     mode => "xts-plain64", hash => "md5", no_support => 1},
        {name => "aes",     mode => "xts-plain64", hash => "sha256"},
        {name => "aes",     mode => "xts-plain",   hash => "sha512"},
        {name => "aes",     mode => "cbc-plain64", hash => "sha256"},
        {name => "serpent", mode => "xts-plain64", hash => "sha256", no_fips => 1},
        {name => "twofish", mode => "cbc-plain64", hash => "sha1", no_fips => 1},
    );    # Not all the combinations will be checked here

    foreach my $c (@check_list) {
        my $cipher = "@$c{name}-@$c{mode}";

        my $result = script_run "echo -e $crypt_pass | cryptsetup --cipher=$cipher --hash @$c{hash} luksFormat $crypt_tmp";
        if ($result) {
            next if @$c{no_support} || (get_var('FIPS_ENABLED') && @$c{no_fips});
            die "$cipher with @$c{hash} verification failed";
        }

        validate_script_output "cryptsetup luksDump $crypt_tmp", sub {
            m/
            Cipher\sname:\s+@$c{name}.*
            Cipher\smode:\s+@$c{mode}.*
            Hash\sspec:\s+@$c{hash}/sxx
        };

        assert_script_run "echo -e $crypt_pass | cryptsetup -q luksOpen $crypt_tmp $crypt_dev";
        assert_script_run "cryptsetup luksClose $crypt_dev";
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
