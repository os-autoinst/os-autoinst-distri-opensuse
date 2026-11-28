use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use testapi qw(set_var);
use version_utils qw(is_sle is_leap);
use x11utils qw(default_gui_terminal update_x11_vt);
use Test::MockModule;
use File::Temp qw(tempdir);
use Mojo::File qw(path);

{
    package FakeConsole;
    our $tty;
    sub set_tty { $tty = $_[1] }
}

subtest 'Expected_terminals' => sub {


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

subtest '_get_graphical_console_tty' => sub {
    my (@cmds, @consoles);
    my $x11 = Test::MockModule->new('x11utils', no_auto => 1);
    $x11->redefine(enter_cmd => sub { push @cmds, $_[0] });
    $x11->redefine(select_console => sub { push @consoles, $_[0] });
    $x11->redefine(script_output => sub { push @cmds, $_[0]; "7\n" });
    $x11->redefine(assert_script_run => sub { push @cmds, $_[0] });
    $x11->redefine(read_ulog => sub { });
    $x11->redefine(autoinst_url => sub { 'http://127.0.0.1:20243/TOKEN' . $_[0] });

    is x11utils::_get_graphical_console_tty(1), "7\n", 'reads the VT from the SUT in offline mode';
    is_deeply \@consoles, ['root-console'], 'switches to the root console in offline mode';
    is_deeply \@cmds, ['echo $XDG_VTNR > /tmp/vt_nr && exit', 'cat /tmp/vt_nr', 'rm /tmp/vt_nr'],
      'writes, reads and removes the VT file in offline mode';

    my $upload = path(tempdir(CLEANUP => 1), 'xdgvtnr')->spew("9\n");
    $x11->redefine(read_ulog => sub { $upload });
    is x11utils::_get_graphical_console_tty(0), "9\n", 'reads the uploaded VT in online mode';
    like $cmds[-1], qr{uploadlog/xdgvtnr}, 'uploads the VT in online mode';
    ok !-e $upload, 'removes the upload';
};

subtest 'update_x11_vt' => sub {
    my (@sequence, @recorded);
    local $FakeConsole::tty = undef;
    my $x11 = Test::MockModule->new('x11utils', no_auto => 1);
    $x11->redefine(default_gui_terminal => sub { 'xterm' });
    $x11->redefine(x11_start_program => sub { push @sequence, 'start' });
    $x11->redefine(_get_graphical_console_tty => sub { push @sequence, "tty($_[0])"; '11' });
    $x11->redefine(record_info => sub { push @recorded, $_[0] });
    $x11->redefine(console => sub { bless {}, 'FakeConsole' });
    $x11->redefine(assert_screen => sub { push @sequence, 'screen' });
    $x11->redefine(select_console => sub { push @sequence, "console($_[0])" });

    set_var('OFFLINE_SUT', 0);
    update_x11_vt();
    is_deeply \@sequence, ['start', 'tty(0)', 'screen'], 'reads the VT and asserts the desktop for an online SUT';
    is $FakeConsole::tty, 11, 'sets the VT on the x11 console';
    is $recorded[0], 'XDG_VTNR', 'records the VT';

    set_var('OFFLINE_SUT', 1);
    @sequence = ();
    update_x11_vt();
    is_deeply \@sequence, ['start', 'tty(1)', 'console(x11)'], 'selects the x11 console for an offline SUT';

    $x11->redefine(_get_graphical_console_tty => sub { 'foo' });
    throws_ok { update_x11_vt() } qr/Failed to get VT number from X11 session/, 'dies on a non-numeric VT';
};

done_testing;
