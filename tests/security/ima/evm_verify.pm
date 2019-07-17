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
# Summary: Test EVM verify function provided by evmctl
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#53585

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $test_app = "/usr/bin/yes";
    my $mok_priv = "/root/certs/key.asc";
    my $cert_der = "/root/certs/ima_cert.der";
    my $mok_pass = "suse";

    assert_script_run "$test_app --version";

    assert_script_run "evmctl sign -p$mok_pass -k $mok_priv $test_app";
    validate_script_output "getfattr -m security.evm -d $test_app", sub {
        # Base64 armored security.ima content (358 chars), we do not match the
        # last three ones here for simplicity
        m/security\.evm=[0-9a-zA-Z+\/]{355}/;
    };
    assert_script_run "evmctl verify -k $cert_der $test_app";

    # Empty evm attribute and verify
    assert_script_run "setfattr -x security.evm $test_app";
    validate_script_output "evmctl verify -k $cert_der $test_app || true", sub {
        m/No data available/;
    };
}

sub test_flags {
    return {always_rollback => 1};
}

1;
