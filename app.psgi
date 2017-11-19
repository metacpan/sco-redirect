use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use MetaCPAN::SCORedirect;

sub {
  my $env = shift;
  my $url = MetaCPAN::SCORedirect::rewrite_url($env->{PATH_INFO}//'/', $env->{QUERY_STRING});
  if ($url) {
    return [ 302, [ 'Content-Type' => 'text/plain', 'Location' => $url ], [ 'Moved' ] ];
  }
  else {
    return [ 404, [ 'Content-Type' => 'text/plain' ], [ 'Not found' ] ];
  }
};
