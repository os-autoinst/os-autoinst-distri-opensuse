# SUSE's openQA tests

package YuiRestClient;
use strict;
use warnings;

use constant {
    API_VERSION => 'v1',
    TIMEOUT => 45,
    INTERVAL => 1
};

use testapi;
use utils qw(enter_cmd_slow type_line_svirt save_svirt_pty);
use Utils::Backends;
use YuiRestClient::App;
use YuiRestClient::Wait;
use YuiRestClient::Logger;
use Utils::Architectures;
use bmwqemu;

my $app;
my $port;
my $host;

sub get_app {
    my (%args) = @_;
    die "No environment for libyui REST API has been configured.",
      " Please schedule test module `setup_libyui.pm` in previous steps." unless YuiRestClient::is_libyui_rest_api();
    $app = init_app(%args) unless $app;
    return $app;
}

sub get_host {
    my (%args) = @_;
    $host = init_host(%args) unless $host;
    return $host;
}

sub init_logger {
    my $path_to_log = 'ulogs/yui-log.txt';
    my $yui_log_level = get_var('YUI_LOG_LEVEL', 'debug');
    mkdir('ulogs') if (!-d 'ulogs');
    YuiRestClient::Logger->get_instance({format => \&bmwqemu::log_format_callback, path => $path_to_log, level => $yui_log_level});
}

sub get_port {
    $port = init_port() unless $port;
    return $port;
}

sub set_host {
    my ($yuihost) = @_;
    $host = $yuihost;
    $app->get_widget_controller()->set_host($yuihost);
}

sub set_port {
    my ($yuiport) = @_;
    $port = $yuiport;
    $app->get_widget_controller()->set_host($yuiport);
}

sub set_interval {
    my ($interval) = @_;
    $app->get_widget_controller()->set_interval($interval);
}

sub set_timeout {
    my ($timeout) = @_;
    $app->get_widget_controller()->set_timeout($timeout);
}

sub init_app {
    my (%args) = @_;
    my $timeout = $args{timeout} || TIMEOUT;
    my $interval = $args{interval} || INTERVAL;
    my $installation = $args{installation};
    $port = init_port();
    $host = init_host($installation);

    $app = YuiRestClient::App->new({
            port => $port,
            host => $host,
            api_version => API_VERSION,
            timeout => $timeout,
            interval => $interval});
}

sub init_port {
    $port = get_var('YUI_START_PORT', 39000);
    $port += get_var('VNC') =~ /(?<vncport>\d+)/ ? $+{vncport} : int(rand(1000));
    die "Cannot set port for YUI REST API" unless $port;

    set_var('YUI_PORT', $port);
    return $port;
}

sub init_host {
    my ($installation) = @_;
    my $yuiport = get_port();
    my $ip_regexp = qr/(?<ip>(\d+\.){3}\d+)/i;
    my $get_ip_from_console_output = sub {
        YuiRestClient::Wait::wait_until(object => sub {
                my $ip = script_output('ip -o -4 addr list | sed -n 2p | awk \'{print $4}\' | cut -d/ -f1', proceed_on_failure => 1);
                return $+{ip} if ($ip =~ $ip_regexp);
        });
    };
    if (is_qemu) {
        $host = 'localhost';
    } elsif (is_pvm || is_ipmi) {
        $host = get_var('SUT_IP');
    } elsif (get_var('S390_ZKVM')) {
        $host = get_var('VIRSH_GUEST');
    } elsif (is_backend_s390x) {
        $installation ? select_console('install-shell') : select_console('root-console');
        $host = &$get_ip_from_console_output;
        select_console('installation') if $installation;
    } elsif (is_hyperv) {
        my $boot_timeout = 500;
        my $svirt = select_console('svirt');
        my $name = $svirt->name;
        my $cmd = "powershell -Command \"Get-VM -Name $name | Select -ExpandProperty Networkadapters | Select IPAddresses\"";
        $host = YuiRestClient::Wait::wait_until(object => sub {
                my $ip = $svirt->get_cmd_output($cmd);
                return $+{ip} if ($ip =~ $ip_regexp);
        }, timeout => $boot_timeout, interval => 30);
        select_console('sut', await_console => 0) if $installation;
    } elsif (check_var('VIRSH_VMM_FAMILY', 'xen')) {
        # For xen, when attempting to switch console while the installation loader is not finished, we end up with test failure.
        assert_screen("yast-still-running", 500) if $installation;
        select_console('root-console');
        $host = &$get_ip_from_console_output;
        select_console('installation') if $installation;
    }

    set_var('YUI_SERVER', $host);
    return $host;
}

sub is_libyui_rest_api {
    return get_var('YUI_REST_API');
}

sub set_libyui_backend_vars {
    my $yuiport = get_port();
    if (is_qemu) {
        # On qemu we connect to the worker using port forwarding
        set_var('NICTYPE_USER_OPTIONS', join(' ', grep($_, (
                        get_var('NICTYPE_USER_OPTIONS'),
                        "hostfwd=tcp::$yuiport-:$yuiport"))));
    }
    set_var('EXTRABOOTPARAMS', get_var('EXTRABOOTPARAMS', '')
          . " extend=libyui-rest-api " . get_yui_params_string($yuiport));
}

sub get_yui_params_string {
    my ($yuiport) = @_;
    return "YUI_HTTP_PORT=$yuiport YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1";
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient - Perl module to interact with YaST applications via libyui-rest-api

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

  my $app  = YuiRestClient::get_app(installation => 1, timeout => 60, interval => 1);

=head1 DESCRIPTION

=head2 Overview

See documentation of the L<libyui-rest-api project|https://github.com/libyui/libyui/tree/master/libyui-rest-api/doc>.
for more details about server side implementation.

=head2 Class and object methods

=head3 Main interface methods

B<get_app(%args)> - main routine to create app object.
Parameters are:

=over 4

=item B<{timeout}> - Timeout for server communication, defaults to 30.

=item B<{interval}> - Retry interval for communication, defaults to 1.

=item B<{installation}> - boolean that triggers code to determine IP addresses on various backends.

=back   

C<get_host()> will call C<init_port()> and C<init_host()> from the low level interface
functions (see below) and then create an app object that will be used during the session.

B<get_host(%args)> - returns name or IP of the REST server.

The %args is a boolean $installation (see parameters of C<get_app()> above.)

B<get_port()> - returns port number for the rest server.

B<init_logger> - Initializes logger instance.

The log path is 'ulogs/yui-log.txt'

B<set_host($host)> - change REST server host to new address or IP.

B<set_port($port)> - change REST server port number.

B<set_interval($interval)> - change retry interval.

B<set_timeout($timeout)> - change timeout value.

=head3 Low level interface methods

B<init_port()> - Determine port for the REST server,

The port number starts at C<YUI_START_PORT>, if C<VNC> is present then ths VNC port number 
will be added, otherwise the function take a random numer between 0..1000.
This function will also set the environment variable. C<YUI_PORT>.

B<init_host()> - Initialize REST server and determine its host address.

This method checks what backend is used for the system under test and adjusts the 
host address for the REST server accordingly. The following backends are checked:

=over 4

=item B<QEMU>: Use 'localhost'.

=item B<PowerVM> or B<IPMI>: Use what is defined in C<SUT_IP>.

=item B<S390 Virtual Machine>: Use what is defined in C<VIRSH_GUEST>.

=item B<s390x>: Extract IP address from output of "ip addr" command. 

=item B<HyperV Hypervisor>: Extract IP address from PowerShell command.

=item B<Xen>: Extract IP address from output of "ip addr" command. 

=back

=head3 Helper methods 

B<is_libyui_rest_api()> - Returns environment variable C<YUI_REST_API>.

B<set_libyui_backend_vars()> - Sets C<NICTYPE_USER_OPTIONS> and C<EXTRABOOTPARAMS>.

B<get_yui_params_string($yuiport)> - creates String for C<EXTRABOOTPARAMS>.
This will return "YUI_HTTP_PORT=$yuiport YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1" 
so that this string can be appended to the boot parameters.

=head1 ENVIRONMENT

B<BACKEND> - Defines which Backend is used. C<host_init()> tests for 's390x'.

B<EXTRABOOTPARAMS> - Additional boot parameters for the bootloader. YuiRestClient will 
add " extend=libyui-rest-api YUI_HHTP_PORT=$yuiport YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1"
to this variable.

B<NICTYPE_USER_OPTIONS> - options for the virtual SUT network configuration. On QEMU backends
this variable will get "hostfwd=tcp::$yuiport-:$yuiport" appended. 

B<S390_ZKVM> - Defines that the SUT is on a S390 Virtual Machine.

B<SUT_IP> - IP address of the system under test on PowerVM or IPMI backends.

B<VIRSH_GUEST> - defines the host address for S390 Virtual Machines. 

B<VIRSH_VMM_FAMILY> - defines the Hypervisor for virtual shells. C<host_init()> tests for 'xen'.

B<VNC> - Port number for VNC connection.

B<YUI_HTTP_PORT> - Port number that the REST server should use for listening.

B<YUI_HTTP_REMOTE> - Boolean, if true, then remote connections to the REST server are allowed.

B<YUI_LOG_LEVEL> - Log lever lor C<init_logger()>, defaults to 'debug'.

B<YUI_PORT> - Port for REST server, caclulated by C<init_port()>.

B<YUI_REST_API> - Boolean that defines if the REST API is present.

B<YUI_REUSE_PORT> - Boolean, if 1 then the socket can be reused by other processes.

B<YUI_SERVER> The host address for the REST server.

B<YUI_START_PORT> - Base value for calculating REST server port number, defaults to 39000.

=cut
