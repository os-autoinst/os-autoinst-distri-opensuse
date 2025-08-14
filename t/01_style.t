#!/usr/bin/perl
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;

# :!*.ps is supposed to match on all files but files matching to "*.ps" - see man 7 glob
my $out = qx{git grep -I -l 'Copyright \\((C)\\|(c)\\|©\\)' ':!*.ps'};
ok $? != 0 && $out eq '', 'No redundant copyright character' or diag $out;
ok system(qq{git grep -I -l 'This program is free software.*if not, see <http://www.gnu.org/licenses/' ':!t/01_style.t'}) != 0, 'No verbatim GPL licenses in source files';
ok system(qq{git grep -I -l '[#/ ]*SPDX-License-Identifier ' ':!t/01_style.t'}) != 0, 'SPDX-License-Identifier correctly terminated';
$out = qx{git grep -ne "check_var('ARCH',.*)" -e "check_var('BACKEND',.*)" ':!lib/Utils/Architectures.pm' ':!lib/Utils/Backends.pm' 'lib' 'tests'};
ok $? != 0 && $out eq '', 'No check_var function to verify ARCH/BACKEND types' or diag $out;
ok system(qq{git grep -I -l \\( -e "egrep" -e "fgrep" \\) ':!t/01_style.t' ':!CONTRIBUTING.md'}) != 0, 'No usage of the deprecated egrep and fgrep commands';
$out = qx{git grep -I -l 'nots3cr3t' ':!data/wsl/Autounattend_*.xml' 'data' | xargs grep -E -L '(luks|encryption).*password.*nots3cr3t'};
ok $out eq '', 'No plain password on data directory' or diag $out;
ok system(qq{git grep -I -l 'use \\(strict\\|warnings\\);' 'tests'}) != 0, 'No redundant strict|warnings in test modules. Already covered in https://github.com/os-autoinst/os-autoinst/blob/master/basetest.pm#L32';
done_testing;
