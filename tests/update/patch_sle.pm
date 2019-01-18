# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
        # disable existing repos temporary
        assert_script_run("zypper lr && zypper mr --disable --all");
        save_screenshot;
        sle_register("register");
        assert_script_run('zypper lr -d');
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
            # Workaround for test failed of the reboot operation need to wait some jobs done
            # Add '-f' to force the reboot to avoid the test be blocked here
            type_string "reboot -f\n";
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

    # Remove test repos after system being patched
    remove_test_repositories;

    #migration with LTSS is not possible, remove it before upgrade
    remove_ltss;
    if (get_var('FLAVOR', '') =~ /-(Updates|Incidents)$/ || get_var('KEEP_REGISTERED')) {
        # The system is registered.
        set_var('HDD_SCC_REGISTERED', 1);
        # SKIP the module installation window, from the add_update_test_repo test
        set_var('SKIP_INSTALLER_SCREEN', 1) if get_var('MAINT_TEST_REPO');

    }
    else {
        sle_register("unregister");
    }

    assert_script_run("zypper mr --enable --all");

    # Disable old repositories during AutoYaST driven upgrade
    if (get_var('AUTOUPGRADE')) {
        disable_installation_repos;
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

#   Function: parse the output from script_output to get the pattern list
#   Reason  : sometimes script_output with 'zypper pt -u' will cost a lot of time to return,
#   which cause the console have some system message in the output. we need filt out these
#   info before we process the result.
#   parameters:
#   $cmd   : the command line
#   $start : the line that start with $start, which is we want
#   return :  an array of pattern list
sub get_pattern_list {
    my ($cmd, $start) = @_;

    my $pkg_name;
    my @column   = ();
    my @pkg_list = ();
    my %seen     = ();
    my @unique   = ();

    my @pkg_lines = split(/\n/, script_output($cmd, 120));

    foreach my $line (@pkg_lines) {
        $line =~ s/^\s+|\s+$//g;
        # In a regular expression, all chars between the \Q and \E are escaped.
        next if ($line !~ m/^\Q$start\E/);
        # filter out the spaces in each filed
        @column = map { s/^\s*|\s*$//gr } split(/\|/, $line);
        # pkg_name is the 2nd field seperated by '|'
        $pkg_name = $column[1];
        push @pkg_list, $pkg_name;
    }

    if (@pkg_list) {
        # unique and sort the @pkg_list
        %seen   = map { $_ => 1 } @pkg_list;
        @unique = sort keys %seen;
    }

    return @unique;
}

# Install extra patterns if var PATTERNS is set
sub install_patterns {
    my $pcm = 0;
    my @pt_list;
    my @pt_list_un;
    my @pt_list_in;

    @pt_list_in = get_pattern_list "zypper pt -i", "i";
    # install all patterns from product.
    if (check_var('PATTERNS', 'all')) {
        @pt_list_un = get_pattern_list "zypper pt -u", "|";
    }
    # install certain pattern from parameter.
    else {
        @pt_list_un = split(/,/, get_var('PATTERNS'));
    }

    my %installed_pt = ();
    foreach (@pt_list_in) {
        $installed_pt{$_} = 1;
    }
    @pt_list = sort grep(!$installed_pt{$_}, @pt_list_un);
    $pcm     = grep /Amazon-Web-Services|Google-Cloud-Platform|Microsoft-Azure/, @pt_list_in;

    for my $pt (@pt_list) {
        # Cloud patterns are conflict by each other, only install cloud pattern from single vender.
        if ($pt =~ /Amazon-Web-Services|Google-Cloud-Platform|Microsoft-Azure/) {
            next unless $pcm == 0;
            $pt .= '*';
            $pcm = 1;
        }
        zypper_call "in -t pattern $pt";
    }
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
            yast_scc_registration();
            # Once SCC registration is done, disable IN_PATCH_SLE so it does not interfere
            # with further calls to accept_addons_license (in upgrade for example)
            set_var('IN_PATCH_SLE', 0);
        }
        else {
            # Erase all local files created from a previous executed registration
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

1;
