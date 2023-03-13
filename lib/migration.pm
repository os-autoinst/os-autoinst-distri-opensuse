# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package migration;

use base Exporter;
use Exporter;

use strict;
use warnings;

use testapi;
use Utils::Architectures;
use utils;
use zypper;
use registration;
use qam 'remove_test_repositories';
use version_utils qw(is_sle is_sles4sap is_leap_migration);

our @EXPORT = qw(
  setup_sle
  setup_migration
  register_system_in_textmode
  deregister_dropped_modules
  disable_installation_repos
  disable_kernel_multiversion
  record_disk_info
  check_rollback_system
  reset_consoles_tty
  set_scc_proxy_url
  set_zypp_single_rpmtrans
  remove_dropped_modules_packages
);

sub setup_sle {
    select_console 'root-console';

    # https://bugzilla.suse.com/show_bug.cgi?id=1205290#c3
    if (is_sle('<=12-SP5')) {
        systemctl('restart systemd-vconsole-setup.service');
    }

    # Stop packagekitd
    if (is_sle('12+')) {
        quit_packagekit;
    }
    else {
        assert_script_run "chmod 444 /usr/sbin/packagekitd";
    }

    # poo#87850 wait the zypper processes in background to finish and release the lock.
    wait_quit_zypper;
    # Change serial dev permissions
    ensure_serialdev_permissions;

    # Enable Y2DEBUG for error debugging
    enter_cmd "echo 'export Y2DEBUG=1' >> /etc/bash.bashrc.local";
    script_run("source /etc/bash.bashrc.local", die_on_timeout => 0);
    set_zypp_single_rpmtrans();
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
        enter_cmd "echo 'url: $u' > /etc/SUSEConnect";
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
    # To register the product and addons via commands, only for sle 12+
    if (get_var('ADDON_REGBYCMD') && is_sle('12+')) {
        register_product();
        register_addons_cmd();
    }
    else {
        yast_scc_registration(yast2_opts => '--ncurses');
    }
    # Once SCC registration is done, disable IN_PATCH_SLE so it does not interfere
    # with further calls to accept_addons_license (in upgrade for example)
    set_var('IN_PATCH_SLE', 0);
}

# Remove LTSS product and manually remove its relevant package before migration
# Also remove ltss from SCC_ADDONS setting for registration in upgrade target
# Besides LTSS, some modules will be dropped in the migration target product,
# need to remove these modules before migration, add the dropped modules to the
# setting of DROPPED_MODULES.
sub deregister_dropped_modules {
    return unless ((get_var('DROPPED_MODULES')) || (get_var('SCC_ADDONS', '') =~ /ltss/));

    my $droplist = get_var('DROPPED_MODULES', '');
    $droplist .= ',ltss' if (get_var('SCC_ADDONS', '') =~ /ltss/);
    my @all_addons = grep($_, split(/,/, get_var('SCC_ADDONS', '')));
    for my $name (grep($_, split(/,/, $droplist))) {
        record_info "deregister $name", "deregister $name module and remove it from SCC_ADDONS";
        if ($name eq 'ltss') {
            if (check_var('SLE_PRODUCT', 'hpc')) {
                remove_suseconnect_product('SLE_HPC-LTSS');
            } elsif ((is_sle('12+') && check_var('SLE_PRODUCT', 'sles')) || (check_var('SLE_PRODUCT', 'sles4sap'))) {
                remove_suseconnect_product('SLES-LTSS');    # sles4sap also uses SLES-LTSS as its ltss
            } else {
                zypper_call 'rm -t product SLES-LTSS';
                zypper_call 'rm sles-ltss-release-POOL';
            }
        }
        else {
            remove_suseconnect_product(get_addon_fullname($name));
        }
        # remove item from addons
        @all_addons = grep { $_ ne $name } @all_addons;
    }
    set_var('SCC_ADDONS', join(',', @all_addons));
}

# This function removes the packages specified with variable DROPPED_MODULES instead of un-registering the modules
# before migrating: it is enough to just remove the -release package to avoid warnings like "the module
# cannot be updated".
sub remove_dropped_modules_packages {
    my $droplist = get_var('DROPPED_MODULES', '');
    for my $name (split(/,/, $droplist)) {
        my $release_package = get_addon_fullname($name) . "-release";
        zypper_call("rm $release_package");
    }
}

# Disable installation repos before online migration
# s390x: use ftp remote repos as installation repos
# Other archs: use local DVDs as installation repos
# https://documentation.suse.com/sles/15-SP2/html/SLES-all/cha-upgrade-online.html#sec-upgrade-online-zypper
sub disable_installation_repos {
    if (is_s390x) {
        zypper_call "mr -d `zypper lr -u | awk '/ftp:.*?openqa.suse.de|10.160.0.207|10.160.0.100/ {print \$1}'`";
    }
    else {
        zypper_call "mr -d -l";
    }
}

# Based on bsc#1097111, need to disable kernel multiversion before migration, and enable it after migration
# https://documentation.suse.com/sles/15-SP3/html/SLES-all/cha-update-preparation.html#sec-update-preparation-multiversion
sub disable_kernel_multiversion {
    my $sed_para = check_var('VERSION', get_var('ORIGIN_SYSTEM_VERSION')) ? 's/^multiversion/#multiversion/g' : 's/^#multiversion/multiversion/g';
    script_run("sed -i $sed_para /etc/zypp/zypp.conf");
}

# Record disk info to help debug diskspace exhausted
# issue during upgrade
sub record_disk_info {
    my $out = script_output 'findmnt -n -o fstype /';
    if ($out =~ /btrfs/) {
        assert_script_run 'btrfs filesystem df / | tee /tmp/btrfs-filesystem-df.txt';
        assert_script_run 'btrfs filesystem usage / | tee /tmp/btrfs-filesystem-usage.txt';
        # we can use disable-used-space option to make 'snapper list' faster, if it has that option.
        assert_script_run("(snapper --help | grep -q -- --disable-used-space && snapper list --disable-used-space || snapper list) | tee /tmp/snapper-list.txt", 180) unless (is_sles4sap());

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
    # for leap to sle migration, we'll have SLE-$VERSION-Updates in the leap repo.
    if ($incorrect_repos) {
        record_info('Incorrect Repos', $incorrect_repos, result => 'fail') unless (is_leap_migration && $incorrect_repos eq 'SLE-' . get_var("VERSION") . '-Updates');
    }

    return unless is_sle;
    # Check SUSEConnect status for SLE
    # check rollback-helper service is enabled and worked properly
    # If rollback service is activating, need wait some time
    # Add wait in a loop, max time is 20 minute, because case with much more modules need more time
    for (1 .. 20) {
        last unless script_run('systemctl --no-pager status rollback') != 0;
        sleep 60;
    }
    systemctl('is-active rollback');

    # Verify registration status matches current system version
    # system is un-registered during media based upgrade
    unless (get_var('MEDIA_UPGRADE')) {
        my $py = (-e '/usr/bin/python3') ? 'python3' : 'python';
        assert_script_run('curl -s ' . data_url('console/check_registration_status.py') . ' | ' . $py);
    }
}

# Reset tty for x11 and root consoles
sub reset_consoles_tty {
    console('x11')->set_tty(get_x11_console_tty);
    console('root-console')->set_tty(get_root_console_tty);
    reset_consoles;
}

# Register the already installed system on a specific SCC server/proxy if needed
sub set_scc_proxy_url {
    if (my $u = get_var('SCC_PROXY_URL')) {
        enter_cmd "echo 'url: $u' > /etc/SUSEConnect";
    }
    save_screenshot;
}

=head2 set_zypp_single_rpmtrans
    set_zypp_single_rpmtrans();

This function is used for adding ZYPP_SINGLE_RPMTRANS
if the test case has ZYPP_SINGLE_RPMTRANS setting. this
feature will enhance the zypper performance.

jira feature https://jira.suse.com/browse/SLE-21973
zypper single transaction performance enhancement (RFE)

=cut

sub set_zypp_single_rpmtrans {

    assert_script_run 'export ZYPP_SINGLE_RPMTRANS=1 ' if get_var('ZYPP_SINGLE_RPMTRANS');

}

1;
