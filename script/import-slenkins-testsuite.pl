#!/usr/bin/perl

use strict;
use Cwd 'abs_path';
use Data::Dump qw/dd pp/;

my $template_control = pp(
    {key => "BOOT_HDD_IMAGE", value => 1},

    {key => "DESKTOP", value => "textmode"},

    {key => "HDD_1", value => "supporserver.qcow2"},

    {key => "NICTYPE", value => "tap"},

    {key => "START_AFTER_TEST", value => "textmode"},

    {key => "SUPPORT_SERVER", value => 1},

    {key => "SUPPORT_SERVER_ROLES", value => "dhcp"},

    {key => "SLENKINS_TESTSUITES_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins:/testsuites/SLE_12_SP1/"},

    {key => "SLENKINS_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins/SLE_12_SP1/"},
);

my $template_node = pp(
    {key => "BOOT_HDD_IMAGE", value => 1},

    {key => "DESKTOP", value => "textmode"},

    {key => "HDD_1", value => "textmode-openqa-%ARCH%.qcow2"},

    {key => "NICTYPE", value => "tap"},

    {key => "START_AFTER_TEST", value => "textmode"},

    {key => "SLENKINS_TESTSUITES_REPO", value => "http://download.suse.de/ibs/Devel:/SLEnkins:/testsuites/SLE_12_SP1/"},
);


sub parse_node_file {
    my ($fn, $project_name) = @_;

    open(my $fh, '<', $fn) || die "can't open $fn: $!\n";
    my %nodes;
    my $node;
    while (my $line = <$fh>) {
        chomp $line;
        $line =~ s/\$\{PROJECT_NAME\}/$project_name/g;

        if ($line =~ /^node\s+([^\s]+)$/) {
            $node = $1;
            $nodes{$node} = {install => []};
        }
        elsif ($line =~ /^install\s/) {
            my @pkg = split(/\s+/, $line);
            shift @pkg;
            push @{$nodes{$node}->{install}}, @pkg;
        }
        elsif ($line =~ /^\s*#/) {
            #nothing to do
        }
        elsif ($line !~ /^\s*$/) {
            print STDERR "unsupported param: $line\n";
        }
    }

    return \%nodes;
}

sub gen_testsuites {
    my ($node_file, $project_name, $control_pkg) = @_;
    my @suites;

    for my $node (keys %$node_file) {
        push @suites,
          {
            name     => "slenkins-${project_name}-${node}",
            settings => [eval $template_node, {key => "SLENKINS_NODE", value => "$node"}, {key => "SLENKINS_INSTALL", value => join(',', @{$node_file->{$node}{install}})},],
          };
    }

    push @suites,
      {
        name     => "slenkins-${project_name}-control",
        settings => [eval $template_control, {key => "SLENKINS_NODE", value => "control"}, {key => "SLENKINS_CONTROL", value => $control_pkg}, {key => "PARALLEL_WITH", value => join(',', map { "slenkins-${project_name}-" . $_ } keys %$node_file)},],
      };

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
    my $node_file = parse_node_file($fn, $project_name);
    return gen_testsuites($node_file, $project_name, $control_pkg);
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

