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

our @EXPORT = qw (
  is_caasp
  is_hyperv
  is_hyperv_in_gui
  is_gnome_next
  is_jeos
  is_krypton_argon
  is_leap
  is_opensuse
  is_sle
  is_staging
  is_sles4sap
  is_sles4sap_standard
  is_tumbleweed
  is_storage_ng
  is_upgrade
  is_sle12_hdd_in_upgrade
  is_installcheck
  is_rescuesystem
  sle_version_at_least
  is_desktop_installed
  is_system_upgrading
  is_pre_15
  is_virtualization_server
);

sub is_leap;

sub is_jeos {
    return get_var('FLAVOR', '') =~ /^JeOS/;
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

# Works only for versions comparable by string (not leap 42.X)
# Query format: [= > < >= <=] version [+] (Example: <=12-sp3 =12-sp1 <4.0 >=15 3.0+)
# Regex format: matches version number (Example: /\d{2}\.\d/)
sub check_version {
    my $query = shift;
    my $regex = shift;

    # Matches operator($op), version($qv), plus($plus) - regex101.com to debug ;)
    if (uc($query) =~ /^(?(?!.*\+$)(?<op>[<>=]|[<>]=))(?<qv>$regex)(?<plus>\+)?$/) {
        my $pv = uc get_var('VERSION');
        my $qv = $+{qv};
        # Hacks for staging and HG2G
        if (is_leap) {
            $qv =~ s/^42/14/;
            $pv =~ s/^42/14/;
            $pv =~ s/:(Core|S)[:\w]*//i;
        }
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
    return 0 unless get_var('DISTRI') =~ /casp|caasp|kubic/;
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
        return check_version($filter, qr/\d\.\d/);
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

    # Leap and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 0 unless get_var('VERSION', '') =~ /^\d{2,}\.\d/;
    return 1 unless $query;

    # Version check
    return check_version($query, qr/\d{2,}\.\d/);
}

sub is_opensuse {
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1;
}

# Check if distribution is SLE with optional filter for:
# Version: <=12-sp3 =12-sp1 >11-sp1 >=15 15+ (>=15 and 15+ are equivalent)
sub is_sle {
    my $query = shift;

    return 0 unless check_var('DISTRI', 'sle');
    return 1 unless $query;

    # Version check
    return check_version($query, qr/\d{2}(?:-sp\d)?/i);
}

sub is_sles4sap {
    return get_var('FLAVOR', '') =~ /SAP/ || check_var('SLE_PRODUCT', 'sles4sap');
}

sub is_sles4sap_standard {
    return is_sles4sap && check_var('SLES4SAP_MODE', 'sles');
}

sub is_staging {
    return get_var('STAGING');
}

sub is_storage_ng {
    return get_var('STORAGE_NG');
}

sub is_upgrade {
    return get_var('UPGRADE') || get_var('ONLINE_MIGRATION') || get_var('ZDUP') || get_var('AUTOUPGRADE');
}

sub is_sle12_hdd_in_upgrade {
    return is_upgrade && !sle_version_at_least('15', version_variable => 'HDDVERSION');
}

# =====================================
# Deprecated, please use is_sle instead
# =====================================
sub sle_version_at_least {
    my ($version, %args) = @_;
    my $version_variable = $args{version_variable} // 'VERSION';

    if ($version eq '12') {
        return !(
               check_var($version_variable, '11-SP1')
            or check_var($version_variable, '11-SP2')
            or check_var($version_variable, '11-SP3')
            or check_var($version_variable, '11-SP4'));
    }

    if ($version eq '12-SP1') {
        return sle_version_at_least('12', version_variable => $version_variable) && !check_var($version_variable, '12');
    }

    if ($version eq '12-SP2') {
        return sle_version_at_least('12-SP1', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP1');
    }

    if ($version eq '12-SP3') {
        return sle_version_at_least('12-SP2', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP2');
    }

    if ($version eq '12-SP4') {
        return sle_version_at_least('12-SP3', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP3');
    }

    if ($version eq '15') {
        return sle_version_at_least('12-SP4', version_variable => $version_variable)
          && !check_var($version_variable, '12-SP4');
    }
    if ($version eq '15-SP1') {
        return sle_version_at_least('15', version_variable => $version_variable)
          && !check_var($version_variable, '15');
    }
    die "unsupported SLE $version_variable $version in check";
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
