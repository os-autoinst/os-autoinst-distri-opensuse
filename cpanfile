requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::LibXML';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';
requires 'List::Util';
requires 'LWP::Simple';
requires 'File::Copy';
requires 'File::Path';
requires 'Selenium::Remote::Driver';
requires 'Selenium::Chrome';
requires 'Selenium::Waiter';
requires 'Selenium::Remote::WDKeys';

on 'test' => sub {
  requires 'Code::DRY';
};
