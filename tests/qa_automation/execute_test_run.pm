# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary:  to execute testsuites in openQA from QA:Head by running its build up test run script
# Maintainer: Yong Sun  <yosun@suse.com>

use strict;
use File::Basename;
use IO::File;
use Data::Dumper;
use utils;
use testapi;
use ctcs2_to_junit;
use upload_system_log;
use base "opensusebasetest";
use version_utils "is_jeos";

sub run {
    my $timeout  = abs(get_var("MAX_JOB_TIME", 9600) - 1200);         #deduct 20 minutes for previous steps, due to poo#30183
    my $test     = get_var("QA_TESTSUITE") . get_var("QA_VERSION");
    my $runfile  = "/usr/share/qa/tools/test_$test-run";
    my $runfile2 = "/usr/lib/ctcs2/tools/test_$test-run";
    my $run_log  = "/tmp/$test-run.log";

    #execute test run
    script_run("if [ -e $runfile ]; then $runfile |tee $run_log; else $runfile2 |tee $run_log; fi", $timeout);

    save_screenshot;

    #output result to serial0 and upload test log
    #we skip the log conversion on JeOS because we do not use the junit logs and
    #starting with 15SP1 bzip2 is no longer included in the JeOS images
    if (get_var("QA_TESTSUITE") && !is_jeos) {
        assert_script_run('sync', 180);
        my $tarball = "/tmp/testlog.tar.bz2";
        zypper_call('in bzip2');
        assert_script_run("tar cjf $tarball -C /var/log/qa/ctcs2 `ls /var/log/qa/ctcs2/`");
        upload_logs($tarball, timeout => 600);
    }

    #upload system log
    upload_system_logs();

    #assert test result
    my $fail_logs = "\n\n" . script_output("grep -l '1 fail' /var/log/qa/ctcs2/qa_$test-*/* | while read line ; do echo -e \"===> \$line <===\" ; cat -es /var/log/qa/ctcs2/qa_$test*/* | head --lines=500 ; done", 600, proceed_on_failure => 1);
    save_screenshot;
    assert_script_run("grep 'Test run completed successfully' $run_log", fail_message => $fail_logs);
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    # Collect executed test logs
    assert_script_run 'tar -cf /tmp/run_logs.tgz /tmp/*-run.log';
    upload_logs '/tmp/run_logs.tgz';
}
1;
