# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package qaset_pre_patch_run;
# Summary: Simplify test reporting for qa_automation tests
#
# This execution is entirely based on qa_automation/qa_run. The test result is simplfied to only show failed testcases
# triggered by regression in product if it is running with qaset_post_patch_run. It also can be run without qaset_post_patch_run if
# INDEPENDENT_RUN is set to 1;
# Using YAML_SCHEDULE to schedule is recommended to keep flexibility.
# INDEPENDENT_RUN schedule as follows:
#name: bash
#vars:
#    DISABLE_SUBMIT_QADB: 1
#    USER_SPACE_TEST-SUITES: bash openssl
#    TESTCASES_BLACKLIST: bash.run-appendop.sh bash.run-array.sh
#    INDEPENDENT_RUN: 1
#schedule:
#    - boot/boot_to_desktop
#    - qa_automation/qaset_pre_patch_run
# qaset_pre_patch_run, patch_and_reboot and qaset_post_patch_run should schedule in order.
#
# features added:
# 1. Only failed test case names triggered by regression are show on result page.
# 2. QADB url of comparison of before update and after is posted under testcase name.
# 3. Added var TESTCASES_BLACKLIST which can mask some test cases.
# 4. Run multiple testsuites.
# 5. disble/enable QADB submission with var DISABLE_SUBMIT_QADB.
#
# Maintainer: Tony Yuan <tyuan@suse.com>

use strict;
use warnings;
use base "qa_run";
use testapi qw(is_serial_terminal :DEFAULT);
use utils;

sub test_run_list {
    return ('_reboot_off', @{get_var_array('USER_SPACE_TESTSUITES')});
}

# Call test_run_list and write the result into /root/qaset/config
sub qaset_config {
    my $self = shift;
    my @list = test_run_list();
    return unless @list;
    if (get_var("DISABLE_SUBMIT_QADB")) {
        # disable submission
        assert_script_run("sed -i '/sq_qadb_server_switch Nuremberg/,/already/ {s/^/#/}' /usr/share/qa/qaset/qavm/sq-result.sh");
        assert_script_run(q(sed -i '/clean/aecho wwww >> \${SQ_TEST_SUBMISSION_DIR}/submission-\${_sq_run}.log' /usr/share/qa/qaset/qavm/sq-result.sh));
    }
    assert_script_run("mkdir -p /root/qaset");
    my $testsuites = "\n\t" . join("\n\t", @list) . "\n";
    assert_script_run("echo 'SQ_TEST_RUN_LIST=($testsuites)' > /root/qaset/config");

    # define undefined testsuites in the testsuites list
    shift @list;
    my $cmd = "for n in " . join(" ", @list) . ";";
    $cmd .= q( do grep test_$n-run /usr/share/qa/qaset/set/* >/dev/null || echo "def_simple_run $n '/usr/share/qa/tools/test_${n}-run' qa_test_$n" >> /usr/share/qa/qaset/set/regression.set; done);
    assert_script_run($cmd);
}
sub upload_parse {
    if (my $soft_tc = get_var("TESTCASES_BLACKLIST")) {
        record_info("$soft_tc");
        my $xslt = <<'EOT';
<?xml version="1.0"?>
 <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
     <xsl:param name="masked_tc"></xsl:param>
     <xsl:template match="@*|node()">
         <xsl:copy>
             <xsl:apply-templates select="@*|node()" />
         </xsl:copy>
     </xsl:template>
     <xsl:template match="testcase">
           <xsl:if test="not(contains($masked_tc, @classname))">
        <xsl:copy>
             <xsl:apply-templates select="@*|node()" />
         </xsl:copy>
           </xsl:if>
         
     </xsl:template>
     
<xsl:template match="testsuite/@failures[. > 0]">
	<xsl:variable name="c" select="count(../testcase[contains($masked_tc, @classname) and @status='failure'])" />
	   <xsl:attribute name="{name()}">
		<xsl:value-of select=".-$c" />
	   </xsl:attribute>
</xsl:template>
<xsl:template match="testsuite/@skipped[. > 0]">
	<xsl:variable name="c" select="count(../testcase[contains($masked_tc, @classname) and @status='skipped'])" />
	   <xsl:attribute name="{name()}">
		<xsl:value-of select=".-$c" />
	   </xsl:attribute>
</xsl:template>
 </xsl:stylesheet>
EOT
        assert_script_run("cat > /tmp/trans_junit.xsl <<'END'\n$xslt\nEND\n( exit \$?)");

        assert_script_run("xml tr /tmp/trans_junit.xsl -s masked_tc=\"$soft_tc\"  /tmp/junit.xml > /tmp/junit_trans.xml");

        parse_junit_log("/tmp/junit_trans.xml");

    } else {

        parse_junit_log("/tmp/junit.xml");
    }
}
# qa_testset_automation validation test
sub run {
    my $self = shift;
    $self->system_login();
    $self->prepare_repos();
    zypper_call("in xmlstarlet libxslt-tools");
    $self->start_testrun();
    my $testrun_finished = $self->wait_testrun(timeout => 180 * 60);

    # Upload test logs
    my $tarball = "/tmp/qaset.tar.bz2";
    assert_script_run("tar cjf '$tarball' -C '/var/log/' 'qaset'");
    upload_logs($tarball, timeout => 600);
    my $log = $self->system_status();
    upload_logs($log, timeout => 100);

    # JUnit xml report
    assert_script_run("/usr/share/qa/qaset/bin/junit_xml_gen.py -n 'regression' -d -o /tmp/junit.xml /var/log/qaset");
    upload_logs('/tmp/junit.xml', timeout => 600);

    if (get_var("INDEPENDENT_RUN")) {


        $self->upload_parse();


    } else {



        # Collect all testcases with status="failure"
        assert_script_run(q(xml sel -t -v '//testcase[@status="failure"]/@classname' /tmp/junit.xml |sed '/\.dummy/d' | tr '\n' ' ' > /tmp/broken_tclist));
        upload_logs('/tmp/broken_tclist', timeout => 100);

        #Save submission ids of all tests to a file.
        my $ts_list = join(" ", @{get_var_array('USER_SPACE_TESTSUITES')});
        my $cmd = "for i in $ts_list; " . 'do xml sel -t -v "/testsuites/testsuite[@name=\"$i\"]/testcase[1]/system-err" /tmp/junit.xml|sed -n "s/.*id=\(.*\)/$i \1/p"; done > /tmp/submission_ids_before';
        assert_script_run("$cmd");
        die "Test run didn't finish within time limit" unless ($testrun_finished);
    }
    # clean up qaset
    assert_script_run('rm -rf /tmp/junit.xml /var/log/qaset/submission/* /var/log/qaset/log/* /tmp/qaset.tar.bz2');
    select_console('root-console');
}

1;
