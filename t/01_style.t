#!/usr/bin/perl
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use Test::Most;
use Mojo::File 'path';

# :!*.ps is supposed to match on all files but files matching to "*.ps" - see man 7 glob
my $out = qx{git grep -I -l 'Copyright \\((C)\\|(c)\\|©\\)' ':!*.ps'};
ok $? != 0 && $out eq '', 'No redundant copyright character' or diag $out;
ok system(qq{git grep -I -l 'This program is free software.*if not, see <http://www.gnu.org/licenses/' ':!t/01_style.t'}) != 0, 'No verbatim GPL licenses in source files';
ok system(qq{git grep -I -l '[#/ ]*SPDX-License-Identifier ' ':!t/01_style.t'}) != 0, 'SPDX-License-Identifier correctly terminated';
$out = qx{git grep -ne "check_var('ARCH',.*)" -e "check_var('BACKEND',.*)" ':!lib/Utils/Architectures.pm' ':!lib/Utils/Backends.pm' 'lib' 'tests'};
ok $? != 0 && $out eq '', 'No check_var function to verify ARCH/BACKEND types' or diag $out;
ok system(qq{git grep -I -l \\( -e "egrep" -e "fgrep" \\) ':!t/01_style.t' ':!CONTRIBUTING.md'}) != 0, 'No usage of the deprecated egrep and fgrep commands';

# Find all files in 'data' directory containing 'nots3cr3t', excluding specific WSL files.
# Then, filter out files that have an allowed context for the password.
my @bad_files = grep {
    chomp $_;    #  chomp $_ the filename
                 # Allowed pattern: file contains 'nots3cr3t' but on the same line of other keywords.
                 # If the file contains the secret but does NOT contain the allowed pattern, it's problematic
    path($_)->slurp !~ qr/(luks|encryption).*password.*nots3cr3t/;
} qx{git grep -I -l 'nots3cr3t' ':!data/wsl/Autounattend_*.xml' 'data'};
# As grep {} expect a list, qx doesn't return the command's output as a single string, but is returns
# a list of strings, where each element is one line from the command's output.
ok !@bad_files, 'No plain password in files within data directory';

done_testing;
