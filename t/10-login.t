#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use WWW::Ofoto;

my $email = $ENV{WWW_OFOTO_EMAIL};
my $passwd = $ENV{WWW_OFOTO_PASSWD};

plan skip_all => "- valid Ofoto account needed for online tests. To enable tests set WWW_OFOTO_EMAIL and WWW_OFOTO_PASSWD environment variables."
		unless $email && $passwd;
plan tests => 2;

# create client with ordered list of arguements
my $ofoto = WWW::Ofoto->new( { email => $email, passwd => $passwd } );
isa_ok $ofoto, 'WWW::Ofoto';

my $result = $ofoto->login();
ok $result, "successfull login";

