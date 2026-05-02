requires 'CPAN::DistnameInfo';
requires 'Config::General';
requires 'Config::ZOMG';
requires 'Cpanel::JSON::XS';
requires 'HTML::Entities';
requires 'HTTP::Tiny';
requires 'IO::Socket::SSL' => 1.42;
requires 'JSON::MaybeXS';
requires 'Log::Contextual';
requires 'Log::Log4perl';
requires 'Moo';
requires 'Mozilla::CA';
requires 'Net::SSLeay' => 1.49;
requires 'Plack::Builder';
requires 'Plack::Request';
requires 'URL::Encode';
requires 'URL::Encode::XS';
requires 'WWW::Form::UrlEncoded';

on test => sub {
    requires 'Test::More';
    requires 'Test::Differences';
    requires 'Test::Deep';
};

on develop => sub {
    requires 'Perl::Critic';
    requires 'Perl::Tidy';
    requires 'App::perlimports';
};
