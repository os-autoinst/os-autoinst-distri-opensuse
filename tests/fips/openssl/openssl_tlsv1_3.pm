# Copyright (C) 2020 SUSE LLC
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
# Summary: openssl 1.1.1 supports and negotiates by default the new TLS 1.3 protocol.
#          Applications that leave everything to the openssl library will automatically
#          start to negotiate the TLS 1.3 protocol. However, many packages have their
#          own settings which override the library defaults and these either have to be
#          recompiled against openssl 1.1.1 or might even need extra patching.
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#64992, tc#1744100

use base "consoletest";
use testapi;
use strict;
use warnings;
use apachetest;

sub run {
    select_console 'root-console';
    setup_apache2(mode => 'SSL');

    # List the supported ciphers and make sure TLSV1.3 is there
    validate_script_output 'openssl ciphers -v', sub { m/TLSv1\.3.*/xg };

    # Establish a transparent connection to apache server to check the TLS protocol
    validate_script_output 'echo | openssl s_client -connect localhost:443 2>&1', sub { m/TLSv1\.3.*/xg };

    # Transfer a URL to check the TLS protocol
    validate_script_output 'curl -Ivvv  https://www.google.com 2>&1', sub { m/TLSv1\.3.*/xg };
}

1;
