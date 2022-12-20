# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
package qaset_post_patch_run;

# Summary: Simplify test reporting for qa_automation
#
# This execution is entirely based on qa_automation/qa_run. The test result is simplfied to only show failed testcases
# triggered by regression bug. That will satisfy the need for maintenance update test
# Using YAML_SCHEDULE to schedule is recommended to keep flexibility.
# qaset_pre_patch_run, patch_and_reboot and qaset_post_patch_run should schedule in order.
#
# features:
# 1. Only failed test case names triggered by regression are show on result page.
# 2. QADB url of comparison of before update and after is posted under testcase name.
# 3. Added var SOFTFAIL_TESTCASES which make a failed testcase softfailed to avoid triggering
#    entire test failed until the corresponding bug is fixed.
# 4. Auto define test in qaset if it's no defined.
# 5. disble/enable QADB submission with var DISABLE_SUBMIT_QADB.
#
# Maintainer: Tony Yuan <tyuan@suse.com>

use strict;
use warnings;
use base "qa_run";
use testapi qw(is_serial_terminal :DEFAULT);
use utils;

# Create qaset/config file, reset qaset, and start testrun
sub start_testrun {
    assert_script_run("/usr/share/qa/qaset/qaset reset");
    assert_script_run("/usr/share/qa/qaset/run/kernel-all-run.openqa");
}

my $xslt = <<'EOT';
<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:param name="var" select="'title'" />
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()" />
        </xsl:copy>
    </xsl:template>
    <xsl:template match="testsuite">
        <xsl:choose>
            <xsl:when test="@failures!='0'">
                <xsl:variable name="nreg" select="testcase[@status='failure' and not(contains($var, @classname))]" />
                <xsl:choose>
                    <xsl:when test="count($nreg) &gt; 0">
                        <xsl:copy>
                            <xsl:apply-templates select="@*" />
                            <xsl:attribute name="failures">
                                <xsl:value-of select="count($nreg)" />
                            </xsl:attribute>
                            <xsl:copy-of select="$nreg" />
                        </xsl:copy>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:copy>
                            <xsl:apply-templates select="@*" />
                            <xsl:attribute name="failures">
                                <xsl:value-of select="count($nreg)" />
                            </xsl:attribute>
                            <xsl:apply-templates select="testcase[1]/system-err" />
                        </xsl:copy>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates select="@*" />
                    <xsl:apply-templates select="testcase[1]/system-err" />
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
</xsl:stylesheet>
EOT

my $compare_results = <<'EOT';
while read test id_before 
do 
  echo "$test,$id_before"
  id_after=`xml sel -t -v "/testsuites/testsuite[@name=\"$test\"]/testcase[1]/system-err" /tmp/junit.xml|sed -n "s/.*id=\(.*\)/\1/p"`
  qadb_url="http://qadb2.suse.de/qadb/regression.php?ref_submission_id=${id_before}&cand_submission_id=$id_after"
  echo "$qadb_url"
  xml ed -L -u "/testsuites/testsuite[@name=\"$test\"]/testcase[1]/system-err" -v "Submission comparison between before and after results: $qadb_url" /tmp/junit.xml
done < /tmp/submission_ids_before
EOT

# qa_testset_automation validation test
sub run {
    my $self = shift;
    $self->system_login();
    start_testrun;
    my $testrun_finished = $self->wait_testrun(timeout => 180 * 60);

    # Upload test logs
    my $tarball = "/tmp/qaset.tar.bz2";
    assert_script_run("tar cjf '$tarball' -C '/var/log/' 'qaset'");
    upload_logs($tarball, timeout => 600);
    my $log = $self->system_status();
    upload_logs($log, timeout => 100);

    # JUnit xml report
    assert_script_run("/usr/share/qa/qaset/bin/junit_xml_gen.py -n 'regression' -d -o /tmp/junit.xml /var/log/qaset");

    # Record into failure for known bugs to avoid triggering whole test failure.
    if (my %softfail_tc = @{get_var_array('SOFTFAIL_TESTCASES')}) {
        my $broken_tc_list;
        while (my ($k, $v) = each %softfail_tc) {
            next unless script_run("grep $k /tmp/broken_tclist");
            $broken_tc_list .= "$k ";
            record_info("$k => $v");
        }
        assert_script_run(qq(echo "`cat /tmp/broken_tclist` $broken_tc_list" > /tmp/broken_tclist ));
    }

    upload_logs("/tmp/junit.xml", timeout => 600);
    # Construct qadb regression url
    assert_script_run("cat > /tmp/compare_results.sh <<'END'\n$compare_results\nEND\n( exit \$?)");
    assert_script_run("bash /tmp/compare_results.sh");

    # transform junit.xml by xslt to filter the result of passed, broken and skipped testcases. Only new regression is kept;
    assert_script_run("cat > /tmp/trans_junit.xsl <<'END'\n$xslt\nEND\n( exit \$?)");
    assert_script_run("xsltproc  --stringparam var \"`cat /tmp/broken_tclist`\" /tmp/trans_junit.xsl /tmp/junit.xml > /tmp/junit_trans.xml");

    parse_junit_log("/tmp/junit_trans.xml");
    die "Test run didn't finish within time limit" unless ($testrun_finished);
    select_console('root-console');
}

1;
