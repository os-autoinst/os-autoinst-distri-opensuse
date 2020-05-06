# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package klp;

use warnings;
use strict;

use Exporter 'import';

use testapi;
use utils;
use version_utils 'is_sle';

our @EXPORT = qw(
  install_klp_product is_klp_pkg find_installed_klp_pkg klp_pkg_eq
  verify_klp_pkg_installation
);

sub install_klp_product {
    my $arch    = get_required_var('ARCH');
    my $version = get_required_var('VERSION');
    my $release_override;
    my $lp_product;
    my $lp_module;
    if ($version eq '12') {
        $release_override = '-d';
    }
    if (!is_sle('>=12-SP3')) {
        $version = '12';
    }
    # SLE15 has different structure of modules and products than SLE12
    if (is_sle('15+')) {
        $lp_product = 'sle-module-live-patching';
        $lp_module  = 'SLE-Module-Live-Patching';
    }
    else {
        $lp_product = 'sle-live-patching';
        $lp_module  = 'SLE-Live-Patching';
    }

    #install kgraft product
    zypper_call("ar http://download.suse.de/ibs/SUSE/Products/$lp_module/$version/$arch/product/ kgraft-pool");
    zypper_call("ar $release_override http://download.suse.de/ibs/SUSE/Updates/$lp_module/$version/$arch/update/ kgraft-update");
    zypper_call("ref");
    zypper_call("in -l -t product $lp_product", exitcode => [0, 102, 103]);
    zypper_call("mr -e kgraft-update");
}

sub is_klp_pkg {
    my $pkg  = shift;
    my $base = qr/(?:kgraft-|kernel-live)patch/;

    if ($$pkg{name} =~ m/^${base}-\d+/) {
        if ($$pkg{name} =~ m/^${base}-(\d+_\d+_\d+-\d+_*\d*_*\d*)-([a-z][a-z0-9]*)$/) {
            my $kver    = $1;
            my $kflavor = $2;
            $kver =~ s/_/./g;
            return {
                name    => $$pkg{name},
                version => $$pkg{version},
                kver    => $kver,
                kflavor => $kflavor,
            };

        } else {
            die "Unexpected kernel livepatch package name format: \"$$pkg{name}\"";
        }
    }

    return undef;
}

sub klp_pkg_eq {
    my ($klp_pkg1, $klp_pkg2) = @_;

    return ($$klp_pkg1{name} eq $$klp_pkg2{name} &&
          $$klp_pkg1{version} eq $$klp_pkg2{version});
}

sub find_installed_klp_pkg {
    my ($kver, $kflavor) = @_;

    my $pkgs = zypper_search("-s -i -t package");
    my $klp_pkg;
    foreach my $pkg (@$pkgs) {
        my $cur_klp_pkg = is_klp_pkg($pkg);

        if ($cur_klp_pkg &&
            $$cur_klp_pkg{kver} eq $kver &&
            $$cur_klp_pkg{kflavor} eq $kflavor) {
            if ($klp_pkg && !klp_pkg_eq($klp_pkg, $cur_klp_pkg)) {
                die "Multiple live patch packages installed for kernel";
            }

            $klp_pkg = $cur_klp_pkg;
        }
    }

    return $klp_pkg;
}

sub _klp_pkg_get_kernel_modules {
    my $klp_pkg = shift;

    my @modules;
    my $output = script_output("rpm -ql '$$klp_pkg{name}-$$klp_pkg{version}'");
    for my $line (split /\n/, $output) {
        if ($line =~ /\.ko$/) {
            push @modules, $line;
        }
    }

    if (!@modules) {
        die "No kernel modules provided by \"$$klp_pkg{name}-$$klp_pkg{version}\"";
    }

    return \@modules;
}

sub klp_pkg_get_kernel_modules {
    my $klp_pkg = shift;

    if (!exists($$klp_pkg{kmods_cached})) {
        $$klp_pkg{kmods_cached} = _klp_pkg_get_kernel_modules($klp_pkg);
    }

    return $$klp_pkg{kmods_cached};
}

sub verify_initrd_for_klp_pkg {
    my $klp_pkg = shift;

    # Inspect that the target kernel's initrd has been repopulated
    # with all the required content, namely the livepatching dracut
    # module and all kernel modules provided by the given livepatch
    # package.
    my %req_kmods           = map { $_ => 0 } @{klp_pkg_get_kernel_modules($klp_pkg)};
    my $dracut_module_found = 0;

    my $initrd = "/boot/initrd-$$klp_pkg{kver}-$$klp_pkg{kflavor}";
    my $output = script_output("lsinitrd '$initrd'");
    for my $line (split /\n/, $output) {
        my @line = split(/\s/, $line);
        if (!@line) {
            next;
        }
        elsif (@line == 1 &&
            ($line[0] eq 'kernel-livepatch' ||
                $line[0] eq 'kgraft')) {
            $dracut_module_found = 1;
        }
        elsif ($line[$#line] =~ /\.ko$/) {
            my $kmod = "/$line[$#line]";
            if (exists($req_kmods{$kmod})) {
                $req_kmods{$kmod} = 1;
            }
        }
    }

    if (!$dracut_module_found) {
        die "Kernel live patch dracut module not found in \"$initrd\"";
    }

    while (my ($kmod, $found) = each(%req_kmods)) {
        if (!$found) {
            die "Kernel module \"$kmod\" not found in \"$initrd\"";
        }
    }
}

sub verify_klp_pkg_installation {
    my $klp_pkg = shift;
    verify_initrd_for_klp_pkg($klp_pkg);
}

1;
