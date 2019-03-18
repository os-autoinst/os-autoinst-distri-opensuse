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
# Summary: AppArmor profile generation made easy testing
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36895, tc#1621144

use strict;
use warnings;
use base "apparmortest";
use testapi;
use utils;
use version_utils qw(is_sle is_leap);

sub run {
    my ($self) = @_;

    my $output_result = "/tmp/output";
    my $output_json   = "/tmp/manifest.json";

    my $easyprof_cmd = "aa-easyprof \\
--template=user-application \\
--policy-groups=opt-application,user-application \\
--abstractions=\"python,audio\" \\
--read-path=\"/usr/share/foo/*\" \\
--write-path=\"/opt/foo/tmp/\" \\
--write-path=\"/opt/foo/log/\" \\
--template-var=\"\@{APPNAME}=foo\" \\
--author=\"SUSE Tester\" \\
--copyright=\"Copyright 2018, SUSE Tester\" \\
--comment=\"AppArmor is easy with aa-easyprof\" \\
/usr/bin/foo ";

    my $easyprof_args_json = "--output-format=json ";

    # For old apparmor version, easyprof json file generation is not supported
    if (is_sle('<15') or is_leap('<15.0')) {    # apparmor < 2.11.95
        assert_script_run($easyprof_cmd . "> " . $output_result);
    }
    else {                                      # apparmor >= 2.11.95
        assert_script_run($easyprof_cmd . $easyprof_args_json . "> " . $output_json);
        assert_script_run("aa-easyprof --manifest=$output_json > $output_result");

        upload_logs($output_json);
    }

    upload_logs($output_result);

    validate_script_output "cat $output_result|tee /dev/$serialdev", sub {
        m/
                          Author.*SUSE\sTester.*
                          Copyright\s2018.*SUSE\sTester.*
						  include\s+<abstractions\/base>.*
						  include\s+<abstractions\/python>.*
						  include\s+<abstractions\/audio>.*
                          \/opt\/\@\{APPNAME\}\/\*\*\s+mrk.*
						  \/usr\/share\/foo\s+r.*
						  \/opt\/foo\/tmp\/\s+rwk.*
                          \}
						  /sxx
    };

}

1;
