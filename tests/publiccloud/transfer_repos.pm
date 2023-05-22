# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rsync
# Summary: Transfer repositories to the public cloud instasnce
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::ssh_interactive "select_host_console";
use publiccloud::utils "is_embargo_update";

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $remote = $args->{my_instance}->username . '@' . $args->{my_instance}->public_ip;
    my @addons = split(/,/, get_var('SCC_ADDONS', ''));
    my $skip_mu = get_var('PUBLIC_CLOUD_SKIP_MU', 0);

    # Trigger to skip the download to speed up verification runs
    if ($skip_mu) {
        record_info('Skip download', 'Skipping maintenance update download (triggered by setting)');
    } else {
        assert_script_run('du -sh ~/repos');
        my $timeout = 2400;

        $args->{my_instance}->retry_ssh_command(cmd => "which rsync || sudo zypper -n in rsync", timeout => 420, retry => 6, delay => 60);

        # In Incidents there is INCIDENT_REPO instead of MAINT_TEST_REPO
        # Those two variables contain list of repositories separated by comma
        set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) unless get_var('MAINT_TEST_REPO');

        # We need to exclude embargoed incidents
        my @all_repos = split(/,/, get_var('MAINT_TEST_REPO'));
        my @repos;
        my $incident;
        for my $maintrepo (@all_repos) {
            $incident = $1 if $maintrepo =~ /\/Maintenance:\/(\d+)/g;
            push(@repos, $maintrepo) unless (is_embargo_update($incident));
        }

        s/http*:\/\/// for @repos;

        # Create list of directories for rsync
        my $directories;
        $directories .= "$_\n" foreach @repos;
        assert_script_run("echo -en '$directories' | tee /tmp/transfer_repos.txt");

        # Mitigate occasional CSP network problems (especially one CSP is prone to those issues!)
        # Delay of 2 minutes between the tries to give their network some time to recover after a failure
        # For rsync the ~/repos/./ means that the --relative will take efect after.
        script_retry("rsync --timeout=$timeout -uahRd -e ssh --files-from /tmp/transfer_repos.txt ~/repos/./ '$remote:/tmp/repos/'", timeout => $timeout + 10, retry => 3, delay => 120);
        $args->{my_instance}->ssh_assert_script_run("sudo find /tmp/repos/ -name *.repo -exec sed -i 's,http://,/tmp/repos/,g' '{}' \\;");
        $args->{my_instance}->ssh_assert_script_run("sudo find /tmp/repos/ -name *.repo -exec zypper ar -p10 '{}' \\;");
        $args->{my_instance}->ssh_assert_script_run("sudo find /tmp/repos/ -name *.repo -exec echo '{}' \\;");

        $args->{my_instance}->ssh_assert_script_run("zypper lr -P");
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
