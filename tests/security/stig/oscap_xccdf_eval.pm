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
use Utils::Architectures;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Get ds file and profile ID
    my $profile_ID = is_sle ? $stigtest::profile_ID_sle : $stigtest::profile_ID_tw;
    my $f_ssg_ds = is_sle ? $stigtest::f_ssg_sle_ds : $stigtest::f_ssg_tw_ds;
    my $f_stdout = $stigtest::f_stdout;
    my $f_stderr = $stigtest::f_stderr;
    my $f_report = $stigtest::f_report;
    my $f_pregex = $stigtest::f_pregex;
    my $f_fregex = $stigtest::f_fregex;
    my $passed_rules_ref;
    my $failed_rules_ref;
    my $n_passed_rules = 210;
    my $n_failed_rules = 5;
    my $eval_match = 'm/
                    Rule.*content_rule_is_fips_mode_enabled.*Result.*fail.*
                    Rule.*content_rule_partition_for_var_log_audit.*Result.*fail.*
                    Rule.*content_rule_smartcard_pam_enabled.*Result.*fail.*
                    Rule.*content_rule_grub2_password.*Result.*fail.*
                    Rule.*content_rule_no_files_unowned_by_user.*Result.*fail/sxx';

    #Conditional checks
    if (is_s390x) {
        $n_passed_rules = 209;
        $n_failed_rules = 5;
    }

    # Verify detection mode
    my $ret = script_run("oscap xccdf eval --profile $profile_ID --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr", timeout => 600);
    if ($ret == 0 || $ret == 2) {
        record_info('PASS');
        # Note: the system cannot be fully remediated in this test and some rules are verified failing
        my $data = script_output "cat $f_stdout";
        # For a new installed OS the first time remediate can permit fail
        if ($stigtest::remediated == 0) {
            record_info('non remediated', 'before remediation more rules fails are expected');
            my $pass_count = $self->pattern_count_in_file($data, $f_pregex, $passed_rules_ref);
            record_info(
                "Passed rules count=$pass_count",
                "Pattern $f_pregex count in file $f_stdout is $pass_count. Matched rules: \n " . join "\n",
                @$passed_rules_ref
            );
            my $fail_count = $self->pattern_count_in_file($data, $f_fregex, $failed_rules_ref);
            record_info(
                "Failed rules count=$fail_count",
                "Pattern $f_fregex count in file $f_stdout is $fail_count. Matched rules: \n" . join "\n",
                @$failed_rules_ref
            );
        }
        else {
            record_info('remediated', 'after remediation less rules are failing');
            #Verify remediated rules
            validate_script_output "cat $f_stdout", sub { $eval_match }, timeout => 300;

            #Verify number of passed and failed rules
            my $pass_count = $self->pattern_count_in_file($data, $f_pregex, $passed_rules_ref);
            if ($pass_count != $n_passed_rules) {
                $self->result('fail');
                record_info(
                    "Failed check of passed rules count",
                    "Pattern $f_pregex count in file $f_stdout is $pass_count, expected $n_passed_rules. Matched rules: \n" . join "\n",
                    @$passed_rules_ref
                );
            }
            else {
                record_info(
                    "Passed check of passed rules count",
                    "Pattern $f_pregex count in file $f_stdout is $pass_count. Matched rules: \n" . join "\n",
                    @$passed_rules_ref
                );
            }
            my $fail_count = $self->pattern_count_in_file($data, $f_fregex, $failed_rules_ref);
            if ($fail_count != $n_failed_rules) {
                $self->result('fail');
                record_info(
                    "Failed check of failed rules count",
                    "Pattern $f_fregex count in file $f_stdout is $fail_count, expected $n_failed_rules. Matched rules: \n" . join "\n",
                    @$failed_rules_ref
                );
            }
            else {
                record_info(
                    "Passed check of failed rules count",
                    "Pattern $f_fregex count in file $f_stdout is $fail_count. Matched rules: \n" . join "\n",
                    @$failed_rules_ref
                );
            }
        }
    }
    else {
        record_info("errno=$ret", "# oscap xccdf eval --profile \"$profile_ID\" returns: $ret");
        $self->result('fail');
    }
=comment
    OSCAP exit codes from https://github.com/OpenSCAP/openscap/blob/maint-1.3/utils/oscap-tool.h
    // standard oscap CLI exit statuses
    enum oscap_exitcode {
        OSCAP_OK             =   0, // successful exit
        OSCAP_ERROR          =   1, // an error occurred
        OSCAP_FAIL           =   2, // a process (e.g. scan or validation) failed
        OSCAP_ERR_FETCH      =   1, // cold not fetch input file (same as error for now)
        OSCAP_BADARGS        = 100, // bad commandline arguments
        OSCAP_BADMODULE      = 101, // unrecognized module
        OSCAP_UNIMPL_MOD     = 110, // module functionality not implemented
        OSCAP_UNIMPL         = 111, // functionality not implemented
        // end of list
        OSCAP_EXITCODES_END_ = 120  // any code returned shall not be higher than this
    };
=cut

    # Upload logs & ouputs for reference
    set_var('UPLOAD_REPORT_HTML', 1);
    $self->upload_logs_reports();
}

sub test_flags {
    return {always_rollback => 1};
}

1;
