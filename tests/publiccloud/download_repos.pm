# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Download repositores from the internal server
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base 'consoletest';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::ssh_interactive "select_host_console";

# Get the status of the update repos
# 0 = no repo, 1 = repos already downloaded, 2 = repos downloading
sub get_repo_status {
    return 0 if (script_run("stat ~/repos/qem_download_status.txt") != 0);
    return 1 if (script_run("grep 'Download completed' ~/repos/qem_download_status.txt") == 0);
    return 2;
}

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance


    if (get_var('PUBLIC_CLOUD_SKIP_MU')) {
        # Skip maintenance updates. This is useful for debug runs
        record_info('Skip download', 'Skipping maintenance update download (triggered by setting)');
        return;
    } else {
        # Remove the ~/repos so they can be redownloaded
        if (get_var('PUBLIC_CLOUD_REDOWNLOAD_MU')) {
            script_run("rm -rf ~/repos");
        }
        # Skip if we already downloaded the repos
        if (get_repo_status() == 1) {
            record_info("Downloaded", "Skipping download because the repositories have been already downloaded");
            return;
        }

        assert_script_run("mkdir ~/repos");
        assert_script_run("cd ~/repos");
        # Note: Clear previous qem_download_status.txt file here
        assert_script_run("echo 'Starting download' > ~/repos/qem_download_status.txt");

        set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) unless get_var('MAINT_TEST_REPO');
        my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
        assert_script_run('touch /tmp/repos.list.txt');

        my $ret = 0;
        for my $maintrepo (@repos) {
            next if $maintrepo !~ m/^http/;
            script_run("echo 'Downloading $maintrepo ...' >> ~/repos/qem_download_status.txt");
            my ($parent) = $maintrepo =~ 'https?://(.*)$';
            my ($domain) = $parent =~ '^([a-zA-Z.]*)';
            $ret = script_run "wget --no-clobber -r -R 'robots.txt,*.ico,*.png,*.gif,*.css,*.js,*.htm*' --reject-regex='s390x\\/|ppc64le\\/|kernel*debuginfo*.rpm|src\\/' --domains $domain --no-parent $maintrepo/", timeout => 600;
            if ($ret !~ /0|8/) {
                # softfailure, if repo doesn't exist (anymore). This is required for cloning jobs, because the original test repos could be empty already
                record_soft_failure("Download failed (rc=$ret):\n$maintrepo");
                script_run("echo 'Download failed for $maintrepo ...' >> ~/repos/qem_download_status.txt");
            } else {
                assert_script_run("echo -en '\\n" . ('#' x 80) . "\\n# $maintrepo:\\n' >> /tmp/repos.list.txt");
                assert_script_run("echo 'Downloaded $maintrepo:' \$(du -hs $parent | cut -f1) >> ~/repos/qem_download_status.txt");
                if (script_run("ls $parent/*.repo") == 0) {
                    assert_script_run(sprintf(q(sed -i '1 s/]/_%s]/' %s/*.repo), random_string(4), $parent));
                    assert_script_run("find $parent >> /tmp/repos.list.txt");
                } else {
                    record_soft_failure("No .repo file found in $parent. This directory will be removed.");
                    assert_script_run("echo 'No .repo found for $maintrepo' >> ~/repos/qem_download_status.txt");
                    assert_script_run("rm -rf $parent");
                }
            }
        }
        # Failsafe: Fail if there are no test repositories, otherwise we have the wrong template link
        my $count = scalar @repos;
        my $check_empty_repos = get_var('PUBLIC_CLOUD_IGNORE_EMPTY_REPO', 0) == 0;
        die "No test repositories" if ($check_empty_repos && $count == 0);

        assert_script_run("echo 'Download completed' >> ~/repos/qem_download_status.txt");
        upload_logs('/tmp/repos.list.txt');
        upload_logs('qem_download_status.txt');
        # Failsafe 2: Ensure the repos are not empty (i.e. size >= 100 kB)
        my $size = script_output('du -s ~/repos | awk \'{print$1}\'');
        die "Empty test repositories" if ($check_empty_repos && $size < 100);
    }

    my $total_size = script_output("du -hs ~/repos");
    record_info("Repo size", "Total repositories size: $total_size");
    assert_script_run("find ./ -name '*.rpm' -exec du -h '{}' \\; | sort -h > /root/rpm_list.txt", timeout => 60);
    upload_logs("/root/rpm_list.txt");

    # The maintenance *.repo files all point to download.suse.de, but we are using dist.suse.de, so we need to rename the directory
    assert_script_run("if [ -d ~/repos/dist.suse.de ]; then mv ~/repos/dist.suse.de ~/repos/download.suse.de; fi");
    assert_script_run("cd");
}

sub post_fail_hook {
    # Do not use `script_run` or `script_output` as the disk might be full
    ## cat > /tmp/scriptH69A2.sh << 'EOT_H69A2'; echo H69A2-$?-
    #> du -s ~/repos
    #> EOT_H69A2
    #bash: cannot create temp file for here-document: No space left on device
    #H69A2-1-
    assert_script_run("du -hs ~/repos || true");
    assert_script_run("find ~/repos/ -name '*.rpm' -exec du -h '{}' \\; | sort -h || true");
    assert_script_run("df -h");
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
        publiccloud_multi_module => 1
    };
}

1;

