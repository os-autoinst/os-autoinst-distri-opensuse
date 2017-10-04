requires 'Net::Telnet';
requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::LibXML';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';
requires 'List::Util';
requires 'LWP::Simple';
requires 'Selenium::Remote::Driver';
requires 'Selenium::Chrome';
requires 'Selenium::Waiter';

on 'test' => sub {
  requires 'Code::DRY';
};
