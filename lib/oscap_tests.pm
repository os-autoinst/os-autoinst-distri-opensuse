# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base module for STIG test cases
# Maintainer: QE Security <none@suse.de>

package oscap_tests;

use strict;
use warnings;
use testapi;
use utils;
use base 'opensusebasetest';
use version_utils qw(is_sle);
use bootloader_setup qw(add_grub_cmdline_settings);
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';

our @EXPORT = qw(
  $profile_ID
  $f_ssg_sle_ds
  $f_stdout
  $f_stderr
  $f_report
  $remediated
  set_ds_file
  upload_logs_reports
  oscap_security_guide_setup
  oscap_remediate
  oscap_evaluate
  oscap_evaluate_remote
);

# The file names of scap logs and reports
our $f_stdout = 'stdout';
our $f_stderr = 'stderr';
our $f_vlevel = 'ERROR';
our $f_report = 'report.html';
our $f_pregex = '\\bpass\\b';
our $f_fregex = '\\bfail\\b';

# Set default value for 'scap-security-guide' ds file
our $f_ssg_sle_ds = '/usr/share/xml/scap/ssg/content/ssg-sle12-ds.xml';
our $f_ssg_tw_ds = '/usr/share/xml/scap/ssg/content/ssg-opensuse-ds.xml';

# Profile IDs
# Priority High:
our $profile_ID_sle_stig = 'xccdf_org.ssgproject.content_profile_stig';
our $profile_ID_sle_cis = 'xccdf_org.ssgproject.content_profile_cis';
our $profile_ID_sle_pci_dss = 'xccdf_org.ssgproject.content_profile_pci-dss';
our $profile_ID_sle_hipaa = 'xccdf_org.ssgproject.content_profile_hipaa';
our $profile_ID_sle_anssi_bp28_high = 'xccdf_org.ssgproject.content_profile_anssi_bp28_high';
# Priority Medium:
our $profile_ID_sle_anssi_bp28_enhanced = 'xccdf_org.ssgproject.content_profile_anssi_bp28_enhanced';
our $profile_ID_sle_cis_server_l1 = 'xccdf_org.ssgproject.content_profile_cis_server_l1';
our $profile_ID_sle_cis_workstation_l2 = 'xccdf_org.ssgproject.content_profile_cis_workstation_l2';
# Priority Low:
our $profile_ID_sle_anssi_bp28_intermediary = 'xccdf_org.ssgproject.content_profile_anssi_bp28_intermediary';
our $profile_ID_sle_anssi_bp28_minimal = 'xccdf_org.ssgproject.content_profile_anssi_bp28_minimal';
our $profile_ID_sle_cis_workstation_l1 = 'xccdf_org.ssgproject.content_profile_cis_workstation_l1';
our $profile_ID_tw = 'xccdf_org.ssgproject.content_profile_standard';

# The OS status of remediation: '0', not remediated; '1', remediated
our $remediated = 0;

# Upload HTML report by default
set_var('UPLOAD_REPORT_HTML', 1);

# Set value for 'scap-security-guide' ds file
sub set_ds_file {

    # Set the ds file for separate product, e.g.,
    # for SLE15 the ds file is "ssg-sle15-ds.xml";
    # for SLE12 the ds file is "ssg-sle12-ds.xml";
    # for Tumbleweed the ds file is "ssg-opensuse-ds.xml"
    my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $f_ssg_sle_ds =
      '/usr/share/xml/scap/ssg/content/ssg-sle' . "$version" . '-ds.xml';
}


sub upload_logs_reports {

    # Upload logs & ouputs for reference
    my $files;
    if (is_sle) {
        $files = script_output('ls | grep "^ssg-sle.*.xml"');
    }
    else {
        $files = script_output('ls | grep "^ssg-opensuse.*.xml"');
    }
    foreach my $file (split("\n", $files)) {
        upload_logs("$file");
    }
    upload_logs("$f_stdout") if script_run "! [[ -e $f_stdout ]]";
    upload_logs("$f_stderr") if script_run "! [[ -e $f_stderr ]]";
    if (get_var('UPLOAD_REPORT_HTML')) {
        upload_logs("$f_report", timeout => 600)
          if script_run "! [[ -e $f_report ]]";
    }
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

sub oscap_security_guide_setup {

    select_console 'root-console';

    # Install packages
    zypper_call('in openscap-utils scap-security-guide', timeout => 180);

    # Record the pkgs' version for reference
    my $out = script_output("zypper se -s openscap-utils scap-security-guide");
    record_info("Pkg_ver", "openscap security guide packages' version:\n $out");

    # Set ds file
    set_ds_file();

    # Check the ds file information for reference
    my $f_ssg_ds = is_sle ? $f_ssg_sle_ds : $f_ssg_tw_ds;
    $out = script_output("oscap info $f_ssg_ds");
    record_info("oscap info", "\"# oscap info $f_ssg_ds\" returns:\n $out");

    # Check the oscap version information for reference
    $out = script_output("oscap -V");
    record_info("oscap version", "\"# oscap -V\" returns:\n $out");
}

sub oscap_remediate {
    my ($self, $f_ssg_ds, $profile_ID) = @_;

    select_console 'root-console';

    # Verify mitigation mode
    my $ret
      = script_run("oscap xccdf eval --profile $profile_ID --remediate --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr", timeout => 600);
    record_info("Return=$ret", "# oscap xccdf eval --profile $profile_ID --remediate\" returns: $ret");
    if ($ret != 0 and $ret != 2) {
        record_info('bsc#1194676', 'remediation should be succeeded', result => 'fail');
    }
    if ($remediated == 0) {
        $remediated = 1;
        record_info('remediated', 'setting status remediated');
    }

    # Upload logs & ouputs for reference
    upload_logs_reports();
}


## remove leading and trailing whitespace from a string
sub strip {
    my $string = shift;
    $string =~ s/^\s+|\s+$//g;
    return $string;
}

# parses oscap output in a key->value hash: Rule->Result
# sample output:
#  Title
#   	Ensure /var Located On Separate Partition
#  Rule
#	    xccdf_org.ssgproject.content_rule_partition_for_var
#  Ident
#	    CCE-85640-1
#  Result
#	    pass
#
# returns {'xccdf_org.ssgproject.content_rule_partition_for_var' => 'pass'}
#
sub parse_oscap_stdout {
    my %parsed;
    my @data = split /\n|\r/, shift;
    my $key;
    while (my ($index, $line) = each @data) {
        if ($line =~ m/^Rule/) {
            $key = strip($data[$index + 1]);
        }
        if ($key && $line =~ m/^Result/) {
            $parsed{$key} = strip($data[$index + 1]);
            $key = undef;
        }
    }
    return %parsed;
}

sub oscap_evaluate {
    my ($self, $f_ssg_ds, $profile_ID, $n_passed_rules, $n_failed_rules, $eval_match) = @_;
    select_console 'root-console';

    # Verify detection mode
    my $ret = script_run("oscap xccdf eval --profile $profile_ID --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr", timeout => 600);
    if ($ret != 0 && $ret != 2) {
        record_info("errno=$ret", "# oscap xccdf eval --profile \"$profile_ID\" returns: $ret", result => 'fail');
        $self->result('fail');
        return;
    }
    record_info("Returned $ret", "oscap xccdf eval --profile $profile_ID --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr");
    # Note: the system cannot be fully remediated in this test and some rules are verified failing
    my %data = parse_oscap_stdout(script_output "cat $f_stdout");
    # look at all entries (keys) of the hash and pick only those with a value that matches the regexp
    my @passed_rules = grep { $data{$_} =~ m/$f_pregex/ } keys %data;
    my $pass_count = scalar @passed_rules;    # get the length of the array
    my @failed_rules = grep { $data{$_} =~ m/$f_fregex/ } keys %data;
    my $fail_count = scalar @failed_rules;
    # For a new installed OS the first time remediate can permit fail
    if ($remediated == 0) {
        record_info('non remediated', 'before remediation more rules fails are expected');
        record_info(
            "Passed rules count=$pass_count",
            "Pattern $f_pregex count in file $f_stdout is $pass_count. Matched rules:\n " . join "\n",
            @passed_rules
        );
        record_info(
            "Failed rules count=$fail_count",
            "Pattern $f_fregex count in file $f_stdout is $fail_count. Matched rules:\n" . join "\n",
            @failed_rules
        );
        upload_logs_reports();
        return;
    }
    #if we get here, system has been remediated. Verify remediated rules
    record_info('remediated', 'after remediation less rules are failing');

    # note: $eval_match is an array reference. We need to get the complete key,
    # e.g. from description 'content_rule_is_fips_mode_enabled' to 'xccdf_org.ssgproject.content_rule_is_fips_mode_enabled'
    my @matched_rules;
    foreach my $rule_desc (@$eval_match) {
        # build array of keys with only the one matching the rule description
        push @matched_rules, grep { $_ =~ m/$rule_desc/ } keys %data;
    }
    # counts the keys matching $f_fregex. Number should be equal to $eval_match length
    my @fails = grep { $data{$_} =~ m/$f_fregex/ } @matched_rules;
    my $fails_len = scalar @fails;

    if ($fails_len == scalar @$eval_match) {
        record_info(
            "Passed check of failed rules",
            "Check of $fails_len failed rules:\n" . (join "\n",
                @$eval_match) . "\n in file $f_stdout. \nMatched rules:\n" . (join "\n", @fails)
        );
    } else {
        record_info(
            "Failed check of failed rules",
            "Pattern $f_fregex count in file $f_stdout is $fails_len, expected $n_failed_rules. Matched rules:\n" . (join "\n",
                @fails) . "\nExpected rules:\n" . (join "\n", @$eval_match),
            result => 'fail'
        );
        $self->result('fail');
    }

    #Verify number of passed and failed rules
    if ($pass_count != $n_passed_rules) {
        record_info(
            "Failed check of passed rules count",
            "Pattern $f_pregex count in file $f_stdout is $pass_count, expected $n_passed_rules. Matched rules:\n" . join "\n",
            @passed_rules, result => 'fail'
        );
        $self->result('fail');
    }
    else {
        record_info(
            "Passed check of passed rules count",
            "Pattern $f_pregex count in file $f_stdout is $pass_count. Matched rules:\n" . join "\n", @passed_rules
        );
    }
    if ($fail_count != $n_failed_rules) {
        record_info(
            "Failed check of failed rules count",
            "Pattern $f_fregex count in file $f_stdout is $fail_count, expected $n_failed_rules. Matched rules: \n" . join "\n",
            @failed_rules, result => 'fail'
        );
        $self->result('fail');
    }
    else {
        record_info(
            "Passed check of failed rules count",
            "Pattern $f_fregex count in file $f_stdout is $fail_count. Matched rules: \n" . join "\n", @failed_rules
        );
    }
    # Upload logs & ouputs for reference
    upload_logs_reports();
}

sub oscap_evaluate_remote {
    my ($self, $f_ssg_ds, $profile_ID) = @_;

    select_console 'root-console';

    add_grub_cmdline_settings('ignore_loglevel', update_grub => 1);
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1);

    select_console 'root-console';

    # Verify detection mode with remote
    my $ret = script_run(
        "oscap xccdf eval --profile $profile_ID --oval-results --fetch-remote-resources --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr",
        timeout => 3000
    );
    record_info("Return=$ret",
        "# oscap xccdf eval --fetch-remote-resources --profile $profile_ID\" returns: $ret"
    );
    if ($ret == 137) {
        record_info('bsc#1194724', "eval returned $ret", result => 'fail');
    }

    # Upload logs & ouputs for reference
    upload_logs_reports();
}
1;
