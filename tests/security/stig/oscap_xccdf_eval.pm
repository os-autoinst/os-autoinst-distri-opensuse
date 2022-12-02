# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'stig' hardening in the 'scap-security-guide': detection mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'stigtest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    my $regex1 = "\\bpass\\b";
    my $regex2 = "\\bfail\\b";
    my $eval_match = 'm/
                    Rule.*content_rule_is_fips_mode_enabled.*Result.*fail.*
                    Rule.*content_rule_partition_for_var_log_audit.*Result.*fail.*
                    Rule.*content_rule_smartcard_pam_enabled.*Result.*fail.*
                    Rule.*content_rule_grub2_password.*Result.*fail.*
                    Rule.*content_rule_no_files_unowned_by_user.*Result.*fail/sxx';

    select_console 'root-console';

    # Get ds file and profile ID
    my $profile_ID = is_sle ? $stigtest::profile_ID_sle : $stigtest::profile_ID_tw;
    my $f_ssg_ds = is_sle ? $stigtest::f_ssg_sle_ds : $stigtest::f_ssg_tw_ds;
    my $f_stdout = $stigtest::f_stdout;
    my $f_stderr = $stigtest::f_stderr;
    my $f_report = $stigtest::f_report;

    # Verify detection mode
    my $ret = script_run("oscap xccdf eval --profile $profile_ID --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr", timeout => 600);
    record_info("errno=$ret", "# oscap xccdf eval --profile \"$profile_ID\" returns: $ret");
#    if ($ret == 0) {
#        record_info('PASS');
#    } elsif ($ret == 1 || $ret == 2) {
#        record_info("errno=$ret", "# oscap xccdf eval --profile \"$profile_ID\" returns: $ret");
#        # Note: the system is not fully compliant before remediation so some fails are permitted
#        # For a new installed OS the first time remediate can permit fail
#        if ($stigtest::remediated == 0) {
#            $stigtest::remediated = 1;
#            record_info('non remediated', 'before remediation some fails are permitted');
#        } else {
#            $self->result('fail');
#            record_info('remediated', 'after remediation fails are not permitted');
#        }
#    } else {
#        $self->result('fail');
#    }
    #Verify failed rules
    #$self->validate_result($f_stdout, $eval_match, "txt");
    validate_script_output "cat $f_stdout", sub { $eval_match }, timeout => 300;
    #Verify number of passed rules
#    my $pass_pattern = "\\bpass\\b";
#    my $fail_pattern = "\\bfail\\b";
#    my $pass_pattern = "pass";
#    my $fail_pattern = "fail";
#    my $pass_count = $self->pattern_count_in_file($f_stdout);
#    my $fail_count = $self->pattern_count_in_file($f_stdout,$fail_pattern);


    my $pass_pattern = "\\bpass\\b";
    my $count = 0;
    my $fh;

    open($fh, $f_stdout);

    while(my $line = <$fh>){
        if($line =~ /$pass_pattern/){
        $count ++;
        }
    }
    record_info("count=$count", "# pattern $pass_pattern count in file $f_stdout is $count");
    close($fh);
#    my $matching_line = script_output("grep -o pass $f_stdout");
    record_info("pass_count=$count", "# pass_count in file $f_stdout is $count");
 #   record_info("fail_count=$fail_count", "# fail_count in $f_stdout is $fail_count");

#    validate_script_output("cat grep_out_pass | wc -l", sub { m/218/ }, timeout => 100);

#    validate_script_output (qq{grep -o \\bpass\\b $f_stdout | wc -l}, sub { m/218/ }, timeout => 300);
    #Verify number of failed rules
#    validate_script_output (qq{grep -o \\bfail\\b $f_stdout | wc -l}, sub { m/5/ }, timeout => 300);

    # Upload logs & ouputs for reference
    $self->upload_logs_reports();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
