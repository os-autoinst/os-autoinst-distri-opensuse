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
# Summary: Test IMA verify function provided by evmctl
# Note: This case should come after 'ima_apprasial_digital_signatures'
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#49562

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $sample_app = '/usr/bin/yes';

    my $mok_priv = '/root/certs/key.asc';
    my $cert_der = "/root/certs/ima_cert.der";

    # Make sure IMA is in the enforce mode
    validate_script_output "grep 'ima_appraise=fix' /etc/default/grub || echo 'IMA enforced'", sub { m/IMA enforced/ };
    assert_script_run("test -e /etc/sysconfig/ima-policy", fail_message => 'ima-policy file is missing');

    assert_script_run "evmctl ima_sign -a sha256 -k $mok_priv $sample_app";

    validate_script_output "getfattr -m security.ima -d $sample_app", sub {
        # Base64 armored security.ima content (358 chars), we do not match the
        # last three ones here for simplicity
        m/security\.ima=[0-9a-zA-Z+\/]{355}/;
    };
    assert_script_run "evmctl ima_verify -k $cert_der $sample_app";

    assert_script_run "setfattr -x security.ima $sample_app";

    validate_script_output "evmctl ima_verify -k $cert_der $sample_app || true", sub {
        m/getxattr\sfailed.*\Q$sample_app\E.*
          No\sdata\savailable/sxx
    };
}

sub test_flags {
    return {always_rollback => 1};
}

1;
