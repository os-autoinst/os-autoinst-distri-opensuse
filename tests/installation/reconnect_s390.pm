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
    deactivate_console("ctrl-alt-f2");
    deactivate_console("ctrl-alt-f3");
    deactivate_console("ctrl-alt-f4");
    deactivate_console("ctrl-alt-f5");
    deactivate_console("ctrl-alt-f6");
    deactivate_console("installation");

    send_key 'ctrl-alt-f1'; #Debug for rbrown
    save_screenshot; #Debug for rbrown

    wait_serial("Welcome to SUSE Linux Enterprise Server", 300);

    activate_console("ctrl-alt-f2", "ssh-xterm_vt");
    activate_console("ctrl-alt-f3", "ssh-xterm_vt");
    activate_console("ctrl-alt-f4", "ssh-xterm_vt");
    activate_console("ctrl-alt-f5", "ssh-xterm_vt");
    activate_console("ctrl-alt-f6", "ssh-xterm_vt");

#TODO - this test probably needs to be smarter and use one of the newly created xterms to configure/start VNC, and then be dumber, because we're not going to test X11, SSH-X and SSH textmode after this point
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
}

1;
