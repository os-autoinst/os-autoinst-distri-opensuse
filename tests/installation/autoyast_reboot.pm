# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot after autoyast installation
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    assert_screen("grub2", get_var('AUTOUPGRADE') ? 5900 : 900);
}

1;
