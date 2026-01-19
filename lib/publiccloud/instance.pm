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
# for boottime checks
use db_utils;
use Mojo::Util 'trim';
use Data::Dumper;
use mmapi qw(get_current_job_id);

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
    $args{timeout} //= SSH_TIMEOUT;

    my $cmd = $args{cmd};
    unless ($args{no_quote}) {
        $cmd =~ s/'/'"'"'/g;
        $cmd = "'$cmd'";
    }

    my $log = '/var/tmp/ssh_sut.log';
    my $ssh_cmd = sprintf('ssh %s %s "%s@%s" -- %s', (($args{ssh_opts} !~ m{-E\s+$log}) ? "-E $log" : ''), $args{ssh_opts}, $args{username}, $self->public_ip, $cmd);

    return $ssh_cmd;
}


=head2 _apply_cmd_timeout
    _apply_cmd_timeout($args, $ssh_cmd) - wraps $ssh_cmd within timeout call which will make sure graceful and unconditional interruption
      after defined period of time

    C<args> - reference to args hash. it is important to pass reference so function can modify timeout passed to script_run by the caller
                to make sure it is bigger than value defined in timeout command which suppose to kill what script_run needs to execute
    C<ssh_cmd> - reference to string containing command which will be executed by script_run. function will tweak it to include timeout call
                which will kill underlying command after time defined by args{timeout}

=cut

sub _apply_cmd_timeout {

    my ($self, $args, $ssh_cmd) = @_;

    $args->{ignore_timeout_failure} //= 0;
    $args->{timeout} //= SSH_TIMEOUT;

    if ($args->{ignore_timeout_failure}) {
        my $external_timeout = $args->{timeout};
        # $args{timeout} will be passed into script_run so it needs to be bigger than value used by timeout command
        # otherwise script_run will die faster than timeout needs to kill running command. Giving 20 second buffer looks safe enough
        $args->{timeout} = $args->{timeout} + 20;
        # timeout is executed with '-k 10' which means that after trying to gracefully shutdown running command for 10 seconds it will
        # start just to kill the process. Taking into account that internal timeout for script_run is longer for 20 seconds
        # kernel has 10 seconds to proceed with killing the process
        $$ssh_cmd = "timeout --foreground -k 10s $external_timeout " . $$ssh_cmd;
    }
    delete($args->{ignore_timeout_failure});
}

=head2 ssh_script_run

    ssh_script_run($cmd [, timeout => $timeout] [,quiet => $quiet] [,ssh_opts => $ssh_opts] [,username => $username][, ignore_timeout_failure => $ignore_timeout_failure])

    C<timeout> - TTL for command execution measured in seconds . After that period of time execution will be aborded
    C<quiet> - avoid recording serial_results ( value pass to script_run call)
    C<ssh_opts> - additional ssh options passed to ssh
    C<username> - username used for ssh tunnel
    C<ignore_timeout_failure> - in case waiting longer than timeout normally script_run will die. Setting this parameter to true
        will avoid such failure

Runs a command C<cmd> via ssh on the publiccloud instance and returns the return code.
=cut

sub ssh_script_run {
    my $self = shift;
    my %args = testapi::compat_args({cmd => undef}, ['cmd'], @_);
    my $ssh_cmd = $self->_prepare_ssh_cmd(%args);
    $self->_apply_cmd_timeout(\%args, \$ssh_cmd);
    delete($args{cmd});
    delete($args{ssh_opts});
    delete($args{username});
    $args{quiet} //= 1;
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
    $self->_apply_cmd_timeout(\%args, \$ssh_cmd);
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
    $self->_apply_cmd_timeout(\%args, \$ssh_cmd);
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

    scp($from, $to[, timeout => 90]);

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

    # Sanitize ssh_opts by removing -E options which are not accepted by 'scp'
    my $ssh_opts = $self->ssh_opts;
    $ssh_opts =~ s/\-E\s[^\s]+//g;

    my $ssh_cmd = sprintf('scp %s "%s" "%s"', $ssh_opts, $from, $to);

    $self->_apply_cmd_timeout(\%args, \$ssh_cmd);

    return script_run($ssh_cmd, %args);
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
    $args{ignore_timeout_failure} = 1 if ($args{failok});
    my $ret = $self->scp('remote:' . $remote_file, $dest, %args);
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
    $res = $self->ssh_script_run(cmd => $cmd, ignore_timeout_failure => 1);
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
    $self->ssh_script_run(cmd => "rpm -qa cloud-regionsrv-client", ignore_timeout_failure => 1);
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

=head2 wait_for_ssh

    wait_for_ssh([timeout => 600] [, proceed_on_failure => 0] [, scan_ssh_host_key => 0] [, ...])

When a remote pc instance starting, by default wait_stop param.=0(false) and 
this routine checks until the SSH port of the remote instance is reachable and open. 
Then by default also checks that system is up, unless systemup_check false/0.

Wnen a remote pc instance is stopping in shutdown, we set input param. wait_stop=1(true),
to expect until ssh is closed; automatic defaults systemup_check=0 and proceed_on_failure=1 applied.
Status values of exit_code: 0 = pass; 1 = fail; 2 = fail,but retry,till timeout or valid outcome.

Parameters:
 timeout => total wait timeout; default: 600.
 wait_stop => If true waits for ssh port to become unreachable, if false waits for ssh reachable; default: false.
 proceed_on_failure => in case of fail, if false exit test with error, if true let calling code to continue; default: wait_stop.
 scan_ssh_host_key => If true we will rescan the SSH host key
                      This will be true when:
                       * SUT changes it's public IP address
                       * SUT regenerates it's SSH host keys
                         (e.g. when cloud-init state is cleared)
 username => default: username().
 systemup_check => If true, checks if the system is up too, instead of just checking the ssh port; default: !wait_stop.
 logs => If true, upload journal to test logs, if false log not uploaded, to speed up check; default: true.

Return:
 duration if pass 
 undef if fail and proceed_on_failure true, otherwise die.
=cut

sub wait_for_ssh {
    my ($self, %args) = @_;
    # Input parameters, see description in above head2 - Parameters section:
    $args{timeout} = get_var('PUBLIC_CLOUD_SSH_TIMEOUT', $args{timeout} // 600);
    $args{wait_stop} //= 0;
    $args{scan_ssh_host_key} //= 0;
    $args{proceed_on_failure} //= $args{wait_stop};
    $args{systemup_check} //= not $args{wait_stop};
    $args{logs} //= 1;
    # DMS migration (tests/publiccloud/migration.pm) is running under user "migration"
    # until it is not over we will receive "ssh permission denied (pubkey)" error
    # but it is not good reason to die early because after it will be over
    # DMS will return normal user and error will be resolved: connection retry for that error.

    $args{username} //= $self->username();
    my $delay = $args{timeout} > 180 ? 5 : 1;
    my $start_time = time();
    my $instance_msg = "instance: $self->{instance_id}, public IP: $self->{public_ip}";
    my ($duration, $exit_code, $sshout, $sysout);

    # Looping until SSH port 22 is reachable or timeout.
    while (($duration = time() - $start_time) < $args{timeout}) {
        $exit_code = script_run('nc -vz -w 1 ' . $self->public_ip . ' 22', quiet => 1);
        last if (isok($exit_code) and not $args{wait_stop});    # ssh port open ok
        last if (not isok($exit_code) and $args{wait_stop});    # ssh port closed ok

        sleep $delay;
    }    # endloop

    # exit_code is 0 when shell script is ok
    if (isok($exit_code)) {
        $sshout = "SSH port is open\n";
    }
    else {
        $sshout = "SSH port is not open failed access\n";
        $sshout .= "as expected by stopping: OK.\n" if $args{wait_stop};
    }    # endif

    # Check also remote system is up and running:
    my $retry = 0;    # count retries of unexpected sysout
    if (isok($exit_code)) {
        if ($args{systemup_check}) {
            # SSH host key is not checked and master socket is not used
            my $ssh_opts = $self->ssh_opts() . ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ControlPath=none -o ConnectTimeout=10';
            while (($duration = time() - $start_time) < $args{timeout}) {
                # timeout recalculated removing consumed time until now
                # We don't support password authentication so it would just block the terminal
                $sysout = $self->ssh_script_output(cmd => 'sudo systemctl is-system-running', ssh_opts => $ssh_opts,
                    timeout => $args{timeout} - $duration, proceed_on_failure => 1, username => $args{username});
                # result check
                if ($sysout =~ m/initializing|starting/) {    # still starting
                    $exit_code = undef;
                }
                elsif ($sysout =~ m/running/) {    # startup OK
                    $exit_code = 0;
                    $sysout .= "\nSystem successfully booted";
                    last;
                }
                elsif ($sysout =~ m/degraded/) {    # up but with failed services to collect
                    $exit_code = 0;
                    $sysout .= "\nSystem booted, but some services failed:\n" .
                      $self->ssh_script_output(cmd => 'sudo systemctl --failed', ssh_opts => $ssh_opts,
                        proceed_on_failure => 1, username => $args{username});
                    last;
                }
                elsif ($sysout =~ m/maintenance|stopping|offline|unknown/) {
                    $exit_code = 1;
                    $sysout .= "\nCan not reach systemd target";
                    last;
                }
                else {    # other outcome or connection refused: retry/reloop
                    $exit_code = 2;
                    ++$retry;
                }    # endif
                sleep $delay;
            }    # end loop
        }    # endif

        if ($args{scan_ssh_host_key}) {
            record_info('RESCAN', 'Rescanning SSH host key');
            # remove username/known_host when missing
            my $known_hosts_2 = (script_run("test -f /home/$testapi::username/.ssh/known_hosts") eq 0)
              ? "/home/$testapi::username/.ssh/known_hosts" : "";
            # Install server's ssh publicckeys to prevent authentication interactions
            # or instance address changes during VM reboots.
            script_run("ssh-keyscan $self->{public_ip} | tee ~/.ssh/known_hosts $known_hosts_2");
        }

        my $exit_ssh;
        # Finally make sure that SSH works
        while (($duration = time() - $start_time) < $args{timeout}) {
            # After the instance is resumed from hibernation the SSH can freeze
            my $ssh_opts = $self->ssh_opts() . ' -o ControlPath=none -o ConnectTimeout=10';
            $exit_ssh = $self->ssh_script_run(cmd => "true", ssh_opts => $ssh_opts, username => $args{username}, timeout => $args{timeout} - $duration, ignore_timeout_failure => 1);
            last if isok($exit_ssh);
            sleep $delay;
        }

        # Merge exit results
        $exit_code = $exit_ssh || $exit_code;
        # Add debugging info on error:
        unless (isok($exit_code)) {
            # validate sshd_config configuration file and verbose ssh debugging
            my $debug = script_output("ssh " . $self->ssh_opts() . " " . $args{username} . "@" . $self->{public_ip} . " -- 'sudo sshd -t && echo sshd OK || echo sshd config error'", timeout => 90, proceed_on_failure => 1) . "\n";
            $debug .= script_output("ssh -vvv " . $self->ssh_opts() . " " . $args{username} . "@" . $self->{public_ip} . " -- 'ls -lR /etc/ssh'", timeout => 90, proceed_on_failure => 1) . "\n";
            record_info('SSH CHECK', "Check ssh on error\n" . $debug, result => 'fail');
        }
        # Log upload
        if (!get_var('PUBLIC_CLOUD_SLES4SAP') and $args{logs}) {
            #Exclude 'mr_test/saptune' test case as it will introduce random softreboot failures.
            $self->ssh_script_run('sudo journalctl -b --no-pager > /tmp/journalctl.log',
                timeout => 360, ignore_timeout_failure => 1, username => $args{username}, quiet => 1);
            $self->upload_log('/tmp/journalctl.log', failok => 1);
        }    # endif
    }    # endif

    # result display
    $sysout .= "\nTimeout $args{timeout} sec. expired" if ($duration >= $args{timeout});
    $instance_msg = "Check" . ($args{systemup_check} ? " SYSTEM " : " SSH ") . ($args{wait_stop} ? "DOWN" : "UP") .
      ", $instance_msg, Duration: $duration sec.\nResult: $sshout";
    $instance_msg .= $sysout if defined($sysout);
    $instance_msg .= "\nRetries on failure: $retry" if ($retry);
    # $sysout is not available if $args{systemup_check} is 0
    record_info("WAIT CHECK:" . isok($exit_code), $instance_msg, result => (defined($sysout) && $sysout =~ m/\sfailed\s/) ? "fail" : "ok");

    # OK
    return $duration if (!$exit_code && !$args{wait_stop} || $exit_code && $args{wait_stop});
    # FAIL
    croak(" results summary:\n" . $sshout . $sysout) unless ($args{proceed_on_failure});
    return;    # proceed_on_failure true
}    # end sub

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
    my $out = $self->wait_for_ssh(timeout => $args{timeout}, wait_stop => 1, username => $args{username});
    # ok ssh port closed
    record_info("Shutdown failed", "WARNING: while stopping the system, ssh port still open after timeout,\nreporting: $out", result => 'fail')
      unless (defined $out);    # not ok port still open

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

=head2 network_speed_test

    network_speed_test();

Test the network speed.
=cut

sub network_speed_test() {
    my ($self, %args) = @_;
    my ($cmd, $ret);

    # Curl stats output format
    my $write_out
      = 'time_namelookup:\t%{time_namelookup} s\ntime_connect:\t\t%{time_connect} s\ntime_appconnect:\t%{time_appconnect} s\ntime_pretransfer:\t%{time_pretransfer} s\ntime_redirect:\t\t%{time_redirect} s\ntime_starttransfer:\t%{time_starttransfer} s\ntime_total:\t\t%{time_total} s\n';
    # PC RMT server domain name
    my $rmt_host = "smt-" . lc(get_required_var('PUBLIC_CLOUD_PROVIDER')) . ".susecloud.net";

    $cmd = "grep \"$rmt_host\" /etc/hosts";
    $ret = $self->ssh_script_run(cmd => $cmd, ignore_timeout_failure => 1);
    record_info("RMT_HOST", printf('$ %s\n%s', $cmd, $ret));

    $cmd = "ping -c3 1.1.1.1";
    $ret = $self->ssh_script_run(cmd => $cmd, ignore_timeout_failure => 1);
    record_info("PING", printf('$ %s\n%s', $cmd, $ret));

    $cmd = "curl -w '$write_out' -o /dev/null -v https://$rmt_host/";
    $ret = $self->ssh_script_run(cmd => $cmd, ignore_timeout_failure => 1);
    record_info("CURL", printf('$ %s\n%s', $cmd, $ret));
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
    $self->ssh_script_retry(cmd => "sudo cloud-init status", timeout => 90, retry => 12, delay => 15);
    $self->ssh_script_retry(cmd => "sudo cloud-init status --long", timeout => 90, retry => 12, delay => 15);

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

=head2 measure_boottime

    measure_boottime();

Perfomrance measurement of the system Boot time. 
Mainly used C<systemd-analyze> command for the data extraction.
Data is then collected in an internal record, ready for storing in a DB.
Set PUBLIC_CLOUD_PERF_COLLECT true or >0, to activate boottime measurements.

=cut

sub measure_boottime() {
    my ($self, $instance, $type) = @_;
    my $data_collect = get_var('PUBLIC_CLOUD_PERF_COLLECT', 1);

    return 0 if (!$data_collect || is_openstack);

    my $ret = {
        kernel_release => undef,
        kernel_version => undef,
        type => undef,
        analyze => {},
        blame => {},
    };

    record_info("BOOT TIME", 'systemd_analyze');
    # first deployment analysis
    my ($systemd_analyze, $systemd_blame) = do_systemd_analyze_time($instance);
    return 0 unless ($systemd_analyze && $systemd_blame);

    $ret->{analyze}->{$_} = $systemd_analyze->{$_} foreach (keys(%{$systemd_analyze}));
    $ret->{blame} = $systemd_blame;
    $ret->{type} = $type;
    # $ret->{analyze}->{ssh_access} = $startup_time; # placeholder for next implementation
    record_info("WARN", "High overall value:" . $ret->{analyze}->{overall}, result => 'fail') if ($ret->{analyze}->{overall} >= 3600.0);

    # Collect kernel version
    $ret->{kernel_release} = $instance->ssh_script_output(cmd => 'uname -r', proceed_on_failure => 1);
    $ret->{kernel_version} = $instance->ssh_script_output(cmd => 'uname -v', proceed_on_failure => 1);

    $Data::Dumper::Sortkeys = 1;
    my $dir = "/var/log";
    my @logs = qw(cloudregister cloud-init.log cloud-init-output.log messages NetworkManager);
    $instance->upload_check_logs_tar(map { "$dir/$_" } @logs);

    record_info("RESULTS", Dumper($ret));
    return $ret;
}


=head2 store_boottime_db

    store_boottime_db();

Save data collected with measure_boottime in a DB;
Mainly stored on a remote InfluxDB on a Grafana server.
To activate boottime push, shall be available results and
  PUBLIC_CLOUD_PERF_PUSH_DATA true/not 0 and
  _SECRET_PUBLIC_CLOUD_PERF_DB_TOKEN defined
=cut

sub store_boottime_db() {
    my ($self, $results, $url) = @_;
    my $data_push = get_var('PUBLIC_CLOUD_PERF_PUSH_DATA', 1);
    my $org = get_var('PUBLIC_CLOUD_PERF_DB_ORG', 'qec');
    my $db = get_var('PUBLIC_CLOUD_PERF_DB', 'perf_2');
    my $token = get_var('_SECRET_PUBLIC_CLOUD_PERF_DB_TOKEN');

    return unless ($results && $data_push && $url);
    unless ($token) {
        record_info("WARN", "_SECRET_PUBLIC_CLOUD_PERF_DB_TOKEN is missing ", result => 'fail');
        return 0;
    }

    my $tags = {
        instance_type => get_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
        job_id => get_current_job_id(),
        os_provider => get_var('PUBLIC_CLOUD_PROVIDER'),
        os_build => get_var('BUILD'),
        os_flavor => get_var('FLAVOR'),
        os_version => get_var('VERSION'),
        os_distri => get_var('DISTRI'),
        os_arch => get_var('ARCH'),
        os_region => $self->{region},
        os_kernel_release => $results->{kernel_release},
        os_kernel_version => $results->{kernel_version},
    };

    $tags->{os_pc_build} = get_var('PUBLIC_CLOUD_QAM') ? 'N/A' : get_var('PUBLIC_CLOUD_BUILD', 0);
    $tags->{os_pc_kiwi_build} = get_var('PUBLIC_CLOUD_QAM') ? 'N/A' : get_var('PUBLIC_CLOUD_BUILD_KIWI', 0);

    record_info("STORE analyze", 'bootup');
    # Store values in influx-db

    my $data = {
        table => 'bootup',
        tags => $tags,
        values => $results->{analyze}
    };
    my $res = influxdb_push_data($url, $db, $org, $token, $data, proceed_on_failure => 1);
    return unless ($res);

    record_info("STORE blame", $results->{type});
    $tags->{boottype} = $results->{type};
    $data = {
        table => 'bootup_blame',
        tags => $tags,
        values => $results->{blame}
    };
    $res = influxdb_push_data($url, $db, $org, $token, $data, proceed_on_failure => 1);
    return $res;
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
    ($str_time) = split(/\r?\n/, $str_time, 2);
    $str_time =~ s/Startup finished in\s*//;
    $str_time =~ s/=(.+)$/+$1 (overall)/;
    for my $time (split(/\s*\+\s*/, $str_time)) {
        $time = trim($time);
        my ($time, $type) = $time =~ /^(.+)\s*\((\w+)\)$/;
        $res->{$type} = systemd_time_to_second($time);
        return 0 if ($res->{$type} == -1);
    }
    foreach (qw(kernel initrd userspace overall)) { return 0 unless exists($res->{$_}); }
    return $res;
}

sub extract_blame_time {
    my $str_time = shift;
    my $ret = {};
    for my $line (split(/\r?\n/, $str_time)) {
        $line = trim($line);
        my ($time, $service) = $line =~ /^(.+)\s+(\S+)$/;
        $ret->{$service} = systemd_time_to_second($time);
        return 0 if ($ret->{$service} == -1);
    }
    return $ret;
}

sub do_systemd_analyze_time {
    my ($instance, %args) = @_;
    $args{timeout} = 120;
    my $start_time = time();
    my $output = "";
    my @ret;

    # calling systemd-analyze time & blame
    # guestregister check executed in create_instances
    while ($output !~ /Startup finished in/ && time() - $start_time < $args{timeout}) {
        $output = $instance->ssh_script_output(cmd => 'systemd-analyze time', proceed_on_failure => 1);
        sleep 5;
    }

    unless ($output && (time() - $start_time < $args{timeout})) {
        record_info("WARN", "Unable to get system-analyze in $args{timeout} seconds", result => 'fail');
        # handle_boot_failure: soft exit from measurement.
        return (0, 0);
    }
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
    my $res = $self->ssh_script_run($cmd, timeout => $timeout, ignore_timeout_failure => 1);
    $self->ssh_script_run(cmd => "sudo chmod 0644 $logs.txz", ignore_timeout_failure => 1);
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
