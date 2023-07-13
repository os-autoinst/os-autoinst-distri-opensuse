=head1 s390base

Helper functions for s390 console tests

=cut
# SUSE’s openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: helper functions for s390 console tests

package s390base;
use base "consoletest";
use testapi;
use utils;
use strict;
use warnings;
use Utils::Logging qw(tar_and_upload_log export_logs);

=head2 execute_script

 execute_script($script, $scriptargs, $timeout);

Execute C<$script> with arguments C<$scriptargs> and upload STDERR and STDOUT as script logs.
The maximum execution time of the script is defined by C<$timeout>.
=cut

sub execute_script {
    my ($self, $script, $scriptargs, $timeout) = @_;
    assert_script_run("./$script $scriptargs 2>&1 | tee --append logs/$script.log", timeout => $timeout);
    save_screenshot;
}

=head2 upload_logs_and_cleanup

  upload_logs_and_cleanup

Collect and upload logs for investigation. cleanup test suite files.

=cut

sub upload_logs_and_cleanup {
    my ($self) = @_;
    export_logs();

    my $test_name = get_var('IBM_TESTSET') . get_var('IBM_TESTS');
    tar_and_upload_log("/root/$test_name/logs/", "/tmp/$test_name.tar.bz2");
}

=head2 post_fail_hook

  post_fail_hook();

Executed when a module fails.

=cut

sub post_fail_hook {
    my ($self) = @_;
    $self->upload_logs_and_cleanup();
}

=head2 post_run_hook

 post_run_hook();

Executed when a module finishes.

=cut

sub post_run_hook {
    my ($self) = @_;
    $self->upload_logs_and_cleanup();
}

=head2 pre_run_hook

  pre_run_hook();

Executed before method run.
Fetch the testcase and common libraries from openQA server.

=cut

sub pre_run_hook {
    my ($self) = @_;
    my $path = data_url("s390x");
    my $tc = get_required_var('IBM_TESTSET') . get_required_var('IBM_TESTS');
    my $script_path = "$path/$tc/$tc.tgz";
    my $commonsh_path = "$path/lib/common.tgz";
    select_console 'root-console';

    # remove previous files from SUT
    assert_script_run("rm -rf /root/$tc/");
    # get new version of test scripts
    assert_script_run("mkdir -p /root/$tc/");
    assert_script_run("cd /root/$tc/");
    assert_script_run("wget $script_path");
    assert_script_run("tar -xf $tc.tgz");
    assert_script_run("mkdir -p lib && cd lib && rm -f common.tgz");
    assert_script_run("wget $commonsh_path");
    assert_script_run("tar -xf common.tgz");
    assert_script_run("cd /root/$tc/");
    assert_script_run('mkdir logs');
    assert_script_run("chmod +x ./*.sh");
    save_screenshot;
    $self->SUPER::pre_run_hook;
}

1;
# vim: set sw=4 et:
