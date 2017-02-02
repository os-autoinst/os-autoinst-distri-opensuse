# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Live Patching regression testsuite
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use base 'kgrafttest';
use testapi;
use qam;

use strict;
use warnings;

sub run() {
    my $svirt = select_console('svirt');
    my $name  = get_var('VIRSH_GUESTNAME');
    $svirt->attach_to_running({name => $name});
    reset_consoles;
    select_console('sut');
    select_console('root-console');

    # full LTP, #TODO --> look at qa_automation , rework  qa_run.pm to library

    script_run(qq{/usr/lib/ctcs2/tools/test_ltp-run; echo "ltp-done" > /dev/$serialdev}, 0);
    wait_serial(qr/ltp-done/, 36000);

    save_screenshot;

    script_run('btrfs fi sync /', 60);

    $svirt->run_cmd("virsh reset $name");

}

1;
