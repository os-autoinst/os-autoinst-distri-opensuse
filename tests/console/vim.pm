# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: vim
# Summary: Test vim editor display including syntax highlighting
# - Check if vim is installed
# - Check if vim-data is installed (should not be on JeOS)
# - Run "vim /etc/passwd"
# - Check if file is opened correctly (with syntax highlight)
# - Force exit vim (":q!")
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use version_utils qw(is_jeos);

sub run {
    select_console 'root-console';
    assert_script_run 'rpm -qi --whatprovides vim_client';
    # vim-data package must not be present on JeOS
    assert_script_run('! rpm -qi vim-data') if is_jeos();
    enter_cmd "vim /etc/passwd";
    my $jeos = is_jeos() ? '-jeos' : '';
    assert_screen "vim-showing-passwd$jeos";
    wait_screen_change { enter_cmd ":q!" };
}

1;
