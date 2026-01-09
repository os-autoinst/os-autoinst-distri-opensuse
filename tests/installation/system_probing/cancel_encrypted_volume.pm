# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Test module to cancel encrypted volume activation.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'y2_installbase';

sub run {
    my $encrypted_volume = $testapi::distri->get_encrypted_volume_activation();
    $encrypted_volume->cancel();
}

1;
