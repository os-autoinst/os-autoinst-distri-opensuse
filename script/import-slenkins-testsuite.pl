#!/usr/bin/perl

use strict;
use Cwd 'abs_path';
use Data::Dump qw/dd pp/;

my $template_control = pp(
    {key => "BOOT_HDD_IMAGE", value => 1},

    {key => "DESKTOP", value => "textmode"},

    {key => "HDD_1", value => "openqa_support_server_sles12sp1.x86_64.qcow2"},

    {key => "NICTYPE", value => "tap"},

    {key => "WORKER_CLASS", value => "tap"},

    {key => "START_AFTER_TEST", value => "sles12_minimal_base_create_hdd"},

    {key => "SUPPORT_SERVER", value => 1},

    {key => "SUPPORT_SERVER_ROLES", value => "dhcp"},

    {key => "SLENKINS_TESTSUITES_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins:/testsuites/SLE_12_SP1/"},

    {key => "SLENKINS_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins/SLE_12_SP1/"},
);

my $template_node = pp(
    {key => "BOOT_HDD_IMAGE", value => 1},

    {key => "DESKTOP", value => "textmode"},

    {key => "HDD_1", value => "SLES_12SP1-%ARCH%-minimal_with_sdk_installed.qcow2"},

    {key => "NICTYPE", value => "tap"},

    {key => "WORKER_CLASS", value => "tap"},

    {key => "START_AFTER_TEST", value => "sles12_minimal_base_create_hdd"},

    {key => "SLENKINS_TESTSUITES_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins:/testsuites/SLE_12_SP1/"},
);


sub parse_node_file {
    my ($fn, $project_name) = @_;

    open(my $fh, '<', $fn) || die "can't open $fn: $!\n";
    my %nodes;
    my %networks;
    my $node;
    my $network;
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/\$\{PROJECT_NAME\}/$project_name/g;

        if ($line =~ /^node\s+([^\s]+)$/) {
            $node    = $1;
            $network = undef;
            $nodes{$node} = {install => []};
        }
        elsif ($line =~ /^network\s+([^\s]+)$/) {
            $network            = $1;
            $node               = undef;
            $networks{$network} = {};
        }
        elsif ($line =~ /^install\s/) {
            my @pkg = split(/\s+/, $line);
            shift @pkg;
            push @{$nodes{$node}->{install}}, @pkg if defined $node;
        }
        elsif ($line =~ /^ethernet\s/) {
            my @net = split(/\s+/, $line);
            shift @net;
            push @{$nodes{$node}->{networks}}, @net if defined $node;
        }
        elsif ($line =~ /^subnet\s/ || $line =~ /^dhcp\s/ || $line =~ /^gateway\s/) {
            my ($param, $value) = split(/\s+/, $line);
            $value = 0 if $value eq 'no';
            $networks{$network}->{$param} = $value if defined $network;
        }
        elsif ($line =~ /^\s*#/) {
            #nothing to do
        }
        elsif ($line !~ /^\s*$/) {
            print STDERR "unsupported param: $line\n";
        }
    }
    return (\%nodes, \%networks);
}

sub gen_testsuites {
    my ($nodes, $networks, $project_name, $control_pkg) = @_;
    my @suites;

    for my $node (keys %$nodes) {
        my @node_net = @{$nodes->{$node}->{networks}} if $nodes->{$node}->{networks};
        push @node_net, 'fixed' unless grep { $_ eq 'fixed' } @node_net;
        push @suites,
          {
            name     => "slenkins-${project_name}-${node}",
            settings => [eval $template_node, {key => "SLENKINS_NODE", value => "$node"}, {key => "SLENKINS_INSTALL", value => join(',', @{$nodes->{$node}{install}})}, {key => "NETWORKS", value => join(',', @node_net)},],
          };
    }

    my $control = {
        name     => "slenkins-${project_name}-control",
        settings => [eval $template_control, {key => "SLENKINS_NODE", value => "control"}, {key => "SLENKINS_CONTROL", value => $control_pkg}, {key => "PARALLEL_WITH", value => join(',', map { "slenkins-${project_name}-" . $_ } keys %$nodes)},],
    };

    my @control_net = keys %$networks;
    push @control_net, 'fixed' unless $networks->{fixed};
    push @{$control->{settings}}, {key => "NETWORKS", value => join(',', @control_net)};

    my $i = 1;
    for my $net (keys %$networks) {
        my @param;
        push @param, $net;
        for my $p (keys %{$networks->{$net}}) {
            push @param, "$p=" . $networks->{$net}->{$p};
        }
        push @{$control->{settings}}, {key => "NETWORK$i", value => join(',', @param)};
        $i++;
    }
    push @suites, $control;

    return @suites;
}

sub import_node_file {
    my ($fn, $project_name, $control_pkg) = @_;

    unless ($project_name) {
        my $abs_path = abs_path($fn);
        if ($abs_path =~ /\/var\/lib\/slenkins\/([^\/]+)\/([^\/]+)\/nodes/) {
            $project_name = $1;
            $control_pkg  = "$1-$2";
        }
        else {
            print STDERR "Can't guess project name from path $abs_path\n";
            exit(1);
        }
    }
    my ($nodes, $networks) = parse_node_file($fn, $project_name);
    return gen_testsuites($nodes, $networks, $project_name, $control_pkg);
}

my @suites;

if (@ARGV == 0) {
    print STDERR "Usage:\n\n";
    print STDERR "import-slenkins-testsuite.pl /var/lib/slenkins/*/*/nodes >slenkins_templates\n";
    print STDERR "load_templates --update slenkins_templates\n";
    exit(1);
}

for my $file (@ARGV) {
    push @suites, import_node_file($file);
}

dd {TestSuites => \@suites};

