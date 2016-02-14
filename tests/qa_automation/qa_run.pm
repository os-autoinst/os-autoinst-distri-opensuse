# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package qa_run;
use strict;
use warnings;
use base "opensusebasetest";
use testapi;

sub create_qaset_config() {
    my $self = shift;
    my @list = $self->test_run_list();
    return unless @list;
    assert_script_run "echo 'SQ_TEST_RUN_LIST=(\n " . join("\n ", @list) . "\n )' > /root/qaset/config";
}

sub test_run_list() {
    return ();
}

sub junit_type() {
    die "you need to overload junit_type in your class";
}

sub test_suite() {
    die "you need to overload test_suite in your class";
}

sub wait_testrun {
    my ($interval) = @_;
    $interval = 120 unless defined $interval;

    my $done_file = '/var/log/qaset/control/DONE';
    while (1) {
        my $pattern = "TESTRUN_FINISHED-" . int(rand(999999));
        type_string "sleep 0.1 ; [[ -f $done_file ]] && echo '$pattern' | tee /dev/$serialdev\n";
        my $ret = wait_serial($pattern, $interval);
        if ($ret) {
            return 1;
        }
    }
    return 0;
}

sub qa_upload_logs {
    my ($dir, $pattern) = @_;
    my $output = script_output("find '$dir' -type f -name '$pattern'", 120);
    my @log_files = split("\n", $output);
    # upload logs
    foreach my $log_file (@log_files) {
        $log_file =~ s/^\s+|\s+$//g;
        upload_logs($log_file);
    }
}

# qa_testset_automation validation test
sub run() {
    my $self = shift;
    # system boot & login
    assert_screen "inst-bootmenu", 30;
    send_key "ret";
    assert_screen "grub2", 15;
    send_key "ret";
    assert_screen "text-login", 50;
    type_string "root\n";
    assert_screen "password-prompt", 10;
    type_password;
    type_string "\n";
    sleep 2;
    # Repo & Package
    assert_script_run "zypper --no-gpg-check -n ar -f " . get_var('QA_HEAD_REPO') . " qa_ibs";
    assert_script_run "zypper --gpg-auto-import-keys ref";
    assert_script_run "zypper -n in qa_testset_automation";
    assert_script_run "mkdir /root/qaset";
    $self->create_qaset_config();
    # Start testrun
    assert_script_run("/usr/share/qa/qaset/qaset reset");
    my $testsuite = $self->test_suite();
    assert_script_run "/usr/share/qa/qaset/run/$testsuite-run";
    # Wait for testrun to finish
    my $interval = 120;
    unless (wait_testrun($interval)) {
        die "Test run didn't finish";
    }
    # Print the QADB link
    type_string "grep -E \"http://.*/submission.php.*submission_id=[0-9]+\"  /var/log/qaset/submission/submission-*.log " . "| awk -F\": \"  '{print \$2}' | tee -a /dev/$serialdev\n";
    # Upload log tarballs
    qa_upload_logs('/var/log/qaset/log', '*.tar.*');
    # junit log
    my $junit_type = $self->junit_type();
    assert_script_run "/usr/share/qa/qaset/bin/junit_xml_gen.py /var/log/qaset/log -s /var/log/qaset/submission -o /tmp/junit.xml -n '$junit_type'";
    parse_junit_log("/tmp/junit.xml");
}

sub test_flags {
    return {important => 1};
}

1;

