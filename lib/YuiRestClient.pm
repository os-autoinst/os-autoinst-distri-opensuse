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

use constant API_VERSION => 'v1';

use testapi;
use utils qw(enter_cmd_slow type_line_svirt save_svirt_pty zypper_call);
use Utils::Backends qw(is_pvm is_ipmi);
use YuiRestClient::App;
use registration;
use YuiRestClient::Wait;

our $interval = 1;
our $timeout  = 10;
our $app;

sub set_interval {
    $interval = shift;
}

sub set_timeout {
    $timeout = shift;
}

sub set_app {
    $app = shift;
}

sub get_app {
    return $app;
}

sub connect_to_app {
    my $port = get_var('YUI_PORT');
    my $host = get_var('YUI_SERVER');
    die "Cannot set libyui REST API server" unless $host;
    record_info('PORT',   "Used port for libyui: $port");
    record_info('SERVER', "Connecting to: $host");
    my $app = YuiRestClient::App->new({port => $port, host => $host, api_version => API_VERSION});
    # As we start installer, REST API is not instantly available
    $app->connect(timeout => 500, interval => 10);
    set_app($app);
}

sub connect_to_app_running_system {
    get_app()->connect(timeout => 30, interval => 2);
}

sub setup_libyui_running_system {
    zypper_call('in libyui-rest-api');

    my $port = get_var('YUI_PORT');
    my $host = get_var('YUI_SERVER');
    record_info('PORT',   "Used port for libyui: $port");
    record_info('SERVER', "Connecting to: $host");
    set_var('YUI_PARAMS', "YUI_HTTP_PORT=$port YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1");
    # Add the port to permanent config and restart firewalld to apply the changes immediately.
    # This is needed, because if firewall is restarted for some reason, then the port become
    # closed (e.g. it was faced while saving settings in yast2 lan) and further tests will not
    # be able to communicate with YaST modules.
    assert_script_run("firewall-cmd --zone=public --add-port=$port/tcp --permanent");
    assert_script_run('firewall-cmd --reload');
    my $app = YuiRestClient::App->new({port => $port, host => $host, api_version => API_VERSION});
    set_app($app);
}

sub is_libyui_rest_api {
    return get_var('YUI_REST_API');
}

sub set_libyui_backend_vars {
    my $yuiport = get_var('YUI_START_PORT', 39000);
    $yuiport += get_var('VNC') =~ /(?<vncport>\d+)/ ? $+{vncport} : int(rand(1000));
    die "Cannot set port for YUI REST API" unless $yuiport;

    set_var('YUI_PORT', $yuiport);

    unless (get_var('BOOT_HDD_IMAGE')) {
        set_var('EXTRABOOTPARAMS', get_var('EXTRABOOTPARAMS', '')
              . " extend=libyui-rest-api YUI_HTTP_PORT=$yuiport YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1");
    }

    my $server;
    if (check_var('BACKEND', 'qemu')) {
        # On qemu we connect to the worker using port forwarding
        $server = 'localhost';
        set_var('NICTYPE_USER_OPTIONS', "hostfwd=tcp::$yuiport-:$yuiport");
    } elsif (is_pvm || is_ipmi) {
        $server = get_var('SUT_IP');
    } elsif (get_var('S390_ZKVM')) {
        $server = get_var('VIRSH_GUEST');
    }

    set_var('YUI_SERVER', $server);
}

sub setup_libyui_firstboot {
    my $port = get_var('YUI_PORT');
    record_info("YUIPORT", "Port that will be used by libyui_rest_api:" . get_var('YUI_PORT'));
    zypper_call('in libyui-rest-api');
    assert_script_run "firewall-cmd --zone=public --add-port=$port/tcp --permanent";
    foreach my $export ("YUI_HTTP_PORT=$port", "YUI_HTTP_REMOTE=1", "YUI_REUSE_PORT=1", "Y2DEBUG=1") {
        assert_script_run "echo export $export >> /usr/lib/YaST2/startup/Firstboot-Stage/S01-rest-api";
    }
    assert_script_run "chmod +x /usr/lib/YaST2/startup/Firstboot-Stage/S01-rest-api";
}

1;
