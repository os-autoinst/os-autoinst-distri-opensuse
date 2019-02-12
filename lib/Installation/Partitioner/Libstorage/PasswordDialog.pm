# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Password Dialog that
# appears while selecting LVM-based partitioning proposal.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::Libstorage::PasswordDialog;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::AbstractPage';

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
