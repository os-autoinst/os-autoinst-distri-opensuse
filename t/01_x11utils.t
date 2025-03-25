use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use testapi qw(set_var);
use version_utils qw(is_sle is_leap);


subtest 'Expected_terminals' => sub {
    use x11utils 'default_gui_terminal';

    set_var('DISTRI', 'microos');
    ok default_gui_terminal eq 'xterm', "Defaults to xterm in unknown distri";

    set_var('DESKTOP', 'gnome');
    set_var('DISTRI', 'sle');
    set_var('VERSION', '16-SP1');
    ok default_gui_terminal eq 'kgx', "Defaults to kgx for SLE 16";

    set_var('DESKTOP', 'gnome');
    set_var('DISTRI', 'sle');
    set_var('VERSION', '15-sp7');
    ok default_gui_terminal eq 'xterm', "15-sp7 returns xterm";

    set_var('DESKTOP', 'gnome');
    set_var('DISTRI', 'opensuse');
    set_var('VERSION', 'Tumbleweed');
    ok default_gui_terminal eq 'kgx', "Tumbleweed defaults to gnome-console";

    set_var('DESKTOP', 'gnome');
    set_var('DISTRI', 'opensuse');
    set_var('VERSION', '16.1');
    ok default_gui_terminal eq 'kgx', "Leap 16+ defaults to gnome-console";

    set_var('DESKTOP', 'gnome');
    set_var('DISTRI', 'opensuse');
    set_var('VERSION', '15.6');
    ok default_gui_terminal eq 'gnome-terminal', "Leap 15 returns gnome-terminal";

};

done_testing;
