# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rsync
# Summary: running rsync server, client tries to list and download files
#  - setup rsync server
#  - make files for downloading
#  - run rsync server
#  - client tries to list files
#  - client tries to download files
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'consoletest';
use testapi;
use lockapi;
use utils "zypper_call";

sub run {
    select_console 'root-console';
    zypper_call('in rsync') if (script_run('rpm -qi rsync') == 1);
    select_console 'user-console';

    #waiting for configuration of rsync server
    mutex_wait 'barrier_setup_done';
    barrier_wait 'rsync_setup';

    assert_script_run 'export RSYNC_PASSWORD=424242';

    #trying to list and download testing files
    validate_script_output 'rsync rsync://test42@server', sub { m/Testing files available for download/ };

    validate_script_output 'rsync rsync://test42@server/pub/', sub { m/.*file1.*file2.*file3.*/s };

    assert_script_run 'rsync -v --progress --partial rsync://test42@server/pub/file1 ./';

    assert_script_run 'rsync -aPv rsync://test42@server/pub/file2 ./';

    barrier_wait 'rsync_finished';
}
1;
