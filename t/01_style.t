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
done_testing;
