use strict;
use warnings;
use Test::More;
use Test::Differences;
use Test::Deep;
use MetaCPAN::SCORedirect;

my @checks = (
  '/api/module/Moo' => undef,
  '/api/dist/Moo' => undef,
  '/api/author/HAARG' => undef,
);

my $redirect = MetaCPAN::SCORedirect->new;

while (@checks) {
  my ($sco, $meta) = (shift @checks, shift @checks);
  my ($sco_path, $sco_query) = split /\?/, $sco, 2;
  my $got = $redirect->rewrite_url($sco_path, $sco_query);
  is $got->[0], 200, 'correct response code for '.$sco;
  is $got->[1], undef, 'no rewrite for '.$sco;
  local $TODO = 'no test data yet';
  eq_or_diff $got->[2], $meta, 'correct content for '.$sco;
}

sub cmp_gte {
  my $num = shift;
  Test::Deep::code(sub {
    $_[0] >= $num ? 1 : ("not greater than or equal to $num");
  });
}

{
  my $url = '/api/cpan_stats';
  my $got = $redirect->rewrite_url($url);
  is $got->[0], 200, 'correct response code for '.$url;
  is $got->[1], undef, 'no rewrite for '.$url;
  cmp_deeply $got->[2], {
    authors => cmp_gte(13530),
    distributions => cmp_gte(38519),
    modules => cmp_gte(241845),
    uploads => cmp_gte(127486),
  }, 'correct content for '.$url;
}

done_testing;
