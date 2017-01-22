requires 'Net::Telnet';
requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';

on 'test' => sub {
  requires 'Code::DRY';
};
