use strict;
use warnings;
use Test::More;
use MetaCPAN::SCORedirect;


my @checks = (
  '/'                                             => [ 301, 'https://metacpan.org/' ],
  '/perldoc'                                      => [ 301, 'https://metacpan.org/' ],
  '/perldoc?Moo'                                  => [ 301, 'https://metacpan.org/pod/Moo' ],
  '/perldoc/Moo'                                  => [ 301, 'https://metacpan.org/pod/Moo' ],
  '/perldoc/guff?Moo'                             => [ 301,  'https://metacpan.org/pod/Moo' ],
  '/perldoc/Moo/guff'                             => [ 404 ],
  '/perldoc/Some-Other-Garbage'                   => [ 301, 'https://metacpan.org/pod/Some-Other-Garbage' ],
  '/CPAN'                                         => [ 301, 'https://cpan.metacpan.org/' ],
  '/CPAN/authors/id/T/TI/TIMB/'                   => [ 301, 'https://cpan.metacpan.org/authors/id/T/TI/TIMB/' ],
  '/mirror'                                       => [ 301, 'https://metacpan.org/mirrors' ],
  '/mirror/guff'                                  => [ 301, 'https://metacpan.org/mirrors' ],
  '/mirror?guff'                                  => [ 301, 'https://metacpan.org/mirrors' ],
  '/uploads.rdf'                                  => [ 301, 'https://metacpan.org/recent.rdf' ],
  '/uploads.rdf/guff'                             => [ 301, 'https://metacpan.org/recent.rdf' ],
  '/uploads.rdf?guff'                             => [ 301, 'https://metacpan.org/recent.rdf' ],
  '/faq.html'                                     => [ 301, 'https://metacpan.org/about/faq' ],
  '/faq.html/guff'                                => [ 301, 'https://metacpan.org/about/faq' ],
  '/feedback'                                     => [ 301, 'https://metacpan.org/about/contact' ],
  '/feedback/guff'                                => [ 301, 'https://metacpan.org/about/contact' ],
  '/recent'                                       => [ 301, 'https://metacpan.org/recent' ],
  '/recent/guff'                                  => [ 301, 'https://metacpan.org/recent' ],
  '/author'                                       => [ 301, 'https://metacpan.org/authors' ],
  '/author/'                                      => [ 301, 'https://metacpan.org/authors' ],
  '/author?A'                                     => [ 301, 'https://metacpan.org/authors/A' ],
  '/author/?A'                                    => [ 301, 'https://metacpan.org/authors/A' ],
  '/author/?AB'                                   => [ 301, 'https://metacpan.org/authors/A' ],
  '/author/?AB&foo=1'                             => [ 301, 'https://metacpan.org/authors/A' ],
  '/author/?AB&B'                                 => [ 301, 'https://metacpan.org/authors/A' ],
  '/diff'                                         => [ 404 ],
  '/diff?from=Moo-2.003003&to=Moo-2.003004'
    => [ 301, 'https://metacpan.org/diff/file?target=HAARG%2FMoo-2.003004&source=HAARG%2FMoo-2.003003' ],
  '/grep?cpanid=HAARG&release=Moo-2.003004&string=inlinify&i=1&n=1&C=0'
    => [ 301, 'https://grep.metacpan.org/search?q=inlinify&qd=Moo&qci=on' ],
  '/grep/guff?cpanid=HAARG&release=Moo-2.003004&string=inlinify&i=1&n=1&C=0'
    => [ 301, 'https://grep.metacpan.org/search?q=inlinify&qd=Moo&qci=on' ],
  '/search?mode=all&query=Moo&n=100&s=101'
    => [ 301, 'https://metacpan.org/search?q=Moo&p=2&size=100' ],
  '/search?m=all&q=Moo&n=100&s=101'
    => [ 301, 'https://metacpan.org/search?q=Moo&p=2&size=100' ],
  '/search/guff?m=all&q=Moo&n=100&s=101'
    => [ 301, 'https://metacpan.org/search?q=Moo&p=2&size=100' ],
  '/search?module=Moo'
    => [ 301, 'https://metacpan.org/search?q=module%3AMoo' ],
  '/search?dist=Moo'
    => [ 301, 'https://metacpan.org/search?q=dist%3AMoo' ],
  '/search?author=Moo'
    => [ 301, 'https://metacpan.org/search?q=Moo' ],
  '/search'                                       => [ 301, 'https://metacpan.org/' ],
  '/rss/search.rss'                               => [ 301, 'https://metacpan.org/recent.rss' ],
  '/rss/search.rss/guff'                          => [ 404 ],

  '/author/haarg'                                 => [ 301, 'https://metacpan.org/author/HAARG' ],
  '/author/haarg/'                                => [ 301, 'https://metacpan.org/author/HAARG' ],
  '/author/HAARG'                                 => [ 301, 'https://metacpan.org/author/HAARG' ],

  '/author/haarg/Moo-2.003004/'                   => [ 301, 'https://metacpan.org/release/HAARG/Moo-2.003004' ],
  '/author/haarg/Moo-2.003004/lib/Moo.pm'         => [ 301, 'https://metacpan.org/pod/release/HAARG/Moo-2.003004/lib/Moo.pm' ],
  '/author/haarg/Moo/'                            => [ 301, 'https://metacpan.org/release/Moo' ],
  '/author/haarg/Moo/lib/Moo.pm'                  => [ 301, 'https://metacpan.org/pod/distribution/Moo/lib/Moo.pm' ],
  '/author/haarg/Moo/lib/Moo/Object.pm'           => [ 301, 'https://metacpan.org/release/Moo/source/lib/Moo/Object.pm?raw=1' ],
  '/author/haarg/Moo/Changes'                     => [ 301, 'https://metacpan.org/release/Moo/source/Changes?raw=1' ],
  '/author/ether/Moose-2.2010/dist.ini'           => [ 301, 'https://metacpan.org/source/ETHER/Moose-2.2010/dist.ini?raw=1' ],

  '/~haarg'                                       => [ 301, 'https://metacpan.org/author/HAARG' ],
  '/~haarg/'                                      => [ 301, 'https://metacpan.org/author/HAARG' ],
  '/~HAARG'                                       => [ 301, 'https://metacpan.org/author/HAARG' ],

  '/~haarg/Moo-2.003004/'                         => [ 301, 'https://metacpan.org/release/HAARG/Moo-2.003004' ],
  '/~haarg/Moo-2.003004/lib/Moo.pm'               => [ 301, 'https://metacpan.org/pod/release/HAARG/Moo-2.003004/lib/Moo.pm' ],
  '/~haarg/Moo/'                                  => [ 301, 'https://metacpan.org/release/Moo' ],
  '/~haarg/Moo/lib/Moo.pm'                        => [ 301, 'https://metacpan.org/pod/distribution/Moo/lib/Moo.pm' ],
  '/~haarg/Moo/lib/Moo/Object.pm'                 => [ 301, 'https://metacpan.org/release/Moo/source/lib/Moo/Object.pm?raw=1' ],
  '/~haarg/Moo/Changes'                           => [ 301, 'https://metacpan.org/release/Moo/source/Changes?raw=1' ],
  '/~ether/Moose-2.2010/dist.ini'                 => [ 301, 'https://metacpan.org/source/ETHER/Moose-2.2010/dist.ini?raw=1' ],
  '/~mstrout/Moo/'                                => [ 302, 'https://metacpan.org/release/MSTROUT/Moo-1.003001' ],

  '/src/'                                         => [ 301, 'https://metacpan.org/' ],
  '/src/HAARG/'                                   => [ 301, 'https://metacpan.org/author/HAARG' ],
  '/src/HAARG/Moo-2.003004/'                      => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004?raw=1' ],
  '/src/HAARG/Moo-2.003004/Changes'               => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004/Changes?raw=1' ],
  '/src/HAARG/Moo-2.003004/lib'                   => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004/lib?raw=1' ],
  '/src/HAARG/Moo-2.003004/lib/'                  => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004/lib?raw=1' ],
  '/src/HAARG/Moo-2.003004/lib/Moo.pm'            => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004/lib/Moo.pm?raw=1' ],

  '/dist/'                                        => [ 301, 'https://metacpan.org/' ],
  '/dist/Moo'                                     => [ 301, 'https://metacpan.org/release/Moo' ],
  '/dist/Moo/'                                    => [ 301, 'https://metacpan.org/release/Moo' ],
  '/dist/Moo/lib/Moo.pm'                          => [ 301, 'https://metacpan.org/pod/distribution/Moo/lib/Moo.pm' ],
  '/dist/Moo/maint/Makefile.PL.include'
    => [ 301, 'https://metacpan.org/release/Moo/source/maint/Makefile.PL.include?raw=1' ],
  '/dist/Moo/Changes'                             => [ 301, 'https://metacpan.org/release/Moo/source/Changes?raw=1' ],
  '/dist/Moo-2.003004'                            => [ 301, 'https://metacpan.org/release/HAARG/Moo-2.003004' ],
  '/dist/Moo-2.003004/'                           => [ 301, 'https://metacpan.org/release/HAARG/Moo-2.003004' ],
  '/dist/Moo-2.003004/lib/Moo.pm'                 => [ 301, 'https://metacpan.org/pod/release/HAARG/Moo-2.003004/lib/Moo.pm' ],
  '/dist/Moo-2.003004/maint/Makefile.PL.include'  => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004/maint/Makefile.PL.include?raw=1' ],
  '/dist/Moo-2.003004/Changes'                    => [ 301, 'https://metacpan.org/source/HAARG/Moo-2.003004/Changes?raw=1' ],

  '/dist/DBIx-Class-Tutorial/'
    => [ 302, 'https://metacpan.org/release/JROBINSON/DBIx-Class-Tutorial-0.0001' ],
  '/~jrobinson/DBIx-Class-Tutorial/'
    => [ 302, 'https://metacpan.org/release/JROBINSON/DBIx-Class-Tutorial-0.0001' ],
  '/~jrobinson/DBIx-Class-Tutorial/lib/DBIx/Class/Tutorial.pod'
    => [ 302, 'https://metacpan.org/pod/release/JROBINSON/DBIx-Class-Tutorial-0.0001/lib/DBIx/Class/Tutorial.pod' ],
  '/perldoc/DBIx::Class::Tutorial'
    => [ 302, 'https://metacpan.org/pod/release/JROBINSON/DBIx-Class-Tutorial-0.0001/lib/DBIx/Class/Tutorial.pod' ],

  '/tools'                                         => [ 301, 'https://metacpan.org/' ],
  '/tools/'                                        => [ 301, 'https://metacpan.org/' ],
  '/tools/Moo'                                     => [ 301, 'https://metacpan.org/release/Moo' ],
  '/tools/Moo-2.003004'                            => [ 301, 'https://metacpan.org/release/HAARG/Moo-2.003004' ],

  '/redirect?url=%2F%7Eaallan%2FAstro-FITS-Header-2.6.2%2F'
    => [ 301, 'https://metacpan.org/release/AALLAN/Astro-FITS-Header-2.6.2' ],
  '/redirect?url=/~hernan/Image-Simple-Gradient-0.03/'
    => [ 301, 'https://metacpan.org/release/HERNAN/Image-Simple-Gradient-0.03' ],

  '/dist/Dancer2/lib/Dancer2/Manual.pod'           => [ 301, 'https://metacpan.org/pod/distribution/Dancer2/lib/Dancer2/Manual.pod' ],
);

my $redirect = MetaCPAN::SCORedirect->new;

while (@checks) {
  my ($sco, $meta) = (shift @checks, shift @checks);
  my ($sco_path, $sco_query) = split /\?/, $sco, 2;
  my $got = $redirect->rewrite_url($sco_path, $sco_query);
  is $got->[0], $meta->[0], 'correct response code for '.$sco;
  is $got->[1], $meta->[1], 'correct rewrite for '.$sco;
  diag $got->[2]
    if $got->[2];
}

done_testing;
