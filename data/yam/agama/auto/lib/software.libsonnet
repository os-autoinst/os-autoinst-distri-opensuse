local extra_repositories() = [
  {
    alias: 'science',
    url: 'https://download.opensuse.org/repositories/science/16.0/',
    gpgFingerprints: ['D1DD 7ACD 6D68 A0B4 3081 B158 01DB 7302 943D 8BB8'],
  },
];

{
  extraRepositories: extra_repositories(),
  modify_patterns(add_patterns='', remove_patterns=''):: {
    add: if add_patterns != '' then std.split(add_patterns, ','),
    remove: if remove_patterns != '' then std.split(remove_patterns, ','),
  },
}
