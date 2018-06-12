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

use Log::Contextual qw( set_logger );
use Log::Log4perl ();
use Log::Log4perl::Level ();
use Config::ZOMG;

if (
  my ($log_file) =
    grep -f,
    map "$root_dir/$_",
    "log4perl_local.conf", "log4perl.conf"
) {
  Log::Log4perl->init($log_file);
}
else {
  Log::Log4perl->easy_init(Log::Log4perl::Level::to_priority('WARN'));
}

set_logger(Log::Log4perl->get_logger('MetaCPAN::SCORedirect'));

my $config = Config::ZOMG->open(
  name => 'MetaCPAN::SCORedirect',
  path => $root_dir,
);
MetaCPAN::SCORedirect->new($config)->app;
