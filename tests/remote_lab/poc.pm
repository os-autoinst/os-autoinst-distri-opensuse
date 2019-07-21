# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Proof-of-concept of connecting to a remote lab hardware for test
#   execution
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: https://progress.opensuse.org/issues/49901

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    zypper_call '--no-refresh in --no-recommends sshpass';
    script_run 'read -s jumpbox_password', 0;
    type_password get_required_var('_SECRET_JUMPBOX_PASSWORD') . "\n";
    script_run 'read -s sut_password', 0;
    type_password get_required_var('_SECRET_SUT_PASSWORD') . "\n";
    assert_script_run 'ssh-keygen -t ed25519 -N \'\' -f ~/.ssh/id_ed25519';
    type_string 'cat - > .ssh/config <<EOF
Host jumpbox
    HostName 129.40.13.66
    StrictHostKeyChecking no

Host sut
    HostName 10.3.1.111
    ProxyJump jumpbox
    StrictHostKeyChecking no
EOF
';
    my $cmd = <<'EOF';
cat ~/.ssh/id_ed25519.pub | sshpass -p $jumpbox_password ssh jumpbox "cat - >> .ssh/authorized_keys"
cat ~/.ssh/id_ed25519.pub | sshpass -p $sut_password ssh sut "cat - >> .ssh/authorized_keys"
time ssh sut hostname
EOF
    assert_script_run($_) foreach (split /\n/, $cmd);
    assert_script_run('time ssh sut supportconfig', 600);
    assert_script_run('ssh sut "cat /var/log/*.tbz" > sut_supportconfig.tbz');
    upload_logs('sut_supportconfig.tbz');
}

1;
