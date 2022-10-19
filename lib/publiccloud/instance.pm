# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for public cloud instances
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::instance;
use testapi;
use Carp 'croak';
use Mojo::Base -base;
use Mojo::Util 'trim';
use File::Basename;
use publiccloud::utils;
use publiccloud::ssh_interactive qw(ssh_interactive_tunnel ssh_interactive_leave);
use version_utils;
use utils;

use constant SSH_TIMEOUT => 90;

has instance_id => undef;    # unique CSP instance id
has resource_id => undef;    # randomized resource id for all resources (e.g. resource group and storage account)
has public_ip => undef;    # public IP of instance
has username => undef;    # username for ssh connection
has ssh_key => undef;    # path to ssh-key for connection
has image_id => undef;    # image from where the VM is booted
has type => undef;
has provider => undef, weak => 1;    # back reference to the provider
has ssh_opts => '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR';

=head2 run_ssh_command

    run_ssh_command(cmd => 'command'[, timeout => 90][, ssh_opts =>'..'][, username => 'XXX'][, no_quote => 0][, rc_only => 0]);

Runs a command C<cmd> via ssh in the given VM. Retrieves the output.
If the command retrieves not zero, a exception is thrown..
Timeout can be set by C<timeout> or 90 sec by default.
C<<proceed_on_failure=>1>> allows to proceed with validation when C<cmd> is
failing (return non-zero exit code)
By default, the command is passed in single quotes to SSH.
To avoid quoting use C<<no_quote=>1>>.
With C<<ssh_opts=>'...'>> you can overwrite all default ops which are in
C<<$instance->ssh_opts>>.
Use argument C<username> to specify a different username then
C<<$instance->username()>>.
Use argument C<rc_only> to only check for the return code of the command.
=cut

sub run_ssh_command {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    die('Argument <cmd> missing') unless ($args{cmd});
    $args{ssh_opts} //= $self->ssh_opts() . " -i '" . $self->ssh_key . "'";
    $args{username} //= $self->username();
    $args{timeout} //= SSH_TIMEOUT;
    $args{quiet} //= 1;
    $args{no_quote} //= 0;
    my $rc_only = $args{rc_only} // 0;
    my $timeout = $args{timeout};

    my $cmd = $args{cmd};
    unless ($args{no_quote}) {
        $cmd =~ s/'/'"'"'/g;
        $cmd = "'$cmd'";
    }

    my $ssh_cmd = sprintf('ssh %s "%s@%s" -- %s', $args{ssh_opts}, $args{username}, $self->public_ip, $cmd);
    $ssh_cmd = "timeout $timeout $ssh_cmd" if ($timeout > 0);
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
        # Increase the hard timeout for script_run, otherwise our 'timeout $args{timeout} ...' has no effect
        $args{timeout} += 2;
        $args{quiet} = 0;
        $args{die_on_timeout} = 1;
        # Run the command and return only the returncode here
        return script_run($ssh_cmd, %args);
    } else {
        # Run the command, wait for it and return the output
        return script_output($ssh_cmd, %args);
    }
}

=head2 retry_ssh_command

    ssh_script_retry(command[, retry => 3][, delay => 10][, timeout => 90][, ssh_opts =>'..'][, username => 'XXX'][, no_quote => 0]);

Run a C<command> via ssh in the given PC instance until it succeeds or
the given number of retries is exhausted and an exception is thrown.
Timeout can be set by C<timeout> or 90 sec by default.
By default, the command is passed in single quotes to SSH.
To avoid quoting use C<<no_quote=>1>>.
With C<<ssh_opts=>'...'>> you can overwrite all default ops which are in
C<<$instance->ssh_opts>>.
Use argument C<username> to specify a different username then
C<<$instance->username()>>.

This function is deprecated. Please use ssh_script_retry instead.
=cut

sub retry_ssh_command {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    $args{rc_only} = 1;
    $args{timeout} //= 90;    # Timeout before we cancel the command
    my $tries = delete $args{retry} // 3;
    my $delay = delete $args{delay} // 10;
    my $cmd = delete $args{cmd};

    for (my $try = 0; $try < $tries; $try++) {
        my $rc = $self->run_ssh_command(cmd => $cmd, %args);
        return $rc if (defined $rc && $rc == 0);
        sleep($delay);
    }
    die "Waiting for Godot: " . $cmd;
}

# Auxilliary function to prepare the ssh command that runs any command on the PC instance
sub _prepare_ssh_cmd {
    my ($self, %args) = @_;
    die('No command defined') unless ($args{cmd});
    $args{ssh_opts} //= $self->ssh_opts() . " -i '" . $self->ssh_key . "'";
    $args{username} //= $self->username();
    $args{timeout} //= SSH_TIMEOUT;

    my $cmd = $args{cmd};
    unless ($args{no_quote}) {
        $cmd =~ s/'/\'/g;    # Espace ' character
        $cmd = "\$'$cmd'";
    }

    my $ssh_cmd = sprintf('ssh -t %s "%s@%s" -- %s', $args{ssh_opts}, $args{username}, $self->public_ip, $cmd);
    #$ssh_cmd = "timeout $args{timeout} $ssh_cmd" if ($args{timeout} > 0);
    return $ssh_cmd;
}

=head2 ssh_script_run

    ssh_script_run($cmd [, timeout => $timeout] [, fail_message => $fail_message] [,quiet => $quiet] [,ssh_opts => $ssh_opts] [,username => $username])

Runs a command C<cmd> via ssh on the publiccloud instance and returns the return code.
=cut

sub ssh_script_run {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    delete($args{cmd});
    delete($args{ssh_opts});
    delete($args{username});
    return script_run($ssh_cmd, %args);
}

=head2 ssh_assert_script_run

    ssh_assert_script_run($cmd [, timeout => $timeout] [, fail_message => $fail_message] [,quiet => $quiet] [,ssh_opts => $ssh_opts] [,username => $username])

Runs a command C<cmd> via ssh on the publiccloud instance and die, unless it returns zero.
=cut

sub ssh_assert_script_run {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    delete($args{cmd});
    delete($args{ssh_opts});
    delete($args{username});
    assert_script_run($ssh_cmd, %args);
}

=head2 ssh_script_output

    ssh_script_output($script [, $wait, type_command => 1, proceed_on_failure => 1] [,quiet => $quiet] [,ssh_opts => $ssh_opts] [,username => $username])

Executing script inside SUT with bash -eo and directs stdout (but not stderr!) to the serial console and
returns the output if the script exits with 0. Otherwise the test is set to failed.
=cut

sub ssh_script_output {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    delete($args{cmd});
    delete($args{ssh_opts});
    delete($args{username});
    return script_output($ssh_cmd, %args);
}

=head2 ssh_script_retry

    ssh_script_retry($cmd, [expect => $expect], [retry => $retry], [delay => $delay], [timeout => $timeout], [die => $die] [,ssh_opts => $ssh_opts] [,username => $username])

Repeat command until expected result or timeout.
=cut

sub ssh_script_retry {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    delete($args{cmd});
    delete($args{ssh_opts});
    delete($args{username});
    return script_retry($ssh_cmd, %args);
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
    $to =~ s/^remote:/$url/;

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
    my $dest = $tmpdir . '/' . basename($remote_file);
    my $ret = $self->scp('remote:' . $remote_file, $dest);
    upload_logs($dest, %args) if (defined($ret) && $ret == 0);
    assert_script_run("test -d '$tmpdir' && rm -rf '$tmpdir'");
}

=head2 wait_for_guestregister

    wait_for_guestregister([timeout => 300]);

Run command C<systemctl is-active guestregister> on the instance in a loop and
wait till guestregister is ready. If guestregister finish with state failed,
a soft-failure will be recorded.
If guestregister will not finish within C<timeout> seconds, job dies.
In case of BYOS images we checking that service is inactive and quit
Returns the time needed to wait for the guestregister to complete.
=cut

sub wait_for_guestregister
{
    my ($self, %args) = @_;
    $args{timeout} //= 300;
    my $start_time = time();
    my $last_info = 0;

    # Check what version of registercloudguest binary we use
    $self->run_ssh_command(cmd => "sudo rpm -qa cloud-regionsrv-client", proceed_on_failure => 1);

    while (time() - $start_time < $args{timeout}) {
        my $out = $self->run_ssh_command(cmd => 'sudo systemctl is-active guestregister', proceed_on_failure => 1, quiet => 1);
        # guestregister is expected to be inactive because it runs only once
        if ($out eq 'inactive') {
            $self->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log');
            return time() - $start_time;
        } elsif ($out eq 'failed') {
            $self->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log');
            $out = $self->run_ssh_command(cmd => 'sudo systemctl status guestregister', proceed_on_failure => 1, quiet => 1);
            record_info("guestregister failed", $out, result => 'fail');
            record_soft_failure("bsc#1195414");
            return time() - $start_time;
        } elsif ($out eq 'active') {
            $self->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log');
            die "guestregister should not be active on BYOS" if (is_byos);
        }

        if (time() - $last_info > 10) {
            record_info('WAIT', 'Wait for guest register: ' . $out);
            $last_info = time();
        }
        sleep 1;
    }

    $self->upload_log('/var/log/cloudregister', log_name => $autotest::current_test->{name} . '-cloudregister.log');
    die('guestregister didn\'t end in expected timeout=' . $args{timeout});
}

=head2 wait_for_ssh

    wait_for_ssh([timeout => 600] [, proceed_on_failure => 0])

Check if the SSH port of the instance is reachable and open.
=cut

sub wait_for_ssh
{
    my ($self, %args) = @_;
    $args{timeout} //= 600;
    $args{proceed_on_failure} //= 0;
    $args{username} //= $self->username();
    $args{public_ip} //= $self->public_ip();
    my $start_time = time();
    my $check_port = 1;

    # Looping until reaching timeout or passing two conditions :
    # - SSH port 22 is reachable
    # - journalctl got message about reaching one of certain targets
    while ((my $duration = time() - $start_time) < $args{timeout}) {
        if ($check_port) {
            $check_port = 0 if (script_run('nc -vz -w 1 ' . $self->{public_ip} . ' 22', quiet => 1) == 0);
        }
        else {
            # On boottime test we do hard reboot which may change the instance address
            script_run("ssh-keyscan $args{public_ip} | tee -a ~/.ssh/known_hosts") if (get_var('PUBLIC_CLOUD_CHECK_BOOT_TIME'));

            my $output = $self->run_ssh_command(cmd => 'sudo journalctl -b | grep -E "Reached target (Cloud-init|Default|Main User Target)"', proceed_on_failure => 1, username => $args{username});
            if ($output =~ m/Reached target.*/) {
                return $duration;
            }
            elsif ($output =~ m/Permission denied (publickey).*/) {
                die "ssh permission denied (pubkey)";
            }
        }
        sleep 1;
    }

    script_run("ssh  -i /root/.ssh/id_rsa -v $args{username}\@$args{public_ip} true", timeout => 360);
    # Debug output: We have occasional error in 'journalctl -b' - see poo#96464 - this will be removed soon.
    $self->run_ssh_command(cmd => 'sudo journalctl -b', proceed_on_failure => 1, username => $args{username});

    unless ($args{proceed_on_failure}) {
        my $error_msg;
        if ($check_port) {
            $error_msg = sprintf("Unable to reach SSH port of instance %s with public IP:%s within %d seconds", $self->{instance_id}, $self->{public_ip}, $args{timeout});
        }
        else {
            $error_msg = sprintf("Can not reach systemd target on instance %s with public IP:%s within %d seconds", $self->{instance_id}, $self->{public_ip}, $args{timeout});
        }
        croak($error_msg);
    }

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
    $args{username} //= $self->username();

    my $duration;

    # On TUNNELED test runs, ensure we are not on the publiccloud instance
    my $prev_console = current_console();
    # We only need to re-establish the ssh tunnel, if we are in a TUNNELED test run, and if the tunnel is already initialized
    my $tunneled = get_var('TUNNELED', 0) && get_var("_SSH_TUNNELS_INITIALIZED", 0);
    if ($tunneled) {
        select_host_console(force => 1);
        ssh_interactive_leave();
    }

    $self->ssh_script_run(cmd => 'sudo shutdown -r +1');
    sleep 60;    # wait for the +1 in the previous command
    my $start_time = time();

    # wait till ssh disappear
    while (($duration = time() - $start_time) < $args{timeout}) {
        last unless (defined($self->wait_for_ssh(timeout => 1, proceed_on_failure => 1, username => $args{username})));
    }
    my $shutdown_time = time() - $start_time;
    die("Waiting for system down failed!") unless ($shutdown_time < $args{timeout});
    my $bootup_time = $self->wait_for_ssh(timeout => $args{timeout} - $shutdown_time, username => $args{username});

    # Re-establish tunnel and switch back to previous console if TUNNELED
    if ($tunneled) {
        ssh_interactive_tunnel($self);
        die("expect ssh serial device to be active") unless (get_var('SERIALDEV') =~ /ssh/);
        select_console($prev_console) if ($prev_console !~ /tunnel/);
    }

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
    $args{timeout} //= 600;
    $self->provider->start_instance($self, @_);
    return $self->wait_for_ssh(timeout => $args{timeout});
}

=head2 get_state

    get_state();

Get the status of the instance using the CSP api calls.
=cut

sub get_state
{
    my $self = shift;
    return $self->provider->get_state_from_instance($self, @_);
}

=head2 network_speed_test

    network_speed_test();

Test the network speed.
=cut

sub network_speed_test() {
    my ($self, %args) = @_;
    # Curl stats output format
    my $write_out = 'time_namelookup:\t%{time_namelookup} s\ntime_connect:\t\t%{time_connect} s\ntime_appconnect:\t%{time_appconnect} s\ntime_pretransfer:\t%{time_pretransfer} s\ntime_redirect:\t\t%{time_redirect} s\ntime_starttransfer:\t%{time_starttransfer} s\ntime_total:\t\t%{time_total} s\n';
    # PC RMT server domain name
    my $rmt_host = "smt-" . lc(get_required_var('PUBLIC_CLOUD_PROVIDER')) . ".susecloud.net";
    my $rmt = $self->run_ssh_command(cmd => "grep \"$rmt_host\" /etc/hosts", proceed_on_failure => 1);
    record_info("rmt_host", $rmt);
    record_info("ping 1.1.1.1", $self->run_ssh_command(cmd => "ping -c30 1.1.1.1", proceed_on_failure => 1, timeout => 600));
    record_info("curl $rmt_host", $self->run_ssh_command(cmd => "curl -w '$write_out' -o /dev/null -v https://$rmt_host/", proceed_on_failure => 1));
}

1;
