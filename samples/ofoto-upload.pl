#!/usr/bin/perl -w

use strict;
use warnings;

use WWW::Ofoto;
use DateTime;
use AppConfig;

my $config = AppConfig->new( 

			# "name|alias|alias<argopts>"
			# =s%    for hash 
			# =s@    for array (list of args)
			# =s     for string (1 arg)
			# !      for boolean (0 args)

			"email=s",
			"passwd=s",
			"title=s",
			"desc=s",
			"date=s",
			"quiet|q!",
			"debug!",
			
		) or die "couldn't setup appconfig";
		
$config->file( $ENV{HOME} . "/.ofoto" )
		or usage("failed to load ~/.ofoto config file\n");
$config->args()
		or usage( "couldn't parse args\n" );
$config->email && $config->passwd
		or usage( "No Ofoto email/passwd supplied\n" );

# create client with ordered list of arguements
my $ofoto = WWW::Ofoto->new( { email => $config->email, passwd => $config->passwd } );
my $result = $ofoto->login() or die "couldn't log into account\n";

my $new_album = 1;
my $title = pick_title();
my $desc  = $config->desc || "";
my $date  = pick_date();
my $pics  = \@ARGV;

confirm() unless $config->quiet;

if( $new_album ){
	$result = $ofoto->upload_new_album( {
			title => $title,
			desc  => $desc,
			date  => $date,
			pics  => $pics,
		} );
} else {
	$result = $ofoto->upload_to_album( {
			title => $title,
			pics  => $pics,
		} );
}

print "$result of ", scalar @ARGV, " photos successfully upload\n";

sub confirm {
	print "About to upload\n";
	print "  Title: $title\n";
	print "  Desc:  $desc\n";
	print "  Date: ", $date->mdy, "\n";
	print "  Pics: ", scalar @ARGV, "\n";
	print "  [", join(", ",@ARGV), "]\n" if $config->debug;
	print "Continue [Yn]: ";
	my $resp = <STDIN>;
	die "User exited.\n" unless $resp =~ /^$|^y(es)?/i;
}

sub pick_title {
	print "Getting list of current albums\n" unless $config->quiet;
	my $albums = $ofoto->list_albums;
	my $title = $config->title || "Photos from " . DateTime->now->mdy("-");

	return $title unless exists $albums->{$title};

	print "Album ($title) already exists. Add to album? [Yn]: ";
	my $resp = <STDIN>;
	die "User exited.\n" unless $resp =~ /^$|^y(es)?/i;

	$new_album = 0;  # TODO: don't like global flags
	return $title;
}

sub pick_date {
	if( $config->date ){
		my ($m,$d,$y) = split m![-/.]!, $config->date;
		$y += 2000 unless $y > 100;   # TODO: fix this y3k bug
		my $date = DateTime->new( year => $y, month => $m, day => $d );
		die "Error parsing the date (", $config->date, ")" unless $date;
		return $date;
	}
	return DateTime->now;
}

sub usage{
	print shift;
	print <<USAGE;
Usage:
USAGE
	exit;
}
