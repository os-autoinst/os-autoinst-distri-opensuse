# Copyright (C) 2017-2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Base module for openSCAP test cases
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#37006

package openscaptest;

use base Exporter;
use Exporter;

use consoletest;
use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  $oval_result
  $oval_result_single
  $xccdf_result
  $xccdf_result_single
  $source_ds
  $source_ds_result
  $arf_result
  oscap_get_test_file
  validate_result
  ensure_generated_file
  prepare_remediate_validation
  finish_remediate_validation
  pre_run_hook
);

our $oval_result         = "scan-oval-results.xml";
our $oval_result_single  = "scan-oval-results-single.xml";
our $xccdf_result        = "scan-xccdf-results.xml";
our $xccdf_result_single = "scan-xccdf-results-single.xml";

our $source_ds        = 'source-ds.xml';
our $source_ds_result = 'source-ds-results.xml';
our $arf_result       = "arf-results.xml";

sub oscap_get_test_file {
    my ($source) = @_;

    assert_script_run "wget --quiet " . data_url("openscap/$source");
}

sub validate_result {
    my ($result_file, $match, $file_ext) = @_;
    $file_ext //= 'xml';

    my $xml_args = '';

    if ($file_ext eq 'xml' || $file_ext eq 'html') {
        $xml_args = '--html' if $file_ext eq 'html';
        assert_script_run "xmllint --noout $xml_args $result_file";
    }

    validate_script_output "cat $result_file", sub { $match };
    upload_logs($result_file);
}

sub ensure_generated_file {
    my ($genfile) = @_;

    my $failmsg = "Missing $genfile file. You should first to run related test accordingly";
    assert_script_run("ls $genfile", fail_message => $failmsg);
}

sub prepare_remediate_validation {
    validate_script_output "cat /etc/securetty",         sub { m/tty[1-6]/ };
    validate_script_output "cat /proc/sys/kernel/sysrq", sub { m/[1-9]+$/ };

    assert_script_run "cp /etc/securetty /tmp/";
    assert_script_run "cp /proc/sys/kernel/sysrq /tmp/";
}

sub finish_remediate_validation {
    assert_script_run "mv /tmp/securetty /etc/";
    assert_script_run "cat /tmp/sysrq > /proc/sys/kernel/sysrq";
}

sub pre_run_hook {

    select_console 'root-console';
}

1;
