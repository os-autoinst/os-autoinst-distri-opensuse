=head1 autoyast

Provide translations for autoyast XML file

=cut
# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Provide translations for autoyast XML file
# Maintainer: Jan Baier <jbaier@suse.cz>

package autoyast;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use version_utils 'is_sle';
use registration qw(scc_version get_addon_fullname);

our @EXPORT = qw(expand_template init_autoyast_profile);

=head2 expand_patterns

 expand_patterns();

Expand patterns for sle12 and sle15.
Returns a list of patterns to be installed.

=cut
sub expand_patterns {
    if (get_var('PATTERNS') =~ m/^\s*$/) {
        if (is_sle('15+')) {
            my @sle15;
            push @sle15, qw(base minimal_base enhanced_base apparmor sw_management yast2_basis);
            push @sle15, qw(x11 gnome_basic fonts) if check_var('DESKTOP', 'gnome');
            push @sle15, qw(gnome gnome_x11 office x11_enhanced gnome_imaging gnome_multimedia x11_yast) if check_var('SLE_PRODUCT', 'sled') || get_var('SCC_ADDONS') =~ m/we/;
            return [@sle15];
        }
        elsif (is_sle('12+') && check_var('SLE_PRODUCT', 'sles')) {
            my @sle12;
            push @sle12, qw(Minimal apparmor base documentation 32bit) if check_var('DESKTOP', 'textmode');
            push @sle12, qw(Minimal apparmor base x11 documentation gnome-basic 32bit) if check_var('DESKTOP', 'gnome');
            push @sle12, qw(desktop-base desktop-gnome) if get_var('SCC_ADDONS') =~ m/we/;
            push @sle12, qw(yast2) if is_sle('>=12-sp3');
            return [@sle12];
        }
        # SLED12 has different patterns
        else {
            my @sled12;
            push @sled12, qw(Minimal apparmor desktop-base documentation 32bit);
            push @sled12, qw(gnome-basic desktop-gnome x11) if check_var('DESKTOP', 'gnome');
            return [@sled12];
        }
    }
    if (check_var('PATTERNS', 'all')) {
        my @all;
        if (is_sle('15+')) {
            if (get_var('SCC_ADDONS') =~ m/base/) {
                push @all, qw(base minimal_base enhanced_base documentation
                  apparmor x11 x11_enhanced yast2_basis sw_management fonts);
                push @all, qw(32bit) unless check_var('ARCH', 's390x');
            }
            if (get_var('SCC_ADDONS') =~ m/serverapp/) {
                push @all, qw(kvm_tools file_server mail_server gnome_basic
                  lamp_server gateway_server dhcp_dns_server directory_server
                  kvm_server fips sap_server ofed);
                push @all, qw(xen_server xen_tools) unless check_var('ARCH', 's390x') || check_var('ARCH', 'aarch64');
                push @all, qw(oracle_server) unless check_var('ARCH', 'aarch64');
            }
            push @all, qw(devel_basis devel_kernel devel_yast) if
              get_var('SCC_ADDONS') =~ m/sdk/;
            push @all, qw(gnome gnome_x11 gnome_multimedia gnome_imaging office
              technical_writing books) if get_var('SCC_ADDONS') =~ m/we/;
            push @all, qw(gnome_basic) if get_var('SCC_ADDONS') =~ m/desktop/;
            push @all, qw(multimedia laptop imaging) if get_var('SCC_ADDONS') =~ m/desktop/ && check_var('SLE_PRODUCT', 'sled');
        }
        elsif (is_sle('12+')) {
            push @all, qw(Minimal documentation 32bit apparmor x11 WBEM
              Basis-Devel laptop gnome-basic);
            push @all, qw(yast2 smt) if
              is_sle('12-sp3+') && check_var('SLE_PRODUCT', 'sles');
            push @all, qw(base xen_tools kvm_tools file_server mail_server
              gnome-basic lamp_server gateway_server dhcp_dns_server
              directory_server kvm_server xen_server fips sap_server
              oracle_server ofed printing) if
              check_var('SLE_PRODUCT', 'sles');
            push @all, qw(default desktop-base desktop-gnome fonts
              desktop-gnome-devel desktop-gnome-laptop kernel-devel) if
              check_var('SLE_PRODUCT', 'sled') || get_var('SCC_ADDONS') =~ m/we/;
            push @all, qw(virtualization_client) if check_var('SLE_PRODUCT', 'sled');
            # SLED12 - > bsc#1117335
            push @all, qw(SDK-C-C++ SDK-Certification SDK-Doc SDK-YaST) if
              (get_var('SCC_ADDONS') =~ m/sdk/ && check_var('SLE_PRODUCT', 'sles'));
        }
        return [@all];
    }
    return [split(/,/, get_var('PATTERNS') =~ s/\bminimal\b/minimal_base/r)] if is_sle('15+');
    return [split(/,/, get_var('PATTERNS') =~ s/\bminimal\b/Minimal/r)];
}

my @unversioned_products = qw(asmm contm lgm tcm wsm);

=head2 get_product_version

 get_product_version();

Return product version from SCC and product name, so-called unversioned products like asmm, contm, lgm, tcm, wsm if product version number lower than 15

=cut
sub get_product_version {
    my ($name) = @_;
    my $version = scc_version(get_var('VERSION', ''));
    return $version =~ s/^(\d*)\.\d$/$1/r if is_sle('<15') && grep(/^$name$/, @unversioned_products);
    return $version;
}

=head2 expand_addons

 expand_addons();

Returns hash of all C<SCC_ADDONS> with name, version and architecture.
=cut
sub expand_addons {
    my %addons;
    my @addons = grep { defined $_ && $_ } split(/,/, get_var('SCC_ADDONS'));
    foreach my $addon (@addons) {
        $addons{$addon} = {
            name    => get_addon_fullname($addon),
            version => get_product_version($addon),
            arch    => get_var('ARCH'),
        };
    }
    return \%addons;
}

=head2 expand_template

 expand_template($profile);

Expand and returns template including autoyast profile and it's varialbes like addons, repos, patterns, get_var

$profile is the autoyast profile 'autoinst.xml'.

=cut
sub expand_template {
    my ($profile) = @_;
    my $template  = Mojo::Template->new(vars => 1);
    my $vars      = {
        addons   => expand_addons,
        repos    => [split(/,/, get_var('MAINT_TEST_REPO'))],
        patterns => expand_patterns,
        # pass reference to get_required_var function to be able to fetch other variables
        get_var => \&get_required_var,
        # pass reference to check_var
        check_var => \&check_var
    };
    my $output = $template->render($profile, $vars);
    return $output;
}

=head2 init_autoyast_profile

 init_autoyast_profile();

Initialize or create a new autoyast profile by 'yast2 clone_system' if doesn't exist and returns the path of autoyast profile

=cut
sub init_autoyast_profile {
    select_console('root-console');
    my $profile_path = '/root/autoinst.xml';
    # Generate profile if doesn't exist
    if (script_run("[ -e $profile_path ]")) {
        my $module_name = y2_module_consoletest::yast2_console_exec(yast2_module => 'clone_system');
        wait_serial("$module_name-0", 60) || die "'yast2 clone_system' exited with non-zero code";
    }
    return script_output("cat $profile_path");
}

1;
