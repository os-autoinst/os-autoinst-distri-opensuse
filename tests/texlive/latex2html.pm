# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: latex2html
# Summary: Test the  latex2html command with a simple example
# - Install latex2html
# - Run late2html command on LaTex document to convert it to HTML
# - Open created HTML and check
# - Cleanup
# Maintainer: QE Core <qe-core@suse.de>

use base 'x11test';
use x11utils 'ensure_unlocked_desktop';
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

my $latex_data = <<EOF;
\\documentclass{article}
\\begin{document}
Hello, this is a LaTeX sample example page!
EOF
sub run {
    my ($self) = @_;
    select_serial_terminal;
    # Install latex2html package
    zypper_call('in latex2html', timeout => 1800);
    script_output "echo '$latex_data' >> /tmp/latex_sample.tex";
    # Convert the LaTeX document to HTML using latex2html
    assert_script_run("latex2html /tmp/latex_sample.tex");

    select_console('x11', await_console => 0);
    ensure_unlocked_desktop();
    $self->start_firefox_with_profile;
    # HTML Page
    $self->firefox_open_url('/tmp/latex_sample/index.html', assert_loaded_url => 'latex_sample_indexpage');
    wait_still_screen 2;
    assert_screen("latex_sample_indexpage", 60);
    $self->cleanup();
}

sub cleanup {
    my $self = shift;
    $self->exit_firefox;
    select_serial_terminal;
    assert_script_run("rm /tmp/latex_sample.tex");
    assert_script_run("rm -r /tmp/latex_sample");
    select_console 'x11', await_console => 0;
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}
1;
