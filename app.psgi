use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use MetaCPAN::SCORedirect;
use JSON::MaybeXS;

my $J = JSON::MaybeXS->new(utf8 => 1, pretty => 1);

sub {
  my $env = shift;
  my $result = MetaCPAN::SCORedirect::rewrite_url($env->{PATH_INFO}//'/', $env->{QUERY_STRING});
  my $body;
  my @headers;
  my $content_type = 'text/plain';
  if ($result->[1]) {
    push @headers, 'Location' => $result->[1];
    $body = 'Moved';
  }
  if ($result->[2]) {
    $body = $J->encode($result->[2]);
    $content_type = 'application/json';
  }
  if ($result->[0] == 404) {
    $body //= 'Not found';
  }
  elsif ($result->[0] == 500) {
    $body //= 'Internal server error';
  }
  else {
    $body //= 'Unhandled';
  }
  push @headers, 'Content-Type' => $content_type;
  return [ $result->[0], \@headers, [ $body ] ];
};
