# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for a dialog which
# appears on Partitioning Scheme Page while entering too simple password for
# partition encrypting.

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Partitioner::LibstorageNG::TooSimplePasswordDialog;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::WizardPage';

use constant {
    TOO_SIMPLE_PASSWORD_DIALOG => 'inst-userpasswdtoosimple'
};

sub press_yes {
    assert_screen(TOO_SIMPLE_PASSWORD_DIALOG);
    send_key('alt-y');
}

1;
