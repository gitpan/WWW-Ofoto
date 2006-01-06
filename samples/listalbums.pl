#!/usr/bin/perl

use strict;
use warnings;

my $email = $ENV{WWW_OFOTO_EMAIL};
my $passwd = $ENV{WWW_OFOTO_PASSWD};

use WWW::Ofoto;
my $ofoto = WWW::Ofoto->new( { 
		email => $email,
		passwd => $passwd,
		} ) or die;

# login to your account
$ofoto->login() or die "couldn't login";

# get a hash of your current photo albums
use DateTime;
my $albums = $ofoto->list_albums;
for my $name (keys %$albums){
	my $album = $albums->{$name};
	printf "Album %s has %d photos and was created on %s\n",
		   $name, $album->{count}, $album->{date}->mdy;
}
