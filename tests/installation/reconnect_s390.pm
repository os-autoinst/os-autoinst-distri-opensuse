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
}
