#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 4;

# Test set 1 -- can we load the library?
BEGIN { use_ok( 'WWW::Ofoto' ); };

# Test set 2 -- create client with ordered list of arguements
my $instance = WWW::Ofoto->new( { email => 'test', passwd => 'test2' } );
isa_ok $instance, 'WWW::Ofoto';

is $instance->email, 'test', 'email accessor ok';
is $instance->passwd, 'test2', 'passwd accessor ok';
