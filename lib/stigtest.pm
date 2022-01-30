# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Base module for STIG test cases
# Maintainer: llzhao <llzhao@suse.com>

package stigtest;

use strict;
use warnings;
use testapi;
use utils;
use base 'opensusebasetest';

our @EXPORT = qw(
  $profile_ID
  $f_ssg_sle_ds
  $f_stdout
  $f_stderr
  $f_report
  $remediated
  set_ds_file
  upload_logs_reports
);

# The file names of scap logs and reports
our $f_stdout = 'stdout';
our $f_stderr = 'stderr';
our $f_report = 'report.html';

# Set default value for 'scap-security-guide' ds file
our $f_ssg_sle_ds = '/usr/share/xml/scap/ssg/content/ssg-sle12-ds.xml';

# Profile ID
our $profile_ID = 'xccdf_org.ssgproject.content_profile_stig';

# The OS status of remediation: '0', not remediatd; '1', remediated
our $remediated = 0;

# Set value for 'scap-security-guide' ds file
sub set_ds_file {
    # Set the ds file for separate product, e.g.,
    # for SLE15 the ds file is "ssg-sle15-ds.xml";
    # for SLE12 the ds file is "ssg-sle12-ds.xml"
    my $version = get_required_var('VERSION') =~ s/([0-9]+).*/$1/r;
    $f_ssg_sle_ds = '/usr/share/xml/scap/ssg/content/ssg-sle' . "$version" . '-ds.xml';
}

sub upload_logs_reports
{
    # Upload logs & ouputs for reference
    my $files = script_output('ls | grep "^ssg-sle.*.xml"');
    foreach my $file (split("\n", $files)) {
        upload_logs("$file");
    }
    upload_logs("$f_stdout") if script_run "! [[ -e $f_stdout ]]";
    upload_logs("$f_stderr") if script_run "! [[ -e $f_stderr ]]";
    if (get_var('UPLOAD_REPORT_HTML')) {
        upload_logs("$f_report", timeout => 600) if script_run "! [[ -e $f_report ]]";
    }
}

1;
