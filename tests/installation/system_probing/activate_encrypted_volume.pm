# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module to activate encrypted volume.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run {
    my $encrypted_volume = $testapi::distri->get_encrypted_volume_activation();
    $encrypted_volume->enter_volume_encryption_password($password);
    $encrypted_volume->accept_password();
}

1;
