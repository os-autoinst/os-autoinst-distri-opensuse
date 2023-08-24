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
use strict;
use warnings;
use testapi;
use lockapi;
use version_utils;


sub run {
    barrier_create('rsync_setup', 2);
    barrier_create('rsync_finished', 2);
    mutex_create 'barrier_setup_done';
    select_console 'root-console';

    #preparation of rsync config files
    assert_script_run('curl -v -o /etc/rsyncd.conf ' . data_url('console/rsyncd.conf'));
    assert_script_run 'echo "test42:424242" > /etc/rsyncd.secrets';

    if (is_sle('<12-sp5')) {    #using xinetd on sle 12
        assert_script_run(q{sed -i 's/\(\s*disable\s*=\).*/\1 no/' /etc/xinetd.d/rsync});
        assert_script_run 'rcxinetd restart';
        assert_script_run 'rcxinetd status';
    }
    else {
        assert_script_run 'systemctl restart rsyncd.service';
        assert_script_run 'systemctl status rsyncd.service';
    }

    #making testing files for download
    assert_script_run 'mkdir -p /srv/rsync_test/pub';
    assert_script_run 'echo "content of rsync testing file" > /srv/rsync_test/pub/file1';
    assert_script_run 'echo "content of second file" > /srv/rsync_test/pub/file2';
    assert_script_run 'echo "third file" > /srv/rsync_test/pub/file3';

    #setup of rsync server done
    barrier_wait 'rsync_setup';
    #client tries to list and download files
    barrier_wait 'rsync_finished';

}
1;
