# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Runs several ncurses tests from ncurses package
# - Text attributes
# - Colors
# - Special characters
# - menus
# - panels
# - forms
# - background combinations
# - key capture
# - window movements

# Maintainer: Ivan Lausuch <ilausuch@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use repo_tools 'prepare_source_repo';
use version_utils 'is_sle';

sub send_key_n_times {
    my ($key, $count) = @_;
    send_key $key for (1 .. $count);
}

sub auto_ncurses {
    my ($option, $screen) = @_;

    type_string "./ncurses\n";
    type_string $option. "\n";
    assert_screen $screen;
    send_key 'ctrl-c';
}

sub run {
    select_console 'root-console';

    prepare_source_repo;

    zypper_call 'source-install ncurses';
    zypper_call 'install ncurses-devel';
    zypper_call 'install rpmbuild';

    assert_script_run("rpmbuild -bb /usr/src/packages/SPECS/ncurses.spec", 30 * 60);
    assert_script_run "cd /usr/src/packages/BUILD/ncurses*/test";
    assert_script_run "./configure";
    assert_script_run "make";
    assert_script_run "gcc -o ncurses ncurses.c -lform -lpanel -lmenu -lncurses -I. -D HAVE_FORM_H=1 -D HAVE_MENU_H=1 -D HAVE_PANEL_H=1 -I/usr/include/ncurses";

    assert_script_run "./test_arrays";
    assert_script_run "./demo_termcap";

    auto_ncurses('b',    "ncurses-ncurses-attributes");
    auto_ncurses('c',    "ncurses-ncurses-colors");
    auto_ncurses('f\nw', "ncurses-ncurses-chars");
    auto_ncurses('m\n',  "ncurses-ncurses-menu");
    auto_ncurses('o',    "ncurses-ncurses-panel");

    type_string "./ncurses\n";
    type_string "r\n";
    wait_still_screen 1;
    type_string "test\n";
    wait_still_screen 1;
    type_string "test";
    assert_screen "ncurses-ncurses-form";
    send_key 'esc';
    wait_still_screen 1;
    type_string "q\n";

    type_string "./background\n";
    assert_screen "ncurses-background-1";
    send_key_n_times('ret', 3);
    assert_screen "ncurses-background-2";
    send_key_n_times('ret', 5);
    assert_screen "ncurses-background-3";
    send_key 'ctrl-c';

    type_string "./demo_keyok\n";
    send_key 'a';
    send_key 'b';
    send_key 'ret';
    assert_screen "ncurses-demo-keyok";
    send_key 'ctrl-c';

    type_string "./hanoi\n";
    assert_screen "ncurses-hanoi";
    send_key 'ctrl-c';

    type_string "./movewindow\n";
    send_key 'c';
    send_key_n_times('right', 5);
    send_key_n_times('down',  5);
    send_key 'ret';
    send_key_n_times('right', 5);
    send_key_n_times('down',  5);
    send_key 'ret';
    send_key 'b';
    send_key 'm';
    send_key_n_times('right', 5);
    assert_screen "ncurses-movewindow";
    send_key 'ctrl-c';
}

1;
