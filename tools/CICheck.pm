#!/usr/bin/perl
use strict;
use warnings;

use File::Find;
use JSON;
use Data::Dumper;
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

my @files;
my $json;
# Json object to map the architecture and backend data
my $datas = '{
     "arch_data" : {
     "s390x" : "is_s390x",
     "i586"  : "is_i586",
     "i686"  :  "is_i686",
     "x86_64": "is_x86_64",
     "aarch64": "is_aarch64",
     "arm" :  "is_arm",
     "ppc64le": "is_ppc64le", 
     "orthos_machine": "is_orthos_machine",
     "supported_suse_domain": "is_supported_suse_domain"
  },
  "backend_data":  {
     "qemu" : "is_qemu",
     "svirt": "is_svirt", 
     "ipmi": "is_ipmi"
  } 
}';

GetOptions(
    'help|?'           => \my $help,
    'dirname|d=s'      => \my $dirname,
    'verify_arch|a'    => \my $arch,
    'verify_backend|b' => \my $backend,
    'verify_shift|s'   => \my $shift,
) or pod2usage(-verbose => 0);

pod2usage(-verbose => 1) if $help;

# Check for Directory and available Options
pod2usage("No directory path is specified.\n")                                        unless $dirname;
pod2usage("Specify one of the options: verify_arch,verify_backend or verify_shift\n") unless ($arch or $backend or $shift);
pod2usage("Wrong directory path.\n")                                                  unless (-e $dirname);

## List all the files in the given directory
find(sub { push @files, $File::Find::name if -f }, $dirname);
@files = grep { !/Architectures.pm|Backends.pm|Firewalld.pm|Systemd.pm/ } @files;
$json  = decode_json $datas;

# Search and replace the function call check_var(ARCH/BACKEND) to respective function call
# Function call defined in json $datas
foreach my $file (@files) {
    next if (-e $file && -l $file);
    if ($shift) {
        print "$file\n";
        `sed -i 's/my \$self *= *shift;/my (\$self) = \@_;/g' $file`;
        `sed -i 's/my (\$self) *= *shift;/my (\$self) = \@_;/g' $file`;
    }
    if ($arch) {
        print "In Arch";
        my @arch_res = (keys %{$json->{'arch_data'}});
        foreach my $key_arch (@arch_res) {
            `sed -i 's/check_var(.ARCH., *.$key_arch.)/$json->{'arch_data'}->{$key_arch}/g' $file`;
        }
    }
    if ($backend) {
        print "In backend";
        my @backend_res = (keys %{$json->{'backend_data'}});
        foreach my $key_backend (@backend_res) {
            `sed -i 's/check_var(.BACKEND., *.$key_backend.)/$json->{'backend_data'}->{$key_backend}/g' $file`;
        }
    }
}
# Include the requied module after the function call modification
add_module($dirname, "arch_data")    if ($arch);
add_module($dirname, "backend_data") if ($backend);

# Function to include the module after replacement function call
sub add_module {
    my ($dir, $data) = @_;
    my (@data_res, $module);
    $module = "use Utils::Architectures" if ($data =~ "arch_data");
    $module = "use Utils::Backends"      if ($data =~ "backend_data");
    my $param = join(q{|}, map { qq{$_} } values %{$json->{$data}});

    my @mod_files = `grep -nrl -E "$param"  $dir --exclude-dir=Utils`;
    foreach (@mod_files) {
        # print "$_\n";
        my $mod_res = `grep -n -E "$module.*" $_`;
        if ($mod_res) {
            `sed -i 's/$module.*/$module;/g' $_`;
        } else {
            my $api_str = `grep -n -E "use testapi;" $_`;
            if ($api_str) {
                `sed  -i '/use testapi;/ a $module;' $_`;
            } else {
                `sed  -i '/use warnings;/ a $module;' $_`;
            }
        }
    }
}

1;

=head1 NAME

CICheck - Using GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

    CICheck OPTIONS

    # Show details for CICheck
    CICheck --help 

    # Replace only the function call check_var('ARCH','.*') to the defined function in Utils.
    CICheck -dirname <dirName> --verify_arch

    # Replace only the function call check_var('BACKEND','.*') to the defined function in Utils.
    CICheck -dirname <dirName> --verify_backend

    # Stick to my ($self) = @_  to avoid mix between my $self = shift and my ($self) = @_
    CICheck -dirname <dirName> --verify_shift
 
    # Replace both the function calls check_var('BACKEND','.*') and check_var('ARCH','.*')\
      to the defined function in Utils.
    CICheck -dirname <dirName> --verify_arch --verify_backend

=head1 OPTIONS

   -h, --help                   brief help message
   -d, --dirname <dirName>      CICheck on the given directory 
   -a, --verify_arch            search and replace the check_var('ARCH','.*') to  respective aforementioned function
   -b, --verify_backend         search and replace the check_var('BACKEND','.*') to  respective aforementioned function 
   -s, --verify_shift           use the Parameter Array to a function
=cut

