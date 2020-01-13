# SUSE's openQA tests
#
# Copyright © 2017-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for any orphaned packages. There should be none in fully
#   supported systems
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: poo#19606

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_upgrade';

sub run {
    select_console 'root-console';
    # Save the orphaned packages list to one log file and upload the log, so QA can use this log to report bug
    my $cmd = 'zypper pa --orphaned | grep -v "\(release-DVD\|release-dvd\|openSUSE-release\|skelcd\)" | (! grep "@System") > /tmp/orphaned.log';
    # there are orphans on older, unsupported openSUSE versions which we
    # upgrade from. They will most likely never be fixed
    my $expect_failure = is_upgrade && get_var('HDD_1') =~ /\b(1[123]|42)[\.-]/;
    set_var('ZYPPER_ORPHANED_CHECK_ONLY', get_var('ZYPPER_ORPHANED_CHECK_ONLY', $expect_failure));
    if (get_var('ZYPPER_ORPHANED_CHECK_ONLY')) {
        script_run($cmd);
    }
    else {
        assert_script_run($cmd, fail_message => "Orphaned packages found, set 'ZYPPER_ORPHANED_CHECK_ONLY' to only check and not fail the test");
    }
}

sub post_fail_hook {
    my $self = shift;

    $self->export_logs();
    upload_logs '/tmp/orphaned.log';
}

1;
