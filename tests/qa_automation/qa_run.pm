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

sub test_run_list {
    return ();
}

sub junit_type {
    die "you need to overload junit_type in your class";
}

sub test_suite {
    die "you need to overload test_suite in your class";
}

# system boot & login
sub system_login {
    my $self = shift;
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
}

# Call test_run_list and write the result into /root/qaset/config
sub create_qaset_config {
    my $self = shift;
    my @list = $self->test_run_list();
    return unless @list;
    assert_script_run("mkdir -p /root/qaset");
    my $testsuites = "\n\t" . join("\n\t", @list) . "\n";
    assert_script_run("echo 'SQ_TEST_RUN_LIST=($testsuites)' > /root/qaset/config");
}

# Add qa head repo for kernel testing. If QA_SERVER_REPO is set,
# remove all existing zypper repos first
sub prepare_repos {
    my $self = shift;
    my $qa_server_repo = get_var('QA_SERVER_REPO', '');
    if ($qa_server_repo) {
        # Remove all existing repos and add QA_SERVER_REPO
        my $rm_repos = "declare -i n=`zypper repos | wc -l`-2; for ((i=0; i<\$n; i++)); do zypper rr 1; done; unset n; unset i";
        assert_script_run($rm_repos, 300);
        assert_script_run("zypper --no-gpg-check -n ar -f '$qa_server_repo' server-repo");
    }
    assert_script_run "zypper --no-gpg-check -n ar -f '" . get_var('QA_HEAD_REPO') . "' qa-ibs";
    assert_script_run "zypper --gpg-auto-import-keys ref";
    assert_script_run "zypper -n in qa_testset_automation";
}

# Create qaset/config file, reset qaset, and start testrun
sub start_testrun {
    my $self = shift;
    $self->create_qaset_config();
    assert_script_run "/usr/share/qa/qaset/qaset reset";
    my $testsuite = $self->test_suite();
    assert_script_run "/usr/share/qa/qaset/run/$testsuite-run";
}

# Check whether DONE file exists every $interval secs in the background
sub wait_testrun {
    my ($self, $interval) = @_;
    $interval = 30 unless defined $interval;
    my $done_file = '/var/log/qaset/control/DONE';
    my $pattern   = "TESTRUN_FINISHED-" . int(rand(999999));
    my $cmd       = "while [[ ! -f $done_file ]]; do sleep $interval; done; echo $pattern >> /dev/$serialdev";
    type_string "bash -c '$cmd' &\n";
    # Set a extremely high timeout value for wait_serial
    # so that it will wait until test run finished or
    # MAX_JOB_TIME(can be set on openQA webui) reached
    my $ret = wait_serial($pattern, 3600 * 240);
    if ($ret) {
        return 1;
    }
    return 0;
}

# Upload all log tarballs in /var/log/qaset/log
sub qa_upload_logs {
    my ($self, $dir, $pattern) = @_;
    my $output = script_output("find '$dir' -type f -name '$pattern'", 120);
    my @log_files = split("\n", $output);
    # upload logs
    foreach my $log_file (@log_files) {
        $log_file =~ s/^\s+|\s+$//g;
        upload_logs $log_file;
    }
}

# qa_testset_automation validation test
sub run() {
    my $self = shift;
    $self->system_login();
    $self->prepare_repos();
    assert_script_run "zypper repos -u";    # Show all repos for debugging
    $self->start_testrun();
    unless ($self->wait_testrun()) {
        die "Test run didn't finish";
    }

    type_string "grep -E \"http://.*/submission.php.*submission_id=[0-9]+\"  /var/log/qaset/submission/submission-*.log " . "| awk -F\": \"  '{print \$2}' | tee -a /dev/$serialdev\n";
    $self->qa_upload_logs('/var/log/qaset/log', '*.tar.*');

    my $junit_type = $self->junit_type();
    assert_script_run "/usr/share/qa/qaset/bin/junit_xml_gen.py /var/log/qaset/log -s /var/log/qaset/submission -o /tmp/junit.xml -n '$junit_type'";
    parse_junit_log("/tmp/junit.xml");
}

sub test_flags {
    return {important => 1};
}

1;

