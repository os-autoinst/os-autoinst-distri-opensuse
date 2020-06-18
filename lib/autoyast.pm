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
use File::Copy 'copy';
use File::Path 'make_path';
use LWP::Simple 'head';

use xml_utils;

our @EXPORT = qw(
  detect_profile_directory
  expand_template
  expand_version
  adjust_network_conf
  expand_variables
  upload_profile
  inject_registration
  init_autoyast_profile
  test_ayp_url
  validate_autoyast_profile
);

=head2 expand_patterns

 expand_patterns();

Expand patterns for sle12 and sle15.
Returns a list of patterns to be installed.

=cut
sub expand_patterns {
    if (get_var('PATTERNS', '') =~ m/^\s*$/) {
        if (is_sle('15+')) {
            my @sle15;
            push @sle15, qw(base minimal_base enhanced_base apparmor sw_management yast2_basis);
            push @sle15, qw(x11 gnome_basic fonts) if check_var('DESKTOP', 'gnome');
            push @sle15, qw(gnome gnome_x11 office x11_enhanced gnome_imaging gnome_multimedia x11_yast) if check_var('SLE_PRODUCT', 'sled') || get_var('SCC_ADDONS') =~ m/we/;
            return [@sle15];
        }
        elsif (is_sle('12+') && check_var('SLE_PRODUCT', 'sles')) {
            my @sle12;
            push @sle12, qw(Minimal apparmor base documentation 32bit)                 if check_var('DESKTOP', 'textmode');
            push @sle12, qw(Minimal apparmor base x11 documentation gnome-basic 32bit) if check_var('DESKTOP', 'gnome');
            push @sle12, qw(desktop-base desktop-gnome) if get_var('SCC_ADDONS') =~ m/we/;
            push @sle12, qw(yast2)                      if is_sle('>=12-sp3');
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
                push @all, qw(oracle_server)        unless check_var('ARCH', 'aarch64');
            }
            push @all, qw(devel_basis devel_kernel devel_yast) if
              get_var('SCC_ADDONS') =~ m/sdk/;
            push @all, qw(gnome gnome_x11 gnome_multimedia gnome_imaging office
              technical_writing books) if get_var('SCC_ADDONS') =~ m/we/;
            push @all, qw(gnome_basic)               if get_var('SCC_ADDONS') =~ m/desktop/;
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
    my @addons = grep { defined $_ && $_ } split(/,/, get_var('SCC_ADDONS', ''));
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
        repos    => [split(/,/, get_var('MAINT_TEST_REPO', ''))],
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

=head2 validate_autoyast_profile

  validate_autoyast_profile($profile);

Validate AutoYaST profile traversing yaml test data
$profile is the root node in the test data

Expected yaml data should mimic structure of xml file for AutoYaST profile,
so hashes and arrays in the yaml should represent nodes in the xml file.

In case of list in xml, yaml structure should be represented as an array,
so it would be able to generate expression to check that element on the list met expectations.
If a hash is used instead, it will validate its inner value but it will not check size of the list.

To identify an element in a list (as they are not ordered) on xml via xpath it has been added
an special field in yaml named 'unique_key' which value is the name of the selected property
to search the element on the list. When that property is not a direct child
(in other words, it is not at the same level in the yaml)
it should be specify in yaml 'unique_value' to specify the value expected for that inner/nested property
(it is verbose but avoid to search every time in the whole yaml tree).
For instance:

- drive:
    unique_key: mount
    unique_value: /
    ...
        partitions:
            - partition:
                unique_key: label
                ...
                label: root_multi_btrfs
                mount: /

In the example, the tester chose 'mount' node/value to distinguish this 'drive'
from other 'drive' nodes in the xml. In order to distinguish that particular 'partition' node
only 'unique_key' was required because label is a direct child of 'partition' node in the xml.

Finally, creates a report at the end with errors (both yaml and execution errors)
and overall expressions executed.

=cut
sub validate_autoyast_profile {
    my $profile = shift;

    my $xpc         = get_xpc(init_autoyast_profile());    # get XPathContext
    my $expressions = [];
    my $errors      = [];
    generate_expressions(node => $profile, exp => "/ns:profile",
        expressions => $expressions, errors => $errors);
    run_expressions(xpc => $xpc, expressions => $expressions, errors => $errors);
    my $report = create_report(errors => $errors, expressions => $expressions);
    record_info('Summary', $report);
    die "Found errors on validation of AutoYaST profile, please check Summary report" if @{$errors};
}

sub generate_expressions {
    my (%args) = @_;

    my $node        = $args{node};
    my $exp         = $args{exp};
    my $expressions = $args{expressions};
    my $errors      = $args{errors};

    if (ref $node eq 'HASH') {
        for my $k (keys %{$node}) {
            next if $k =~ /unique_key|unique_value/;
            if (!ref $node->{$k}) {
                push @{$expressions}, "$exp" . "/ns:$k" . "[text() = '$node->{$k}'" .
                  (($node->{$k} eq '') ? ' or not(text())]' : ']');    # node might not have text node descendant
            }
            else {
                generate_expressions(node => $node->{$k}, exp => "$exp/ns:$k",
                    expressions => $expressions, errors => $errors);
            }
        }
    }
    elsif (ref $node eq 'ARRAY') {
        my ($list_name) = keys %{$node->[0]};
        my $list_size = scalar @{$node};

        # add expression to check expected list size
        push @{$expressions}, "$exp" . "[count(ns:$list_name)=$list_size]";

        for my $item (@{$node}) {
            if (my $unique_exp = get_unique_exp(list_name => $list_name, item => $item,
                    exp => $exp, errors => $errors)) {
                push @{$expressions}, $unique_exp;
                generate_expressions(node => $item->{$list_name}, exp => $unique_exp,
                    expressions => $expressions, errors => $errors);
            }
        }
    }
}

# get unique expression for a list item
sub get_unique_exp {
    my (%args) = @_;

    my $list_name = $args{list_name};
    my $item      = $args{item};
    my $exp       = $args{exp};
    my $errors    = $args{errors};

    if (my $search_key = $item->{$list_name}->{unique_key}) {
        my $value = '';
        my $sep   = '';
        if ($value = $item->{$list_name}->{unique_value}) {
            $sep = './/'    # separator for any descendant
        }
        elsif ($value = $item->{$list_name}->{$search_key}) {
            $sep = './'     # separator for direct child
        }
        else {
            push @{$errors}, "YAML error: 'unique_key: $search_key' does not point to existing key in: '$item->{$list_name}'";
        }
        return "$exp/ns:$list_name" . "[$sep" . "ns:$search_key" . "[text()='$value']]";
    }
    else {
        push @{$errors}, "YAML error: 'unique_key' key not found on yaml list for '$list_name'";
    }
    return;
}

sub run_expressions {
    my (%args) = @_;

    my $xpc         = $args{xpc};
    my $expressions = $args{expressions};
    my $errors      = $args{errors};

    my @nodes = ();
    for my $exp (@{$expressions}) {
        @nodes = $xpc->findnodes($exp);
        if (scalar @nodes == 0) {
            push @{$errors}, "XPATH error: no node found as a result of expression: $exp";
        }
        elsif (scalar @nodes > 1) {
            push @{$errors}, "XPATH error: more than one node found as a result of expression: $exp";
        }
    }
}

sub create_report {
    my %args = @_;

    my $expressions         = $args{expressions};
    my $errors              = $args{errors};
    my $error_summary       = @{$errors} ? "Errors found:\n" . join("\n", @{$errors}) : "Errors found:\nnone";
    my $expressions_summary = "Expressions executed:\n" . join("\n", @{$expressions});
    return "$error_summary\n\n$expressions_summary\n";
}

=head2 detect_profile_directory

 detect_profile_directory(profile => $profile, path => $path)

 Try to detect profile directory (autoyast_opensuse/, autoyast_sle{12,15}/, autoyast_sles11/)
 and returns its path.
 TODO: autoyast_{caasp,kvm,qam,xen}

 $profile is the autoyast profile 'autoinst.xml'.
 $path is AutoYaST profile path

=cut
sub detect_profile_directory {
    my (%args)  = @_;
    my $profile = $args{profile};
    my $path    = $args{path};

    my $dir    = "autoyast_";
    my $regexp = $dir . '\E[^/]+\/';

    if (!$profile && $path !~ /\Q$regexp/) {
        my $distri = get_required_var('DISTRI');
        if (is_sle) {
            $distri .= "s" if is_sle('<12');    # sles11
            my $major_version = get_required_var('VERSION');
            $major_version =~ s/-SP.*//;
            $distri .= $major_version;
        }
        $path = "$dir${distri}/$path";
        record_info('INFO', "Trying to use path with detected folder: '$path'");
    }
    return $path;
}

=head2 expand_version

 expand_version($profile);

 Expand VERSION, as e.g. 15-SP1 has to be mapped to 15.1

 $profile is the autoyast profile 'autoinst.xml'.

=cut
sub expand_version {
    my ($profile) = @_;
    if (my $version = scc_version(get_var('VERSION', ''))) {
        $profile =~ s/\{\{VERSION\}\}/$version/g;
    }
    return $profile;
}

=head2 adjust_network_conf

 adjust_network_conf($profile);

 For s390x and svirt backends need to adjust network configuration

 $profile is the autoyast profile 'autoinst.xml'.

=cut
sub adjust_network_conf {
    my ($profile) = @_;
    my $hostip;
    if (check_var('BACKEND', 's390x')) {
        ($hostip) = get_var('S390_NETWORK_PARAMS') =~ /HostIP=(.*?)\//;
    }
    elsif (check_var('BACKEND', 'svirt')) {
        $hostip = get_var('VIRSH_GUEST');
    }
    $profile =~ s/\{\{HostIP\}\}/$hostip/g if $hostip;
    return $profile;
}


=head2 expand_variables

 expand_variables($profile);

 Expand variables from job settings which do not require further processing

 $profile is the autoyast profile 'autoinst.xml'.

=cut
sub expand_variables {
    my ($profile) = @_;
    # Expand other variables
    my @vars = qw(SCC_REGCODE SCC_REGCODE_HA SCC_REGCODE_GEO SCC_REGCODE_HPC SCC_REGCODE_WE SCC_URL ARCH LOADER_TYPE NTP_SERVER_ADDRESS);
    # Push more variables to expand from the job setting
    my @extra_vars = push @vars, split(/,/, get_var('AY_EXPAND_VARS', ''));
    if (get_var 'SALT_FORMULAS_PATH') {
        my $tarfile = data_url(get_var 'SALT_FORMULAS_PATH');
        $profile =~ s/\{\{SALT_FORMULAS_PATH\}\}/$tarfile/g;
    }
    for my $var (@vars) {
        # Skip if value is not defined
        next unless my ($value) = get_var($var);
        $profile =~ s/\{\{$var\}\}/$value/g;
    }
    return $profile;
}

=head2 upload_profile

 upload_profile(profile => $profile, path => $path)

 Upload modified profile
 Update url
 Update path
 Make available profile in job logs

 $profile is the AutoYaST profile 'autoinst.xml'.
 $path is AutoYaST profile path

=cut
sub upload_profile {
    my (%args)  = @_;
    my $profile = $args{profile};
    my $path    = $args{path};

    if (check_var('IPXE', '1')) {
        $path = get_required_var('SUT_IP') . $path;
    }
    save_tmp_file($path, $profile);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    copy(hashed_string($path), 'ulogs/autoyast_profile.xml');
    # Set AUTOYAST variable with new url
    my $url = autoinst_url . "/files/$path";
    set_var('AUTOYAST', $url);
}

=head2 inject_registration

 inject_registration($profile);

 $profile is the autoyast profile 'autoinst.xml'.

=cut
sub inject_registration {
    my ($profile) = @_;

    # Create registration block
    my $suse_register = <<"EOF";
  <suse_register>
    <do_registration config:type="boolean">true</do_registration>
    <email/>
    <reg_code>{{SCC_REGCODE}}</reg_code>
    <install_updates config:type="boolean">true</install_updates>
    <reg_server>{{SCC_URL}}</reg_server>
  </suse_register>
EOF
    # Inject registration block
    $profile =~ s/(?<profile><profile.*>\s)/$+{profile}$suse_register/g;
    record_info('inject reg', "Registration block was added to AutoYaST profile");
    return $profile;
}

=head2 test_ayp_url

 test_ayp_url();

 Test if the autoyast profile url is reachable, before the autoyast installation begins.

=cut
sub test_ayp_url {
    my $ayp_url = get_var('AUTOYAST');
    if ($ayp_url =~ /^http/) {
        if (head($ayp_url)) {
            record_info("ayp url ok", "Autoyast profile url $ayp_url is reachable");
        } else {
            record_info("Failure", "Autoyast profile url $ayp_url is unreachable");
        }
    }
}
1;
