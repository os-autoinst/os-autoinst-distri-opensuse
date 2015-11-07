package qa_run;
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

# qa_testset_automation validation test
sub run() {
    my $self = shift;

    assert_screen "inst-bootmenu", 30;
    send_key "ret";    # boot

    assert_screen "grub2", 15;
    send_key "ret";

    assert_screen "text-login", 50;
    type_string "root\n";
    assert_screen "password-prompt", 10;
    type_password;
    type_string "\n";
    sleep 1;

    # remove SLES
    assert_script_run "zypper rr 1";
    # remove SDK
    assert_script_run "zypper rr 1";

    my $repo = get_var('HOST') . "/assets/repo/" . get_var('REPO_0');
    assert_script_run "zypper -n ar -f $repo sles";
    $repo = get_var('HOST') . "/assets/repo/" . get_var('REPO_1');
    assert_script_run "zypper -n ar -f $repo sdk";

    # Add Repo - http://dist.nue.suse.com/ibs/QA:/Head/SLE-12-SP1/
    assert_script_run "zypper --no-gpg-check -n ar -f " . get_var('QA_HEAD_REPO') . " qa_ibs";

    # refresh repo
    assert_script_run "zypper --gpg-auto-import-keys ref -r qa_ibs";

    # Install - zypper in qa_testset_automation
    assert_script_run "zypper -n in qa_testset_automation";

    assert_script_run "mkdir /root/qaset";
    $self->create_qaset_config();

    # Trigger run script
    my $testsuite = $self->test_suite();
    assert_script_run "/usr/share/qa/qaset/run/$testsuite-run";

    # This tests creates 2 screens 1 Main screen, 1 screen for specific test/module
    # Monitor - Connect to Main Screen
    type_string "screen -r `screen -ls | grep $testsuite | cut -d\".\" -f1`\n";

    # When finished, the screen will terminate
    for (1 .. 60) {
        my $ret = check_screen [qw/qa_screen_done qa_error/], 120;
        if ($ret && $ret->{needle}->has_tag('qa_error')) {
            die "run failed";
        }
        elsif ($ret) {
            last;
        }
        # change the screen periodically to avoid standstill detection for long running tests
        my $time = time;
        type_string "$time\n";
    }
    # output the QADB link
    type_string "grep -E \"http://.*/submission.php.*submission_id=[0-9]+\"  /var/log/qaset/submission/submission-*.log " . "| awk -F\": \"  '{print \$2}' | tee -a /dev/$serialdev\n";

    # can't use upload_log, so do a loop version of it
    assert_script_run "cd /var/log/qaset/log; for i in *.bz2; do curl --form upload=\@\$i " . autoinst_url() . "/uploadlog/`basename \$i`; done";

    # QA DB upload happens for each module
    # output the failed tests to serial console
    assert_script_run "export PS1=#";
    # qa_testset_automation remove the oldlogs, we create it back here for junit collecting information
    assert_script_run "mkdir /var/log/qa/oldlogs; cd /var/log/qa/oldlogs; for i in /var/log/qaset/log/*.bz2; do tar -xjvf \$i; done";

    # test junit
    my $junit_type = $self->junit_type();
    assert_script_run "/usr/share/qa/qaset/bin/junitxml_generator.py -t $junit_type -l /var/log/qaset/runs/ -s /var/log/qaset/submission/ -o /tmp/junit.xml";
    assert_script_run "ls -l /tmp/";
    parse_junit_log("/tmp/junit.xml");
}

sub test_flags {
    return {important => 1};
}

1;

