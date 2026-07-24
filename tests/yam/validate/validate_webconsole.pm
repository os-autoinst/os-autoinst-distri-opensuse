# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that Web Console (Cockpit) is enabled and accesible through http.
# Check Web Console functionality by profiling Agama.
# See https://agama-project.github.io/docs/user/reference/profile/access

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'Yam::Agama::agama_base';
use testapi;

sub run {
    select_console 'root-console';
    my $webConsole_status = script_output('systemctl status cockpit.socket');
    unless ($webConsole_status =~ /status=0\/SUCCESS/) {
        die "Self update did not end successfully";
    }

    my $webConsole_curl = script_output('curl http://localhost:9090');
    if ($webConsole_curl !~ /cockpit/) {
        die "Error, Cockpit string not found in curl output";
    }

    my $webConsole_port = script_output('ss -tulnp | grep :9090');
    if ($webConsole_port !~ /cockpit-tls/) {
        die "Error, Cockpit port not found in ss output";
    }
}

1;
