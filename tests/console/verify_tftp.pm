# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: this test checks that tftp-server runs properly in the SUT.
# Can be used to validate tftp service in the installed system.
# - Verify that service is up and running
# - Connect using tftp command, get test file and check
# - Connect using tftp command, put test file back
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    assert_script_run 'echo "hello world" > /srv/tftpboot/tmp.txt';
    assert_script_run 'chown -R tftp /srv/tftpboot/tmp.txt';

    assert_script_run 'tftp -v localhost -c get tmp.txt';
    # Compare that downloaded file is identical to the file on the server
    assert_script_run 'diff -u tmp.txt /srv/tftpboot/tmp.txt';

    assert_script_run 'tftp -v localhost -c put tmp.txt';
}

1;
