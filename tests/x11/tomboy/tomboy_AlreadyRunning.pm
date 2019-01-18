# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: already running
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248878

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    # open tomboy
    x11_start_program('tomboy note', target_match => 'test-tomboy_AlreadyRunning-1');
    send_key "alt-f4";

    # open again
    x11_start_program('tomboy note', target_match => 'test-tomboy_AlreadyRunning-2');
    send_key "alt-f4";
}

1;
