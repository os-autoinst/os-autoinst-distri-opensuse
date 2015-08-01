use base "opensusebasetest";
use testapi;

# qa_testset_automation validation test
sub run() {
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

    # Add Repo - http://dist.nue.suse.com/ibs/QA:/Head/SLE-12-SP1/
    assert_script_run "zypper --no-gpg-check -n ar -f " . get_var('QA_HEAD_REPO') . " qa_ibs";

    # refresh repo
    assert_script_run "zypper --gpg-auto-import-keys ref -r qa_ibs";

    # Install - zypper in qa_testset_automation
    assert_script_run "zypper -n in qa_testset_automation";

    # Trigger run script
    # Stress Validation - /usr/share/qa/qaset/run/acceptance-run
    assert_script_run "/usr/share/qa/qaset/run/" . get_var('QA_TESTSET') . "-run";

    # This tests creates 2 screens 1 Main screen, 1 screen for specific test/module
    # Monitor - Connect to Main Screen
    type_string "screen -r `screen -ls | grep regression | cut -d\".\" -f1`\n";

    # When finished, the screen will terminate
    for (1..60) {
        my $ret = check_screen [qw/qa_screen_done qa_error/], 120;
        if ($ret && $ret->{needle}->has_tag('qa_error')) {
            die "run failed";
        }
        elsif ($ret) {
            last;
        }
        # change the screen periodically to avoid standstill detection for long running tests
        send_key '.';
    }
    # output the QADB link
    type_string  "grep -E \"http://.*/submission.php.*submission_id=[0-9]+\"  /var/log/qaset/submission/submission-*.log " .
                 "| awk -F\": \"  '{print $2}' | tee -a /dev/$serialdev\n";

    # can't use upload_log, so do a loop version of it
    assert_script_run "cd /var/log/qaset/log; for i in *.bz2; do curl --form upload=\@\$i " . autoinst_url() ."/uploadlog/`basename \$i`; done";

    # QA DB upload happens for each module
    # output the failed tests to serial console
    type_string "export PS1=#\n";
    type_string "find /var/log/qa/oldlogs/ -name test_results | xargs grep -l -B1 ^1 | tee -a /dev/$serialdev\n";
    check_screen 'no_output_from_qa_find';
}

sub test_flags {
    return { important => 1 };
}

1;

