# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable and test that systemd is running in WSL
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use utils qw(zypper_call enter_cmd_slow);
use version_utils qw(is_opensuse);
use wsl qw(is_fake_scc_url_needed);

sub run {
    my $self = shift;

    assert_screen(['windows_desktop', 'powershell-as-admin-window']);
    $self->open_powershell_as_admin if match_has_tag('windows_desktop');

    # Check that systemd is not enabled by default.
    $self->run_in_powershell(
        cmd => '$port.WriteLine($(wsl /bin/bash -c "systemctl is-system-running"))',
        code => sub {
            die("Systemd is running by default...")
              unless wait_serial("offline");
        }
    );
    $self->run_in_powershell(
        cmd => q(wsl),
        code => sub {
            # become_root is now preferred and expected behavior:
            # https://bugzilla.suse.com/show_bug.cgi?id=1225075
            become_root;
            enter_cmd("zypper in -y -t pattern wsl_systemd");
            wait_still_screen stilltime => 3, timeout => 10, similarity_level => 43;
            save_screenshot;
            enter_cmd("exit");
            wait_still_screen stilltime => 3, timeout => 10, similarity_level => 43;
            # There's need to exit twice, one from the root and another
            # one from the WSL
            enter_cmd("exit");
        }
    );
    $self->run_in_powershell(cmd => q(wsl --shutdown));
    $self->run_in_powershell(
        cmd => '$port.WriteLine($(wsl /bin/bash -c "systemctl is-system-running"))',
        code => sub {
            die("systemd is offline...")
              unless wait_serial("running", timeout => 120);
        }
    );
    $self->run_in_powershell(cmd => q(wsl /bin/bash -c "exit"));
}

1;
