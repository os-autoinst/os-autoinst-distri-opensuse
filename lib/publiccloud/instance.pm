# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for public cloud instances
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::instance;
use testapi;
use Carp croak;
use Mojo::Base -base;
use Mojo::Util 'trim';
use File::Basename;

use constant SSH_TIMEOUT => 90;

has instance_id => undef;                                                                             # unique CSP instance id
has public_ip   => undef;                                                                             # public IP of instance
has username    => undef;                                                                             # username for ssh connection
has ssh_key     => undef;                                                                             # path to ssh-key for connection
has image_id    => undef;                                                                             # image from where the VM is booted
has type        => undef;
has provider    => undef, weak => 1;                                                                  # back reference to the provider
has ssh_opts    => '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR';

=head2 run_ssh_command

    run_ssh_command(cmd => 'command', timeout => 90);

Runs a command C<cmd> via ssh in the given VM. Retrieves the output.
If the command retrieves not zero, a exception is thrown..
Timeout can be set by C<timeout> or 90 sec by default.
TODO Do not raise exception on error
TODO Be aware of special shell letters like ';'
=cut
sub run_ssh_command {
    my ($self, %args) = @_;

    die('Argument <cmd> missing') unless ($args{cmd});

    $args{timeout} //= SSH_TIMEOUT;

    my $ssh_cmd = sprintf('ssh %s -i "%s" "%s@%s" -- %s',
        $self->ssh_opts, $self->ssh_key, $self->username, $self->public_ip, $args{cmd});
    record_info('SSH CMD', $ssh_cmd);
    delete($args{cmd});
    $args{quiet} //= 1;
    return script_output($ssh_cmd, %args);
}

=head2 scp

    scp($from, $to, timeout => 90);

Use scp to copy a file from or to this instance. A url starting with
C<remote:> is replaced with the IP from this instance. E.g. a call to copy
the file I</var/log/cloudregister> to I</tmp> looks like:
C<<<$instance->scp('remote:/var/log/cloudregister', '/tmp');>>>
=cut
sub scp {
    my ($self, $from, $to, %args) = @_;
    $args{timeout} //= SSH_TIMEOUT;

    my $url = sprintf('%s@%s:', $self->username, $self->public_ip);
    $from =~ s/^remote:/$url/;
    $to   =~ s/^remote:/$url/;

    my $ssh_cmd = sprintf('scp %s -i "%s" "%s" "%s"',
        $self->ssh_opts, $self->ssh_key, $from, $to);

    return script_run($ssh_cmd, %args);
}

=head2 upload_log

    upload_log($filename);

Upload a file from this instance to openqa using L<upload_logs()>.
If the file doesn't exists on the instance, B<no> error is thrown.
=cut
sub upload_log {
    my ($self, $remote_file) = @_;

    my $tmpdir = script_output('mktemp -d');
    my $dest   = $tmpdir . '/' . basename($remote_file);
    my $ret    = $self->scp('remote:' . $remote_file, $dest);
    if (defined($ret) && $ret == 0) {
        upload_logs($dest);
    }
    assert_script_run("test -d '$tmpdir' && rm -rf '$tmpdir'");
}

=head2 wait_fo_guestregister

    wait_for_guestregister([timeout => 300]);

Run command C<systemctl is-active guestregister> on the instance in a loop
for max C<timeout> seconds until it will return inactive.
=cut
sub wait_for_guestregister
{
    my ($self, %args) = @_;
    $args{timeout} //= 300;
    my $start_time = time();
    my $last_info  = 0;

    while (time() - $start_time < $args{timeout}) {
        my $out = $self->run_ssh_command(cmd => 'sudo systemctl is-active guestregister', proceed_on_failure => 1, quiet => 1);
        if ($out eq 'inactive') {
            return time() - $start_time;
        }
        if (time() - $last_info > 10) {
            record_info('WAIT', 'Wait for guest register: ' . $out);
            $last_info = time();
        }
        sleep 1;
    }
    die('guestregister didn\'t end in expected timeout=' . $args{timeout});
}

=head2 check_ssh_port

    check_ssh_port([timeout => 600] [, proceed_on_failure => 0])

Check if the SSH port of the instance is reachable and open.
=cut
sub check_ssh_port
{
    my ($self, %args) = @_;
    $args{timeout}            //= 600;
    $args{proceed_on_failure} //= 0;
    my $start_time = time();

    while ((my $duration = time() - $start_time) < $args{timeout}) {
        return $duration if (script_run('nc -vz -w 1 ' . $self->{public_ip} . ' 22', quiet => 1) == 0);
        sleep 1;
    }
    croak(sprintf("Unable to reach SSH port of instance %s with public IP:%s within %d seconds",
            $self->{instance_id}, $self->{public_ip}, $self->{timeout}))
      unless ($args{proceed_on_failure});
    return;
}

=head2 softreboot

    ($shutdown_time, $bootup_time) = softreboot([timeout => 600]);

Does a softreboot of the instance by running the command C<shutdown -r>.
Return an array of two values, first one is the time till the instance isn't
reachable anymore. The second one is the estimated bootup time.
=cut
sub softreboot
{
    my ($self, %args) = @_;
    $args{timeout} //= 600;

    my $duration;

    $self->run_ssh_command(cmd => 'sudo shutdown -r +1');
    # skip the one minute waiting
    sleep 60;
    my $start_time = time();

    # wait till ssh disappear
    while (($duration = time() - $start_time) < $args{timeout}) {
        last unless (defined($self->check_ssh_port(timeout => 1, proceed_on_failure => 1)));
    }
    my $shutdown_time = time() - $start_time;
    die("Waiting for system down failed!") unless ($shutdown_time < $args{timeout});
    my $bootup_time = $self->check_ssh_port(timeout => $args{timeout} - $shutdown_time);
    return ($shutdown_time, $bootup_time);
}

=head2 stop

    stop();

Stop the instance using the CSP api calls.
=cut
sub stop
{
    my $self = shift;
    $self->provider->stop_instance($self, @_);
}

=head2 start

    start([timeout => ?]);

Start the instance and check SSH connectivity. Return the number of seconds
till the SSH port was available.
=cut
sub start
{
    my ($self, %args) = @_;
    $self->provider->start_instance($self, @_);
    return $self->check_ssh_port(timeout => $args{timeout});
}

1;
