# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YuiRestClient;
use strict;
use warnings;

use constant {
    API_VERSION => 'v1',
    TIMEOUT     => 10,
    INTERVAL    => 1
};

use testapi;
use utils qw(enter_cmd_slow type_line_svirt save_svirt_pty zypper_call);
use Utils::Backends;
use YuiRestClient::App;
use YuiRestClient::Wait;
use Utils::Architectures 'is_s390x';

my $app;
my $port;
my $host;

sub get_app {
    my (%args) = @_;
    $app = init_app(%args) unless $app;
    return $app;
}

sub get_host {
    my (%args) = @_;
    $host = init_host(%args) unless $host;
    return $host;
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
    my (%args)       = @_;
    my $timeout      = $args{timeout}  || TIMEOUT;
    my $interval     = $args{interval} || INTERVAL;
    my $installation = $args{installation};
    $port = init_port();
    $host = init_host($installation);

    $app = YuiRestClient::App->new({
            port        => $port,
            host        => $host,
            api_version => API_VERSION,
            timeout     => $timeout,
            interval    => $interval});
}

sub init_port {
    $port = get_var('YUI_START_PORT', 39000);
    $port += get_var('VNC') =~ /(?<vncport>\d+)/ ? $+{vncport} : int(rand(1000));
    die "Cannot set port for YUI REST API" unless $port;

    set_var('YUI_PORT', $port);
    return $port;
}

sub init_host {
    my ($installation)             = @_;
    my $yuiport                    = get_port();
    my $ip_regexp                  = qr/(?<ip>(\d+\.){3}\d+)/i;
    my $get_ip_from_console_output = sub {
        YuiRestClient::Wait::wait_until(object => sub {
                my $ip = script_output('ip -o -4 addr list | sed -n 2p | awk \'{print $4}\' | cut -d/ -f1', proceed_on_failure => 1);
                return $+{ip} if ($ip =~ $ip_regexp);
        });
    };
    if (check_var('BACKEND', 'qemu')) {
        $host = 'localhost';
    } elsif (is_pvm || is_ipmi) {
        $host = get_var('SUT_IP');
    } elsif (get_var('S390_ZKVM')) {
        $host = get_var('VIRSH_GUEST');
    } elsif (check_var('BACKEND', 's390x')) {
        $installation ? select_console('install-shell') : select_console('root-console');
        $host = &$get_ip_from_console_output;
        select_console('installation') if $installation;
    } elsif (is_hyperv) {
        my $boot_timeout = 500;
        my $svirt        = select_console('svirt');
        my $name         = $svirt->name;
        my $cmd          = "powershell -Command \"Get-VM -Name $name | Select -ExpandProperty Networkadapters | Select IPAddresses\"";
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
    if (check_var('BACKEND', 'qemu')) {
        # On qemu we connect to the worker using port forwarding
        set_var('NICTYPE_USER_OPTIONS', "hostfwd=tcp::$yuiport-:$yuiport");
    }
    set_var('EXTRABOOTPARAMS', get_var('EXTRABOOTPARAMS', '')
          . " extend=libyui-rest-api " . get_yui_params_string($yuiport));
}

sub get_yui_params_string {
    my ($yuiport) = @_;
    return "YUI_HTTP_PORT=$yuiport YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1";
}

1;
