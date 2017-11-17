package MetaCPAN::SCO;
use strict;
use warnings;
use Plack::Builder;
use Plack::Request;
use HTTP::Tiny;
use HTML::Entities;
use WWW::Form::UrlEncoded qw(build_urlencoded);

my $VERSION = '0.001000';
my $ua = HTTP::Tiny->new(agent => "metacpan-sco/$VERSION");

sub redirect {
  my ($url, $perm) = @_;
  my $full_url = $url =~ /^\w+:/ ? $url : 'https://metacpan.org/'.$url;
  [ $perm ? 301 : 302, [ 'Location' => $url, 'Content-Type' => 'text/plain' ], ["Moved"]];
}

sub not_found {
  [ 404, ['Content-Type' => 'text/plain'], ['Not Found']];
}

sub is_dist {
  $_[0] !~ /-[0-9][0-9._a-zA-Z]+$/;
}

sub dist_lookup {
  my ($dist, $author) = @_;
  my $release;
  if (is_dist($dist)) {
    #TODO: dist lookup
    $release = $dist;
  }
  else {
    $release = $dist;
    if (wantarray && !$author) {
      #TODO: author lookup
    }
  }
  return wantarray ? ($dist, $author) : $dist;
}

sub has_pod {
  my ($author, $dist, $path) = @_;
  # TODO: pod lookup
  return $path =~ /\.(?:pm|pod)$/;
}

builder {
  enable sub {
    my $app = shift;
    sub {
      my $env = shift;
      my $path = $env->{PATH_INFO} || '';
      return $app->($env)
        unless $path =~ m{^/~};

      my ($author, $dist, $file_path)
        = $path =~ m{^/\~([^/]+)(?:/?|/([^/]+)(?:/?|/(.+)))$};
      $author = uc $author;

      return redirect "author/$author", 1
        if !defined $dist;

      my $release = dist_lookup($dist, $author);

      return redirect "release/$author/$release"
        if !defined $file_path;

      return redirect "module/$author/$release/$file_path"
        if has_pod($author, $dist, $file_path);

      # XXX: should this be a raw link?
      return redirect "source/$author/$release/$file_path";
    };
  };
  mount '/perldoc' => sub {
    my $env = shift;

    return redirect "/pod/$env->{QUERY_STRING}", 1
      if length $env->{QUERY_STRING};

    return redirect "/pod$env->{PATH_INFO}", 1
      if length $env->{PATH_INFO};

    # should 404
    return redirect "/perldoc", 1;
  };
  mount '/src' => sub {
    my $env = shift;
    my $path = $env->{PATH_INFO} || '';
    return redirect ''
      if $path =~ m{^/?$};

    my ($author, $dist, $file_path) 
      = $path =~ m{^/([^/]+)(?:/?|/([^/]+)(?:/?|/(.+)))$};
    $author = uc $author;

    # XXX should these be raw?

    return redirect "author/$author/releases"
      if !defined $dist;

    my $release = dist_lookup($dist, $author);

    return redirect "source/$author/$release"
      if !defined $file_path;

    return redirect "source/$author/$release/$file_path";
  };
  mount '/dist' => sub {
    my $env = shift;
    my $path = $env->{PATH_INFO} || '';
    return redirect ''
      if $path =~ m{^/?$};

    my ($dist, $file_path) 
      = $path =~ m{^/([^/]+)(?:/?|/(.+))$};

    if (is_dist($dist)) {
      return redirect "release/$dist"
        if !defined $file_path;

      return redirect "pod/distribution/$dist/$file_path"
        if has_pod(undef, $dist, $file_path);

      #XXX: we don't have an unversioned source URL
      my ($author, $release) = dist_lookup($dist);
      return redirect "source/$author/$release/$file_path";
    }
    else {
      my ($author, $release) = dist_lookup($dist);
      return redirect "release/$author/$release"
        if !defined $file_path;

      return redirect "pod/release/$author/$release/$file_path"
        if has_pod($author, $dist, $file_path);

      return redirect "source/$author/$release/$file_path";
    }
  };
  mount '/CPAN' => sub {
    my $env = shift;
    my $path = $env->{PATH_INFO} || '';
    return redirect "https://cpan.metacpan.org$path";
  };
  mount '/recent' => sub {
    my $env = shift;
    my $path = $env->{PATH_INFO} || '';
    my $req = Plack::Request->new($env);
    return redirect "/recent$path"
      unless $req->query_parameters->get('d');
    #TODO: do something with the date
    return redirect "/recent"
  };
  mount '/diff' => sub {
    my $env = shift;
    my $req = Plack::Builder->new($env);
    my ($from_release, $from_author) = dist_lookup($req->parameters->get('from'));
    my ($to_release, $to_author) = dist_lookup($req->parameters->get('to'));

    return redirect "diff/file?".build_urlencoded(
      source => "$from_author/$from_release",
      target => "$to_author/$to_release",
    );

    #http://search.cpan.org/grep?cpanid=TIMB&release=DBI-1.634&string=welp&i=1&F=1&n=1&C=2
  };
  mount '/grep' => sub {
    my $env = shift;
    my $req = Plack::Builder->new($env);
    my $author = $req->parameters->get('cpanid');
    my $release = $req->parameters->get('release');
  };
  mount '/' => sub {
    my $env = shift;
    (my $path = $env->{PATH_INFO} || '') =~ s{^/}{};
    for ($path) {
      s{^mirror$}{mirrors}
        or s{^uploads\.rdf}{feed/recent}
        or s{^faq\.html$}{about/faq}
        or s{^feedback$}{about/contact}
        or s{^rss/search\.rss$}{feed/recent?format=RSS&version=0.91} #XXX currently unsupported
    }
    return redirect $path;
  };
};

__END__

http://search.mcpan.org/~timb/DBI_AdvancedTalk/

http://cpansearch.perl.org/src/TIMB/DBI-1.636/

http://search.cpan.org/search?query=dbi&mode=all
http://search.cpan.org/search?query=dbi&mode=module
http://search.cpan.org/search?query=dbi&mode=dist
http://search.cpan.org/search?query=timb&mode=author
http://search.cpan.org/search?q={searchTerms};s={startIndex}
http://search.cpan.org/search?m=all&q=hi&n=100&s=101
http://search.cpan.org/search?mode=module&format=xml&query=LWP
http://search.cpan.org/api/module/Dancer
http://search.cpan.org/api/dist/Dancer
http://search.cpan.org/api/author/SUKRIA
http://search.cpan.org/author/
http://search.cpan.org/author/?Q
http://search.cpan.org/pod2html


#annocpan
#cpanforum
#related modules (from perlmonks)
#rt count classifications
#license link
#author browser
#manifest viewer
