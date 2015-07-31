use base "opensusebasetest";
use testapi;

# qa_testset_automation validation test
sub run() {
	become_root;	
	
	# Add Repo - http://dist.nue.suse.com/ibs/QA:/Head/SLE-12-SP1/
	assert_script_run "zypper rr 1";
	assert_script_run "zypper --no-gpg-check -n ar -f " . get_var('QA_HEAD_REPO') . " qa_ibs";
	assert_script_run "zypper --no-gpg-check -n ar -f http://dist.nue.suse.com/install/SLP/SLE-12-SP1-Server-TEST/x86_64/DVD1/ sles";
	assert_script_run "zypper --no-gpg-check -n ar -f http://147.2.207.1/dist/install/SLP/SLE-12-SP1-SDK-Alpha2/x86_64/dvd1/ sdk";
	assert_script_run "zypper lr -U";

	# refresh repo
    assert_script_run "zypper --gpg-auto-import-keys ref -r qa_ibs";

	# Install - zypper in qa_testset_automation
	assert_script_run "zypper -n in qa_testset_automation";

	# Change the list for qaset
	type_string "mkdir /root/qaset\n";
	type_string "echo \"SQ_TEST_RUN_LIST=( \n _reboot_off \n cpio \n findutils \n)\" \ > /root/qaset/config\n";
	type_string "echo \"SUSE Linux Enterprise Server 12 SP1 Alpha2 (x86_64) - Kernel \" > /etc/issue\n";	

	# Trigger run script
	#    Stress Validation - /usr/share/qa/qaset/run/acceptance-run
	assert_script_run "/usr/share/qa/qaset/run/regression-run";

	#        This tests creates 2 screens 1 Main screen, 1 screen for specific test/module
	#        Monitor - Connect to Main Screen
	type_string "screen -r `screen -ls | grep regression | cut -d\".\" -f1`\n";

	#        When finished, /var/log/qaset/control/DONE will appear
	for (1..60) {
	  my $ret = check_screen [qw/qa_screen_done qa_error/], 120;
	  if ($ret && $ret->{needle}->has_tag('qa_error')) {
	    die "run failed";
	  }
      elsif ($ret) {
        last;
      }

	}
	# output the QADB link
	type_string  "grep -E \"http://.*/submission.php.*submission_id=[0-9]+\"  /var/log/qaset/submission/submission-*.log | awk -F\": \"  '{print $2}' | tee -a /dev/$serialdev\n";

    assert_script_run("cd /var/log/qaset/log; for i in *.bz2; do curl --form upload=\@\$i " . autoinst_url() . 
                      "/uploadlog/`basename \$i`; done");

    #        QA DB upload Happens for each module
    # output the failed tests to serial console
    type_string "export PS1=#\n";
    type_string "find /var/log/qa/oldlogs/ -name test_results | xargs grep -l -B1 ^1 | tee -a /dev/$serialdev\n";
    check_screen 'no_output_from_qa_find';

	#        Results - /var/log/qa/oldlogs/2015-07-28-19-55-53/ctcs2/qa_cracklib-2015-07-28-19-54-39/test_results
	#        If cat /var/log/qa/oldlogs/2015-07-28-19-55-53/ctcs2/qa_cracklib-2015-07-28-19-54-39/test_results | grep -B1 ^1 then FAIL
	#        Each arch - s390s ppc64le x86_64 xen
}

sub test_flags {
    return { important => 1 };
}

1;

