# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: Base module for baremetal test cases
# Maintainer: Michael Moese <mmoese@suse.de>

package baremetalbasetest;

use base opensusebasetest;

use testapi;
use strict;
use warnings;

use HTTP::Tiny;
use IPC::Run;
use Socket;
use Time::HiRes 'sleep';


# base class for baremetal tests
sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);

    $token = get_var('BAREMETAL_LOCK_TOKEN', '');
    if ($token == '') {
        $self->host_lock();
    }
    return $self;
}


=head2 post_run_hook

  post_run_hook();

This method will be called after each module finished.
It will B<not> get executed when the test module failed.
Test modules (or their intermediate base classes) may overwrite
this method.

=cut
sub post_run_hook {
    my ($self) = @_;

    die "only IPMI is supported for baremetal testing right now" unless check_var('BACKEND', 'ipmi');

    $self->SUPER::post_run_hook();
}

=head2 post_fail_hook

 post_fail_hook();

When the test module fails, this method will be called.
It will try to fetch some logs from the SUT.
Test modules (or their intermediate base classes) may overwrite
this method to export certain specific logfiles and call the
base method using C<$self-E<gt>SUPER::post_fail_hook;> at the end.

=cut
sub post_fail_hook {
    my ($self) = @_;

    # usually, we are on a serial terminal, but we could of course
    # also run on a VNC session, so support this by running the
    # post fail hook from the base class
    $self->SUPER::post_fail_hook();

    # unlock the host if it was locked. Make sure not to keep the
    # host locked for longer that needed.
    if (host_is_locked()) {
        host_unlock();
    }

}

=head2 poweron

 poweron()

Power on the machine if the backend in use is supported. 
=cut
sub poweron {
    if (check_var('BACKEND', 'ipmi')) {
        ipmitool("chassis power on");
        while (1) {
            sleep(3);
            my $stdout = ipmitool('chassis power status');
            last if $stdout =~ m/is on/;
            ipmitool('chassis power on');
        }
    } else {
        die('Backend ' . get_var('BACKEND') . 'not supported');
    }
}

=head2 poweroff

 poweroff()

Power off the machine if the backend in use is supported. 
=cut
sub poweroff {
    if (check_var('BACKEND', 'ipmi')) {
        ipmitool("chassis power off");
        while (1) {
            sleep(3);
            my $stdout = ipmitool('chassis power status');
            last if $stdout =~ m/is off/;
            ipmitool('chassis power off');
        }
    } else {
        die('Backend ' . get_var('BACKEND') . 'not supported');
    }
}

=head2 poweron

 set_net_boot()

Set boot from network if the backend in use is supported. 
=cut
sub set_net_boot {
    if (check_var('BACKEND', 'ipmi')) {
        while (1) {
            my $stdout = ipmitool('chassis bootparam get 5');
            last if $stdout =~ m/Force PXE/;
            ipmitool("chassis bootdev pxe");
            sleep(3);
        }
    } else {
        die('Backend ' . get_var('BACKEND') . 'not supported');
    }
}

=head2 wait_boot

wait_boot()

Wait for the machine to boot up.
=cut
sub wait_boot {
    my $timeout = shift;
    if (!defined $timeout) {
        $timeout = 1800;
    }
    if (check_var('BACKEND', 'ipmi')) {
        select_consolei('sol', await_console => 0);
        assert_screen('linux-login', $timeout);
    } else {
        die('Backend ' . get_var('BACKEND') . 'not supported');
    }
}

=head2 host_lock

 host_lock() 

Lock the SUT from the baremetal support service. 
=cut
sub host_lock {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url         = "$http_server/v1/host_lock/lock/$ip";

    my $retries = get_var('BAREMETAL_LOCK_RETRIES', 60);
    if (!check_var('BAREMETAL_LOCK_TOKEN'), '') {
        diag('baremetalbasetest::host_lock(): Host is already locked, doing nothing');
        return;
    }
    do {
        my $response = HTTP::Tiny->new->request('GET', $url, {content => '', headers => {'content-type' => 'text/plain'}});
        if ($response->{status} == 200) {
            set_var('BAREMETAL_LOCK_TOKEN', $response->{content});
            break;
        } elsif ($response->{status} == 412) {
            if ($retries != 0) {
                $retries--;
                sleep(60);
            } else {
                record_info('lock timeout', 'failed to acquire the host lock. giving up!', 'fail');
                die('timeout acquiring the host lock - host is not being freed in time');
            }
        } else {
            record_info('lock failure', "failed to acquire the host lock. got HTTP status $response->{status} and message $response->{reason}", 'fail');
            die("baremetalbasetest::host_lock(): failed to acquire the host lock. got HTTP status $response->{status} and message $response->{reason}");
        }
    }

}

=head2 host_is_locked

 host_is_locked() 

Check if the SUT is locked in the support service
=cut
sub host_is_locked {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url_status  = "$http_server/v1/host_lock/lock_state/$ip";

    my $response = HTTP::Tiny->new->request('GET', $url_status, {content => '', headers => {'content-type' => 'text/plain'}});
    if ($response->{status} != 200) {
        diag("baremetalbasetest::host_is_locked(): unable to get lock state for $host: $response->{status} ($response->{reason}");
    } else {
        return unless $response->{content} eq 'locked';
    }
}

=head2 host_unlock

 host_unlock() 

Unlock the SUT from the baremetal support service. 
=cut
sub host_unlock {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $token       = get_var(BAREMETAL_LOCK_TOKEN);
    my $url_status  = "$http_server/v1/host_lock/lock_state/$ip";
    if ($token == '') {
        diag("baremetalbasetest::host_unlock(): no token available, is this machine locked by me?");
        return;
    }
    my $url      = "$http_server/v1/host_lock/lock/$ip/$token";
    my $response = HTTP::Tiny->new->request('PUT', $url_status, {content => '', headers => {'content-type' => 'text/plain'}});
    if ($response->{status} != 200) {
        diag("baremetalbasetest::host_unlock(): unable to unlock $host: $response->{status} ($response->{reason}");
    } else {
        set_var('BAREMETAL_LOCK_TOKEN', '');
    }
}

sub ipmitool {
    my ($cmd) = @_;

    my @cmd = ('ipmitool', '-I', 'lanplus', '-H', $bmwqemu::vars{IPMI_HOSTNAME}, '-U', $bmwqemu::vars{IPMI_USER}, '-P', $bmwqemu::vars{IPMI_PASSWORD});
    push(@cmd, split(/ /, $cmd));

    my ($stdin, $stdout, $stderr, $ret);
    print @cmd;
    $ret = IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
    chomp $stdout;
    chomp $stderr;

    die join(' ', @cmd) . ": $stderr" unless ($ret);
    diag("barepetalbasetest::ipmitool(): $stdout");
    return $stdout;
}

1;
