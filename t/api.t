use strict;
use warnings;
use Test::More;
use Test::Differences;
use MetaCPAN::SCORedirect;

my @checks = (
  '/api/module/Moo' => undef,
  '/api/dist/Moo' => undef,
  '/api/author/HAARG' => undef,
);

while (@checks) {
  my ($sco, $meta) = (shift @checks, shift @checks);
  my ($sco_path, $sco_query) = split /\?/, $sco, 2;
  my $got = MetaCPAN::SCORedirect::rewrite_url($sco_path, $sco_query);
  is $got->[0], 200, 'correct response code for '.$sco;
  is $got->[1], undef, 'no rewrite for '.$sco;
  local $TODO = 'no test data yet';
  eq_or_diff $got->[2], $meta, 'correct content for '.$sco;
}

done_testing;
