package MetaCPAN::SCORedirect;
use strict;
use warnings;

our $VERSION = '0.001001';
$VERSION =~ tr/_//d;

use HTTP::Tiny ();
use WWW::Form::UrlEncoded qw(parse_urlencoded build_urlencoded);
use CPAN::DistnameInfo ();
use JSON::MaybeXS ();
use URL::Encode qw(url_encode);
use Log::Contextual::Easy::Default;

use Moo;

my $J = JSON::MaybeXS->new(utf8 => 1, pretty => 1, canonical => 1);

has user_agent => (is => 'ro', default => 'metacpan-sco/'.$VERSION);
has ua => (is => 'lazy', default => sub {
  my $self = shift;
  HTTP::Tiny->new(agent => $self->user_agent, verify_SSL => 1);
});
has api_url => (is => 'ro', default => 'https://fastapi.metacpan.org/v1/');
has app => (is => 'lazy');

sub _build_app {
  my $self = shift;
  sub {
    my $env = shift;
    my $result = $self->rewrite_url($env->{PATH_INFO}//'/', $env->{QUERY_STRING});
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
    if ($result->[0] == 302) {
      push @headers,
        'Cache-Control'     => 'max-age=3600',
      ;
    }
    elsif ($result->[0] == 200) {
      push @headers,
        'Cache-Control'     => 'max-age=3600',
      ;
    }
    return [ $result->[0], \@headers, [ $body ] ];
  }
};


sub is_dist {
  my $info = CPAN::DistnameInfo->new($_[0].'.tar.gz');
  return !defined $info->version;
}

sub find_dev {
  my ($self, $dist, $author) = @_;
  my $query = {
    query => {
      bool => {
        must => [
          {
            term => {
              distribution => $dist,
            },
          },
          ($author ? {
            term => {
              author => $author,
            },
          } : ()),
        ],
      },
    },
    sort => [ { date => 'desc' } ],
    size => 1,
    fields => [ qw(name author) ],
  };
  my $res = $self->ua->post($self->api_url.'release', {
    content => $J->encode($query),
  });
  die [ $res->{status} ]
    unless $res->{status} == 200;

  my $rel = $J->decode($res->{content});
  my $release = $rel->{hits}{hits}[0]{fields} or die [ 404 ];

  return ($release->{name}, $release->{author});
}

sub dist_lookup {
  my ($self, $dist, $author) = @_;
  my $release;
  my $is_latest;
  if (is_dist($dist)) {
    my $res = $self->ua->get($self->api_url.'release/latest_by_distribution/'.url_encode($dist));
    my $latest = $res->{status} == 200 && $J->decode($res->{content})->{release};
    if ($author) {
      if ($latest && $latest->{author} eq $author) {
        $release = $latest->{name};
        $is_latest = 1;
      }
      else {
        ($release, $author) = $self->find_dev($dist, $author);
        # XXX: search for latest by author
      }
    }
    else {
      if ($latest) {
        $release = $latest->{name};
        $author = $latest->{author};
        $is_latest = 1;
      }
      else {
        ($release, $author) = $self->find_dev($dist);
      }
    }
  }
  else {
    $release = $dist;
    if (wantarray && !$author) {
      my $query = {
        query => {
          bool => {
            must => [
              {
                term => {
                  name => $release,
                },
              },
              {
                term => {
                  authorized => JSON::MaybeXS->true,
                },
              },
            ],
          },
        },
        sort => [ { date => 'desc' } ],
        size => 1,
        fields => [ qw(author) ],
      };
      my $json = $J->encode($query);
      my $res = $self->ua->post($self->api_url.'release', {
        content => $json,
      });
      die [ $res->{status} ]
        unless $res->{status} == 200;

      my $rel = $J->decode($res->{content});
      $author = $rel->{hits}{hits}[0]{fields}{author};
    }
  }
  return wantarray ? ($release, $author, $is_latest) : $release;
}

sub has_pod {
  my ($self, $author, $dist, $path) = @_;
  my $res = $self->ua->get($self->api_url."file/$author/$dist/$path");
  return 0
    unless $res->{status} == 200;
  my $file = $J->decode($res->{content});
  return !!($file->{pod_lines} && @{$file->{pod_lines}});
}

sub rewrite_url {
  my ($self, $url, $query) = @_;
  my @params = length $query ? parse_urlencoded($query) : ();
  pop @params
    if @params == 2 && $query !~ /=/;
  my $result;
  eval {
    $result = $self->rewrite($url, @params);
    1;
  } or do {
    $result = ref $@ ? $@ : [ 500, undef, $@ ];
  };
  $result->[1] && $result->[1] =~ s{^/}{https://metacpan.org/};
  $result;
}

sub rewrite {
  my ($self, $path, @params) = @_;
  for ($path) {
    if (m{^/(~.*)}) {
      return $self->tilde("$1");
    }
    elsif (m{^/perldoc(?:/([^/]+)(/.*)?)?$}) {
      if (@params == 1) {
        return [ 301, '/pod/' . $params[0] ];
      }
      elsif (@params || length $2) {
        return [ 404 ];
      }
      elsif (length $1) {
        return [ 301, '/pod/' . $1 ];
      }
      else {
        return [ 301, '/' ];
      }
    }
    elsif (m{^/src/(.*)$}) {
      return length $1 ? $self->src("$1") : [ 301, '/' ];
    }
    elsif (m{^/dist(?:/(.*))?$}) {
      return length $1 ? $self->dist("$1") : [ 301, '/' ];
    }
    elsif (m{^/CPAN(?:/(.*))?$}) {
      return [ 301, 'https://cpan.metacpan.org/' . (length $1 ? $1 : '') ];
    }
    elsif (m{^/recent(?:/|$)}) {
      my %params = @params;
      if (my $date = $params{d}) {
        #TODO: do something with the date
      }
      return [ 301, '/recent' ];
    }
    elsif (m{^/diff$}) {
      my %params = @params;
      return [ 404 ]
        unless $params{from} && $params{to};
      my ($from_release, $from_author) = $self->dist_lookup($params{from});
      my ($to_release, $to_author) = $self->dist_lookup($params{to});

      return [ 301, '/diff/file?'.build_urlencoded(
        target => "$to_author/$to_release",
        source => "$from_author/$from_release",
      ) ];
    }
    elsif (m{^/grep(?:/.*)?$}) {
      my %params = @params;
      my ($author, $release, $search, $ignore_case, $fixed, $line_numbers, $context_lines)
        = @params{qw(cpanid release string i F n C)};
      my $dist = CPAN::DistnameInfo->new("$author/$release.tar.gz");
      if ($fixed) {
        $search = quotemeta($search);
      }
      return [ 301, 'https://grep.metacpan.org/search?'.build_urlencoded(
        q => $search,
        qd => $dist->dist,
        ($ignore_case ? (qci => 'on') : ()),
      ) ];
    }
    elsif (m{^/api(?:/(.*))?$}) {
      return [ 301, 'https://fastapi.metacpan.org/' ]
        if !defined $1;
      return $self->api("$1");
    }
    elsif (m{^/search(?:/.*)?$}) {
      my %params = @params;
      my $query = $params{q} // $params{query} // return undef;
      my $mode = $params{m} // $params{mode} // 'all'; # all, dist, module, author
      my $page_size = $params{n} || 100;
      my $page = int((($params{s} // 1) - 1) / ($page_size) + 1);
      my $format = $params{format}; # XXX xml
      return [ 301, '/search?'.build_urlencoded(
        q => $query,
        ($page > 1 ? (p => $page) : ()),
        ($page > 1 || $params{n} ? (size => $page_size) : ()),
      ) ];
    }
    else {
      return [ 301,
          m{^/$}                        ? '/'
        : m{^/mirror(?:/.*)?$}          ? '/mirrors'
        : m{^/uploads\.rdf(?:/.*)?}     ? '/feed/recent'
        : m{^/faq\.html(?:/.*)?$}       ? '/about/faq'
        : m{^/feedback(?:/.*)?$}        ? '/about/contact'
        : m{^/pod2html(?:/.*)?$}        ? '/pod2html'
        : m{^/rss/search\.rss$}         ? '/feed/recent?format=RSS&version=0.91' #XXX currently unsupported
        : return [ 404 ]
      ];
    }
  }
  return [ 404 ];
}

sub api {
  my ($self, $url) = @_;
  my ($type, $id) = split m{/}, $url, 2;
  if ($type eq 'module') {
    my $res = $self->ua->get('https://fastapi.metacpan.org/v1/module/'.url_encode($id));
    return [ $res->{status} ]
      unless $res->{status} == 200;
    my $data = $J->decode($res->{content});
    my $url = $data->{download_url};
    my $author = $data->{author};
    $url =~ s{.*?/authors/id/./../\Q$author\E/}{};
    return [ $res->{status}, undef, {
      status        => ($data->{maturity} eq 'released' ? 'stable' : 'testing'),
      authorized    => $data->{authorized},
      module        => $id,
      cpanid        => $author,
      version       => $data->{version},
      abstract      => $data->{abstract},
      distvname     => $data->{release},
      archive       => $url,
    } ];
  }
  elsif ( $type eq 'dist' ) {
    my $res = $self->ua->get($self->api_url.'release/versions/'.url_encode($id));
    return [ $res->{status} ]
      unless $res->{status} == 200;
    my $data = $J->decode($res->{content});
    my $latest;
    my @releases = map {
      my $rel = $_;
      if ($rel->{status} eq 'latest') {
        $latest = $rel->{name};
      }
      my $url = $rel->{download_url};
      my $author = $rel->{author};
      $url =~ s{.*?/authors/id/./../\Q$author\E/}{};
      {
        dist        => $id,
        status      => ($rel->{maturity} eq 'released' ? 'stable' : 'testing'),
        released    => $rel->{date}.'Z',
        authorized  => $rel->{authorized},
        version     => $rel->{version},
        archive     => $url,
        distvname   => $rel->{name},
        cpanid      => $author,
      }
    } grep $_->{status} ne 'backpan', @{$data->{releases}};
    return [ $res->{status}, undef, {
      latest => $latest,
      releases => \@releases,
    } ];
  }
  elsif ( $type eq 'author' ) {
    my $author_res = $self->ua->get($self->api_url.'author/'.url_encode($id));
    return [ $author_res->{status} ]
      unless $author_res->{status} == 200;
    my $author = $J->decode($author_res->{content});
    my $release_res = $self->ua->get($self->api_url.'release/all_by_author/'.url_encode($id));
    my $releases = $release_res->{status} == 200 ? $J->decode($release_res->{content})->{releases} : [];
    return [ $author_res->{status}, undef, {
      cpanid => $author->{pauseid},
      name => $author->{name},
      releases => [ map {
        my $rel = $_;
        my $url = $rel->{download_url};
        my $author = $rel->{author};
        $url =~ s{.*?/authors/id/./../\Q$author\E/}{};
        {
          status      => ($rel->{maturity} eq 'released' ? 'stable' : 'testing'),
          authorized  => $rel->{authorized},
          released    => $rel->{date}.'Z',
          dist        => $rel->{distribution},
          cpanid      => $rel->{author},
          version     => $rel->{version},
          archive     => $url,
          distvname   => $rel->{name},
        }
      } grep $_->{status} ne 'backpan', @$releases ],
    }];
  }
  else {
    return [ 404, undef, { error => 'Not found' } ];
  }
}

sub src {
  my ($self, $path) = @_;

  # http://cpansearch.perl.org/src/TIMB/DBI-1.636/
  #
  my ($author, $dist, $file_path)
    = $path =~ m{^([^/]+)(?:/?|/([^/]+)(?:/?|/(.+)))$};
  $author = uc $author;

  return [ 301, "/author/$author" ]
    if !defined $dist;

  (my $release, $author) = $self->dist_lookup($dist, $author);

  my $code = $release eq $dist ? 301 : 302;

  return [ $code, "/source/$author/$release" ]
    if !defined $file_path;

  $file_path =~ s{/\z}{};
  return [ $code, "/source/$author/$release/$file_path" ];
}

sub tilde {
  my ($self, $path) = @_;

  my ($author, $dist, $file_path)
    = $path =~ m{^\~([^/]+)(?:/?|/([^/]+)(?:/?|/(.+)))$};
  $author = uc $author;

  return [ 301, "/author/$author" ],
    if !defined $dist;

  $self->dist_path($dist, $author, $file_path);
}

sub dist {
  my ($self, $path) = @_;
  my ($dist, $file_path)
    = $path =~ m{^([^/]+)(?:/?|/(.+))$};

  $self->dist_path($dist, undef, $file_path);
}

sub dist_path {
  my ($self, $dist, $author, $file_path) = @_;

  (my $release, $author, my $is_latest) = $self->dist_lookup($dist, $author);

  if (is_dist($dist) && $is_latest) {
    return [ 301, "/release/$dist" ]
      if !defined $file_path;

    return [ 301, "/pod/distribution/$dist/$file_path" ]
      if $self->has_pod($author, $dist, $file_path);

    return [ 302, "/source/$author/$release/$file_path" ];
  }

  my $code = $dist eq $release ? 301 : 302;

  return [ $code, "/release/$author/$release" ]
    if !defined $file_path;

  return [ $code, "/pod/release/$author/$release/$file_path" ]
    if $self->has_pod($author, $dist, $file_path);

  # XXX: should this be a raw link?
  return [ $code, "/source/$author/$release/$file_path" ];
}

1;

__END__

## medium
# http://search.cpan.org/author/
# http://search.cpan.org/author/?Q
# github/rt count classifications
# license link

## low
# manifest viewer

## very low
# annocpan
# related modules (from perlmonks)

# TODO: http://search.cpan.org/~timb/DBI_AdvancedTalk/
