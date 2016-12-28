# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple PHP5 code hosted locally
#   This test requires the Web and Scripting module on SLE. Also, it
#   should preferably be executed after the 'console/http_srv' test.
# Maintainer: Romanos Dodopoulos <romanos.dodopoulos@suse.cz>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    select_console 'root-console';

    # install requirements
    zypper_call "in php5 apache2-mod_php5";
    assert_script_run "a2enmod php5";

    # configure and restart the web server
    type_string qq{echo -e "<?php\nphpinfo()\n?>" > /srv/www/htdocs/index.php\n};
    assert_script_run "systemctl restart apache2.service";

    # test that PHP works
    assert_script_run "curl --no-buffer http://localhost/index.php | grep \"\$(uname -s -n -r -v -m)\"";
}
1;
