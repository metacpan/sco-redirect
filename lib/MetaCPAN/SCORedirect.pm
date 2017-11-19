package MetaCPAN::SCORedirect;
use strict;
use warnings;

our $VERSION = '0.001001';
$VERSION =~ tr/_//d;

use HTTP::Tiny;
use WWW::Form::UrlEncoded qw(parse_urlencoded build_urlencoded);
use CPAN::DistnameInfo;

my $ua = HTTP::Tiny->new(agent => "metacpan-sco/$VERSION");

sub is_dist {
  $_[0] !~ /-[0-9][0-9._a-zA-Z]+$/;
}

sub dist_lookup {
  my ($dist, $author) = @_;
  my $release;
  if (is_dist($dist)) {
    # TODO: dist lookup
    $release = $dist;
  }
  else {
    $release = $dist;
    if (wantarray && !$author) {
      # TODO: author lookup
    }
  }
  return wantarray ? ($dist, $author) : $dist;
}

sub has_pod {
  my ($author, $dist, $path) = @_;
  # TODO: pod lookup
  return $path =~ /\.(?:pm|pod)$/;
}

sub rewrite_url {
  my ($url, $query) = @_;
  my @params = length $query ? parse_urlencoded($query) : ();
  pop @params
    if @params == 2 && $query !~ /=/;
  rewrite($url, @params);
}

sub rewrite {
  my ($path, @params) = @_;
  my $new;
  for ($path) {
    if (m{^/(~.*)}) {
      $new = tilde("$1");
    }
    elsif (m{^/perldoc(?:/(.+))?$} && (length $1 || @params == 1)) {
      $new = '/pod/' . (length $1 ? $1 : $params[0]);
    }
    elsif (m{^/src/(.*)$}) {
      $new = length $1 ? src("$1") : '/';
    }
    elsif (m{^/dist(?:/(.*))?$}) {
      $new = length $1 ? dist("$1") : '/';
    }
    elsif (m{^/CPAN(?:/(.*))?$}) {
      $new = 'https://cpan.metacpan.org/' . (length $1 ? $1 : '');
    }
    elsif (m{^/recent(?:/|$)}) {
      my %params = @params;
      if (my $date = $params{d}) {
        #TODO: do something with the date
      }
      $new = '/recent';
    }
    elsif (m{^/diff$}) {
      my %params = @params;
      my ($from_release, $from_author) = dist_lookup($params{from});
      my ($to_release, $to_author) = dist_lookup($params{to});

      $new = '/diff/file?'.build_urlencoded(
        source => "$from_author/$from_release",
        target => "$to_author/$to_release",
      );
    }
    elsif (m{^/grep$}) {
      my %params = @params;
      my ($author, $release, $search, $ignore_case, $fixed, $line_numbers, $context_lines)
        = @params{qw(cpanid release string i F n C)};
      my $dist = CPAN::DistnameInfo->new("$author/$release.tar.gz");
      if ($fixed) {
        $search = quotemeta($search);
      }
      return 'https://grep.metacpan.org/search?'.build_urlencoded(
        q => $search,
        qd => $dist->dist,
        ($ignore_case ? (qci => 'on') : ()),
      );
    }
    elsif (m{^/api(?:/(.*))?$}) {
      # TODO
      # http://search.cpan.org/api/module/Dancer
      # http://search.cpan.org/api/dist/Dancer
      # http://search.cpan.org/api/author/SUKRIA
    }
    elsif (m{^/search$}) {
      my %params = @params;
      my $query = $params{q} // $params{query} // return undef;
      my $mode = $params{m} // $params{mode} // 'all'; # all, dist, module, author
      my $page_size = $params{n} || 100;
      my $page = int((($params{s} // 1) - 1) / ($page_size) + 1);
      my $format = $params{format}; # XXX xml
      $new = '/search'.build_urlencoded(
        q => $query,
        ($page > 1 ? (p => $page) : ()),
        ($page > 1 || $params{n} ? (size => $page_size) : ()),
      );
    }
    else {
      $new
        = m{^/mirror$}          ? '/mirrors'
        : m{^/uploads\.rdf}     ? '/feed/recent'
        : m{^/faq\.html$}       ? '/about/faq'
        : m{^/feedback$}        ? '/about/contact'
        : m{^/rss/search\.rss$} ? '/feed/recent?format=RSS&version=0.91' #XXX currently unsupported
        : undef;
    }
  }
  $new //= '/';
  return $new =~ m{^/} ? ('https://metacpan.org'.$new) : $new;
}

sub src {
  my $path = shift;

  # http://cpansearch.perl.org/src/TIMB/DBI-1.636/
  #
  my ($author, $dist, $file_path) 
    = $path =~ m{^([^/]+)(?:/?|/([^/]+)(?:/?|/(.+)))$};
  $author = uc $author;

  # XXX should these be raw?
  return "/author/$author/releases"
    if !defined $dist;

  my $release = dist_lookup($dist, $author);

  return "/source/$author/$release"
    if !defined $file_path;

  return "/source/$author/$release/$file_path";
}

sub tilde {
  my $path = shift;

  # TODO: http://search.cpan.org/~timb/DBI_AdvancedTalk/

  my ($author, $dist, $file_path)
    = $path =~ m{^\~([^/]+)(?:/?|/([^/]+)(?:/?|/(.+)))$};
  $author = uc $author;

  return "/author/$author",
    if !defined $dist;

  my $release = dist_lookup($dist, $author);

  return "/release/$author/$release"
    if !defined $file_path;

  return "/module/$author/$release/$file_path"
    if has_pod($author, $dist, $file_path);

  # XXX: should this be a raw link?
  return "/source/$author/$release/$file_path";
}

sub dist {
  my $path = shift;

  my ($dist, $file_path)
    = $path =~ m{^([^/]+)(?:/?|/(.+))$};

  if (is_dist($dist)) {
    return "/release/$dist"
      if !defined $file_path;

    return "/pod/distribution/$dist/$file_path"
      if has_pod(undef, $dist, $file_path);

    #XXX: we don't have an unversioned source URL
    my ($author, $release) = dist_lookup($dist);
    return "/source/$author/$release/$file_path";
  }
  else {
    my ($author, $release) = dist_lookup($dist);
    return "/release/$author/$release"
      if !defined $file_path;

    return "/pod/release/$author/$release/$file_path"
      if has_pod($author, $dist, $file_path);

    return "/source/$author/$release/$file_path";
  }
}

1;

## high
# http://search.cpan.org/pod2html

## medium
# http://search.cpan.org/author/
# http://search.cpan.org/author/?Q
# github/rt count classifications
# license link

## low
# http://search.cpan.org/api/module/Dancer
# manifest viewer

## very low
# annocpan
# related modules (from perlmonks)

