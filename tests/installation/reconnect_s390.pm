use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

use Data::Dumper qw(Dumper);
use Carp qw(confess cluck carp croak);

use feature qw/say/;


sub run() {
    
    # deactivate all the consoles
    deactivate_console("ctrl-alt-f2", "ssh-xterm_vt");
    deactivate_console("ctrl-alt-f3", "ssh-xterm_vt");
    deactivate_console("ctrl-alt-f4", "ssh-xterm_vt");
    deactivate_console("ctrl-alt-f5", "ssh-xterm_vt");
    deactivate_console("ctrl-alt-f6", "ssh-xterm_vt");
    deactivate_console("installation");

    wait_serial("Welcome to SUSE Linux Enterprise Server");

    activate_console("ctrl-alt-f2", "ssh-xterm_vt");
    activate_console("ctrl-alt-f3", "ssh-xterm_vt");
    activate_console("ctrl-alt-f4", "ssh-xterm_vt");
    activate_console("ctrl-alt-f5", "ssh-xterm_vt");
    activate_console("ctrl-alt-f6", "ssh-xterm_vt");

    if (get_var("DISPLAY")->{TYPE} eq "VNC") {
    # The vnc parameters are taken from vars.json; connect to the
    # Xvnc running on the system under test...
    activate_console("installation", "remote-vnc" );
    }
    elsif (get_var("DISPLAY")->{TYPE} eq "X11") {
        # connect via an ssh console, the start yast with the
        # appropriate parameters.
        # The ssh parameters are taken from vars.json
        activate_console("start-yast", "ssh");
        my $ssh = console("start-yast");
        $ssh->send_3270("String(\"Y2FULLSCREEN=1 yast\")");
        $ssh->send_3270("ENTER");
        #local $Devel::Trace::TRACE;
        #$Devel::Trace::TRACE = 1;
        activate_console("installation", "remote-window", 'YaST2@');
    }
    elsif (get_var("DISPLAY")->{TYPE} eq "SSH") {
        # The ssh parameters are taken from vars.json
        activate_console("installation", "ssh-xterm_vt");
        type_string("yast\n");
    }
    elsif (get_var("DISPLAY")->{TYPE} eq "SSH-X") {
        # The ssh parameters are taken from vars.json
        activate_console("start-yast", "ssh-X");
        my $ssh = console("start-yast");
        $ssh->send_3270("String(\"Y2FULLSCREEN=1 yast\")");
        $ssh->send_3270("ENTER");
        activate_console("installation", "remote-window", 'YaST2@');
    }
    else {
        die "unknown display type to access the host: ". get_var("DISPLAY")->{TYPE};
    }

    if (exists get_var("DEBUG")->{"demo consoles"}) {
        #local $Devel::Trace::TRACE;
        #$Devel::Trace::TRACE = 1;
        sleep 3;
        select_console("ctrl-alt-f2");
        type_string("echo 'Hello, just checking back at the c-a-f2'\n");
        sleep 1;
        if (get_var("DISPLAY")->{TYPE} eq "VNC") {
            type_string("DISPLAY=:0 xterm -title 'a worker xterm on the SUT Xvnc :D' &\n");
            select_console("installation");
            type_string("ls -laR\n");
        }
        select_console("bootloader");
        type_string("#cp q v dasd\n");
        wait_serial("0150", 2);
        sleep 5;
        select_console("installation");
        type_string("exit\n") if (get_var("DISPLAY")->{TYPE} eq "VNC");
        sleep 3;
        # DEBUG BUG FIXME FIXME FIXME why does this not work?  it works manually!
        send_key("ctrl-alt-shift-x");
        sleep 3;
        select_console("ctrl-alt-f2");
        type_string("echo 'and yet Hello, c-a-f2 World again!'\n");
        sleep 5;
        select_console("installation");
    }

    # FIXME this is for interactive sessions.
    if (exists get_var("DEBUG")->{"wait after linuxrc"}) {
        say "Hit enter here to continue test run.";

        # non-blocking wait for somthing on STDIN
        my $s = IO::Select->new();
        $s->add( \*STDIN );
        my @ready;
        while (!(@ready = $s->can_read())) {
            sleep 1;
        }
        for my $fh (@ready) {
            my $input = <$fh>;
        }

        say "resuming test...";

    }
    else {
        die $exception if $exception;
    }
}
