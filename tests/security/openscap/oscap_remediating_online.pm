# Copyright (C) 2018 SUSE LLC
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
#
# Summary: Post-scan remediation test - online
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36916, tc#1621174

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use openscaptest;

sub run {
    my $remediate_result = "scan-xccdf-remediate-results.xml";

    my $remediate_match = 'm/
                      Rule.*no_direct_root_logins.*Result.*fail.*
                      Rule.*rule_misc_sysrq.*Result.*fail.*
                      Starting\s+Remediation.*
                      Rule.*no_direct_root_logins.*Result.*fixed.*
                      Rule.*rule_misc_sysrq.*Result.*fixed/sxx';

    my $remediate_result_match = 'm/
              version="[0-9]+\.[0-9]+"\s+encoding="UTF-8".*
              <Benchmark.*<Profile\s+id="standard".*
              select.*no_direct_root_logins.*selected="true".*
              select.*rule_misc_sysrq.*selected="true".*
              Rule.*no_direct_root_logins"\s+selected="false".*
              Rule.*rule_misc_sysrq"\s+selected="false".*
              TestResult.*platform.*cpe:\/o:suse.*
              rule-result.*idref="no_direct_root_logins".*result.*fixed.*
              rule-result.*idref="rule_misc_sysrq".*result.*fixed.*
              score\s+system="urn:xccdf:scoring:default".*
              maximum="[0-9]+/sxx ';

    prepare_remediate_validation;

    # Remediate
    validate_script_output "oscap xccdf eval --remediate --profile standard --results $remediate_result xccdf.xml", sub { $remediate_match };
    validate_result($remediate_result, $remediate_result_match);

    # Verify the remediate action result
    validate_script_output "cat /etc/securetty",         sub { m/^$/ };
    validate_script_output "cat /proc/sys/kernel/sysrq", sub { m/^0$/ };

    # Restore
    finish_remediate_validation;
}

1;
