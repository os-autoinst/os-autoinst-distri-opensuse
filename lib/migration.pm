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
use qam qw/remove_test_repositories/;
use version_utils qw(sle_version_at_least is_sle);

our @EXPORT = qw(
  setup_sle
  setup_migration
  register_system_in_textmode
  remove_ltss
  disable_installation_repos
  record_disk_info
  check_rollback_system
  reset_consoles_tty
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
    if (sle_version_at_least('12-SP2', version_variable => 'HDDVERSION')) {
        set_var('HDD_SP2ORLATER', 1);
    }
    yast_scc_registration;
}

# Remove LTSS product and manually remove its relevant package before migration
sub remove_ltss {
    if (get_var('SCC_ADDONS', '') =~ /ltss/) {
        zypper_call 'rm -t product SLES-LTSS';
        zypper_call 'rm sles-ltss-release-POOL';
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
        assert_script_run 'snapper list | tee /tmp/snapper-list.txt';
        upload_logs '/tmp/btrfs-filesystem-df.txt';
        upload_logs '/tmp/btrfs-filesystem-usage.txt';
        upload_logs '/tmp/snapper-list.txt';
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
    # Wait some time if rollback is in activating state
    # Consider a bug if rollback service isn't done after that time
    script_run('for x in `seq 60`; do (systemctl --no-pager status rollback | grep -q activating) && sleep 5; done');
    systemctl('status rollback');
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

1;
# vim: sw=4 et
