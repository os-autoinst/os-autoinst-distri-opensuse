# secure boot libs
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: secure boot enablment/disablement support
#
# Maintainer: QE Security <none@suse.de>

package security::secureboot;

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use Exporter 'import';
use Utils::Architectures 'is_aarch64';
use bootloader_setup qw(tianocore_disable_secureboot);
use version_utils qw(is_sle);

our @EXPORT = qw(handle_secureboot);

sub handle_secureboot {
    my ($self, $sb_state, $sb_opt) = @_;
    my $boot_method = ((is_aarch64 && is_sle('>=16')) ? 'wait_boot_past_bootloader' : 'wait_boot');

    record_info('bsc#1189988:', 'Disabling Secure Boot due to known IMA fix mode issue');
    $self->wait_grub(bootloader_time => 200);

    if (defined $sb_opt && $sb_opt eq 're_enable') {
        $self->tianocore_disable_secureboot('re_enable');
    } else {
        $self->tianocore_disable_secureboot;
    }

    $self->$boot_method(textmode => 1);
}

1;
