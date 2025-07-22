# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup regproxy and redirect registry.opensuse.org to it
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'consoletest';
use testapi;
use utils;
use containers::urls 'get_opensuse_registry_prefix';
use version_utils qw(is_sle is_opensuse is_tumbleweed is_leap);

sub run {
    select_console 'root-console';

    my $opensuse_prefix = get_opensuse_registry_prefix();

    # Can't install deps here, this also runs on transactional RO systems
    # zypper_call('in python3-base');

    # Download all files into /usr/local/bin
    assert_script_run('pushd /usr/local/bin');
    assert_script_run('curl -L -v ' . autoinst_url('/data/regproxy') . ' | cpio -id && mv data/* .');
    # Make it persistent
    assert_script_run('cp $PWD/regproxy.service /etc/systemd/system/');
    assert_script_run('echo "PREFIX=' . $opensuse_prefix . '" > /etc/regproxy.conf');
    assert_script_run('systemctl daemon-reload && systemctl enable --now regproxy.service');
    # Install the MITM cert
    assert_script_run('ln -s $PWD/regproxy-cert.pem /etc/pki/trust/anchors');
    systemctl('start ca-certificates');
    assert_script_run('popd');

    # Redirect to localhost
    assert_script_run('cp -a /etc/hosts hosts.bak');
    assert_script_run('echo -e "127.0.0.1\tregistry.opensuse.org" >> /etc/hosts');
    script_run('nscd -i hosts');    # Just ignore the return value

    # Verify that it works
    validate_script_output('curl -kH "Host: registry.opensuse.org" https://localhost/v2', sub { m/{}/ });
    validate_script_output('curl https://registry.opensuse.org/v2', sub { m/{}/ });

    # Backdate /etc/hosts to not trigger mkdumprd on reboot (boo#1190532)
    assert_script_run('touch -r hosts.bak /etc/hosts && rm hosts.bak');
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
