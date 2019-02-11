# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for a dialog which
# appears on Partitioning Scheme Page while entering too simple password for
# partition encrypting.

# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package Installation::Partitioner::LibstorageNG::TooSimplePasswordDialog;
use strict;
use warnings FATAL => 'all';
use testapi;
use parent 'Installation::AbstractPage';

use constant {
    TOO_SIMPLE_PASSWORD_DIALOG => 'inst-userpasswdtoosimple'
};

sub agree_with_too_simple_password {
    assert_screen(TOO_SIMPLE_PASSWORD_DIALOG);
    send_key('alt-y');
}

1;
