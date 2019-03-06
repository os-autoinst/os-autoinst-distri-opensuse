use base "opensusebasetest";
use testapi;
use strict;
use utils;


sub run {
	my ($self,$test) = @_;
	$self->select_serial_terminal;

	my $HOST       = get_required_var('HOST_IP');
	my $USER       = get_required_var('HOST_USER');
	my $TESTS_PATH = get_required_var('TESTS_PATH');
	my $IMAGE      = get_required_var('IMAGE');

	my $path = $TESTS_PATH . $test;
	my $image = '/var/lib/openqa/share/factory/hdd/' . $IMAGE;
	my $cmd='qatrfm ' . ' --path ' . $path . ' --image ' . $image;
	my $output_log = $test . '.log';
	exec_and_insert_password('ssh -o StrictHostKeyChecking=no root@' . $HOST . ' -- ' . $cmd . ' &>' . $output_log, timeout=>1200);
	upload_logs($output_log);
}

1;