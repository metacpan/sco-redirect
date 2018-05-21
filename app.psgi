package MetaCPAN::SCORedirect::PSGI;
use strict;
use warnings;
use File::Basename ();
my $root_dir;
BEGIN {
  $root_dir = File::Basename::dirname(__FILE__);
}
use lib "$root_dir/lib";

use MetaCPAN::SCORedirect;

MetaCPAN::SCORedirect->new->app;
