#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use WWW::Ofoto;
use DateTime;

my $email = $ENV{WWW_OFOTO_EMAIL};
my $passwd = $ENV{WWW_OFOTO_PASSWD};

plan skip_all => "- valid Ofoto account needed for online tests. To enable tests set WWW_OFOTO_EMAIL and WWW_OFOTO_PASSWD environment variables."
		unless $email && $passwd;
plan tests => 6;

# create client with ordered list of arguements
my $ofoto = WWW::Ofoto->new( { email => $email, passwd => $passwd } );
isa_ok $ofoto, 'WWW::Ofoto';

my $result = $ofoto->login();
ok $result, "successfull login";

my $title = 'new ' . localtime(time);
my $desc  = 'test album';
my $date  = DateTime->now;
my $pics  = ['t/pics/test1.jpg','t/pics/test2.jpg'];

$result = $ofoto->upload_new_album( {
		title => $title,
		desc  => $desc,
		date  => $date,
		pics  => $pics,
	} );

is $result, scalar @$pics, "successfully upload";

my $albums = $ofoto->list_albums;
ok $albums->{$title}, "list albums found new album";
ok $albums->{$title}->{count} == scalar @$pics, "correct count returned";
is( $albums->{$title}->{date}->ymd, $date->ymd, "dates are equal" )
		or print "Date(web) = ", scalar $albums->{$title}->{date}, "\n",
		         "Date(int) = ", scalar $date, "\n";

