#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More tests => 2;

# Test set 1 -- can we load the library?
BEGIN { use_ok( 'WWW::KodakGallery' ) };

# Test set 2 -- create client with ordered list of arguements
my $instance = WWW::KodakGallery->new();
isa_ok $instance, 'WWW::KodakGallery';
