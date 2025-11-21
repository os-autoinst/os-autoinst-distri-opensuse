# SUSE's openQA tests
#
# Copyright 2019-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rsync
# Summary: Transfer repositories to the public cloud instasnce
#
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils;
use publiccloud::utils qw(zypper_remote_call);
use publiccloud::ssh_interactive "select_host_console";
use maintenance_smelt qw(is_embargo_update);
use version_utils qw(is_sle_micro is_transactional);

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    my $instance = $args->{my_instance};
    my $remote = $instance->username . '@' . $args->{my_instance}->public_ip;
    my $repodir = "/opt/repos/";

    assert_script_run('du -sh ~/repos');
    my $timeout = 2400;
    my $err = $instance->ssh_script_run(cmd => "which rsync") // -1;
    if ($err > 0) {
        my $cmd = (is_transactional) ? "sudo transactional-update -n in rsync" : "sudo zypper -n in rsync";
        $instance->zypper_remote_call(cmd => $cmd, timeout => 420, retry => 6, delay => 60);
    }
    # In Incidents there is INCIDENT_REPO instead of MAINT_TEST_REPO
    # Those two variables contain list of repositories separated by comma
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) unless get_var('MAINT_TEST_REPO');

    # We need to exclude embargoed incidents
    my @all_repos = split(/,/, get_var('MAINT_TEST_REPO'));
    for my $exclude (split(/,/, get_var('EXCLUDED_TEST_REPO', ''))) {
        for my $index (reverse 0 .. $#all_repos) {
            splice(@all_repos, $index, 1, ()) if ($all_repos[$index] =~ /$exclude/);
        }
    }

    my @repos;
    my ($incident, $type);
    for my $maintrepo (@all_repos) {
        if (is_sle_micro(">=6.0")) {
            push(@repos, $maintrepo);
        } else {
            ($incident, $type) = ($2, $1) if ($maintrepo =~ /\/(PTF|Maintenance):\/(\d+)/g);
            push(@repos, $maintrepo) unless (is_embargo_update($incident, $type)); }
    }

    s/https?:\/\/.*\/ibs\/// for @repos;

    # Create list of directories for rsync
    for my $repo (@repos) {
        assert_script_run("echo $repo | tee -a /tmp/transfer_repos.txt");
    }
    # VM repos.dir support preparation
    $instance->ssh_assert_script_run("sudo mkdir $repodir;sudo chmod 777 $repodir");
    # Mitigate occasional CSP network problems (especially one CSP is prone to those issues!)
    # Delay of 2 minutes between the tries to give their network some time to recover after a failure
    # For rsync the ~/repos/./ means that the --relative will take efect after.
    # * The --relative (-R) option is implied when --files-from is specified.
    # * The --dirs (-d) option is implied whn --files-from is specified.
    # * The --archive (-a) option's behavior does not imply --recursive (-r) when --files-from is specified.
    # --recursive (-r), --update (-u), --archive (-a), --human-readable (-h), --rsh (-e)
    script_retry("rsync --timeout=$timeout -ruahd -e ssh --files-from /tmp/transfer_repos.txt ~/repos/./ '$remote:$repodir'", timeout => $timeout + 10, retry => 3, delay => 120);

    my $total_size = $instance->ssh_script_output(cmd => "du -hs $repodir");
    record_info("Repo size", "Total repositories size: $total_size");
    $instance->ssh_assert_script_run("find $repodir -name '*.rpm' -exec du -h '{}' + | sort -h > /tmp/rpm_list.txt", timeout => 60);
    $instance->upload_log('/tmp/rpm_list.txt');

    if (is_sle_micro(">=6.0")) {
        my $counter = 0;
        for my $repo (@repos) {
            $instance->zypper_remote_call("sudo zypper ar -p10 " . $repodir . $repo . " ToTest_$counter");
            $counter += 1;
        }
    }
    else {
        $instance->ssh_assert_script_run("sudo find $repodir -name *.repo -exec sed -i 's,http://download.suse.de/ibs/,$repodir,g' '{}' \\;");
        $instance->zypper_remote_call("sudo find $repodir -name *.repo -exec zypper ar -p10 '{}' \\;");
        $instance->ssh_assert_script_run("sudo find $repodir -name *.repo -exec echo '{}' \\;");
    }

    $instance->zypper_remote_call("zypper lr -P");
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

1;
