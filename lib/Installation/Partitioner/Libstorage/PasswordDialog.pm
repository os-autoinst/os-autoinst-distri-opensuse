# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Password Dialog that
# appears while selecting LVM-based partitioning proposal.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::Libstorage::PasswordDialog;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';

use constant {
    ENTER_PASSWORD_DIALOG => 'inst-encrypt-password-prompt'
};

sub enter_password {
    assert_screen(ENTER_PASSWORD_DIALOG);
    send_key('alt-p');
    type_password();
}

sub enter_password_confirmation {
    assert_screen(ENTER_PASSWORD_DIALOG);
    send_key('alt-r');
    type_password();
}

sub press_ok {
    assert_screen(ENTER_PASSWORD_DIALOG);
    send_key('alt-o');
}

1;
