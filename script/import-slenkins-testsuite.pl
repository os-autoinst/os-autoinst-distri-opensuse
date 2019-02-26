#!/usr/bin/perl

use strict;
use warnings;
use Cwd 'abs_path';
use Data::Dump qw(dd pp);
use XML::Simple;

my $template_control = pp(
    {key => "BOOT_HDD_IMAGE", value => 1},

    {key => "DESKTOP", value => "textmode"},

    {key => "HDD_1", value => "openqa_support_server_sles12sp2.x86_64.qcow2"},

    {key => "NICTYPE", value => "tap"},

    {key => "WORKER_CLASS", value => "tap"},

    {key => "START_AFTER_TEST", value => "sles12_minimal_base+sdk_create_hdd"},

    {key => "SUPPORT_SERVER", value => 1},

    {key => "SUPPORT_SERVER_ROLES", value => "dhcp,dns"},

    #   this is a part of support server configuration
    #    {key => "SLENKINS_TESTSUITES_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins:/testsuites/SLE_12_SP1/"},
    #
    #    {key => "SLENKINS_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins/SLE_12_SP1/"},
);

my $template_node = pp(
    {key => "BOOT_HDD_IMAGE", value => 1},

    {key => "DESKTOP", value => "textmode"},

    {key => "ISO_1", value => "SLE-%VERSION%-SDK-DVD-%ARCH%-Build%BUILD_SDK%-Media1.iso"},

    {key => "HDD_1", value => "SLES-%VERSION%-%ARCH%-%BUILD%-minimal_with_sdk%BUILD_SDK%_installed.qcow2"},

    {key => "NICTYPE", value => "tap"},

    {key => "WORKER_CLASS", value => "tap"},

    {key => "START_AFTER_TEST", value => "sles12_minimal_base+sdk_create_hdd"},

    #   this should be a part of media configuration
    #    {key => "SLENKINS_TESTSUITES_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins:/testsuites/SLE_12_SP1/"},
);

sub parse_channels {
    my ($repo_var) = @_;
    my $repo;
    my $family        = "SLE_12_SP3";
    my $channels_file = "/etc/slenkins/channels.conf";

    my $xml  = XML::Simple->new;
    my $data = $xml->XMLin($channels_file);

    my %repo_table = (
        UPDATES          => "Updates",
        DEBUG            => "Debug",
        QA               => "QA",
        QAHEAD           => "QAHead",
        HA               => "HA",
        HAUPDATES        => "HAUpdates",
        HAFACTORY        => "HAFactory",
        GALAXY           => "Galaxy",
        RUBYEXTENSIONS   => "RubyExtensions",
        NETWORKUTILITIES => "NetworkUtilities",
        SALT             => "Salt",
        HPC              => "HPC",
    );

    my $channel_name  = $repo_table{$repo_var};
    my $channel_array = $data->{channel}{$channel_name}{repo};

    foreach (@$channel_array) {
        $repo = $_->{url} if $_->{family} eq $family;
        $repo =~ s/\@\@ARCH\@\@/x86_64/g;
    }

    if (!length $repo) {
        if (grep { $repo_var eq $_ } qw(SLENKINS SDK)) {
            print STDERR "Repository \"$repo_var\" already present in the image.\n";
        }
        else {
            print STDERR "Repository \"$repo_var\" for \"$family\" not found in $channels_file.\n";
        }
    }
    return $repo;
}

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
            $nodes{$node} = {install => [], repos => [], disks => []};
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
        elsif ($line =~ /(^repository|^repo)\s+\$\{CHANNEL_(.*)_.*\}$/) {
            my $repo = parse_channels($2);
            if (length $repo) {
                push @{$nodes{$node}->{repos}}, $repo if defined $node;
            }
        }
        elsif ($line =~ /(^repository|^repo)\s+(http.*\.repo)$/) {
            my @repo = split(/\s+/, $line);
            shift @repo;
            push @{$nodes{$node}->{repos}}, @repo if defined $node;
        }
        elsif ($line =~ /^disk\s+([^\s]+)$/) {
            # Stores size info about each additional drive but it's not used yet
            push @{$nodes{$node}->{disks}}, $1 if defined $node;
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

    ## no critic (ProhibitStringyEval)
    for my $node (keys %$nodes) {
        my @node_net;
        @node_net = @{$nodes->{$node}->{networks}} if $nodes->{$node}->{networks};
        push @node_net, 'fixed' unless grep { $_ eq 'fixed' } @node_net;
        push @suites,
          {
            name     => "slenkins-${project_name}-${node}",
            settings => [
                eval $template_node,
                {key => "SLENKINS_NODE",    value => "$node"},
                {key => "SLENKINS_INSTALL", value => join(',', sort @{$nodes->{$node}{install}})},
                {key => "NETWORKS",         value => join(',', @node_net)},
                {key => "FOREIGN_REPOS",    value => join(',', sort @{$nodes->{$node}{repos}})},
                {key => "NUMDISKS",         value => 1 + scalar(@{$nodes->{$node}{disks}})},
            ],
          };
    }

    my $control = {
        name     => "slenkins-${project_name}-control",
        settings => [
            eval $template_control,
            {key => "SLENKINS_NODE",    value => "control"},
            {key => "SLENKINS_CONTROL", value => $control_pkg},
            {key => "PARALLEL_WITH",    value => join(',', sort map { "slenkins-${project_name}-" . $_ } keys %$nodes)},
        ],
    };
    ## use critic (ProhibitStringyEval)

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
    my ($json, $fn, $project_name, $control_pkg) = @_;

    unless ($project_name) {
        my $abs_path = abs_path($fn) || $fn;
        if ($abs_path =~ /var\/lib\/slenkins\/([^\/]+)\/([^\/]+)\/nodes/) {
            $project_name = $1;
            $control_pkg  = "$1-$2";
        }
        else {
            print STDERR "Can't guess project name from path $abs_path\n";
            exit(1);
        }
    }
    my ($nodes, $networks) = parse_node_file($fn, $project_name);
    for my $ts (gen_testsuites($nodes, $networks, $project_name, $control_pkg)) {
        push(@{$json->{TestSuites}}, $ts);
        push(
            @{$json->{JobTemplates}},
            {
                group_name => "Slenkins",
                machine    => {name => "64bit"},
                prio       => 60,
                product    => {
                    arch    => "x86_64",
                    distri  => "sle",
                    flavor  => "Server-DVD",
                    group   => "sle-12-SP3-Server-DVD",
                    version => "12-SP3",
                },
                test_suite => {name => $ts->{name}},
            });
    }
    return;
}

my @suites;

my $PWD = abs_path();

if (@ARGV == 0) {
    print STDERR "Example usage:\n\n";
    print STDERR "sudo zypper download twopence-krb5-control\n";
    print STDERR "unrpm /var/cache/zypp/packages/*/*/twopence-krb5-control-*\n";
    print STDERR "import-slenkins-testsuite.pl $PWD/var/lib/slenkins/twopence-krb5/*/nodes > twopence-krb5\n";
    print STDERR "load_templates twopence-krb5\n";
    exit(1);
}

my %json = (JobTemplates => [], TestSuites => []);
for my $file (@ARGV) {
    import_node_file(\%json, $file);
}

dd \%json;

