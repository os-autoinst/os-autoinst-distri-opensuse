use base "installbasetest";

use testapi;

use strict;
use warnings;
use English;

use Data::Dumper qw(Dumper);
use Carp qw(confess cluck carp croak);

use feature qw/say/;

###################################################################
# linuxrc helpers

sub linuxrc_menu() {
    my ($self, $menu_title, $menu_entry) = @_;
    # get the menu, ends with qr(^> ) prompt
    my $r = $self->{s3270}->expect_3270(output_delim => qr/^> /);
    ### say Dumper $r;

    # newline separate list of strings when interpolating @${r]
    local $LIST_SEPARATOR = "\n";

    if (!grep /^$menu_title/, @$r) {
	confess "menu does not match expected menu title ${menu_title}\n @${r}";
    }

    my @match_entry = grep /\) $menu_entry/, @$r;

    if (!@match_entry) {
	confess "menu does not contain expected menu entry ${menu_entry}:\n@${r}";
    }

    my ($match_id) = $match_entry[0] =~ /(\d+)\)/;

    my $sequence = ["Clear", "String($match_id)", "ENTER"];

    $self->{s3270}->sequence_3270(@$sequence);
}

sub linuxrc_prompt () {
    my ($self, $prompt, %arg) = @_;

    $arg{value}   //= '';
    $arg{timeout} //= 7;

    my $r = $self->{s3270}->expect_3270(output_delim => qr/(?:\[.*?\])?> /, timeout => $arg{timeout});

    ### say Dumper $r;

    # two lines or more
    # [previous repsonse]
    # PROMPT
    # [more PROMPT]
    # [\[EXPECTED_RESPONSE\]]>

    # newline separate list of strings when interpolating...
    local $LIST_SEPARATOR = "\n";

    if (!grep /^$prompt/, @$r[0..(@$r-1)] ) {
	confess "prompt does not match expected prompt (${prompt}) :\n@$r\n";
    }

    my $sequence = ["Clear", "String($arg{value})", "ENTER"];
    push @$sequence, "ENTER" if $arg{value} eq '';

    $self->{s3270}->sequence_3270(@$sequence);

}

sub ftpboot_menu () {
    my ($self, $menu_entry) = @_;

    my $r_screenshot = $self->{s3270}->expect_3270(clear_buffer => 1, flush_lines => undef, buffer_ready => qr/PF3=QUIT/);
    ## say Dumper $r_screenshot;

    my $r_home_position = $self->{s3270}->send_3270("Home");
    # Perl question:
    # Why can't I just call this function?  why do I need & ??
    # and why this FQDN?
    my $s_home_position = &backend::s390x::s3270::nice_3270_status($r_home_position->{terminal_status});

    my $cursor_row = $s_home_position->{cursor_row};

    ## say Dumper $r_screenshot;
    my $row = 0;
    my $found = 0;

    foreach (@$r_screenshot) {
	$found = 1, last if /$menu_entry/;
	++$row;
    }

    confess "ftpboot_menu: $menu_entry not found!\n" . join("\n", @$r_screenshot)
	unless $found;

    my $sequence = ["Home", ("Down") x ($row-$cursor_row), "ENTER", "Wait(InputField)"];
    ### say "\$sequence=@$sequence";

    $self->{s3270}->sequence_3270(@$sequence);

    return $r_screenshot;
}

###################################################################
require Text::Wrap;

sub hash2parmfile() {
    my ($parmfile_href) = @_;

    # collect the {key => value, ...}  pairs from the hash into a
    # space separated string "key=value ..." of assignments, in the
    # form needed in the parmfile.
    my @parmentries;

    while (my ($k, $v) = each %{$parmfile_href}) {
        push @parmentries, "$k=$v";
    }

    my $parmfile_with_Newline_s = join( " ", @parmentries);

    # Chop this long line up in hunks less than 80 characters wide, to
    # send them to the host with s3270 "String(...)" commands, with
    # additional "Newline" commands to add new lines.

    # Creatively use Text::Wrap for this, with 'String("' as line
    # prefix and '")\n' as line separator.  Actually '")\nNewline\n'
    # is the line separator :)
    local $Text::Wrap::separator;
    $Text::Wrap::separator = "\")\nNewline\n";

    # For the maximum line length for the wrapping, the s3270
    # 'String("")' command characters in each line don't account for
    # the parmfile line length.	 The X E D I T editor has a line
    # counter column to the left.
    local $Text::Wrap::columns;
    $Text::Wrap::columns = 79 + length('String("') - length("00004 ");

    $parmfile_with_Newline_s = Text::Wrap::wrap(
	'String("',		# first line prefix
	'String("',		# subsequent lines prefix
	$parmfile_with_Newline_s
    );

    # If there is no 'Newline\n' at the end of the parmfile, the last
    # line was not long enough to split it.  Then add the closing
    # paren and the Newline now.
    $parmfile_with_Newline_s .= "\")\nNewline"
      unless $parmfile_with_Newline_s =~ /Newline\n$/s;

    return $parmfile_with_Newline_s;
}

use backend::console_proxy;

#<<< don't perltidy this part:
# it makes perfect sense to have request and response _above_ each other

sub linuxrc_manual() {
    my $self = shift;

    my $s3270 = $self->{s3270};
    # wait for linuxrc to come up...
    my $r = $s3270->expect_3270(output_delim => qr/>>> Linuxrc/, timeout => 30);
    ### say Dumper $r;

    $self->linuxrc_menu("Main Menu", "Start Installation");
    $self->linuxrc_menu("Start Installation", "Start Installation or Update");
    $self->linuxrc_menu("Choose the source medium", "Network");
    $self->linuxrc_menu("Choose the network protocol", get_var("INSTSRC")->{PROTOCOL});

    if (((get_var("PARMFILE")->{ssh} // "0" ) eq "1" || (get_var("PARMFILE")->{sshd} // "0" ) eq "1") &&
	 (undef get_var("PARMFILE")->{sshpassword})) {
	die "temporary installation 'sshpassword' not set in PARMFILE in vars.json";
	$self->linuxrc_prompt("Enter your temporary SSH password.",
			      timeout => 30,
			      value => "SSH!554!");
    }

    if (check_var("NETWORK", "hsi-l3")) {
	$self->linuxrc_menu("Choose the network device",
			    "\QIBM Hipersocket (0.0.7000)\E");

	$self->linuxrc_prompt("Device address for read channel");
	$self->linuxrc_prompt("Device address for write channel");
	$self->linuxrc_prompt("Device address for data channel");

	$self->linuxrc_menu("Enable OSI Layer 2 support", "No");
	$self->linuxrc_menu("Automatic configuration via DHCP", "No");

    }
    elsif (check_var("NETWORK", "hsi-l2")) {
	$self->linuxrc_menu("Choose the network device",
			    "\QIBM Hipersocket (0.0.7100)\E");

	$self->linuxrc_prompt("Device address for read channel");
	$self->linuxrc_prompt("Device address for write channel");
	$self->linuxrc_prompt("Device address for data channel");

	## FIXME which mac address if YES?
	$self->linuxrc_menu("Enable OSI Layer 2 support", "Yes");
	$self->linuxrc_prompt("\QMAC address. (Enter '+++' to abort).\E");
	$self->linuxrc_menu("Automatic configuration via DHCP", "No");

    }
    elsif (check_var("NETWORK", "ctc")) {
	$self->linuxrc_menu("Choose the network device", "\QIBM parallel CTC Adapter (0.0.0600)\E");
	$self->linuxrc_prompt("Device address for read channel");
	$self->linuxrc_prompt("Device address for write channel");
	$self->linuxrc_menu("Select protocol for this CTC device", "Compatibility mode");
	$self->linuxrc_menu("Automatic configuration via DHCP", "No");
    }
    elsif (check_var("NETWORK", "vswitch-l3")) {
	$self->linuxrc_menu("Choose the network device", "\QIBM OSA Express Network card (0.0.0700)\E");
	$self->linuxrc_menu("Please choose the physical medium", "Ethernet");

	## in our set up, the default just works
	$self->linuxrc_prompt("Enter the relative port number");

	$self->linuxrc_prompt("Device address for read channel");
	$self->linuxrc_prompt("Device address for write channel");
	$self->linuxrc_prompt("Device address for data channel");

	$self->linuxrc_prompt("\QPortname to use\E");

	$self->linuxrc_menu("Enable OSI Layer 2 support", "No");

	$self->linuxrc_menu("Automatic configuration via DHCP", "No");

    }
    elsif (check_var("NETWORK", "vswitch-l2")) {
	$self->linuxrc_menu("Choose the network device", "\QIBM OSA Express Network card (0.0.0800)\E");
	$self->linuxrc_menu("Please choose the physical medium", "Ethernet");

	## in our set up, the default just works
	$self->linuxrc_prompt("Enter the relative port number");

	$self->linuxrc_prompt("Device address for read channel");
	$self->linuxrc_prompt("Device address for write channel");
	$self->linuxrc_prompt("Device address for data channel");

	$self->linuxrc_prompt("\QPortname to use\E");

	$self->linuxrc_menu("Enable OSI Layer 2 support", "Yes");
	$self->linuxrc_prompt("\QMAC address. (Enter '+++' to abort).\E");

	## TODO: vswitch L2 += DHCP
	$self->linuxrc_menu("Automatic configuration via DHCP", "No");

    }
    elsif (check_var("NETWORK", "iucv")) {
	$self->linuxrc_menu("Choose the network device", "\QIBM IUCV\E");

	$self->linuxrc_prompt("\QPlease enter the name (user ID) of the target VM guest\E",
			      value => "ROUTER01");

	$self->linuxrc_menu("Automatic configuration via DHCP", "No");
    }
    else {
	confess "unknown network device in vars.json: NETWORK = ${get_var('NETWORK')}";
    };

    # FIXME work around https://bugzilla.suse.com/show_bug.cgi?id=913723
    # normally use value from parmfile.
    $self->linuxrc_prompt("Enter your IPv4 address",
			  value => get_var("PARMFILE")->{HostIP});

    # FIXME: add NETMASK parameter to test "Entr your Netmask" branch
    # for now, give the netmask with the IP where needed.
    #if (check_var("NETWORK", "hsi-l3")||
    #    check_var("NETWORK", "hsi-l2")||
    #    check_var("NETWORK", "vswitch-l3")) {
    #    $self->linuxrc_prompt("Enter your netmask. For a normal class C network, this is usually 255.255.255.0.",
    #                          timeout => 10, # allow for the CTC peer to react
    #        );
    #}

    if (check_var("NETWORK", "hsi-l3")     ||
	check_var("NETWORK", "hsi-l2")     ||
	check_var("NETWORK", "vswitch-l2") ||
	check_var("NETWORK", "vswitch-l3")) {

	$self->linuxrc_prompt("Enter the IP address of the gateway. Leave empty if you don't need one.");
	$self->linuxrc_prompt("Enter your search domains, separated by a space",
			      timeout => 10);
    }
    elsif (check_var("NETWORK", "ctc") ||
	   check_var("NETWORK", "iucv")) {
	# FIXME why is this needed?  it is in the parmfile!
	$self->linuxrc_prompt("Enter the IP address of the PLIP partner.",
			      value   => get_var("PARMFILE")->{Gateway});

    };

    # use value from parmfile
    $self->linuxrc_prompt("Enter the IP address of your name server.",
			  timeout => 10);

    if (get_var("INSTSRC")->{PROTOCOL} eq "HTTP" ||
	get_var("INSTSRC")->{PROTOCOL} eq "FTP" ||
	get_var("INSTSRC")->{PROTOCOL} eq "NFS" ||
	get_var("INSTSRC")->{PROTOCOL} eq "SMB") {

	$self->linuxrc_prompt("Enter the IP address of the (HTTP|FTP|NFS) server",
			      value => get_var("INSTSRC")->{HOST});

	$self->linuxrc_prompt("Enter the directory on the server",
			      value => get_var("INSTSRC")->{DIR_ON_SERVER});
    }
    else {
	confess "unknown installation source in vars.json: INSTSRC = ${get_var('INSTSRC')}";
    };

    if (get_var("INSTSRC")->{PROTOCOL} eq "HTTP" ||
	get_var("INSTSRC")->{PROTOCOL} eq "FTP") {
	$self->linuxrc_menu("Do you need a username and password to access the (HTTP|FTP) server",
			    "No");

	$self->linuxrc_menu("Use a HTTP proxy",
			    "No");
    }

    $r = $s3270->expect_3270(
	output_delim => qr/Reading Driver Update/,
	timeout      => 50
	);

    ### say Dumper $r;

    $self->linuxrc_menu("Select the display type",
			get_var("DISPLAY")->{TYPE});

    if (get_var("DISPLAY")->{TYPE} eq "VNC" &&
	(undef get_var("PARMFILE")->{VNCPassword})) {
	$self->linuxrc_prompt("Enter your VNC password",
			      value => get_var("DISPLAY")->{PASSWORD} // die "vnc password unset in vars.json");
    }
    elsif (get_var("DISPLAY")->{TYPE} eq "X11") {
	$self->linuxrc_prompt("Enter the IP address of the host running the X11 server.",
			      # FIXME DISPLAY->SCREEN actually is (worker local) Xvnc now, i.e. VNC
			      value => get_var("DISPLAY")->{HOST} . ":" . get_var("DISPLAY")->{SCREEN});
    }
    elsif (get_var("DISPLAY")->{TYPE} eq "SSH") {

    };
}

sub linuxrc_unattended() {
    my $self = shift;
    # nothing to do.  just wait.
    if (defined get_var("PARMFILE")->{dud}) {
	my $r = $self->{s3270}->expect_3270(output_delim => qr/Reading driver update/,
					    timeout => 60);
	$r = $self->{s3270}->expect_3270(output_delim => qr/File not signed./,
					 timeout => 60);
	$self->linuxrc_menu("If you really trust your repository, you may continue in an insecure mode.",
			    "OK");
    };
    my $r = $self->{s3270}->expect_3270(output_delim => qr/Loading Installation System/,
					timeout => 60);

}

sub get_to_yast() {
    my $self = shift;
    my $s3270 = $self->{s3270};

    my $r;

    ###################################################################
    # ftpboot
    {
	my $zVM_bootloader = get_var('FTPBOOT')->{COMMAND};
	# FIXME if this is qaboot, call it like this
	# qaboot FTP_SERVER  DIR_TO_SUSE_INS
	my $ftp_server = get_var('FTPBOOT')->{FTP_SERVER};
	my $dir_with_suse_ins = get_var('FTPBOOT')->{PATH_TO_SUSE_INS};
	if ($zVM_bootloader eq "qaboot") {
	    $s3270->sequence_3270(
		"String(\"$zVM_bootloader $ftp_server $dir_with_suse_ins\")",
		"ENTER",
		"Wait(InputField)",
	    );
	} else {
	    $s3270->sequence_3270(
		"String($zVM_bootloader)",
		"ENTER",
		"Wait(InputField)",
	    );

	    my $host = get_var("FTPBOOT")->{HOST};
	    my $distro = get_var("FTPBOOT")->{DISTRO};
	    sleep(1);
	    $r = $self->ftpboot_menu(qr/\Q$host\E/);
	    $r = $self->ftpboot_menu(qr/\Q$distro\E/);
	}
    }

    ##############################
    # edit parmfile
    {
	$r = $s3270->expect_3270(buffer_ready => qr/X E D I T/, timeout => 240);

	$s3270->sequence_3270( qw{ String(INPUT) ENTER } );

	$r = $s3270->expect_3270(buffer_ready => qr/Input-mode/);
	### say Dumper $r;

	my $parmfile_href = get_var("PARMFILE");

	$parmfile_href->{ssh} = '1';

	my $parmfile_with_Newline_s = &hash2parmfile($parmfile_href);

	my $sequence = <<"EO_frickin_boot_parms";
${parmfile_with_Newline_s}
ENTER
ENTER
EO_frickin_boot_parms

	# can't use qw{} because of space in commands...
	$s3270->sequence_3270(split /\n/, $sequence);

	$r = $s3270->expect_3270(buffer_ready => qr/X E D I T/);

	## Remove the "manual=1" and the empty line at the end
	## of the parmfile.

	## HACK HACK HACK HACK this code just 'knows' there is
	## an empty line and a single "manual=1" at the bottom
	## of the ftpboot parmfile.  This may fail in obscure
	## ways when that changes.
	$s3270->sequence_3270(qw{String(BOTTOM) ENTER String(DELETE) ENTER});
	$s3270->sequence_3270(qw{String(BOTTOM) ENTER String(DELETE) ENTER});

	$r = $s3270->expect_3270(buffer_ready => qr/X E D I T/);

	# save the parmfile.  ftpboot then starts the installation.
	$s3270->sequence_3270( qw{ String(FILE) ENTER });

    }
    ###################################################################
    # linuxrc

    if (get_var("PARMFILE")->{manual} eq "0") {
	$self->linuxrc_unattended();
    }
    elsif (get_var("PARMFILE")->{manual} eq "1") {
	$self->linuxrc_manual();
    }
    else {
	die "must specify vars.json->PARMFILE->manual=[01]";
    };
    my $startshell = get_var("PARMFILE")->{startshell} || "0";
    my $display_type = get_var("DISPLAY")->{TYPE};
    my $output_delim =
	$startshell ?
	    qr/\QATTENTION: Starting shell...\E/ :
	$display_type eq "SSH" ||
	$display_type eq "SSH-X" ?
	    qr/\Q***  run 'yast' to start the installation  ***\E/ :
	$display_type eq "X11" ?
	    qr/\Q***  run 'yast' to start the installation  ***\E/ :
	$display_type eq "VNC" ?
	    qr/\Q*** Starting YaST2 ***\E/ :
	    die "unknown vars.json:DISPLAY->TYPE <$display_type>";

    $r = $s3270->expect_3270(
	output_delim => $output_delim,
	timeout      => 20
    );

}

sub run() {

    my $self = shift;

    my $r;

    # The backend magically sets up the s3270 zVM console from
    # vars.json in the backend, so a later connect_and_login 'knows'
    # what to do, again in the backend.
    activate_console("bootloader", "s3270");
    my $s3270 = console("bootloader");

    # remember for the other methods in this test
    $self->{s3270} = $s3270;

    eval {
	###################################################################
	# connect to zVM, login to the guest
	my $reconnect = exists get_var("DEBUG")->{"no get_to_yast"};
	$r = $s3270->connect_and_login($reconnect);

	$self->get_to_yast() unless $reconnect;
    };

    my $exception = $@;

    die join("\n", '#'x67, $exception, '#'x67) if $exception;

    # create a "ctrl-alt-f2" ssh console which can be the target of
    # any send_key("ctrl-alt-fX") commands.  used in backend::s390x.
    activate_console("ctrl-alt-f2", "ssh");

    type_string("echo 'Hello, ssh World\! nice typing at the vnc front door here...'\n");

    my $ssh = console("ctrl-alt-f2");
    $ssh->send_3270('String("echo \'How about some speed typing at the x3270 script interface ;p ?\'")');
    $ssh->send_3270('ENTER');
    sleep 3;
    type_string("echo 'gonna start the YaSTie now...'\n");

    ###################################################################
    # now connect to the running VNC server
    # FIXME: this should connect to the terminal, ssh or vnc or X11...
    # and for SSH it then needs to start yast.
    if (get_var("DISPLAY")->{TYPE} eq "VNC") {
	# FIXME this really is just for itneractive debugging.  pull it out.
	if (exists get_var("DEBUG")->{"wait after linuxrc"}) {
	    say "vnc should be running.\n".
		"Hit enter here to vnc_connect.";

	    my $dummy = <STDIN>;

	    say "doing vnc_connect...";

	};

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
	activate_console("installation", "ssh");
	my $ssh = console("installation");
	$ssh->send_3270("String(\"yast\")");
	$ssh->send_3270("ENTER");
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
    #local $Devel::Trace::TRACE;
    #$Devel::Trace::TRACE = 1;
    # FIXME this really is just for interactive debugging.  pull it out.
    if (exists get_var("DEBUG")->{"wait after linuxrc"}) {
	say "get your system ready.\n".
	    "Hit enter here to continue test run.";

	# non-blocking wait for somthing on STDIN
	my $s = IO::Select->new();
	$s->add( \*STDIN );
	my @ready;
	while (!(@ready = $s->can_read())) { sleep 1; }
	for my $fh (@ready) {
	    my $input = <$fh>;
	}

	say "resuming test...";

    }
    else {
	die $exception if $exception;
    }

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
    sleep 5;
    select_console("installation");
    type_string("exit # the xterm\n") if (get_var("DISPLAY")->{TYPE} eq "VNC");
    sleep 3;
    # DEBUG BUG FIXME FIXME FIXME why does this not work?  it works manually!
    send_key("ctrl-alt-shift-x");
    sleep 3;
    select_console("ctrl-alt-f2");
    type_string("echo 'and yet Hello, c-a-f2 World again!'\n");
    sleep 5;
    select_console("installation");

}
#>>> perltidy again from here on

1;
