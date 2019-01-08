# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Initialize controller node
# Maintainer: Martin Kravec <mkravec@suse.com>

## OS installation
# Basesystem Module
# Desktop Applications Module (gnome,firefox)
# Server Applications Module (dhcp-server,bind)
# user: Bernhard M. Wiedemann
# - ext4 fs without swap/home (minimize size & avoid btrfs balance)
# - disable firewall
# - disable kdump
# - install dhcp,dns server
# - don't install apparmor

## Firefox - make default, show blank page on startup
# don't show "open or save" dialog
# about:config browser.download.forbid_open_with true
# don't show password saving dialog
# about:config signon.rememberSignons false

## General setup
# mkdir .kube
# hostnamectl set-hostname susetest

## Repositories for extra packages
# SUSEConnect -d
# zypper ar -f -G http://download.suse.de/ibs/SUSE:/SLE-15:/Update/standard/SUSE:SLE-15:Update.repo
# zypper ar -f -G https://download.opensuse.org/repositories/devel:/CaaSP:/Head:/ControllerNode/SLE_15/devel:CaaSP:Head:ControllerNode.repo
# zypper in kubernetes-client (kubectl) mozilla-nss-tools

## Before poweroff
# rm /etc/udev/rules.d/70-persistent-net.rules

use parent 'caasp_controller';
use caasp_controller;

use strict;
use testapi;
use caasp 'pause_until';
use utils qw(ensure_serialdev_permissions turn_off_gnome_screensaver zypper_call);

# Setup key-based access to admin node
sub setup_ssh {
    assert_script_run 'ssh-keygen -N "" -t ecdsa -f ~/.ssh/id_ecdsa';
    assert_script_run 'echo -e "host *
\tUser root
\tStrictHostKeyChecking no
\tUserKnownHostsFile /dev/null
\tLogLevel ERROR" > ~/.ssh/config';

    script_run "ssh-copy-id -f $admin_fqdn", 0;
    assert_screen 'ssh-password-prompt';
    type_password;
    send_key 'ret';
}

sub setup_firefox_ca {
    assert_script_run "scp $admin_fqdn:/etc/pki/ca.crt .";
    assert_script_run 'certutil -A -n CaaSP -d .mozilla/firefox/*.default -i ca.crt -t "C,,"';
}

sub run {
    select_console 'x11';
    x11_start_program('xterm');
    send_key 'super-up';

    # Setup as root
    become_root;
    ensure_serialdev_permissions;
    zypper_call 'up kubernetes-client';
    type_string "exit\n";

    # Setup as user
    turn_off_gnome_screensaver;
    pause_until 'VELUM_STARTED';
    setup_ssh;
    setup_firefox_ca;

    # Leave xterm open for kubernetes tests
    save_screenshot;
    send_key "ctrl-l";
}

1;
