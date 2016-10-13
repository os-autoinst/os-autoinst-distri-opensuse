# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: shibboleth-sp test
# Maintainer: Romanos Dodopoulos <romanos.dodopoulos@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    my $self = shift;
    select_console 'root-console';

    zypper_call "in shibboleth-sp";
    type_string "a2enmod shib";
    assert_script_run "systemctl restart apache2.service";

    assert_script_run "curl --no-buffer http://localhost/Shibboleth.sso/Status | grep 'Cannot connect to shibd process'";

    assert_script_run "curl --no-buffer http://localhost/Shibboleth.sso/Session | grep 'A valid session was not found.'";
}
1;
