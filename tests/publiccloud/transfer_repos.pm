# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: rsync
# Summary: Transfer repositories to the public cloud instasnce
#
# Maintainer: <qa-c@suse.de>

use Mojo::Base 'publiccloud::ssh_interactive_init';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use publiccloud::utils "select_host_console";
use publiccloud::aws_client;

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

        # Mitigate occasional CSP network problems (especially one CSP is prone to those issues!)
        # Delay of 2 minutes between the tries to give their network some time to recover after a failure

        my $bucket = get_var("PUBLIC_CLOUD_UPDATE_REPOS_S3_BUCKET", "ilausuch.suse.testbucket");
        my $key = get_var("PUBLIC_CLOUD_UPDATE_REPOS_S3_KEy", "repos.tgz");
        
        my $aws = publiccloud::aws_client->new();
        $aws->init();
        my $aws_access_key = $aws->key_id;
        my $aws_secret_key = $aws->key_secret;
        
        $args->{my_instance}->run_ssh_command(cmd => "sudo zypper in -y aws-cli");
        $args->{my_instance}->run_ssh_command(cmd => "AWS_ACCESS_KEY_ID=$aws_access_key AWS_SECRET_ACCESS_KEY=$aws_secret_key aws s3 cp s3://$bucket/$key /tmp");
        $args->{my_instance}->run_ssh_command(cmd => "rm -rf /tmp/repos");
        $args->{my_instance}->run_ssh_command(cmd => "cd /tmp && tar zxvf /tmp/$key");
        #NOTE: the final structure should  be /tmp/repos

        $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec sed -i 's,http://,/tmp/repos/repos/,g' '{}' \\;");
        $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec zypper ar -p10 '{}' \\;");
        $args->{my_instance}->run_ssh_command(cmd => "sudo find /tmp/repos/ -name *.repo -exec echo '{}' \\;");

        $args->{my_instance}->run_ssh_command(cmd => "zypper lr -P");
    }
}

1;

