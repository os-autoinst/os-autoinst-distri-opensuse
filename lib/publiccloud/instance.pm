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
use Carp 'croak';
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

    run_ssh_command(cmd => 'command'[, timeout => 90][, ssh_opts =>'..'][, username => 'XXX'][, no_quote => 0][, rc_only => 0]);

Runs a command C<cmd> via ssh in the given VM. Retrieves the output.
If the command retrieves not zero, a exception is thrown..
Timeout can be set by C<timeout> or 90 sec by default.
C<<proceed_on_failure=>1>> allows to proceed with validation when C<cmd> is
failing (return non-zero exit code)
By default, the command is passed in single quotes to SSH.
To avoid quoting us C<<no_quote=>1>>.
With C<<ssh_opts=>'...'>> you can overwrite all default ops which are in
C<<$instance->ssh_opts>>.
Use argument C<username> to specify a different username then
C<<$instance->username()>>.
Use argument C<rc_only> to only check for the return code of the command.
=cut
sub run_ssh_command {
    my ($self, %args) = @_;
    die('Argument <cmd> missing') unless ($args{cmd});
    $args{ssh_opts} //= $self->ssh_opts() . " -i '" . $self->ssh_key . "'";
    $args{username} //= $self->username();
    $args{timeout}  //= SSH_TIMEOUT;
    $args{quiet}    //= 1;
    $args{no_quote} //= 0;
    my $rc_only = $args{rc_only} // 0;

    my $cmd = $args{cmd};
    unless ($args{no_quote}) {
        $cmd =~ s/'/'"'"'/g;
        $cmd = "'$cmd'";
    }

    my $ssh_cmd = sprintf('ssh %s "%s@%s" -- %s',
        $args{ssh_opts}, $args{username}, $self->public_ip, $cmd);
    record_info('SSH CMD', $ssh_cmd);

    delete($args{cmd});
    delete($args{no_quote});
    delete($args{ssh_opts});
    delete($args{username});
    delete($args{rc_only});
    if ($args{timeout} == 0) {
        # Run the command and don't wait for it - no output nor returncode here
        script_run($ssh_cmd, %args);
    } elsif ($rc_only) {
        # Run the command and return only the returncode here
        my $ret = script_run($ssh_cmd, %args);
        die("Timeout on $ssh_cmd") unless (defined($ret));
        return $ret;
    } else {
        # Run the command, wait for it and return the output
        return script_output($ssh_cmd, %args);
    }
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
    my ($self, $remote_file, %args) = @_;

    my $tmpdir = script_output('mktemp -d');
    my $dest   = $tmpdir . '/' . basename($remote_file);
    my $ret    = $self->scp('remote:' . $remote_file, $dest);
    upload_logs($dest, %args) if (defined($ret) && $ret == 0);
    assert_script_run("test -d '$tmpdir' && rm -rf '$tmpdir'");
}

=head2 wait_for_guestregister

    wait_for_guestregister([timeout => 300]);

Run command C<systemctl is-active guestregister> on the instance in a loop and
wait till guestregister is ready. If guestregister finish with state failed,
a soft-failure will be recorded.
If guestregister will not finish within C<timeout> seconds, job dies.
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
        if ($out eq 'failed') {
            $out = $self->run_ssh_command(cmd => 'sudo systemctl status guestregister', proceed_on_failure => 1, quiet => 1);
            record_soft_failure("guestregister failed:\n\n" . $out);
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

=head2 wait_for_ssh

    wait_for_ssh([timeout => 600] [, proceed_on_failure => 0])

Check if the SSH port of the instance is reachable and open.
=cut
sub wait_for_ssh
{
    my ($self, %args) = @_;
    $args{timeout}            //= 600;
    $args{proceed_on_failure} //= 0;
    $args{username}           //= $self->username();
    my $start_time = time();

    # Check port 22
    while ((my $duration = time() - $start_time) < $args{timeout}) {
        last if (script_run('nc -vz -w 1 ' . $self->{public_ip} . ' 22', quiet => 1) == 0);
        sleep 1;
    }

    # Check ssh command
    while ((my $duration = time() - $start_time) < $args{timeout}) {
        return $duration if ($self->run_ssh_command(cmd => 'echo test', proceed_on_failure => 1, quiet => 1, username => $args{username}) eq 'test');
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
    $args{timeout}  //= 600;
    $args{username} //= $self->username();

    my $duration;

    $self->run_ssh_command(cmd => 'sudo shutdown -r +1');
    # skip the one minute waiting
    sleep 60;
    my $start_time = time();

    # wait till ssh disappear
    while (($duration = time() - $start_time) < $args{timeout}) {
        last unless (defined($self->wait_for_ssh(timeout => 1, proceed_on_failure => 1, username => $args{username})));
    }
    my $shutdown_time = time() - $start_time;
    die("Waiting for system down failed!") unless ($shutdown_time < $args{timeout});
    my $bootup_time = $self->wait_for_ssh(timeout => $args{timeout} - $shutdown_time, username => $args{username});
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
    return $self->wait_for_ssh(timeout => $args{timeout});
}

1;
