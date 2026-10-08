# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable and test that systemd is running in WSL
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base 'windowsbasetest';
use testapi;
use utils qw(zypper_call enter_cmd_slow);
use version_utils qw(is_opensuse is_tumbleweed);
use wsl qw(is_fake_scc_url_needed);

sub run {
    my $self = shift;

    assert_screen(['windows-desktop', 'powershell-as-admin-window', 'welcome_to_wsl']);
    if (match_has_tag('windows-desktop')) {
        $self->open_powershell_as_admin;
    } elsif (match_has_tag('welcome_to_wsl')) {
        click_lastmatch;
        send_key 'alt-f4';
        $self->open_powershell_as_admin;
    }

    # Check whether systemd is enabled by default. The legacy appx images boot
    # without it, while the images built from the tarball recipe ship
    # /etc/wsl.conf with '[boot] systemd=true' and come up with systemd on.
    my $systemd_on_by_default = 1;
    $self->run_in_powershell(
        cmd => '$port.WriteLine($(wsl /bin/bash -c "systemctl is-system-running"))',
        code => sub {
            $systemd_on_by_default = 0 if wait_serial("offline", timeout => 90);
        }
    );
    record_info('systemd', $systemd_on_by_default ?
          'systemd is already enabled in the image' :
          'systemd is off by default, enabling it');
    $self->run_in_powershell(
        cmd => q(wsl --user root),
        code => sub {
            enter_cmd("zypper in -y -t pattern wsl_systemd");
            wait_still_screen stilltime => 5, timeout => 300, similarity_level => 43;
            save_screenshot;
            enter_cmd("exit");
            # Leaving the distribution takes noticeably longer once systemd is
            # in charge of the session, and anything typed before the prompt is
            # back gets swallowed by the console
            wait_still_screen stilltime => 5, timeout => 120, similarity_level => 43;
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
