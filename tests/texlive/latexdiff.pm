# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the latexdiff command with a simple example
# - Install texlive-latexdiff-bin
# - Run latexdiff between to latex files (original and modified) and save output
# - Convert output file from diff to pdf
# - Open created pdf and check
# - Cleanup
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console('root-console');
    zypper_call('in texlive-latexdiff-bin', timeout => 1800);
    select_console('x11');
    x11_start_program('xterm');

    assert_script_run 'mkdir texlive';
    assert_script_run 'latexdiff data/texlive/original.tex data/texlive/modify.tex > texlive/difference.tex';
    assert_script_run 'cd texlive';
    assert_script_run 'pdflatex difference.tex';

    script_run 'evince difference.pdf', 0;
    assert_screen 'texlive_diff';

    wait_screen_change { send_key "ctrl-w" };
    assert_script_run 'cd ..';
    assert_script_run 'rm -rf texlive';
    send_key "ctrl-d";
}
1;
