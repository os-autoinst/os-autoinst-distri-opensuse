# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic smoke test to verify SUSE/openSUSE efiboot
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base qw(opensusebasetest);
use testapi;
use transactional qw(trup_call check_reboot_changes);
use version_utils qw(is_sle_micro);
use utils qw(assert_secureboot_status);

sub run {
    select_console('root-console');

    trup_call('bootloader');
    check_reboot_changes;

    my $efiboot = script_output('efibootmgr -v', proceed_on_failure => 1);

    unless ($efiboot == /^Boot\w{4}\*\s(opensuse|sle)-secureboot/) {
        die 'System has booted from unexpected efi boot record!';
    }

    validate_script_output('mokutil --sb-state', sub { m/secureboot enabled/i });
}

1;
