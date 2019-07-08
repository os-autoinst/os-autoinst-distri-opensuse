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
# Summary: Test EVM protection using HMACs
# Note: This case should come after 'evm_setup'
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#53579

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup "replace_grub_cmdline_settings";
use power_action_utils "power_action";

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $fstype     = 'ext4';
    my $sample_app = '/usr/bin/yes';
    my $sample_cmd = 'yes --version';

    my $findret = script_output("/usr/bin/find / -fstype $fstype -type f -uid 0 -exec evmctl -a sha256 ima_hash '{}' \\;", 1800, proceed_on_failure => 1);
    # Allow "No such file" message for the files in /proc because they are mutable
    my @finds = split /\n/, $findret;
    $_ =~ m/\/proc\/.*No such file/ or die "Failed to create security.evm for $_" foreach (@finds);

    validate_script_output "getfattr -m . -d $sample_app", sub {
        # Base64 armored security.evm and security.ima content (50 chars), we
        # do not match the last three ones here for simplicity
        m/security\.evm=[0-9a-zA-Z+\/]{27}.*
          security\.ima=[0-9a-zA-Z+\/]{47}/sxx;
    };

    # Remove security.evm attribute manually, and verify it is empty
    assert_script_run "setfattr -x security.ima $sample_app";
    validate_script_output "getfattr -m security.evm -d $sample_app", sub { m/^$/ };

    replace_grub_cmdline_settings('evm=fix ima_appraise=fix', '', 1);

    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1);
    $self->select_serial_terminal;

    my $ret = script_output($sample_cmd, 30, proceed_on_failure => 1);
    die "$sample_app should not have permission to run" if ($ret !~ "\Q$sample_app\E: *Permission denied");
}

sub test_flags {
    return {always_rollback => 1};
}

1;
