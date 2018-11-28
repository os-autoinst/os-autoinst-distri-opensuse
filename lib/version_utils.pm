# Copyright © 2017-2018 SUSE LLC
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

package version_utils;

use base Exporter;
use Exporter;
use strict;
use testapi qw(check_var get_var set_var);
use version 'is_lax';

use constant {
    VERSION => [
        qw(
          is_sle
          is_pre_15
          is_caasp
          is_gnome_next
          is_jeos
          is_krypton_argon
          is_leap
          is_opensuse
          is_tumbleweed
          is_rescuesystem
          is_sles4sap
          is_sles4sap_standard
          is_released
          is_rt
          is_staging
          is_storage_ng
          is_using_system_role
          is_using_system_role_first_flow
          requires_role_selection
          )
    ],
    BACKEND => [
        qw(
          is_vmware
          is_hyperv
          is_hyperv_in_gui
          is_aarch64_uefi_boot_hdd
          is_svirt_except_s390x
          )
    ],
    SCENARIO => [
        qw(
          install_this_version
          install_to_other_at_least
          is_upgrade
          is_sle12_hdd_in_upgrade
          is_installcheck
          is_desktop_installed
          is_system_upgrading
          is_virtualization_server
          is_server
          is_s390x
          is_livecd
          is_x86_64
          has_product_selection
          has_license_on_welcome_screen
          )
      ]
};

our @EXPORT = (@{(+VERSION)}, @{(+SCENARIO)}, @{+BACKEND});

our %EXPORT_TAGS = (
    VERSION  => (VERSION),
    BACKEND  => (BACKEND),
    SCENARIO => (SCENARIO)
);

sub is_leap;

sub is_jeos {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

sub is_vmware {
    return check_var('VIRSH_VMM_FAMILY', 'vmware');
}

sub is_hyperv {
    return check_var('VIRSH_VMM_FAMILY', 'hyperv');
}

sub is_hyperv_in_gui {
    return is_hyperv && !check_var('VIDEOMODE', 'text');
}

sub is_krypton_argon {
    return get_var('FLAVOR', '') =~ /(Krypton|Argon)/;
}

sub is_gnome_next {
    return get_var('FLAVOR', '') =~ /Gnome-Live/;
}

sub is_installcheck {
    return get_var('INSTALLCHECK');
}

sub is_rescuesystem {
    return get_var('RESCUESYSTEM');
}

sub is_virtualization_server {
    return get_var('SYSTEM_ROLE', '') =~ /(kvm|xen)/;
}

sub is_livecd {
    return get_var("LIVECD");
}

# Usage: check_version('>15.0', get_var('VERSION'), '\d{2}')
# Query format: [= > < >= <=] version [+] (Example: <=12-sp3 =12-sp1 <4.0 >=15 3.0+)
# Check agains: product version to check against - probably get_var('VERSION')
# Regex format: checks query version format (Example: /\d{2}\.\d/)
sub check_version {
    my $query = lc shift;
    my $pv    = lc shift;
    my $regex = shift // qr/[^<>=+]+/;

    # Matches operator($op), version($qv), plus($plus) - regex101.com to debug ;)
    if ($query =~ /^(?(?!.*\+$)(?<op>[<>=]|[<>]=))(?<qv>$regex)(?<plus>\+)?$/i) {
        my $qv = $+{qv} or die "Query $query not matching required format $regex";

        # Compare versions if they can be parsed
        if (is_lax($pv) && is_lax($qv)) {
            $pv = version->declare($pv);
            $qv = version->declare($qv);
        }
        return $pv ge $qv if $+{plus} || $+{op} eq '>=';
        return $pv le $qv if $+{op} eq '<=';
        return $pv gt $qv if $+{op} eq '>';
        return $pv lt $qv if $+{op} eq '<';
        return $pv eq $qv if $+{op} eq '=';
    }
    # Version should be matched and processed by now
    die "Unsupported version parameter: $query";
}

# Check if distribution is CaaSP or Kubic with optional filter:
# Media type: DVD (iso) or VMX (all disk images)
# Version: 1.0 | 2.0 | 2.0+
# Flavor: DVD | MS-HyperV | XEN | KVM-and-Xen | ..
sub is_caasp {
    my $filter = shift;
    return 0 unless get_var('DISTRI') =~ /caasp|kubic/;
    return 1 unless $filter;

    if ($filter eq 'DVD') {
        return get_var('FLAVOR') =~ /DVD/;    # DVD and Staging-?-DVD
    }
    elsif ($filter eq 'VMX') {
        return get_var('FLAVOR') !~ /DVD/;    # If not DVD it's VMX
    }
    elsif ($filter =~ /\d\.\d\+?$/) {
        # If we use '+' it means "this or newer", which includes tumbleweed
        return ($filter =~ /\+$/) if check_var('VERSION', 'Tumbleweed');
        return check_version($filter, get_var('VERSION'), qr/\d\.\d/);
    }
    elsif ($filter =~ /kubic|caasp/) {
        return check_var('DISTRI', $filter);
    }
    elsif ($filter eq 'qam') {
        return check_var('FLAVOR', 'CaaSP-DVD-Incidents') || get_var('LOCAL_QAM_DEVENV');
    }
    elsif ($filter eq 'local') {
        return get_var('LOCAL_DEVENV') || get_var('LOCAL_QAM_DEVENV');
    }
    elsif ($filter =~ /staging/) {
        return get_var('FLAVOR') =~ /Staging-.-DVD/;
    }
    else {
        return check_var('FLAVOR', $filter);    # Specific FLAVOR selector
    }
}

sub is_tumbleweed {
    # Tumbleweed and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1 if get_var('VERSION') =~ /Tumbleweed/;
    return get_var('VERSION') =~ /^Staging:/;
}

# Check if distribution is Leap with optional filter for:
# Version: <=42.2 =15.0 >15.0 >=42.3 15.0+
sub is_leap {
    my $query = shift;
    my $version = get_var('VERSION', '');

    # Leap and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 0 unless $version =~ /^\d{2,}\.\d/;
    return 1 unless $query;

    # Hacks for staging and HG2G :)
    $query =~ s/^([<>=]*)42/${1}14/;
    $version =~ s/^42/14/;
    $version =~ s/:(Core|S)[:\w]*//i;

    return check_version($query, $version, qr/\d{2,}\.\d/);
}

sub is_opensuse {
    return 1 if check_var('DISTRI', 'opensuse');
    return 1 if check_var('DISTRI', 'kubic');
    return 0;
}

# Check if distribution is SLE with optional filter for:
# Version: <=12-sp3 =12-sp1 >11-sp1 >=15 15+ (>=15 and 15+ are equivalent)
sub is_sle {
    my $query   = shift;
    my $version = shift // get_var('VERSION');

    return 0 unless check_var('DISTRI', 'sle');
    return 1 unless $query;

    # Version check
    return check_version($query, $version, qr/\d{2}(?:-sp\d)?/);
}

sub is_sles4sap {
    return get_var('FLAVOR', '') =~ /SAP/ || check_var('SLE_PRODUCT', 'sles4sap');
}

sub is_sles4sap_standard {
    return is_sles4sap && check_var('SLES4SAP_MODE', 'sles');
}

sub is_rt {
    return check_var('SLE_PRODUCT', 'rt');
}

sub is_released {
    return get_var('FLAVOR') =~ /Incidents/ || get_var('FLAVOR') =~ /Updates/;
}

sub is_staging {
    return get_var('STAGING');
}

sub is_storage_ng {
    return get_var('STORAGE_NG');
}

sub is_upgrade {
    return get_var('UPGRADE') || get_var('ONLINE_MIGRATION') || get_var('ZDUP') || get_var('AUTOUPGRADE') || get_var('LIVE_UPGRADE');
}

sub is_sle12_hdd_in_upgrade {
    return is_upgrade && is_sle('<15', get_var('HDDVERSION'));
}

sub is_desktop_installed {
    return get_var("DESKTOP") !~ /textmode|minimalx/;
}

sub is_system_upgrading {
    # If PATCH=1, make sure patch action is finished
    return is_upgrade && (!get_var('PATCH') || (get_var('PATCH') && get_var('SYSTEM_PATCHED')));
}

sub is_pre_15 {
    return (is_sle('<15') || is_leap('<15.0')) && !is_tumbleweed;
}

sub is_aarch64_uefi_boot_hdd {
    return get_var('MACHINE') =~ /aarch64/ && get_var('UEFI') && get_var('BOOT_HDD_IMAGE');
}

sub is_svirt_except_s390x {
    return !get_var('S390_ZKVM') && check_var('BACKEND', 'svirt');
}

sub is_s390x {
    return check_var('ARCH', 's390x');
}

sub is_x86_64 {
    return check_var('ARCH', 'x86_64');
}


sub is_server {
    return 1 if is_sles4sap();
    return 1 if get_var('FLAVOR', '') =~ /^Server/;
    # If unified installer, we need to check SLE_PRODUCT
    return 0 if get_var('FLAVOR', '') !~ /^Installer-/;
    return check_var('SLE_PRODUCT', 'sles');
}

sub install_this_version {
    return !check_var('INSTALL_TO_OTHERS', 1);
}

#Check the real version of the test machine is at least some value, rather than the VERSION variable
#It is for version checking for tests with variable "INSTALL_TO_OTHERS".
sub install_to_other_at_least {
    my $version = shift;

    if (!check_var("INSTALL_TO_OTHERS", "1")) {
        return 0;
    }

    #setup the var for real VERSION
    my $real_installed_version = get_var("REPO_0_TO_INSTALL");
    $real_installed_version =~ /.*SLES?-(\d+-SP\d+)-.*/m;
    $real_installed_version = $1;
    set_var("REAL_INSTALLED_VERSION", $real_installed_version);
    bmwqemu::save_vars();

    return is_sle(">=$version", $real_installed_version);
}

sub is_using_system_role {
    #system_role selection during installation was added as a new feature since sles12sp2
    #so system_role.pm should be loaded for all tests that actually install to versions over sles12sp2
    #no matter with or without INSTALL_TO_OTHERS tag
    # On SLE 15 SP0 we unconditionally have system roles screen
    # SLE 15 SP1:
    #   * Has system roles only if more than one is available, meaning either registered or with all packages DVD;
    #   * RT Product has only one (minimal) role.
    # On kubic, leap 15.1+, TW we have it instead of desktop selection screen
    return is_sle('>=12-SP2') && is_sle('<15')
      && check_var('ARCH', 'x86_64')
      && is_server()
      && (!is_sles4sap() || is_sles4sap_standard())
      && (install_this_version() || install_to_other_at_least('12-SP2'))
      || is_sle('=15')
      || (is_sle('>15') && (check_var('SCC_REGISTER', 'installation') || get_var('ADDONS') || get_var('ADDONURL')))
      || (is_opensuse && !is_leap('<15.1'))    # Also on leap 15.1, TW, Kubic
}

# On leap 15.0 we have desktop selection first, and everywhere, where we have system roles
sub is_using_system_role_first_flow {
    return is_leap('=15.0') || is_using_system_role;
}

# If there is only one role, there is no selection offered
sub requires_role_selection {
    return get_var('FLAVOR', '') !~ /Krypton/;
}

=head2 has_product_selection

    has_product_selection;

Identify cases when Installer has to show Product Selection screen.

Starting with SLE 15, all products are distributed using one medium, and Product
to install has to be chosen explicitly.

Though, there are some exceptions (like s390x) when there is only one Product,
so that License agreement is shown directly, skipping the Product selection step.
Also, Product Selection screen is not shown during upgrade.

Returns true (1) if Product Selection step has to be shown for the certain
configuration, otherwise returns false (0).

=cut

sub has_product_selection {
    return is_sle('15+') && !(is_s390x() || get_var('UPGRADE'));
}

=head2 has_license_on_welcome_screen

    has_license_on_welcome_screen;

Identify cases when License Agreement has to be shown on Welcome screen and should be accepted there.

Returns true (1) if License Agreement has to be shown on Welcome screen for the certain
configuration, otherwise returns false (0).

=cut

sub has_license_on_welcome_screen {
    return 1 if is_caasp('caasp');
    return get_var('HASLICENSE') && ((is_sle('15+') && is_s390x()) || is_sle('<15'));
}
