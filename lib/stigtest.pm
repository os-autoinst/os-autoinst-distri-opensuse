# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base module for STIG test cases
# Maintainer: QE Security <none@suse.de>

package stigtest;

use strict;
use warnings;
use testapi;
use utils;
use base 'opensusebasetest';
use version_utils qw(is_sle);

our @EXPORT = qw(
  $profile_ID
  $f_ssg_sle_ds
  $f_stdout
  $f_stderr
  $f_report
  $remediated
  set_ds_file
  upload_logs_reports
  validate_result
  pattern_count_in_file
);

# The file names of scap logs and reports
our $f_stdout = 'stdout';
our $f_stderr = 'stderr';
our $f_report = 'report.html';

# Set default value for 'scap-security-guide' ds file
our $f_ssg_sle_ds = '/usr/share/xml/scap/ssg/content/ssg-sle12-ds.xml';
our $f_ssg_tw_ds = '/usr/share/xml/scap/ssg/content/ssg-opensuse-ds.xml';

# Profile ID
our $profile_ID_sle = 'xccdf_org.ssgproject.content_profile_stig';
our $profile_ID_tw = 'xccdf_org.ssgproject.content_profile_standard';

# The OS status of remediation: '0', not remediatd; '1', remediated
our $remediated = 0;

# Set value for 'scap-security-guide' ds file
sub set_ds_file {
    # Set the ds file for separate product, e.g.,
    # for SLE15 the ds file is "ssg-sle15-ds.xml";
    # for SLE12 the ds file is "ssg-sle12-ds.xml";
    # for Tumbleweed the ds file is "ssg-opensuse-ds.xml"
    my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $f_ssg_sle_ds = '/usr/share/xml/scap/ssg/content/ssg-sle' . "$version" . '-ds.xml';
}

sub upload_logs_reports
{
    # Upload logs & ouputs for reference
    my $files;
    if (is_sle) {
        $files = script_output('ls | grep "^ssg-sle.*.xml"');
    } else {
        $files = script_output('ls | grep "^ssg-opensuse.*.xml"');
    }
    foreach my $file (split("\n", $files)) {
        upload_logs("$file");
    }
    upload_logs("$f_stdout") if script_run "! [[ -e $f_stdout ]]";
    upload_logs("$f_stderr") if script_run "! [[ -e $f_stderr ]]";
    if (get_var('UPLOAD_REPORT_HTML')) {
        upload_logs("$f_report", timeout => 600) if script_run "! [[ -e $f_report ]]";
    }
}

sub validate_result {
    my ($result_file, $match, $file_ext) = @_;
    $file_ext //= 'xml';

    my $xml_args = '';

    if ($file_ext eq 'xml' || $file_ext eq 'html') {
        $xml_args = '--html' if $file_ext eq 'html';
        assert_script_run "xmllint --noout $xml_args $result_file";
    }

    validate_script_output "cat $result_file", sub { $match }, timeout => 300;
    upload_logs($result_file);
}
sub pattern_count_in_file {
    my $data = $_[0];
    my $pattern = $_[1];
    $pattern //= "\\bpass\\b";
    my $count = 0;

    print("IN Pattern: $pattern \n");
    my @lines = split /\n|\r/, $data;
    foreach my $line (@lines){
        if($line =~ /$pattern/){
            print("$line \n");
            $count ++;
        }
    }
    print("pattern_count_in_file returned $count for $pattern");
    return $count;
}

1;
