use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use testapi qw(set_var);
use version_utils qw(is_sle is_leap);
use x11utils qw(default_gui_terminal update_x11_vt);
use Test::MockModule;
use Cwd qw(getcwd);
use File::Temp qw(tempdir);
use Mojo::File qw(path);

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

subtest 'update_x11_vt' => sub {
    my @sequence;
    my $stale_removed;
    {
        package FakeX11Console;
        our $tty;
        sub set_tty { $tty = $_[1] }
    }
    my $x11 = Test::MockModule->new('x11utils', no_auto => 1);
    $x11->redefine(default_gui_terminal => sub { 'xterm' });
    $x11->redefine(x11_start_program => sub { push @sequence, 'start' });
    my ($url_arg, $read_arg);
    $x11->redefine(autoinst_url => sub { $url_arg = $_[0]; 'http://127.0.0.1/uploadlog/xdgvtnr' });
    $x11->redefine(enter_cmd => sub { push @sequence, 'upload'; $stale_removed = !-e 'ulogs/xdgvtnr' });
    $x11->redefine(read_ulog => sub { $read_arg = $_[0]; push @sequence, 'read'; "7\n" });
    $x11->redefine(assert_screen => sub { push @sequence, 'screen' });
    $x11->redefine(record_info => sub { });
    $x11->redefine(console => sub { bless {}, 'FakeX11Console' });

    my $cwd = getcwd;
    my $dir = tempdir(CLEANUP => 1);
    chdir $dir or die "chdir $dir: $!";
    path('ulogs')->make_path;
    path('ulogs/xdgvtnr')->spew("3\n");

    my $ok = eval { update_x11_vt(); 1 };
    my $error = $@;
    chdir $cwd or die "chdir $cwd: $!";
    die $error unless $ok;

    is_deeply \@sequence, [qw(start upload read screen)], 'reads the upload before the desktop assertion';
    is $FakeX11Console::tty, 7, 'sets the uploaded VT on the x11 console';
    is $url_arg, '/uploadlog/xdgvtnr', 'uploads to the file name it reads';
    is $read_arg, 'xdgvtnr', 'reads the file name it uploaded to';
    ok $stale_removed, 'removes the upload of a previous call before uploading again';
};

done_testing;
