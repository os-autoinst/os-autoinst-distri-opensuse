# Copyright (C) 2017-2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

package migration;

use base Exporter;
use Exporter;

use strict;

use testapi;
use utils;
use registration;
use qam 'remove_test_repositories';
use version_utils qw(is_sle is_sles4sap);

our @EXPORT = qw(
  setup_sle
  setup_migration
  register_system_in_textmode
  remove_ltss
  disable_installation_repos
  record_disk_info
  check_rollback_system
  reset_consoles_tty
  boot_into_ro_snapshot
);

sub setup_sle {
    select_console 'root-console';

    # Stop packagekitd
    if (is_sle('12+')) {
        pkcon_quit;
    }
    else {
        assert_script_run "chmod 444 /usr/sbin/packagekitd";
    }

    # Change serial dev permissions
    ensure_serialdev_permissions;

    # Enable Y2DEBUG for error debugging
    type_string "echo 'export Y2DEBUG=1' >> /etc/bash.bashrc.local\n";
    script_run "source /etc/bash.bashrc.local";
}

sub setup_migration {
    my ($self) = @_;

    $self->setup_sle();

    # remove the PATCH test_repos
    remove_test_repositories();
    save_screenshot;
}

sub register_system_in_textmode {
    # SCC_URL was placed to medium types
    # so set SMT_URL here if register system via smt server
    # otherwise must register system via real SCC before online migration
    if (my $u = get_var('SMT_URL')) {
        type_string "echo 'url: $u' > /etc/SUSEConnect\n";
    }

    # register system and addons in textmode for all archs
    set_var("VIDEOMODE", 'text');
    if (is_sle('12-SP2+', get_var('HDDVERSION'))) {
        set_var('HDD_SP2ORLATER', 1);
    }
    # Tag the test as being called from this module, so accept_addons_license
    # (called by yast_scc_registration) can handle license agreements from modules
    # that do not show license agreement during installation but do when registering
    # after install
    set_var('IN_PATCH_SLE', 1);
    yast_scc_registration;
    # Once SCC registration is done, disable IN_PATCH_SLE so it does not interfere
    # with further calls to accept_addons_license (in upgrade for example)
    set_var('IN_PATCH_SLE', 0);
}

# Remove LTSS product and manually remove its relevant package before migration
# Also remove ltss from SCC_ADDONS setting for registration in upgrade target
sub remove_ltss {
    if (get_var('SCC_ADDONS', '') =~ /ltss/) {
        my $scc_addons = get_var_array('SCC_ADDONS');
        record_info 'remove ltss', 'got all updates from ltss channel, now remove ltss and drop it from SCC_ADDONS before migration';
        zypper_call 'rm -t product SLES-LTSS';
        zypper_call 'rm sles-ltss-release-POOL';
        set_var('SCC_ADDONS', join(',', grep { $_ ne 'ltss' } @$scc_addons));
    }
}

# Disable installation repos before online migration
# s390x: use ftp remote repos as installation repos
# Other archs: use local DVDs as installation repos
sub disable_installation_repos {
    if (check_var('ARCH', 's390x')) {
        zypper_call "mr -d `zypper lr -u | awk '/ftp:.*?openqa.suse.de/ {print \$1}'`";
    }
    else {
        zypper_call "mr -d -l";
    }
}

# Record disk info to help debug diskspace exhausted
# issue during upgrade
sub record_disk_info {
    if (get_var('FILESYSTEM', 'btrfs') =~ /btrfs/) {
        assert_script_run 'btrfs filesystem df / | tee /tmp/btrfs-filesystem-df.txt';
        assert_script_run 'btrfs filesystem usage / | tee /tmp/btrfs-filesystem-usage.txt';
        assert_script_run 'snapper list | tee /tmp/snapper-list.txt' unless (is_sles4sap());
        upload_logs '/tmp/btrfs-filesystem-df.txt';
        upload_logs '/tmp/btrfs-filesystem-usage.txt';
        upload_logs '/tmp/snapper-list.txt' unless (is_sles4sap());
    }
    assert_script_run 'df -h > /tmp/df.txt';
    upload_logs '/tmp/df.txt';
}

# System check after snapper rollback
sub check_rollback_system {
    # Check if repos are rolled back to correct version
    script_run("zypper lr -u | tee /dev/$serialdev");
    my $incorrect_repos = script_output("
        version=\$(grep VERSION= /etc/os-release | cut -d'=' -f2 | cut -d' ' -f1 | sed 's/\"//g')
        base_version=\$(echo \$version | cut -d'-' -f1)
        zypper lr | cut -d'|' -f3 | gawk '/SLE/ || /openSUSE/' | sed \"/\$version\\|Module.*\$base_version/d\"
    ", 100);
    record_info('Incorrect Repos', $incorrect_repos, result => 'fail') if $incorrect_repos;

    return unless is_sle;
    # Check SUSEConnect status for SLE
    # check rollback-helper service is enabled and worked properly
    # If rollback service is activating, need wait some time
    # Add wait in a loop, max time is 5 minute, because case with much more modules need more time
    for (1 .. 5) {
        last unless script_run('systemctl --no-pager status rollback') != 0;
        sleep 60;
    }
    systemctl('is-active rollback');

    # Disable the obsolete cd and dvd repos to avoid zypper error
    assert_script_run("zypper mr -d -m cd -m dvd");
    # Verify registration status matches current system version
    # system is un-registered during media based upgrade
    assert_script_run('curl -s ' . data_url('console/check_registration_status.py') . ' | python') unless get_var('MEDIA_UPGRADE');
}

# Reset tty for x11 and root consoles
sub reset_consoles_tty {
    console('x11')->set_tty(get_x11_console_tty);
    console('root-console')->set_tty(get_root_console_tty);
    reset_consoles;
}

# Assert read-only snapshot before migrated
# Assert screen 'linux-login' with 200s
# Workaround known issue: bsc#980337
# In this case try to select tty1 with multi-times then select root console
sub boot_into_ro_snapshot {
    unlock_if_encrypted(check_typed_password => 1);
    if (!check_screen('linux-login', 200)) {
        record_soft_failure 'bsc#980337';
        for (1 .. 10) {
            check_var('VIRSH_VMM_FAMILY', 'hyperv') ? send_key 'alt-f1' : send_key 'ctrl-alt-f1';
            if (check_screen('tty1-selected', 12)) {
                return 1;
            }
            else {
                record_info('not in tty1', 'switch to tty1 failed', result => 'softfail');
            }
        }
        die "Boot into read-only snapshot failed over 5 minutes, considering a product issue";
    }
}

1;
