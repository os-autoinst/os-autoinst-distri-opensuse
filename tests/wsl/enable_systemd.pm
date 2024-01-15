# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable and test that systemd is running in WSL
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use utils qw(enter_cmd_slow);
use version_utils qw(is_opensuse);
use wsl qw(is_fake_scc_url_needed);

sub run {
    my $self = shift;

    assert_screen(['windows_desktop', 'powershell-as-admin-window']);
    $self->open_powershell_as_admin if match_has_tag('windows_desktop');
    # In openSUSE the WSL shell is not root, so there's need to run become_root
    # in order to write in the /etc/wsl.conf file
    $self->run_in_powershell(
        cmd => q(wsl),
        code => sub {
            become_root if (is_opensuse);
            enter_cmd("ps 1 | grep '/init'");
            enter_cmd("stat /init | grep 'init'");
            enter_cmd("echo -e '[boot]\nsystemd=true' > /etc/wsl.conf");
            wait_still_screen stilltime => 3, timeout => 10;
            save_screenshot;
            enter_cmd("exit");
            # In openSUSE there's need to exit twice, one from the root and another
            # one from the WSL
            enter_cmd("exit") if (is_opensuse);
        }
    );
    $self->run_in_powershell(cmd => q(wsl --shutdown));
    $self->run_in_powershell(cmd => q(wsl /bin/bash -c "ps 1 | grep '/sbin/init'"));
    $self->run_in_powershell(cmd => q(wsl /bin/bash -c "stat /sbin/init | grep 'systemd'"));
    $self->run_in_powershell(cmd => q(wsl /bin/bash -c "systemctl list-unit-files --type=service | head -n 20"));
    $self->run_in_powershell(cmd => q(wsl /bin/bash -c "exit"));
}

1;
