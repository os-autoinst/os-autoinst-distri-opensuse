# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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
use utils 'type_string_slow';
use Utils::Backends 'is_pvm';
use YuiRestClient::App;


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

sub setup_libyui {
    my $port = get_var('YUI_PORT');
    my $host = get_var('YUI_SERVER');
    record_info('PORT',   "Used port for libyui: $port");
    record_info('SERVER', "Connecting to: $host");
    assert_screen('startshell', timeout => 500);
    type_string_slow "extend libyui-rest-api\n";
    type_string_slow "exit\n";
    my $app = YuiRestClient::App->new({port => $port, host => $host, api_version => API_VERSION});
    # As we start installer, REST API is not instantly available
    $app->connect(timeout => 500, interval => 10);
    set_app($app);
}

sub teardown_libyui {
    assert_screen('startshell', timeout => 100);
    type_string_slow "exit\n";
}

sub is_libyui_rest_api {
    return get_var('YUI_REST_API');
}

sub set_libyui_backend_vars {
    my $yuiport = get_var('YUI_START_PORT', 39000);
    $yuiport += get_var('VNC') =~ /(?<vncport>\d+)/ ? $+{vncport} : int(rand(1000));
    die "Cannot set port for YUI REST API" unless $yuiport;

    set_var('YUI_PORT', $yuiport);
    set_var('EXTRABOOTPARAMS', get_var('EXTRABOOTPARAMS', '')
          . " startshell=1 YUI_HTTP_PORT=$yuiport YUI_HTTP_REMOTE=1 YUI_REUSE_PORT=1");

    my $server;
    if (check_var('BACKEND', 'qemu')) {
        # On qemu we connect to the worker using port forwarding
        $server = 'localhost';
        set_var('NICTYPE_USER_OPTIONS', "hostfwd=tcp::$yuiport-:$yuiport");
    } elsif (is_pvm) {
        $server = get_var('SUT_IP');
    }
    die "Cannot set libyui REST API server" unless $server;
    set_var('YUI_SERVER', $server);
}

1;
