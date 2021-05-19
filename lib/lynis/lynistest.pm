# Copyright (C) 2021 SUSE LLC
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

# Summary: Base module for Lynis test cases
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#78224

package lynis::lynistest;

use strict;
use warnings;
use testapi;
use utils;
use autotest;

use base 'consoletest';
use LTP::TestInfo 'testinfo';

our @EXPORT = qw(
  $testdir
  $f_position_b
  $f_position_c
  @lynis_ok
  @lynis_fail
  @lynis_softfail
  $lynis_baseline_file
  $lynis_baseline_file_default
  $lynis_audit_system_current_file
  $lynis_audit_system_error_file
  parse_lynis_section_list
  load_lynis_section_tests
  parse_lynis_section_content
  compare_lynis_section_content
);

our $testdir = "/tmp/";

# File pointer
our $f_position_b = 0;
our $f_position_c = 0;

my $var_str = get_var("VERSION", "15-SP3") . "-" . get_var("ARCH", "x86_64") . "-" . get_var("DESKTOP", "textmode");
our $lynis_baseline_file_default = "baseline-lynis-audit-system-nocolors-" . "$var_str";
our $lynis_baseline_file         = get_var("LYNIS_BASELINE_FILE", $lynis_baseline_file_default);

our $lynis_audit_system_current_file = "lynis_audit_system_current_file";
our $lynis_audit_system_error_file   = "lynis_audit_system_error_file";

# Lynix test status mappping with openQA
our @lynis_ok       = split(/,/, get_var("LYNIS_OK",      "OK,DONE,YES"));
our @lynis_fail     = split(/,/, get_var("LYNIS_ERROR",   "ERROR,WEAK,UNSAFE"));
our @lynis_softfail = split(/,/, get_var("LYNIS_WARNING", "WARNING,EXPOSED,NONE,SUGGESTION"));

sub loadtest_lynis {
    my ($test, %args) = @_;
    autotest::loadtest("lib/lynis/$test.pm", %args);
}

# Parse lynis test report sections
# input: $file - file name
# output: @section_list - section list
sub parse_lynis_section_list {
    my ($file) = @_;
    # Section token
    my $s_tok        = '\[\+\] ';
    my @section_list = ();

    my $rf;
    my $i = 0;

    # Parse the "sections" of input file
    open($rf, $file) or die "Can not open $file, $!";
    while (my $line = <$rf>) {
        if ($line =~ /$s_tok/) {
            push @section_list, $line;
            $i++;
        }
    }
    record_info("T: $i", "Total \"$i\" sections found in file \"$file\":\n @section_list");
    close($rf) or die "Can not close $file, $!";
    return @section_list;
}

# Rename the section for a eaiser regex matching
sub rename_lynis_section {
    my ($section) = @_;
    my @flags;

    # Added "my" before parameter to fix CI check error "Loop iterator is not lexical at line 265, column 5.  See page 108 of PBP.  (Severity: 4)"
    @flags = ('\[\+\] ');
    foreach my $s_flag (@flags) {
        $section =~ s/$s_flag/[+]_/g;
    }

    @flags = (' ', '\(', '\)');
    foreach my $s_flag (@flags) {
        $section =~ s/$s_flag/_/g;
    }

    @flags = ('\n', '\r');
    foreach my $s_flag (@flags) {
        $section =~ s/$s_flag//g;
    }

    return $section;
}

# Load the tests/modules according to section list
# input: @section_list - section list
sub load_lynis_section_tests {
    my (@section_list) = @_;
    my $i = 1;

    # The main script which dynamically generates test modules according to different sections
    my $script = "lynis_run";
    my $tinfo  = testinfo({}, test => "$script");

    for my $section (@section_list) {
        $tinfo = testinfo({}, test => $section);
        loadtest_lynis("$script", name => $i . "_" . rename_lynis_section($section), run_args => $tinfo);
        $i++;
    }
}

# Parse the contents of each section
# input: $section - section name
#        $file - file name
# output: @section_content - section content parsed
sub parse_lynis_section_content {
    my ($section, $file) = @_;
    my $rf;
    my $str;
    my $str_orig;
    my $s_tok           = '\[\+\] ';
    my $found           = 0;
    my @section_content = ();

    $section = substr($section, 4);

    # Parse the "section" contents of input file
    open($rf, "$file") or die "Can not open $file, $!";

    # Seek the position to avoid duplicated section names
    if ($file =~ /baseline/) {
        seek($rf, $f_position_b, 0);
    }
    else {
        seek($rf, $f_position_c, 0);
    }

    while (my $line = <$rf>) {
        $str_orig = $line;
        $str      = $str_orig;

        if ($str =~ /$s_tok/) {
            # Found a section
            if ($found == 1) {
                # This line of content belongs to another/following section, then exit
                last;
            }

            # Replace "\n, \r, \(, \) " in this section for easier regex match
            $str =~ s/\n//g;
            $str =~ s/\r//g;
            $str =~ s/\(/_/g;
            $str =~ s/\)/_/g;

            $section =~ s/\(/_/g;
            $section =~ s/\)/_/g;

            my $str_new = substr($str, 4);
            if ("$section" eq "$str_new") {
                # Found the section
                # This line of content belongs to this section, then save
                push @section_content, $str_orig;
                $found = 1;

                # Save the position for next search to avoid duplicated section name
                if ($file =~ /baseline/) {
                    $f_position_b = tell($rf);
                }
                else {
                    $f_position_c = tell($rf);
                }
            }
        }
        else {
            # Found a new line but not a section
            if ($found == 1) {
                # This line of content belongs to this section, then save
                push @section_content, $str_orig;
            }
        }
    }

    if ($file =~ /baseline/) {
        record_info("FYI: baseline content", "@section_content");
    }
    else {
        record_info("FYI: current content", "@section_content");
    }

    close($rf) or die "Can not close $file, $!";

    return @section_content;
}

# Compare the contents between "baseline" and "current"
# input: $found - "1", this section is found in baseline file; "0", not found
#        $arrar1 - section content of "baseline"
#        $arrar2 - section content of "current"
# output: $result - compare results: e.g., "ok", "softfail", "fail"
sub compare_lynis_section_content {
    my ($found, $array1, $array2) = @_;
    my @section_baseline = @$array1;
    my @section_current  = @$array2;

    my $s_new;
    my $ret    = 0;
    my $result = "ok";

    # If an old section then compare baseline and current
    if ($found) {
        # Delete the blank lines in case
        chomp @section_baseline;
        chomp @section_current;
        # Do not use "if (@section_baseline ~~ @section_current) {" to avoid
        # CI check Error "Smartmatch is experimental"
        my $str_section_baseline = join('', @section_baseline);
        my $str_section_current  = join('', @section_current);

        if ($str_section_baseline eq $str_section_current) {
            record_info("Same", "Section contents of \"Current\" and \"Baseline\" are the same, exit and pass");
            $result = "ok";
            return $result;
        }
        else {
            # Filter out some exceptions, e.g., "execution time" as it changes
            # "Boot and services": [WARNING]: Test CORE-1000 had a long execution: 25.848287 seconds
            # "File systems": "[WARNING]: Test BINARY-1000 had a long execution: 123.139555 seconds"
            # "Ports and packages": "[WARNING]: Test PKGS-7308 had a long execution: 21.594952 seconds"
            #    "[WARNING]: Test PKGS-7328 had a long execution: 11.963337 seconds"
            my @exceptions = ("  \\[WARNING\\]: Test .* had a long execution: .* seconds");
            for my $exception (@exceptions) {
                if ($str_section_baseline =~ m/$exception/ || $str_section_current =~ m/$exception/) {
                    $str_section_baseline =~ s/$exception//g;
                    $str_section_current  =~ s/$exception//g;
                    record_info("Warning", "Section contents need to be double checked manually: \"$exception\"");
                }
            }
            # Compare again
            if ($str_section_baseline eq $str_section_current) {
                $result = "ok";
                return $result;
            }
            else {
                record_info("NotSame", "Section contents of \"Current\" and \"Baseline\" are NOT the same, check \"Current\" only");
            }
        }
    }

    # Filter out "System_Tools": "[2C- Starting dbus policy check...[28C"
    # As this will likely change rather frequently and we have good mechanisms
    # on our side to tackle this
    if (grep(/Starting dbus policy check/, @section_current)) {
        $result = "ok";
        return $result;
    }

    # If a new section then only check the current
    record_info("CHECK", "Section contents NOT the same then check \"Current\" only");
    for my $s_lynis (@lynis_ok) {
        $s_new = "\\[.*$s_lynis.*\\]";
        $ret   = grep(/$s_new/, @section_current);
        if ($ret) {
            $result = "ok";
            record_info("[$s_lynis] ");
            record_info(":$ret", "found $ret [ $s_lynis ] in current output");
        }
    }

    for my $s_lynis (@lynis_softfail) {
        $s_new = "\\[.*$s_lynis.*\\]";
        $ret   = grep(/$s_new/, @section_current);
        if ($ret) {
            # Filter out some exceptions allowed:
            # "Boot_and_services": "[4C- Checking for password protection[23C [ WARNING ]"
            # "Name services": "[4C- Checking /etc/hosts (hostname)[25C [ SUGGESTION ]"
            # "Kernel: "[4CCPU support: No PAE or NoeXecute supported[15C [ NONE ]"
            # "Initializing_program": "[2C- Program update status... [32C [ WARNING ]"
            # "Networking": "[[4C- Minimal of 2 responsive nameservers^[[20C [ WARNING ]"
            # "Ports and packages": "Using Zypper to find vulnerable packages[17C [ NONE ]"
            my @exceptions = (
                "Checking for password protection.*WARNING.*",
                "Checking /etc/hosts .*hostname.*SUGGESTION.*",
                "CPU support: No PAE or NoeXecute supported.*NONE.*",
                "Program update status.*WARNING.*",
                "Minimal of 2 responsive nameservers.*WARNING.*",
                "Using Zypper to find vulnerable packages.*NONE.*",
                "Test .* had a long execution: .* seconds"
            );
            for my $exception (@exceptions) {
                if (grep(/$exception/, @section_current)) {
                    $result = "ok";
                    return $result;
                }
            }

            $result = "softfail";
            record_soft_failure("poo#91383, found $ret [ $s_lynis ] in current output");
        }
    }

    for my $s_lynis (@lynis_fail) {
        $s_new = "\\[.*$s_lynis.*\\]";
        $ret   = grep(/$s_new/, @section_current);
        if ($ret) {
            $result = "fail";
            # Invoke record_soft_failure() for better/notable openQA show
            record_soft_failure("poo#91383, found $ret [ $s_lynis ] in current output");
        }
    }

    return $result;
}

1;
