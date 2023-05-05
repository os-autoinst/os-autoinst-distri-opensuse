=head1 autoyast

Provide translations for autoyast XML file

=cut
# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provide translations for autoyast XML file
# Maintainer: Jan Baier <jbaier@suse.cz>

package autoyast;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use Utils::Backends;
use Utils::Architectures;
use version_utils 'is_sle';
use registration qw(scc_version get_addon_fullname);
use File::Copy 'copy';
use File::Find qw(finddepth);
use File::Path 'make_path';
use LWP::Simple 'head';
use Socket;

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
  get_test_data_files
  prepare_ay_file
  generate_xml
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
            push @sle12, qw(Minimal apparmor base documentation) if check_var('DESKTOP', 'textmode');
            push @sle12, qw(Minimal apparmor base x11 documentation gnome-basic) if check_var('DESKTOP', 'gnome');
            push @sle12, qw(desktop-base desktop-gnome) if get_var('SCC_ADDONS') =~ m/we/;
            push @sle12, qw(yast2) if is_sle('>=12-sp3');
            push @sle12, qw(32bit) if !is_aarch64 && get_var('DESKTOP') =~ /gnome|textmode/;
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
                push @all, qw(32bit) unless is_s390x;
            }
            if (get_var('SCC_ADDONS') =~ m/serverapp/) {
                push @all, qw(kvm_tools file_server mail_server gnome_basic
                  lamp_server gateway_server dhcp_dns_server directory_server
                  kvm_server fips sap_server ofed);
                push @all, qw(xen_server xen_tools) unless is_s390x || is_aarch64;
                push @all, qw(oracle_server) unless is_aarch64;
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
    if (is_sle('15+')) {
        my $patterns = get_var('PATTERNS');
        $patterns =~ s/\bbase\b/enhanced_base/;
        $patterns =~ s/\bminimal\b/minimal_base/;
        return [split(/,/, $patterns)];
    }
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
            name => get_addon_fullname($addon),
            version => get_product_version($addon),
            arch => get_var('ARCH'),
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
    my $template = Mojo::Template->new(vars => 1);
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) if get_var('INCIDENT_REPO');
    my $vars = {
        addons => expand_addons,
        repos => [split(/,/, get_var('MAINT_TEST_REPO', ''))],
        patterns => expand_patterns,
        # pass reference to get_required_var function to be able to fetch other variables
        get_var => \&get_required_var,
        # pass reference to check_var
        check_var => \&check_var,
        is_ltss => get_var('SCC_REGCODE_LTSS') ? '1' : '0'
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

Validate XML AutoYaST profile traversing YAML test data
$profile is the root node in the test data

Expected YAML data should mimic structure of XML file for the AutoYaST profile,
so hashes and arrays in the yaml should represent nodes in the xml file.

Generates a list of XPATH expressions based on the YAML file provided, run those
expressions and create a summary based with the errors found and all the expressions.

There are special keys to handle xml attributes for the node types, or in case
exact number of nodes has to be validated, e.g. C<_t> for the type, C<__text> for
the text value of the node, C<__count> to specify exact number of child nodes.

See 'has_properties' and 'generate_expressions' functions for the further info.

In order to validate following xml:
<profile>
    <suse_register t="map">
        <addons t="list">
            <addon t="map">
                <name>sle-module-server-applications</name>
            </addon>
            <addon t="map">
                <arch>ppc64le</arch>
                <name>sle-module-basesystem</name>
            </addon>
        </addons>
        <do_registration t="boolean">true</do_registration>
        <install_updates t="boolean">false</install_updates>
    </suse_register>
</profile>

YAML example to validate given xml:
profile:
  suse_register:
    addons:
      _t: list
      __count: 2
      addon:
        - name: sle-module-server-applications
        - name: sle-module-basesystem
    do_registration:
      _t: boolean
      __text: 'true'


=cut

sub validate_autoyast_profile {
    my $profile = shift;

    my $xpc = get_xpc(init_autoyast_profile());    # get XPathContext
    my $errors = [];
    my $expressions = [map { '/ns:profile' . $_ } generate_expressions($profile)];
    run_expressions(xpc => $xpc, expressions => $expressions, errors => $errors);
    my $report = create_report(errors => $errors, expressions => $expressions);
    record_info('Summary', $report);
    die 'Found errors on validation of AutoYaST profile, ' .
      'please check Summary report' if (@{$errors});
}

=head2 is_processable

    is_processable($node);

  A node is considered 'processable' when:
   - is a simple key-value pair where value is text:
     quotas: 'true'
   - has properties:
     quotas:
       _t: boolean
       __text: 'true'
  In other words, a node is not processable when just needs to be traversed in the YAML.

=cut

sub is_processable {
    my $node = shift;
    return (!ref $node ||
          (ref $node eq 'HASH' && has_properties($node)));
}

=head2 has_properties

  has_properties($node);

- A XML node can be specified in YAML along with its attributes from XML:
    XML:  <subvolumes t="list">
    YAML: subvolumes:
            _t: list
    XPATH: ns:subvolumes[@t='list']

- XPATH functions can be used:

    'count': when you want to explicitly count the element in a list
    XML:  <subvolumes t="list">
            <subvolume t="map">
    YAML: subvolumes:
            __count: 8
            subvolume:
                ...
    XPATH: ns:subvolumes[count(ns:subvolume)=8]

    'text': when you want to check some attribute and the text itself
    XML:  <quotas t="boolean">true</quotas>
    YAML: quotas:
            _t: boolean
            __text: true
    XPATH: ns:quotas[text()='true' and @t='boolean']

    'descendant': by default the algorithm will try to identify an element
    in a list using direct children, but with this property is it possible to
    add children which are descendant but not necessarily direct children.
    It is useful when XML structure are almost exactly the same for different
    list items and the only difference is found in more deeper descendants,
    therefore avoiding to return multiple result for an XPATH expression.

    YAML:
            drive:
            - label:
                _descendant: any
                __text: root_multi_btrfs
                disklabel: none
                partitions:
                partition:
                - filesystem: btrfs
                    label: root_multi_btrfs
            - label:
                _descendant: any
                __text: test_multi_btrfs
                disklabel: none
                partitions:
                partition:
                - filesystem: btrfs
                    label: test_multi_btrfs

=cut

sub has_properties {
    my $node = shift;
    return 0 unless ref $node;
    return scalar(grep {
            $_ eq '_t' ||
              $_ eq '__text' ||
              $_ eq '__count' ||
              $_ eq '_descendant'
    } keys %{$node});
}

=head2 create_xpath_predicate

    create_xpath_predicate($node);

Based on the properties of the node will create a predicate for the XPATH expression.

=cut

sub create_xpath_predicate {
    my $node = shift;
    my @predicates = ();

    if (has_properties($node)) {
        push @predicates, "text()='$node->{__text}'" if $node->{__text};
        push @predicates, '@t=' . "'" . $node->{_t} . "'" if $node->{_t};
        if ($node->{__count}) {
            my ($list_item) = grep { ref $node->{$_} } keys %{$node};
            push @predicates, 'count(' . ns($list_item) . ")=$node->{__count}";
        }
    } else {
        push @predicates, ($node eq '') ? 'not(text())' : "text()='$node'";
    }
    return close_predicate(@predicates);
}

=head2 close_predicate

    close_predicate(@array);

Joins a list of intermediate predicates and closes it to create one XPATH predicate.

=cut

sub close_predicate {
    my @predicates = @_;
    return '[' . join(' and ', @predicates) . ']';
}

=head2 ns

    ns($node);

Add XML namespace to the node declared in YAML file to be able to build
the correct XPATH expression with namespaces.

=cut

sub ns {
    my $node = shift;
    return "ns:$node";
}

=head2 get_traversable

    get_traversable($node);

Return the node 'traversable' of a node which contains properties, so
it returns the key of the hash needed to continue traversing the YAML.

Example which would return 'subvolume' as the key to continue traversing.
YAML:  subvolumes:
         _t: list
         __count: 8
         subvolume:
           - path: var

=cut

sub get_traversable {
    my $node = shift;
    if ((ref $node eq 'HASH')) {
        my ($traversable) = grep { ref $node->{$_} } keys %{$node};
        return $traversable;
    }
    return undef;
}

=head2 get_descendant

    get_descendant($node);

It will apply the right separator in case direct children nodes (default)
or any descendant is applied ('' also means ./ for direct children)

=cut

sub get_descendant {
    my $node = shift;
    return ".//" if (ref $node eq 'HASH' && $node->{_descendant});
    return '';
}

=head2 generate_expressions

    generate_expressions($node);

Recursive algorithm to traverse YAML file and create a list of XPATH expressions.

=cut

sub generate_expressions {
    my ($node) = shift;
    # accumulate expressions
    my @expressions = ();

    # one of the choices when reading YAML structure is that is a hash ref
    if (ref $node eq 'HASH') {
        for my $k (keys %{$node}) {
            my @inner_expressions = ();
            # some node are processables
            if (is_processable($node->{$k})) {
                # which gives a predicate with all its processable properties
                # or simple text
                push @inner_expressions, create_xpath_predicate($node->{$k});
                # after processing continue traversing is still needed
                if (my $t = get_traversable($node->{$k})) {
                    # prepend all the expression that will generated for nested nodes
                    # (in this case with starting point as the 'traversable' node)
                    # with available info for current child in this iteration.
                    push @inner_expressions,
                      map { '/' . ns($t) . $_ } generate_expressions($node->{$k}->{$t});
                }
            } else {
                # continue traversing and accumulating
                push @inner_expressions, generate_expressions($node->{$k});
            }
            # all the accumulated inner expressions are concatenated with current node info
            push @expressions, map { '/' . ns($k) . $_ } @inner_expressions;
        }
    }
    # the other choice is when is a array ref
    elsif (ref $node eq 'ARRAY') {
        for my $item (@{$node}) {
            # only in case we have a list of scalars
            if (!ref $item) {
                push @expressions, create_xpath_predicate($item);
                next;
            }
            # get items with some nested properties
            my @processables = grep { is_processable($item->{$_}) } sort keys(%{$item});
            # create a predicate and consider where to look, if direct children or any descendant
            my @predicates = map {
                get_descendant($item->{$_}) . ns($_) . create_xpath_predicate($item->{$_})
            } @processables;
            # close the predicate joining all the intermediate ones and add it as expression
            my $predicate = close_predicate(@predicates);
            push @expressions, $predicate;

            # consider how to continue traversing the YAML when we need to search a node to traverse
            # in case it could have some properties
            for my $p (@processables) {
                if (my $t = get_traversable($item->{$p})) {
                    # concatenate current node info with result of recursive call
                    push @expressions, map { $predicate . '/' . ns($p) . '/' . ns($t) . $_ } generate_expressions($item->{$p}->{$t});
                }
            }

            # items which do not have properties are directly ready to traverse them
            my @traversables = grep { !is_processable($item->{$_}) } sort keys(%{$item});
            for my $k (@traversables) {
                # concatenate current node info with result of recursive call
                push @expressions, map { $predicate . '/' . ns($k) . $_ } generate_expressions($item->{$k});
            }
        }
    }
    # return expressions recursively to caller
    return @expressions;
}

=head2 run_expressions

    run_expressions($args);

Run XPATH expressions. Errors handled are 'no node found' and 'more than one node found'

=cut

sub run_expressions {
    my (%args) = @_;

    my $xpc = $args{xpc};
    my $expressions = $args{expressions};
    my $errors = $args{errors};

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

=head2 create_report

    create_report($args);

Create a report with the errors found and listing all the XPATH expressions executed.

=cut

sub create_report {
    my %args = @_;

    my $expressions = $args{expressions};
    my $errors = $args{errors};
    my $error_summary = @{$errors} ? "Errors found:\n" . join("\n", @{$errors}) : "Errors found:\nnone";
    my $expressions_summary = "Expressions executed:\n" . join("\n", @{$expressions});
    return "$error_summary\n\n$expressions_summary\n";
}

=head2 detect_profile_directory

 detect_profile_directory(profile => $profile, path => $path)

 Try to detect profile directory (autoyast_opensuse/, autoyast_sle{12,15}/, autoyast_sles11/)
 and returns its path.
 TODO: autoyast_{kvm,qam,xen}

 $profile is the autoyast profile 'autoinst.xml'.
 $path is AutoYaST profile path

=cut

sub detect_profile_directory {
    my (%args) = @_;
    my $profile = $args{profile};
    my $path = $args{path};

    my $dir = "autoyast_";
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
    if (is_backend_s390x) {
        ($hostip) = get_var('S390_NETWORK_PARAMS') =~ /HostIP=(.*?)\//;
    }
    elsif (is_svirt) {
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
    my @vars = qw(SCC_REGCODE SCC_REGCODE_HA SCC_REGCODE_GEO SCC_REGCODE_HPC
      SCC_REGCODE_LTSS SCC_REGCODE_WE SCC_URL ARCH LOADER_TYPE NTP_SERVER_ADDRESS
      REPO_SLE_MODULE_DEVELOPMENT_TOOLS);
    # Push more variables to expand from the job setting
    my @extra_vars = push @vars, split(/,/, get_var('AY_EXPAND_VARS', ''));
    if (get_var 'SALT_FORMULAS_PATH') {
        my $tarfile = data_url(get_var 'SALT_FORMULAS_PATH');
        $profile =~ s/\{\{SALT_FORMULAS_PATH\}\}/$tarfile/g;
    }
    for my $var (@vars) {
        if ($var eq 'WORKER_IP') {
            set_var('WORKER_IP', inet_ntoa(inet_aton(get_var 'WORKER_HOSTNAME')));
        }
        # Skip if value is not defined
        next unless my ($value) = get_var($var);
        $profile =~ s/\{\{$var\}\}/$value/g;
    }
    return $profile;
}

=head2 upload_profile

 upload_profile(profile => $profile, path => $path)

 Upload modified profile
 Update path
 Make available profile in job logs

 $profile is the AutoYaST profile 'autoinst.xml'
 $path is the path of the AutoYaST profile or one of the xml files when
 using rules and classes.

=cut

sub upload_profile {
    my (%args) = @_;
    my $profile = $args{profile};
    my $path = $args{path};

    if (check_var('IPXE', '1')) {
        $path = get_required_var('SUT_IP') . $path;
    }
    save_tmp_file($path, $profile);
    # Copy profile to ulogs directory, so profile is available in job logs
    make_path('ulogs');
    my $file_path = $path;

    # just to shorten the path (specially useful for AutoYaST rules and classes)
    $path =~ s/^.*?\///;
    $path =~ s/\//-/g;

    copy(hashed_string($file_path), 'ulogs/' . $path);
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
        # replace default qemu gateway by loopback
        $ayp_url =~ s/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/localhost/;

        # if the $ayp_url ends with a / we use the rules_and_classes approach
        # that means we should test for rules/rules.xml because retrieving
        # the directory will end up in a 404.
        $ayp_url =~ s/\/$/\/rules\/rules.xml/;

        if (head($ayp_url)) {
            record_info("ayp url ok", "Autoyast profile url $ayp_url is reachable from the worker");
        } else {
            record_info("Failure", "Autoyast profile url $ayp_url is unreachable from the worker");
        }
    }
}

# get relative path to all test data files in a directory
=head2 get_test_data_files
  get_test_data($dir_relative_path)

Returns list of all relative xml file paths for a relative directory path.

Example:
  get_test_data_files('autoyast_sle15/rule-based_example/')
This could return a reference to an array with content:
  - autoyast_sle15/rule-based_example/profile_a.xml
  - autoyast_sle15/rule-based_example/profile_b.xml
  - autoyast_sle15/rule-based_example/rules/rules.xml
  - autoyast_sle15/rule-based_example/classes/swap/smallswap.xml
  - autoyast_sle15/rule-based_example/classes/swap/bigswap.xml
  - autoyast_sle15/rule-based_example/classes/general/software.xml
  - autoyast_sle15/rule-based_example/classes/general/registration.xml
  - autoyast_sle15/rule-based_example/classes/general/users.xml

=cut

sub get_test_data_files {
    my ($path) = @_;
    my $casedir_data = get_var('CASEDIR') . '/data/';
    my @files;
    finddepth(sub {
            return if ($_ !~ /\.xml$/);
            $File::Find::name =~ s/^$casedir_data//;
            push @files, $File::Find::name;
    }, $casedir_data . $path);
    return \@files;
}

=head2 prepare_ay_file

 prepare_ay_file(profile => $profile, path => $path)

Get profile from autoyast template
Map version names
Get IP address from system variables
Get values from SCC_REGCODE SCC_REGCODE_HA SCC_REGCODE_GEO SCC_REGCODE_HPC SCC_URL ARCH LOADER_TYPE
Modify profile with obtained values
Return new path in case of using AutoYaST templates

 $path is the path of the AutoYaST profile or one of the xml files when
 using rules and classes.

=cut

sub prepare_ay_file {
    my ($path) = @_;

    my $profile = get_test_data($path);
    die "Empty AutoYaST xml file" unless $profile;

    # if profile is a template, expand and rename
    $profile = expand_template($profile) if $path =~ s/^(.*\.xml)\.ep$/$1/;
    die $profile if $profile->isa('Mojo::Exception');

    $profile = expand_version($profile);
    $profile = adjust_network_conf($profile);
    $profile = expand_variables($profile);
    upload_profile(profile => $profile, path => $path);
    return $path;
}

=head2 generate_xml

  generate_xml(addons => $addons)

Get maintenance updates addons
Generate one xml file
Get values from MAINT_TEST_REPO
Return string with xml format

  $addons is maintenance updates URL

=cut

sub generate_xml {
    my ($addons) = @_;

    # Generate addon products xml file
    my $writer = XML::Writer->new(
        DATA_MODE => 'true',
        DATA_INDENT => 2,
        OUTPUT => "self"
    );
    $writer->startTag(
        "add_on_products",
        xmlns => "http://www.suse.com/1.0/yast2ns",
        "xmlns:config" => "http://www.suse.com/1.0/configns"
    );
    $writer->startTag("product_items", "config:type" => "list");
    for my $addon (split(/,/, $addons)) {
        my ($repo_id, $repo) = $addon =~ (/^\S+\/(\d+)\/(\S+)\/$/);
        my $name = join '_', ($repo, $repo_id);
        $writer->startTag("product_item");
        $writer->startTag("url");
        $writer->characters($addon);
        $writer->endTag("url");
        $writer->startTag("name");
        $writer->characters($name);
        $writer->endTag("name");
        $writer->startTag("alias");
        $writer->characters($name);
        $writer->endTag("alias");
        $writer->startTag("priority", "config:type" => "integer");
        $writer->characters("50");
        $writer->endTag("priority");
        $writer->startTag("ask_user", "config:type" => "boolean");
        $writer->characters("true");
        $writer->endTag("ask_user");
        $writer->startTag("selected", "config:type" => "boolean");
        $writer->characters("true");
        $writer->endTag("selected");
        $writer->startTag("check_name", "config:type" => "boolean");
        $writer->characters("true");
        $writer->endTag("check_name");
        $writer->endTag("product_item");
    }
    $writer->endTag("product_items");
    $writer->endTag("add_on_products");
    $writer->end();
    return $writer->to_string;
}

1;
