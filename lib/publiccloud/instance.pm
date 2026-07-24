# SUSE's openQA tests
#
# Copyright 2018-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base class for public cloud instances
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::instance;
use testapi;
use Carp 'croak';
use Mojo::Base -base;
use Mojo::Util 'trim';
use File::Basename;
use publiccloud::utils;
use Utils::Backends qw(set_sshserial_dev unset_sshserial_dev);
use publiccloud::ssh_interactive qw(ssh_interactive_tunnel ssh_interactive_leave select_host_console);
use version_utils;
use utils;
use Mojo::Util 'trim';
use Data::Dumper;

use constant SSH_TIMEOUT => 90;

has instance_id => undef;    # unique CSP instance id
has resource_id => undef;    # randomized resource id for all resources (e.g. resource group and storage account)
has public_ip => undef;    # public IP of instance
has username => undef;    # username for ssh connection
has image_id => undef;    # image from where the VM is booted
has type => undef;
has region => undef;    # provider region, filled by provider::terraform_apply
has provider => undef, weak => 1;    # back reference to the provider
has ssh_opts => '';

=head2 retry_ssh_command

    ssh_script_retry(command[, retry => 3][, delay => 10][, timeout => 90][, ssh_opts =>'..'][, username => 'XXX']);

Run a C<command> via ssh in the given PC instance until it succeeds or
the given number of retries is exhausted and an exception is thrown.
Timeout can be set by C<timeout> or 90 sec by default.
The command is passed in single quotes to SSH.
With C<<ssh_opts=>'...'>> you can overwrite all default ops which are in
C<<$instance->ssh_opts>>.
Use argument C<username> to specify a different username then
C<<$instance->username()>>.

This function is deprecated. Please use ssh_script_retry instead.
=cut

sub retry_ssh_command {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $tries = delete $args{retry} // 3;
    my $delay = delete $args{delay} // 10;
    my $cmd = delete $args{cmd};

    for (my $try = 0; $try < $tries; $try++) {
        my $rc = $self->ssh_script_run(cmd => $cmd, %args);
        return $rc if (defined $rc && $rc == 0);
        sleep($delay);
    }
    die "Waiting for Godot: " . $cmd;
}

# Auxilliary function to prepare the ssh command that runs any command on the PC instance
sub _prepare_ssh_cmd {
    my ($self, %args) = @_;
    die('No command defined') unless ($args{cmd});
    $args{ssh_opts} //= $self->ssh_opts();
    $args{username} //= $self->username();

    my $cmd = $args{cmd};
    $cmd =~ s/'/\\'/g;

    my $log = '/var/tmp/ssh_sut.log';
    my $ssh_cmd = sprintf(q(ssh %s %s "%s@%s" -- $'%s'), (($args{ssh_opts} !~ m{-E\s+$log}) ? "-E $log" : ''), $args{ssh_opts}, $args{username}, $self->public_ip, $cmd);

    return $ssh_cmd;
}


=head2  _wrap_timeout
     _wrap_timeout($args, $ssh_cmd) - wraps $ssh_cmd within timeout call which will make sure graceful and unconditional interruption
      after defined period of time

    C<args> - reference to args hash. it is important to pass reference so function can modify timeout passed to script_run by the caller
                to make sure it is bigger than value defined in timeout command which suppose to kill what script_run needs to execute
    C<ssh_cmd> - reference to string containing command which will be executed by script_run. function will tweak it to include timeout call
                which will kill underlying command after time defined by args{timeout}

=cut

sub _wrap_timeout {

    my ($self, $args, $ssh_cmd) = @_;

    $args->{apply_graceful_timeout} //= 0;
    $args->{timeout} //= SSH_TIMEOUT;

    if ($args->{apply_graceful_timeout} && ($args->{timeout}) > 0) {
        my $external_timeout = $args->{timeout};
        # $args{timeout} will be passed into script_run so it needs to be bigger than value used by timeout command
        # otherwise script_run will die faster than timeout needs to kill running command. Giving 20 second buffer looks safe enough
        $args->{timeout} = $args->{timeout} + 20;
        # timeout is executed with '-k 10' which means that after trying to gracefully shutdown running command for 10 seconds it will
        # start just to kill the process. Taking into account that internal timeout for script_run is longer for 20 seconds
        # kernel has 10 seconds to proceed with killing the process
        $$ssh_cmd = "timeout --foreground -k 10s $external_timeout " . $$ssh_cmd;
    }
    delete($args->{apply_graceful_timeout});
}

=head2 ssh_script_run

    ssh_script_run($cmd [, timeout => $timeout] [,quiet => $quiet] [,ssh_opts => $ssh_opts] [,username => $username][, apply_graceful_timeout => $apply_graceful_timeout])

    C<timeout> - TTL for command execution measured in seconds . After that period of time execution will be aborded
    C<quiet> - avoid recording serial_results ( value pass to script_run call)
    C<ssh_opts> - additional ssh options passed to ssh
    C<username> - username used for ssh tunnel
    C<apply_graceful_timeout> - in case waiting longer than timeout normally script_run will die. Setting this parameter to true
        will avoid such failure

Runs a command C<cmd> via ssh on the publiccloud instance and returns the return code, using testapi::script_run.
=cut

sub ssh_script_run {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    $self->_wrap_timeout(\%args, \$ssh_cmd);
    delete($args{cmd});
    delete($args{ssh_opts});
    delete($args{username});
    $args{quiet} //= 1;
    return script_run($ssh_cmd, %args);
}

=head2 ssh_assert_script_run

    ssh_assert_script_run($cmd [, timeout => $timeout] [, fail_message => $fail_message] [,quiet => $quiet] [,ssh_opts => $ssh_opts] [,username => $username][, apply_graceful_timeout => $apply_graceful_timeout])

Runs a command C<cmd> via ssh on the publiccloud instance and die on error.

Use the parameters of ssh_script_run.

=cut

sub ssh_assert_script_run {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    $self->_wrap_timeout(\%args, \$ssh_cmd);
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
    $args{quiet} //= 1;
    my $output = script_output($ssh_cmd, %args);
    # Filter the output ending from "Connection to ($HOST) closed."
    $output =~ s/Connection to .* closed\.$//;
    return $output;
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

    scp($from, $to [, timeout => 90] [, proceed_on_failure => 0][, apply_graceful_timeout => $apply_graceful_timeout]);

Copy a file to or from this instance using C<scp>.

Arguments:

C<$from> - source path. When it starts with C<remote:>, the prefix is
    replaced with C<< <username>@<public_ip>: >> so the file is read from
    this instance (download). Otherwise it is treated as a local path.
    Using C<remote:> is only a convenience: you are free to pass an explicit
    C<< user@host:/path >> instead, which is left untouched by this function.

C<$to> - destination path. Uses the same C<remote:> rewriting as C<$from>,
    so a C<remote:> destination uploads a local file to this instance. As
    with C<$from>, an explicit C<< user@host:/path >> can be passed and is
    left untouched.

C<timeout> - maximum time in seconds allowed for the scp command. Defaults
    to C<SSH_TIMEOUT> (90 seconds).

C<proceed_on_failure> - when set to a true value a failing scp does not abort
    the test: the command is run via C<script_run> and only an informational
    message is recorded. When false (the default) the copy is run via
    C<assert_script_run> so a failure dies. Defaults to C<0>.

C<apply_graceful_timeout> - same parameter as ssh_script_run.

Any C<-E <file>> logging options present in C<< $instance->ssh_opts >> are
stripped, because C<scp> does not accept them.

E.g. to download the file I</var/log/cloudregister> into I</tmp>:

    $instance->scp('remote:/var/log/cloudregister', '/tmp');

and to upload a local I</tmp/foo> to the instance home directory:

    $instance->scp('/tmp/foo', 'remote:/home/user/foo');
=cut

sub scp {
    my ($self, $from, $to, %args) = @_;
    $args{proceed_on_failure} //= 0;

    my $url = sprintf('%s@%s:', $self->username, $self->public_ip);
    $from =~ s/^remote:/$url/;
    $to =~ s/^remote:/$url/;

    # Sanitize ssh_opts by removing -E options which are not accepted by 'scp'
    my $ssh_opts = $self->ssh_opts;
    $ssh_opts =~ s/\-E\s[^\s]+//g;

    my $ssh_cmd = sprintf('scp %s "%s" "%s"', $ssh_opts, $from, $to);

    $self->_wrap_timeout(\%args, \$ssh_cmd);

    if ($args{proceed_on_failure}) {
        record_info(
            "Proceed on Failure",
            "SCP failed but proceed_on_failure flag is set to true. Continuing..."
        ) if script_run($ssh_cmd, timeout => $args{timeout});
    } else {
        assert_script_run($ssh_cmd, timeout => $args{timeout});
    }
}

=head2 upload_log

    upload_log($filename);

Upload a file from this instance to openqa using L<upload_logs()>.
If the file doesn't exists on the instance, B<no> error is thrown.
=cut

sub upload_log {
    my ($self, $remote_file, %args) = @_;
    my $tmpdir = script_output_retry('mktemp -d');
    my $dest = $tmpdir . '/' . basename($remote_file);
    $args{failok} //= 0;
    $args{apply_graceful_timeout} = 1 if ($args{failok});
    my $ret = $self->scp('remote:' . $remote_file, $dest, proceed_on_failure => 1, %args);
    upload_logs($dest, %args) if (defined($ret) && $ret == 0);
    script_run("test -d '$tmpdir' && rm -rf '$tmpdir'");
}

=head2 upload_check_logs_tar

    upload_check_logs_tar(@files);

Check remote log files status and upload tar.gz of only ok logs, to oqa UI.

Input: C<@files> full-path-files array;

Return C<1> true explicit, as stateless and never impact calling code.

=cut

sub upload_check_logs_tar {
    my ($self, @files) = @_;
    my $remote_tar = "/tmp/" . $autotest::current_test->{name} . "_logs.tar.gz";
    my $cmd = 'sudo ls -x ' . join(' ', @files) . " 2>/dev/null";
    my $res = $self->ssh_script_output(cmd => $cmd, proceed_on_failure => 1);
    my @logs = split(" ", $res);
    return 1 unless (scalar(@logs) > 0);
    # Upload existing logs to openqa  UI
    $cmd = "sudo tar -czvf $remote_tar " . join(" ", @logs);
    $res = $self->ssh_script_run(cmd => $cmd, apply_graceful_timeout => 1);
    $self->upload_log("$remote_tar", log_name => basename($remote_tar), failok => 1) if ($res == 0);
    return 1;
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

sub wait_for_guestregister {
    my ($self, %args) = @_;
    $args{timeout} //= 300;
    my $start_time = time();
    my $last_info = 0;
    my $log = '/var/log/cloudregister';
    my $name = $autotest::current_test->{name} . '-cloudregister.log.txt';

    # Check what version of registercloudguest binary we use
    $self->ssh_script_run(cmd => "rpm -qa cloud-regionsrv-client", apply_graceful_timeout => 1);
    record_info('CHECK guestregister', 'guestregister check');
    while (time() - $start_time < $args{timeout}) {
        my $out = $self->ssh_script_output(cmd => 'sudo systemctl is-active guestregister', proceed_on_failure => 1, quiet => 1);
        # guestregister is expected to be inactive because it runs only once
        # the tests match the expected string at end of the cmd output
        if ($out =~ m/inactive$/) {
            diag("guestregister inactive");
            $self->upload_log($log, log_name => $name);
            return 1;
        }
        elsif ($out =~ m/failed$/) {
            diag("guestregister failed");
            # we have some cases where it is known that guestregister service will fail
            # ( e.g. when we testing images not published on Market hence w/o product codes)
            return 1 if (get_var('PUBLIC_CLOUD_IGNORE_UNREGISTERED'));
            die('guestregister failed');
        }
        elsif ($out =~ m/active$/) {
            diag("guestregister active");
            die "guestregister should not be active on BYOS" if (is_byos);
            $self->upload_log($log, log_name => $name);
        }

        if (time() - $last_info > 10) {
            record_info('WAIT', 'Wait for guest register: ' . $out);
            $last_info = time();
        }
        sleep 1;
    }
    diag("guestregister timeout");
    die('guestregister didn\'t end in expected timeout=' . $args{timeout});
}

=head2 update_instance_ip

    update_instance_ip(timeout => 600)

This subroutine checks the public IP cloud provider provides for the VM.
When the IP differs from `$self->public_ip` we update `$self->public_ip`.

=cut

sub update_instance_ip {
    my $self = shift;
    my $timeout = 300;
    my $delay = 5;

    return if (get_var('PUBLIC_CLOUD_SLES4SAP'));

    my $start_time = time();
    my $public_ip_from_provider = $self->provider->get_public_ip();
    until ($public_ip_from_provider !~ /null/ || (time() - $start_time) >= $timeout) {
        sleep($delay);
        $public_ip_from_provider = $self->provider->get_public_ip();
    }

    # Update the public IP address if it differs
    if ($self->public_ip ne $public_ip_from_provider and $public_ip_from_provider !~ /null/) {
        record_info('IP CHANGED', "The address we know is $self->{public_ip} but provider returns $public_ip_from_provider", result => 'fail');
        $self->public_ip($public_ip_from_provider);
    }
}

sub scan_ssh_host_key {
    my ($self) = @_;

    record_info('RESCAN', 'Rescanning SSH host key');

    my $user_known_hosts = (script_run("test -f /home/$testapi::username/.ssh/known_hosts") eq 0)
      ? "/home/$testapi::username/.ssh/known_hosts"
      : "";

    script_retry("ssh-keyscan $self->{public_ip} | tee -a ~/.ssh/known_hosts $user_known_hosts", retry => 6, delay => 10);
}

sub wait_for_ssh {
    my ($self, %args) = @_;
    $self->wait_for_ssh_reachable(%args);
    $self->scan_ssh_host_key(%args) if $args{scan_ssh_host_key};
    $self->wait_for_ssh_login(%args);
}

sub wait_for_ssh_reachable {
    my ($self, %args) = @_;

    my $delay = $args{delay} // 30;
    my $timeout = $args{timeout} // get_var('PUBLIC_CLOUD_SSH_TIMEOUT', 300);
    my $retry = $timeout / $delay;
    my $port = $args{port} // 22;

    script_retry('nc -vz -w 1 ' . $self->public_ip . ' ' . $port, delay => $delay, retry => $retry, fail_message => "ssh port unreachable after $timeout seconds (port probed via nc)");
}

=head2 wait_for_ssh_unreachable

    my $rc = $instance->wait_for_ssh_unreachable([delay => 2] [, timeout => 300] [, port => 22] [, die => 1]);

Wait until the SSH port of this instance stops accepting connections, i.e.
when the instance goes down. Retrying continues until the port becomes
unreachable or C<timeout> seconds elapse (the number of attempts is derived
as C<timeout / delay>).

This is typically used to detect the reboot/shutdown window (e.g. from
C<softreboot>). The default C<delay> is intentionally small so the short
interval during which SSH becomes unreachable is not missed.

Returns the exit code of the last C<nc> probe, as forwarded by C<script_retry>.
The value tells whether the port is still connectable: C<0> means "not
connected" (unreachable), a non-zero value means "still connected" (reachable).

=over

=item * C<0> when the port became unreachable within the timeout (success).

=item * a non-zero value when the port is still reachable after the timeout,
        but only if C<die> is set to a false value.

=item * with the default C<die =E<gt> 1>, a still-reachable port makes
        C<script_retry> B<die> instead of returning, so the only value ever
        returned in that mode is C<0>.

=item * C<undef> as a corner case: C<script_retry> returns C<undef> when the
        last probe attempt is killed by its C<timeout> wrapper before an exit
        code is reported. This is unlikely here (the probe is C<nc -w 1>), but
        callers relying on the return value should treat C<undef> as "not
        unreachable".

=back

Arguments:

=over

=item B<delay> - seconds to wait between two probes. Defaults to C<2>. Keep it
                 low to avoid missing the brief window where SSH is unreachable.

=item B<timeout> - overall time budget in seconds. Defaults to the test setting
                   C<PUBLIC_CLOUD_SSH_TIMEOUT> or C<300> if unset.

=item B<port> - TCP port to probe. Defaults to C<22>.

=item B<die> - when true (the default C<1>) the function dies if the port is
               still reachable after C<timeout>. Set to C<0> to instead return
               the non-zero return code.

=back

=cut

sub wait_for_ssh_unreachable {
    my ($self, %args) = @_;

    # delay must be low otherwise we miss the reboot window where ssh is unreachable
    my $delay = $args{delay} // 2;
    my $timeout = $args{timeout} // get_var('PUBLIC_CLOUD_SSH_TIMEOUT', 300);
    my $retry = $timeout / $delay;
    my $port = $args{port} // 22;
    my $die = ${args}{die} // 1;

    my $rc = script_retry('! nc -vz -w 1 ' . $self->public_ip . ' ' . $port,
        delay => $delay,
        retry => $retry,
        fail_message => "ssh port still reachable after $timeout seconds (port probed via nc)",
        die => $die);
    # Print a warning message, if we don't want to `die` here in the previous check
    record_info("ssh still reachable", "WARNING: ssh port is still reachable", result => 'fail') if ($rc != 0);
    return $rc;
}

sub wait_for_ssh_login {
    my ($self, %args) = @_;
    my $timeout = $args{timeout} // get_var('PUBLIC_CLOUD_SSH_TIMEOUT', 300);
    my $delay = $args{delay} // 30;
    my $retry = $timeout / $delay;

    ## ssh options to avoid issues with pipelining and host key validation
    my $ssh_opts = $self->ssh_opts() . ' -o ControlPath=none -o ConnectTimeout=10 -o strictHostKeyChecking=no -o UserKnownHostsFile=/dev/null';
    $self->ssh_script_retry("true", ssh_opts => $ssh_opts, retry => $retry, delay => $delay, fail_message => "ssh connection failed ($delay attempts in $timeout seconds)");
}

=head2 isok

    isok($exit_code);

To convert in a true or 1 value for perl tests the exit_code 0 of shell script ok.

Return:
the positive test status of a shell exit code, 
that is true(1) and ok when its value is defined and zero: C<$x == 0>
otherwise false(undef).
=cut

sub isok {
    my ($x) = @_;
    return (defined($x) and $x == 0);
}    # end sub

=head2 softreboot

    ($shutdown_time, $bootup_time) = softreboot([timeout => 600] [, scan_ssh_host_key => ?]);

Does a softreboot of the instance by running the command C<shutdown -r>.
Return an array of two values, first one is the time till the instance isn't
reachable anymore. The second one is the estimated bootup time.
=cut

sub softreboot {
    my ($self, %args) = @_;
    $args{timeout} //= 600;
    $args{scan_ssh_host_key} //= 0;
    $args{username} //= $self->username();
    # see detailed explanation inside wait_for_ssh

    my $duration;

    my $prev_console = current_console();
    # On TUNNELED test runs, we need to re-establish the tunnel
    my $tunneled = is_tunneled() && get_var("_SSH_TUNNELS_INITIALIZED", 0);
    if ($tunneled) {
        select_console('tunnel-console', await_console => 0);
        ssh_interactive_leave();
        for (1 .. 5) {
            last if (script_run(sprintf('ssh -O check %s@%s', $args{username}, $self->public_ip)) != 0);
            script_run(sprintf('ssh -O exit %s@%s', $args{username}, $self->public_ip));
            sleep 5;
        }
    }

    # Let's go to host console (where we have the provider specific environment variables)
    select_host_console();

    $self->ssh_assert_script_run(cmd => 'sudo /sbin/shutdown -r +1');
    sleep 60;    # wait for the +1 in the previous command
    my $start_time = time();

    # wait till ssh disappear
    $self->wait_for_ssh_unreachable(die => 0);

    my $shutdown_time = time() - $start_time;
    die("Waiting for system down failed!") unless ($shutdown_time < $args{timeout});

    $self->update_instance_ip();
    my $bootup_time = $self->wait_for_ssh(timeout => $args{timeout} - $shutdown_time, username => $args{username}, scan_ssh_host_key => $args{scan_ssh_host_key});

    # ensure the tunnel-console is healthy, usefuly to early detect possible issues with the serial terminal
    assert_script_run("true", fail_message => "console is broken");

    # Re-establish tunnel and switch back to previous console if needed
    if ($tunneled) {
        record_info("re-establish tunnel", "re-esablishing ssh tunnel");
        ssh_interactive_tunnel($self, reconnect => 1);
        die("expect ssh serial device to be active") unless (get_var('SERIALDEV') =~ /ssh/);
        select_console($prev_console) if ($prev_console !~ /tunnel/);
    }

    return ($shutdown_time, $bootup_time);
}


=head2 stop

    stop();

Stop the instance using the CSP api calls.
=cut

sub stop {
    my $self = shift;
    $self->provider->stop_instance($self, @_);
}

=head2 start

    start([timeout => ?] [, scan_ssh_host_key => ?]);

Start the instance and wait for the system to be up.
Returns the number of seconds till the system up and running.
=cut

sub start {
    my ($self, %args) = @_;
    $args{timeout} //= 600;
    $args{scan_ssh_host_key} //= 0;
    $self->provider->start_instance($self, @_);
    $self->update_instance_ip();
    return $self->wait_for_ssh(timeout => $args{timeout}, scan_ssh_host_key => $args{scan_ssh_host_key});
}

=head2 get_state

    get_state();

Get the status of the instance using the CSP api calls.
=cut

sub get_state {
    my $self = shift;
    return $self->provider->get_state_from_instance($self, @_);
}

sub cleanup_cloudinit() {
    my ($self) = @_;
    $self->ssh_assert_script_run('sudo cloud-init clean --logs');
    if (get_var('PUBLIC_CLOUD_CLOUD_INIT')) {
        $self->ssh_assert_script_run('sudo rm /root/test_cloud-init.txt');
        $self->ssh_assert_script_run('sudo zypper -n rm ed');
    }
}

sub check_cloudinit() {
    my ($self) = @_;

    # cloud-init status
    my $rc = $self->ssh_script_run(cmd => "sudo cloud-init status --wait", timeout => 300);
    record_info("cloud-init", $self->ssh_script_output("sudo cloud-init status --long", proceed_on_failure => 1, timeout => 300), result => $rc == 0 ? 'ok' : 'fail');
    # Cloud-init error codes: 0 - success, 1 - unrecoverable error, 2 - recoverable error (See cloud-init documentation)
    # As of https://bugzilla.suse.com/show_bug.cgi?id=1266207 we ignore recoverable errors
    if (get_var('PUBLIC_CLOUD_IGNORE_CLOUDINIT_ERRORS') != 1) {
        if ($rc == 1) {
            die "unrecoverable cloud-init error";
        } elsif ($rc == 2) {
            record_info("cloud-init", "recoverable error (return code 2)");
        } elsif ($rc != 0) {
            die "unknown cloud-init return code $rc";
        }
    }

    # cloud-id
    my $cloud_id = (is_azure) ? 'azure' : 'aws';
    $self->ssh_assert_script_run(cmd => "sudo cloud-id | grep '^$cloud_id\$'");

    # cloud-init collect-logs
    $self->ssh_assert_script_run('sudo cloud-init collect-logs');
    $self->upload_log('~/cloud-init.tar.gz', failok => 1);

    if (get_var('PUBLIC_CLOUD_CLOUD_INIT')) {
        # Check for bootcmd, runcmd and write_files module
        $self->ssh_assert_script_run('sudo grep pookie /root/test_cloud-init.txt');
        $self->ssh_assert_script_run('sudo grep Mithrandir /root/test_cloud-init.txt');
        $self->ssh_assert_script_run('sudo grep snickerdoodle /root/test_cloud-init.txt');

        # Check for packages module
        $self->ssh_assert_script_run('ed -V');

        # Check for final_message module
        $self->ssh_assert_script_run('sudo journalctl -b | grep "cloud-init qa has finished"');

        # cloud-init schema
        $self->ssh_assert_script_run('sudo cloud-init schema --system') unless (is_sle('=12-SP5'));
    }
}

sub enable_kdump() {
    my ($self) = @_;

    $self->ssh_assert_script_run(q(sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT/ s/\\\\\\"$/ crashkernel=256M,high crashkernel=128M,low \\\\\\"/" /etc/default/grub));
    $self->ssh_assert_script_run('sudo grub2-mkconfig -o /boot/grub2/grub.cfg');

    if ($self->ssh_script_run('sudo grep -q "^KDUMP_CRASHKERNEL=" /etc/sysconfig/kdump') == 0) {
        $self->ssh_assert_script_run(q(sudo sed -i "/^KDUMP_CRASHKERNEL/ s/\\\\\\"$/ crashkernel=256M,high crashkernel=128M,low \\\\\\"/" /etc/sysconfig/kdump));
    } else {
        $self->ssh_assert_script_run(q(echo "KDUMP_CRASHKERNEL=\"crashkernel=256M,high crashkernel=128M,low\"" | sudo tee -a /etc/sysconfig/kdump));
    }

    $self->ssh_assert_script_run('sudo systemctl enable kdump.service');
    $self->softreboot();
}

=head2 check_system_boottime

    check_system_boottime();

Check the system boot time, measured by C<systemd-analyze>, to be under a threshold.
Assign the threshold in seconds to PUBLIC_CLOUD_BOOTTIME_MAX in test settings.
The boot time is saved in a local json structure, then printed in the test's logs:
when the threshold is exceeded the job is stopped.
The routine is skipped when the threshold is undefined or zero.

=cut

sub check_system_boottime() {
    my ($instance, %args) = @_;
    my $max_boot_time = get_var('PUBLIC_CLOUD_BOOTTIME_MAX');
    return unless ($max_boot_time);

    my $ret = {
        kernel_release => undef,
        kernel_version => undef,
        type => 'boottime',
        analyze => {},
        blame => {},
    };

    record_info("BOOT TIME", 'systemd_analyze');
    # first deployment analysis
    my ($systemd_analyze, $systemd_blame) = $instance->do_systemd_analyze_time(%args);
    die("failed to obtain boottime from systemd") unless ($systemd_analyze && $systemd_blame);

    $ret->{analyze}->{$_} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame} = $systemd_blame;
    my $boottime = $ret->{analyze}->{overall};

    # Collect kernel version
    $ret->{kernel_release} = $instance->ssh_script_output(cmd => 'uname -r', proceed_on_failure => 1);
    $ret->{kernel_version} = $instance->ssh_script_output(cmd => 'uname -v', proceed_on_failure => 1);

    $Data::Dumper::Sortkeys = 1;
    record_info("RESULTS", Dumper($ret));
    my $dir = "/var/log";
    my @logs = qw(cloudregister cloud-init.log cloud-init-output.log messages NetworkManager);
    $instance->upload_check_logs_tar(map { "$dir/$_" } @logs);

    # Boot time overall limit check
    if ($boottime > $max_boot_time) {
        if (is_azure()) {
            # Unreliable userspace boot time in Azure.
            record_soft_failure("bsc#1262587 - openQA publiccloud tests have anomalous-high boot-time from systemd-analyze");
        } else {
            # threshold exceeded
            die("System boot time overall $boottime is out of limit $max_boot_time");
        }
    }
}

sub systemd_time_to_second
{
    my $str_time = trim(shift);

    if ($str_time !~ /^(?<check_hour>(?<hour>\d{1,2})\s*h\s*)?(?<check_min>(?<min>\d{1,2})\s*min\s*)?((?<sec>\d{1,2}\.\d{1,3})s|(?<ms>\d+)ms)$/) {
        record_info("WARN", "Unable to parse systemd time '$str_time'", result => 'fail');
        return -1;
    }
    my $sec = $+{sec} // $+{ms} / 1000;
    $sec += $+{min} * 60 if (defined($+{check_min}));
    $sec += $+{hour} * 3600 if (defined($+{check_hour}));
    return $sec;
}

sub extract_analyze_time {
    my $str_time = shift;
    my $res = {};
    # Pick the line that actually holds the timing, not blindly the first line:
    # ssh_script_output may prepend an SSH login banner / MOTD, which would
    # otherwise leave us parsing an empty or non-timing line (poo#203817).
    ($str_time) = grep { /Startup finished in/i } split(/\r?\n/, $str_time);
    return undef unless defined($str_time);
    $str_time =~ s/Startup finished in\s*//i;
    $str_time =~ s/=(.+)$/+$1 (overall)/;
    for my $time (split(/\s*\+\s*/, $str_time)) {
        $time = trim($time);
        my ($time, $type) = $time =~ /^(.+)\s*\((\w+)\)$/;
        $res->{$type} = systemd_time_to_second($time);
        return undef if ($res->{$type} == -1);
    }
    foreach (qw(kernel initrd userspace overall)) { return undef unless exists($res->{$_}); }
    return $res;
}

sub extract_blame_time {
    my $str_time = shift;
    my $ret = {};
    for my $line (split(/\r?\n/, $str_time)) {
        $line = trim($line);
        # Only <time> <service> lines are blame entries; skip anything else
        # (e.g. an SSH login banner / MOTD prepended to the output, poo#203817).
        my ($time, $service) = $line =~ /^(\S+)\s+(\S+)$/;
        next unless defined($service);
        my $sec = systemd_time_to_second($time);
        next unless ($sec >= 0);
        $ret->{$service} = $sec;
    }
    return $ret;
}

sub do_systemd_analyze_time {
    my ($instance, %args) = @_;
    my $timeout = $args{timeout} // 300;
    my $start_time = time();
    my $output = "";
    my $finished = 0;
    my @ret;

    # Poll systemd-analyze until the system has actually finished booting.
    # On a freshly-launched Public Cloud instance SSH becomes reachable while
    # late boot units (e.g. cloud-init) are still running, so systemd-analyze
    # reports "Bootup is not yet finished (...FinishTimestampMonotonic=0)" and
    # exits non-zero (poo#203817). "Startup finished in" only appears once boot
    # is complete, so it is our readiness signal. Break out on the successful
    # match *before* sleeping so a result arriving near the timeout is not
    # discarded, and gate success on the match rather than on elapsed time.
    while (time() - $start_time < $timeout) {
        # calling systemd-analyze time
        $output = $instance->ssh_script_output(cmd => 'systemd-analyze time', proceed_on_failure => 1);
        if ($output =~ /Startup finished in/i) {
            $finished = 1;
            last;
        }
        sleep 5;
    }
    unless ($finished) {
        record_info("WARN", "Unable to get systemd-analyze in ${timeout}s.\nLast output:" . $output, result => 'fail');
        return (0, 0);
    }
    # log time
    $instance->ssh_script_run("uptime");

    push @ret, extract_analyze_time($output);

    $output = $instance->ssh_script_output(cmd => 'systemd-analyze blame', proceed_on_failure => 1);
    push @ret, extract_blame_time($output);

    return @ret;
}

sub upload_supportconfig_log {
    my ($self, %args) = @_;
    my $timeout = 600 + (is_sle('=12-SP5') ? 1400 : 0);
    my $start = time();
    my $logs = "/var/tmp/scc_supportconfig";
    # Eventual comma-separated tokens list to exclude
    # Excluding AUDIT due to bsc#1250310
    my $exclude = get_var('PUBLIC_CLOUD_SUPPORTCONFIG_EXCLUDE', 'AUDIT');
    # To remove exclusions, _EXCLUDE='-'
    $exclude = undef if ($exclude eq '-');
    $exclude = "-x " . $exclude if ($exclude);
    my $cmd = "echo | sudo supportconfig -R " . dirname($logs) . " -B supportconfig $exclude > $logs.txt 2>&1";
    my $res = $self->ssh_script_run($cmd, timeout => $timeout, apply_graceful_timeout => 1);
    $self->ssh_script_run(cmd => "sudo chmod 0644 $logs.txz", apply_graceful_timeout => 1);
    $self->upload_log("$logs.txz", failok => 1, timeout => 180);
    if (isok($res)) {
        record_info('supportconfig done', "OK: duration " . (time() - $start) . "s. Log $logs.txz" . (($exclude) ? " - Excluded: $exclude" : ''));
    } else {
        record_info('FAILED supportconfig', 'Failed after: ' . (time() - $start) . 'sec.', result => 'fail');
    }
    # Never fail
    return 1;
}

sub wait_for_state {
    my ($self, $state, $timeout) = @_;
    $timeout //= 1800;
    my $deadline = time() + $timeout;
    my $current;
    while (time() < $deadline) {
        $current = lc($self->provider->get_state_from_instance($self));
        return if ($current =~ /$state/);
        sleep 15;
    }
    die("The instance state is not '$state' but '$current' instead.");
}

1;
