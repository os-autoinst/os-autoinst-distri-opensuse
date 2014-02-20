use base "basetest";
use bmwqemu;
# check if sshd works
sub run()
{
	my $self=shift;
	become_root();
	script_run('SuSEfirewall2 off');
	script_run('chkconfig sshd on');
	script_run("chkconfig sshd on && echo 'sshd_on' > /dev/$serialdev");
	waitserial("sshd_on", 60) || die "enable sshd failed";
	script_run("rcsshd restart && echo 'sshd_restart' > /dev/$serialdev"); # will do nothing if it is already running
	waitserial("sshd_restart", 60) || die "restart sshd failed";
	script_run('echo $?');
	script_run('rcsshd status');
	script_run('exit');
	$self->check_screen;
}

sub test_flags() {
   return {'milestone' => 1};
}

1;
