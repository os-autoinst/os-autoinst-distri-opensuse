use base "basetest";
use bmwqemu;
sub run()
{
	my $self=shift;
	become_root();
	# cdrom is ejected already, disabled cdrom repo in zypper
	script_run("zypper mr -d -R -m cd");
	script_run("zypper lr -d > /dev/$serialdev");
	script_run("killall gpk-update-icon kpackagekitsmarticon packagekitd");
	#script_run("zypper ar http://download.opensuse.org/repositories/Cloud:/EC2/openSUSE_Factory/Cloud:EC2.repo"); # for suse-ami-tools
	script_run("zypper --gpg-auto-import-keys -n in screen xdelta suse-ami-tools && echo 'installed' > /dev/$serialdev");
	waitserial("installed", 200) || die "zypper install failed";
	waitidle 5;
	script_run('echo $?');
	$self->check_screen;
	sleep 5;
	sendkey "ctrl-l"; # clear screen to see that second update does not do any more
	my $pkgname="xdelta";
	script_run("rpm -e $pkgname && echo 'package_removed' > /dev/$serialdev");
	waitserial("package_removed") || die "package remove failed";
	script_run("rpm -q $pkgname");
	script_run('exit');
	$self->check_screen;
}

1;
