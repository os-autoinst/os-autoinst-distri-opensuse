# If you update this file you must also:
# - run ./tools/update_spec
# - add the updated spec to your commit
# - osc sr devel:openQA os-autoinst-distri-opensuse-deps devel:openQA:tested os-autoinst-distri-opensuse-deps
# - wait for the SR to be accepted
# - osc sr devel:openQA:tested os-autoinst-distri-opensuse-deps openSUSE:Factory os-autoinst-distri-opensuse-deps

requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::LibXML';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';
requires 'IO::Socket::INET';
requires 'List::Util';
requires 'LWP::Simple';
requires 'File::Copy';
requires 'File::Path';
requires 'Selenium::Remote::Driver';
requires 'Selenium::Chrome';
requires 'Selenium::Waiter';
requires 'Selenium::Remote::WDKeys';
requires 'Digest::file';
requires 'YAML::Tiny';
requires 'Test::Assert';


on 'test' => sub {
  requires 'Code::DRY';
  requires 'Test::Exception';
  requires 'Test::Warnings';
  requires 'Test::YAML::Valid';
};
