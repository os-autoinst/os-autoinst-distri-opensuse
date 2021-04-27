# Copyright © 2016-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: zypper
# Summary: Patch SLE qcow2 images before migration (offline)
# Maintainer: Dumitru Gutu <dgutu@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_desktop_installed is_upgrade is_sles4sap);
use migration;
use registration;
use qam;
use Utils::Backends 'is_pvm';
use y2_base;


sub patching_sle {
    my ($self) = @_;

    # Save VIDEOMODE and SCC_REGISTER vars
    my $orig_videomode    = get_var('VIDEOMODE',    '');
    my $orig_scc_register = get_var('SCC_REGISTER', '');

    # Do not attempt to log into the desktop of a system installed with SLES4SAP
    # being prepared for upgrade, as it does not have an unprivileged user to test
    # with other than the SAP Administrator
    my $nologin = (get_var('HDDVERSION') and is_upgrade() and is_sles4sap());

    # Skip registration here since we use autoyast profile to register origin system on zVM
    if (!get_var('UPGRADE_ON_ZVM')) {
        # Set vars to make yast_scc_registration work in text mode
        set_var("VIDEOMODE",    'text');
        set_var("SCC_REGISTER", 'console');
        # remember we perform registration on pre-created HDD images
        if (is_sle('12-SP2+')) {
            set_var('HDD_SP2ORLATER', 1);
        }
        disable_installation_repos;
        # Set SCC_PROXY_URL if needed
        set_scc_proxy_url if ((check_var('HDDVERSION', get_var('ORIGINAL_TARGET_VERSION')) && is_upgrade()));
        sle_register("register");
        zypper_call('lr -d');
    }

    # add test repositories and logs the required patches
    add_test_repositories();

    # Default to fully update unless MINIMAL_UPDATE is set
    if (get_var('MINIMAL_UPDATE')) {
        minimal_patch_system();
    }
    else {
        fully_patch_system();
        # Update origin system on zVM that is controlled by autoyast profile and reboot is done by end of autoyast installation
        # So we skip reboot here after fully patched on zVM to reduce times of reconnection to s390x
        if (!get_var('UPGRADE_ON_ZVM')) {
            # Perform sync ahead of reboot to flush filesystem buffers
            assert_script_run 'sync', 600;
            # Open gdm debug info for poo#45236, this issue happen sometimes in openqa env
            script_run('sed -i s/#Enable=true/Enable=true/g /etc/gdm/custom.conf');
            # Remove '-f' for reboot for poo#65226
            enter_cmd "reboot";
            reconnect_mgmt_console if is_pvm;
            $self->wait_boot(textmode => !is_desktop_installed(), ready_time => 600, bootloader_time => 300, nologin => $nologin);
            # Setup again after reboot
            $self->setup_sle();
        }
    }

    # Install extra patterns as required
    install_patterns() if (get_var('PATTERNS'));

    # Install extra packages as required
    install_packages() if (get_var('PACKAGES'));

    # Install salt packages as required
    install_salt_packages() if (check_var_array('SCC_ADDONS', 'asmm'));

    # create btrfs subvolume for aarch64
    create_btrfs_subvolume() if (check_var('ARCH', 'aarch64'));

    # Remove test repos after system being patched
    remove_test_repositories;

    #migration with LTSS is not possible, remove it before upgrade
    remove_ltss;

    #migration with ESPOS is not possible, remove it before upgrade
    remove_espos;
    if (get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/ || get_var('KEEP_REGISTERED')) {
        # The system is registered.
        set_var('HDD_SCC_REGISTERED', 1);
        # SKIP the module installation window, from the add_update_test_repo test
        set_var('SKIP_INSTALLER_SCREEN', 1) if get_var('MAINT_TEST_REPO');

    }
    else {
        sle_register("unregister");
    }

    # Restore the old value of VIDEOMODE and SCC_REGISTER
    # For example, in case of SLE 12 offline migration tests with smt pattern
    # or modules, we need set SCC_REGISTER=installation at test suite settings
    # to trigger scc registration during offline migration
    set_var("VIDEOMODE",    $orig_videomode);
    set_var("SCC_REGISTER", $orig_scc_register);

    # Record the installed rpm list
    assert_script_run 'rpm -qa > /tmp/rpm-qa.txt';
    upload_logs '/tmp/rpm-qa.txt';

    # mark system patched
    set_var("SYSTEM_PATCHED", 1);
}


# Install extra packages if var PACKAGES is set
sub install_packages {
    my @pk_list = split(/,/, get_var('PACKAGES'));
    for my $pk (@pk_list) {
        # removed package if starting with -
        if ($pk =~ /^-/) {
            $pk =~ s/^-//;
            zypper_call "rm -t package $pk";
        }
        else {
            zypper_call "in -t package $pk";
        }
    }
}

# Install packages salt-master salt-minion before migration, to ensure salt
# regression test work well even the asmm is disabled after migration.
sub install_salt_packages {
    zypper_call('in -t package salt-master salt-minion');
}

sub sle_register {
    my ($action) = @_;
    # Register sle before update
    # SLE 12 and later use SCC, but SLE 11 uses NCC
    if ($action eq 'register') {
        if (is_sle('12+')) {
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
                yast_scc_registration();
            }
            # Once SCC registration is done, disable IN_PATCH_SLE so it does not interfere
            # with further calls to accept_addons_license (in upgrade for example)
            set_var('IN_PATCH_SLE', 0);
        }
        else {
            # Erase all local files created from a previous executed registration
            assert_script_run("sed -i '/^url[[:space:]]*/s|.*|url = https://scc.suse.com/ncc/center/regsvc|' /etc/suseRegister.conf") if (get_var('SLE11_USE_SCC'));
            assert_script_run('suse_register -E');
            # Register SLE 11 to SMT server
            my $smt_url = get_var('SMT_URL', '');
            if ($smt_url) {
                my $setup_script = 'clientSetup4SMT.sh';
                assert_script_run("wget $smt_url/repo/tools/$setup_script" =~ s/https/http/r);
                assert_script_run("chmod +x $setup_script");
                assert_script_run("echo y | ./$setup_script $smt_url/center/regsvc");
                assert_script_run("suse_register -n");
            }
            # NCC can be replaced by SCC even for SLE 11
            # Needed to workaround a bug with NCC and LTSS module in some cases, see bsc#1158950
            elsif (get_var('SLE11_USE_SCC')) {
                my $reg_code = get_required_var('NCC_REGCODE');
                my $reg_mail = get_var('NCC_MAIL');               # email address is not mandatory for SCC
                if (get_var('NCC_REGCODE_SDK')) {
                    my $reg_code_sdk = get_required_var('NCC_REGCODE_SDK');
                    zypper_call("ar http://schnell.suse.de/SLE11/SLE-11-SP4-SDK-GM/s390x/DVD1/ sdk");
                    zypper_call("in --auto-agree-with-licenses sle-sdk-release");
                    assert_script_run("suse_register -a email=$reg_mail -a regcode-sles=$reg_code -a regcode-sdk=$reg_code_sdk", 300);
                } else {
                    assert_script_run("suse_register -a email=$reg_mail -a regcode-sles=$reg_code", 300);
                }
            }
            # Otherwise, register SLE 11 to NCC server
            else {
                my $reg_code = get_required_var("NCC_REGCODE");
                my $reg_mail = get_required_var("NCC_MAIL");
                assert_script_run("suse_register -n -a email=$reg_mail -a regcode-sles=$reg_code", 300);
            }
        }
    }
    # Unregister sle after update
    if ($action eq 'unregister') {
        if (is_sle('12+')) {
            scc_deregistration;
        }
        else {
            assert_script_run('suse_register -E');
        }
    }
}


sub run {
    my ($self) = @_;

    $self->setup_sle();
    $self->patching_sle();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    y2_base::save_upload_y2logs;
}
1;
