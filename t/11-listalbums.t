#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

my $email = $ENV{WWW_OFOTO_EMAIL};
my $passwd = $ENV{WWW_OFOTO_PASSWD};

plan skip_all => "- valid Ofoto account needed for online tests. To enable tests set WWW_OFOTO_EMAIL and WWW_OFOTO_PASSWD environment variables."
		unless $email && $passwd;
plan tests => 7;

# can we load the library?
BEGIN { use_ok( 'WWW::Ofoto' ); };

# create client with ordered list of arguements
my $ofoto = WWW::Ofoto->new( { email => $email, passwd => $passwd } );
isa_ok $ofoto, 'WWW::Ofoto';

my $result = $ofoto->login();
ok $result, "successfull login";

# TODO: exception handling
my $albums = $ofoto->list_albums();
my $count = scalar keys %$albums;
ok( $count,"returned $count albums" ) 
	or die "Unable to parse the list of albums, do you have any in your account?";

ok( exists $albums->{'Sample Album'}, "found sample album" ) 
	or die "Your account must contain the 'Sample Album' for tests to work"; 

ok( $albums->{'Sample Album'}->{count} > 0, "non zero photo count");
ok( $albums->{'Sample Album'}->{link} =~ m!^BrowsePhotos!,"link looks ok" )
	or diag("link is: ",  $albums->{'Sample Album'}->{link} );

isa_ok( $albums->{'Sample Album'}->{date}, 'DateTime',
		"date is a valid DateTime object" );
