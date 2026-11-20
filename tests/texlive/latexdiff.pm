# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: texlive-latexdiff-bin
# Summary: Test the latexdiff command with a simple example
# - Install texlive-latexdiff-bin
# - Run latexdiff between to latex files (original and modified) and save output
# - Convert output file from diff to pdf
# - Open created pdf and check
# - Cleanup
# Maintainer: Katerina Lorenzova <klorenzova@suse.cz>

use Mojo::Base 'x11test';
use testapi;
use utils;
use x11utils 'default_gui_terminal';
use version_utils 'is_sle';

sub run {
    select_console('root-console');
    zypper_call('in texlive-latexdiff-bin', timeout => 1800);
    select_console('x11');
    x11_start_program(default_gui_terminal);

    assert_script_run 'mkdir texlive';
    assert_script_run 'latexdiff data/texlive/original.tex data/texlive/modify.tex > texlive/difference.tex';
    assert_script_run 'cd texlive';
    assert_script_run 'pdflatex difference.tex';

    # Tumbleweed no longer installs evince by default, use papers instead
    # SLE ships an older GNOME, so evince is still available there.
    my $pdf_viewer = is_sle ? 'evince' : 'papers';
    ensure_installed($pdf_viewer);
    x11_start_program(default_gui_terminal);
    script_run "$pdf_viewer texlive/difference.pdf", 0;
    assert_screen 'texlive_diff';

    wait_screen_change { send_key "ctrl-w" };
    assert_script_run 'cd ..';
    assert_script_run 'rm -rf texlive';
    send_key "ctrl-d";
}
1;
