# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nginx
# Summary: Package for nginx service tests
#
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package services::nginx;
use base 'opensusebasetest';
use testapi;
use warnings;
use strict;
use utils qw(zypper_call common_service_action script_retry);

my $service_type = 'Systemd';

sub add_custom_ports_to_selinux {
    my (%args) = @_;
    $args{nginx_conf} //= "/etc/nginx/nginx.conf";

    # Standard ports to exclude
    my %standard_ports = (
        http => [80],
        https => [443],
    );

    # Function to extract ports using Bash
    my $extract_ports = sub {
        my ($conf, $ssl) = @_;
        my @ports;
        my $command = $ssl
          ? qq{grep -oP 'listen\\s+\\K\\d+(?=.*ssl)' $conf}
          : qq{grep -oP 'listen\\s+\\K\\d+(?=;)' $conf | grep -v ssl};

        my $output = script_output($command, proceed_on_failure => 1);
        for my $line (split /\n/, $output) {
            push @ports, $line if $line =~ /^\d+$/;
        }
        return @ports;
    };

    # Add port to SELinux
    my $add_semanage_port = sub {
        my ($port, $context) = @_;
        my $cmd = "semanage port -a -t $context -p tcp $port";
        my $output = script_output($cmd, proceed_on_failure => 1);
        record_info("Port $port", $output =~ /already added/ ? "Already added." : "Added.");
    };

    # Process HTTP and HTTPS ports
    foreach my $type ("http", "https") {
        my $is_https = $type eq 'https';
        foreach my $port ($extract_ports->($args{nginx_conf}, $is_https)) {
            next if grep { $_ == $port } @{$standard_ports{$type}};
            $add_semanage_port->($port, 'http_port_t');
        }
    }
}

sub install_service {
    zypper_call '-v in nginx', timeout => 1000;
}

sub enable_service {
    common_service_action 'nginx', $service_type, 'enable';
}

sub start_service {
    common_service_action('apache2', $service_type, 'stop') if (script_run("systemctl is-active apache2.service") == 0);
    common_service_action 'nginx', $service_type, 'start';
}

# Configure nginx so it can be tested
sub config_service {
    my $selinux_enabled = script_run('selinuxenabled') == 0;
    zypper_call('in curl') if (script_run('which curl') != 0);
    zypper_call('in openssl') if (script_run('which openssl') != 0);

    assert_script_run('echo "<html>Hello from nginx</html>" > /srv/www/htdocs/index.html');

    my $openssl_command = 'openssl req -keyout /etc/nginx/ssl/key.pem -out /etc/nginx/ssl/cert.pem';
    $openssl_command .= ' -x509 -newkey rsa:4096 -sha256 -days 365 -nodes -subj "/CN=vhost"';
    assert_script_run('mkdir -p /etc/nginx/ssl/');
    assert_script_run($openssl_command);

    my $nginx_conf = "/etc/nginx/vhosts.d/nginx_vhost.conf";

    # Add new virtual host and check the configuration files
    assert_script_run("curl -fv " . data_url("console/nginx_vhost.conf") . " -o $nginx_conf");

    # Add custom ports to SELinux
    add_custom_ports_to_selinux(nginx_conf => $nginx_conf) if $selinux_enabled;

    assert_script_run('nginx -t');

    assert_script_run "echo '127.0.0.1 vhost' >> /etc/hosts";
    assert_script_run "echo '::1 vhost' >> /etc/hosts";

    common_service_action 'nginx', $service_type, 'restart';
}

# check service is running and enabled
sub check_service {
    common_service_action 'nginx', $service_type, 'is-enabled';
    common_service_action 'nginx', $service_type, 'is-active';
}

sub check_function {
    my $grep = sub { /Hello from nginx/ };

    # Check that the servers responds
    # It may take few seconds as the nginx.service has been just started
    script_retry('curl http://localhost/', delay => 5, retry => 3);

    # Check that the response is correct
    validate_script_output('curl http://localhost/', $grep);

    # Test that IPv6 works properly
    validate_script_output('curl -6 http://localhost/', $grep);

    # curl does not follow redirects by default but successfully exits on 3** responses
    validate_script_output('curl http://vhost/', sub { /301 Moved Permanently/ });

    # curl does not accept insecure certificates by default
    assert_script_run('! curl -L https://vhost/');

    # Test HTTPS
    validate_script_output('curl -k https://vhost/', $grep);

    # Follow the HTTP -> HTTPS redirect
    validate_script_output('curl -kL http://vhost/', $grep);

    # Test custom HTTPS port
    validate_script_output('curl -k4 https://vhost:444/', $grep);
    validate_script_output('curl -k6 https://vhost:444/', $grep);

    # Test custom HTTP port
    validate_script_output('curl -kL4 http://vhost:81/', $grep);
    validate_script_output('curl -kL6 http://vhost:81/', $grep);

    # Test HTTP2
    validate_script_output('curl -k4 --http2 https://vhost:444/', $grep);
    validate_script_output('curl -k6 --http2 https://vhost:444/', $grep);
}

1;
