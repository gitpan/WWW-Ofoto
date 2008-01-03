package WWW::Ofoto;

###########################################################################
# WWW::Ofoto
# Mark Grimes
# $Id: Ofoto.pm,v 1.12 2007/09/19 17:06:38 mgrimes Exp $
#
# A perl module to interact with the ofoto website.
# Copyright (c) 2005  (Mark Grimes).
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.
#
# Formatted with tabstops at 4
#
###########################################################################

# TODO: get pictures from albums?
# TODO: delete albums?

use strict;
use warnings;

use Carp;
use Hash::Util qw(lock_keys);	# Lock a hash so no new keys can be added
use WWW::Mechanize;
use DateTime;
use base qw(Class::Accessor::Fast);

our $VERSION = '1.27';

my $debug = 0;		# Class level debug flag

# #########################################################
#
#	Fields contains all of the objects data which can be
#	set/retreived by an accessor methods
#
# #########################################################

my %fields = (		# List of all the fields which will have accessors
	'name'		=> undef,		# the name 
	'email'		=> undef,
	'passwd'	=> undef,
    'loggedin'  => undef,
);
__PACKAGE__->mk_accessors( keys %fields );

sub new {
	my $that  = shift;
	my $class = ref($that) || $that;	# Enables use to call $instance->new()
	my $self  = {
		'_permitted'	=> \%fields,
		'_DEBUG' 		=> 0,			# Instance level debug flag
		'_maxupload'	=> 10,
		'_collid_cache'	=> {},
		'_ua'			=> undef,
		%fields,
	};
	bless $self, $class;

	# Lock the $self hashref, so we don't accidentally add a key!
	# TODO: how does this impact inheritance?
	lock_keys( %$self );

	# Work in any arguements to constructor
	my $args = shift || {};
	carp "arguments to WWW::Ofoto must be in a hash ref" unless ref($args) eq 'HASH';
	while(my($k,$v)=each %$args){ $self->$k($v) };

	$self->{_ua} = WWW::Mechanize->new();

	return $self;
}

sub login {
	my $self = shift;
	my $ua = $self->{_ua};

	croak "need to set the email and passwd"
		unless defined $self->email && defined $self->passwd;

	# TODO: should we recreate the user agent in case we want to start over?

	print "Loading the ofoto website\n" if $self->debug;
	$ua->get("http://www.kodakgallery.com/Welcome.jsp") or croak "could not load start page";
	$ua->follow_link( text_regex => qr/Sign in/i ) or croak "could not find Sign In link";

	print "Signing into ofoto account\n" if $self->debug;
	$ua->submit_form( 
				# form_name	=> 'pri-form',   
					# ofoto uses "<form id=" rather than  "<form name="
					# pick out the form by number instead
				form_number	=> 1,
				fields      => {
					email       => $self->email,
					password    => $self->passwd,
				}
			) or croak "error submiting login form";
	$self->dump2file();

	$ua->follow_link( url_regex => qr{MyGallery.jsp} ) or croak "could not find My Kodak link";
	$self->dump2file();

	return $self->{loggedin} = $ua->content =~ m{Welcome };
}

sub _get_page_links {
	my $self = shift;
	my $ua = $self->{_ua};

	#Page: 1
	# <a href="AlbumMenu.jsp?view=1&amp;sort_order=1&amp;ownerid=0&amp;albumsperpage=12&amp;page=2&amp;navfolderid=&amp;displayallyears=&amp;">2</a>
	# <a href="AlbumMenu.jsp?view=1&amp;sort_order=1&amp;ownerid=0&amp;albumsperpage=12&amp;page=3&amp;navfolderid=&amp;displayallyears=&amp;">3</a>
	my @pages = $ua->content =~ m!
			# Page: \s+ 1		\s*
			<a \s+ href="( AlbumMenu.jsp [^"]* ) [^>]* > \d+ </a>
		!gmx;
	# return two sets of links; one from the top, the other from the bottom of the page
	@pages = splice @pages, 0, (scalar @pages / 2);
	print "there are ", scalar @pages, " additional pages of albums\n" if $self->debug;

	return @pages;
}

sub _get_album_links {
	my $self = shift;
	my $ua = $self->{_ua};

	# <p class="albumname"><a href="BrowsePhotos.jsp?&amp;collid=77589001207.98868301207.1136485979825&amp;page=1&amp;sort_order=0&amp;albumsperpage=12&amp;navfolderid=0&amp;ownerid=0">new Thu Jan  6 17:34:39 2005</a></p>
	# <p>
	# 1/7/05
	# (2 photos)</p>
	my @matches =  $ua->content =~ m!
			<p [^>]*>
				<a [^>]* href="(BrowsePhotos.jsp.*?)">	# the link
					(.*?)								# the name
				</a>
			</p>    		\s*
			<p>				\s*
				([\d\/]+)   \s*							# the date
				\((\d+) \s+ photos\) 					# photo count
			</p>
		!gmx;
    for (@matches) { s|-\s*<br\s*/>||gi; }              # remove any hyphen

	print "found ", scalar @matches, " matches\n" if $self->debug;
	return @matches;
}

sub list_albums {
	my $self = shift;
	my $ua = $self->{_ua};

	croak "need to login first" unless $self->{loggedin};

	# $ua->follow_link( text_regex => qr{My Recent Albums|My Albums} ) or croak "Couldn't find the View All Albums link";
	$ua->follow_link( url_regex => qr{AlbumMenu.jsp\?$} ) or croak "Couldn't find the AlbumMenu main link";

	my @matches = $self->_get_album_links;		# pull raw album data off the page
	my $page_count = $self->_get_page_links;	# are there any Page 1 2 3 4 links
	for my $i (2..$page_count+1){
		print "getting next page of albums: $i\n" if $self->debug;
		$ua->follow_link( url_regex => qr/AlbumMenu.jsp/, text => $i )
				or croak "couldn't follow page link: $i";
		push @matches, $self->_get_album_links;
		$self->dump2file;
	}

	# Create the album psuedo object
	my $albums = {};
	while( @matches ){
		@matches % 4 and croak "failed to match albums correctly";
		my ($link, $name, $date, $num) = splice( @matches, 0, 4 );
		my ($month, $day, $year) = split m!/!, $date;
		$year += 2000 if $year < 100;  # TODO: fix this y3k bug
		$link =~ s/&amp;/&/g;		# fix weird formatting of the url
		$albums->{$name} = {
				link	=> $link,
				date	=> DateTime->new( year => $year, month => $month, day => $day ),
				count	=> $num,
			};
	}

	return $albums;
}

sub upload_new_album {
	my $self = shift;
	my $opts = shift;
	my $ua = $self->{_ua};

	# Checks
	croak "need to login first" unless $self->{loggedin};
	my @pics = $self->_confirm_album_opts( $opts, 1 ) or return 0;
	
	$self->_create_new_album( $opts );

	# upload the first 10 images
	my @pics_subset = splice @pics, 0, $self->{_maxupload};
	my $count = $self->_upload_images( @pics_subset );

	return $count unless @pics;

	$count += $self->upload_to_album({
			title	=> $opts->{title},
			pics	=> \@pics,
		});

	return $count;
}

sub _create_new_album {
	my $self = shift;
	my $opts = shift;
	my $ua = $self->{_ua};

	$ua->follow_link( url_regex => qr{Upload.jsp} ) or croak "Couldn't find an upload link";
    $self->dump2file;

	# Create new album
	$ua->submit_form(
		form_name	=> "upload_edit_sniff_form",
		fields		=> {
			month	=>  $opts->{date}->month,
			day		=>  $opts->{date}->day,
			year	=>  $opts->{date}->year,
			desc	=>  $opts->{desc},
			name	=>  $opts->{title},
		}
	) or croak "Couldn't upload form";

    $self->dump2file;
    return;
}

sub _upload_images {
	my ($self, @pics) = @_;
	my $ua = $self->{_ua};

    my $fields;
    my $input_html;

	my $i=0;
	for my $file (@pics){
        my $id = sprintf("%s%d", "image_file_", ++$i);
        $fields->{ $id } = $file;
        $input_html .= "<input class='showFile' type='file' size='0' name='$id' id='$id' value='$file'/>\n";
	}

    # print "input = $input_html\n";
    my $content = $ua->content;
    $content =~ s{
            \s* <input[^>]*id="image_file_1"[^>]*/> \s*
        }{
            $input_html
        }x  or croak "couldn't update the html for input\n";
    # print $content;
    $ua->update_html( $content );


    $fields->{uploadinprogress} = 'true';
    $fields->{num_files} = scalar @pics;

	$ua->submit_form(
            form_name => "ofoto_uploadBrowseform2",
            fields => $fields,
        ) or croak "couldn't upload pictures";

    $self->dump2file;

	my ($count) = $ua->content =~ m!(\d+) photos? ha(?:ve|s) been uploaded to this album!;
	print "uploaded $count pictures\n" if $self->debug;
	$self->dump2file;

	return $count;
}

sub upload_to_album {
	my $self = shift;
	my $opts = shift;

	# Checks
	croak "need to login first" unless $self->{loggedin};
	my @pics = $self->_confirm_album_opts( $opts, 0 ) or return 0;
	my $albums = $self->list_albums;
	croak "album $opts->{title} does not exists" unless $albums->{ $opts->{title} }; 

	my $count = 0;
	while( my @pics_subset = splice @pics, 0, $self->{_maxupload} ){
		$count += $self->_upload_to_album( $opts->{title}, @pics_subset );
	}
	return $count;
}

sub _upload_to_album {
	my ($self, $title, @pics) = @_;
	my $ua = $self->{_ua};

	$ua->follow_link( text => "Upload Photos" ) or croak "couldn't find Upload Photos page";
	$ua->follow_link( text => "add photos to an existing album" ) or croak "couldn't file existing album upload";
	$self->dump2file();

	# uses Javascript dang it! Need to find the collid
	my $collid = $self->_find_upload_album_id( $title );
	
	# Then post to the form
	# need to work some magic first so we can set a hidden/locked field
	my $of = $ua->form_name( "ofotoupload_form" ) or croak "couldn't find the ofotoupload_form";
	my $if = $of->find_input( "collid" ) or croak "couldn't find the collid field of the ofotoupload_form";
	$if->readonly( 0 );

	$ua->submit_form(
		form_name	=> "ofotoupload_form",
		fields		=> {
			collid	=>  $collid,
		}
	) or croak "Couldn't upload the add photo form";
	$self->dump2file();

	my $count = $self->_upload_images( @pics );
	return $count;
}

sub _find_upload_album_id {
	my $self = shift;
	my $title = shift;
	my $ua = $self->{_ua};

	# Have we already found this one?
	return $self->{_collid_cache}->{$title}
			if $self->{_collid_cache}->{$title};

	# Find the album that we want to upload to, looking page by page
	my $c = 1;
	while(! $ua->content =~ /$title/ ){
		# Try the next page
		$ua->follow_link(
				url_regex => qr/UploadSelectAlbum.jsp/,
				text => ++$c,
			) or croak "couldn't find $title after $c pages";
	} 

	# Dig the id out of the html
	# <p class="albumname"><a href="#" onclick="uploadToAlbum('93967094907');document.ofotoupload_form.submit();return false;">new Thu Jan  5 12:29:39 2006</a></p>
    my $content = $ua->content;
    $content =~ s|-\s*<br\s*/>||gi;  # remove any hyphen
	my ($collid) = $content =~ m{uploadToAlbum\('(\d+)'\);document.ofotoupload_form.submit\(\);return false;">$title}; #<};  # no critic
	print "collid is $collid\n" if $self->debug;

	return $self->{_collid_cache}->{$title} = $collid;
}

sub _confirm_album_opts {
	my $self = shift;
	my $opts = shift;
	my $new  = shift;
	
	croak "missing title passed to upload_new_album" unless $opts->{title};
	if( $new ){
	croak "missing desc passed to upload_new_album" unless defined $opts->{desc};
	croak "missing date passed to upload_new_album" unless $opts->{date};
	croak "date must be a DateTime object pass to upload_new_album" unless ref $opts->{date} eq "DateTime";
	}

	return 0 unless ref $opts->{pics} eq 'ARRAY' && scalar @{$opts->{pics}};
	return @{$opts->{pics}};
}

sub DESTROY {
	my $self = shift;
	print "WWW::Ofoto: DESTROY\n" if $self->debug;
    return;
}

# #########################################################
#
# Debug accessor
# 	Can work on both the instance and the class
#		$instance->debug([level]);
#		PACKAGE->debug([level]);
#
# #########################################################

sub debug { 
	my ($self, $level) = @_;

	if($level){				# Set the debug level       
		if( ref($self) ){
			$self->{'_DEBUG'} = $level;
		} else {
			$debug = $level;
		}
		# Call the parent class debug method, TODO: check that it is an inherited class
		# $self->SUPER::debug($debug);
	} else {			# Return the debug level
		return $debug || $self->{'_DEBUG'};
	}
    return;
}

sub dump2file {
	my $self = shift;
	my $file = shift || "t";

	return unless $self->debug;

	open my $f, ">", "$file.html" or croak $!;
	print $f $self->{_ua}->content;
	close $f;

    return;
}

1;

__END__

=head1 NAME

WWW::Ofoto - A module to interact with the Ofoto (now Kodakgallery) website

=head1 SYNOPSIS

  use WWW::Ofoto;
  my $ofoto = WWW::Ofoto->new( { 
		  email => 'me@home.com',
		  passwd => 'mypasswd',
		 } );
  
  # login to your account
  $ofoto->login() or die "couldn't login";

  # get a hash of your current photo albums
  use DateTime;
  my $albums = $ofoto->list_albums;
  for my $album (keys %$albums){
	my $album = $albums->{$name};
	printf "Album %s has %d photos and was created on %s\n",
		   $name, $album->{count}, $album->{date}->mdy;
  }

  # upload photos to a new album
  $count = $ofoto->upload_new_album( {
			title => 'Nov 2005 Beach',
			desc  => 'Pictures from my beach vacation',
			date  => DateTime->now,
			pics  => [ 'pic1.jpg', 'pic2.jpg' ],
		} );

  # upload photos to an existing album
  $result = $ofoto->upload_to_album( {
			title => 'Nov 2005 Beach',
			pics  => [ 'pic3.jpg', 'pic4.jpg'],
		} );

=head1 DESCRIPTION

This module provides a basic interface to the Ofoto (now KodakGallery) 
website (C<http://www.ofoto.com/> or C<http://wwww.kodakgallery.com/>). 
It is based on the excellent C<WWW::Mechanize> module by Andy Lester. 
I also requires the C<DateTime> module to handle dates.

=head1 CLASS METHODS

=over 4

=item new()

  my $ofoto = WWW::Ofoto->new( { 
		  email => 'me@home.com',
		  passwd => 'mypasswd',
	 } );

Constructor - Creates and returns a new C<WWW::Ofoto> object. Typically
you will want to pass in your email and password for the Ofoto site, but 
they can be set later via accessors. Returns the created object or
croaks if there is error.

=back

=head1 OBJECT METHODS

=over 4

=item $ofoto->login()

  $ofoto->login() or die "couldn't login";

Logs into the Ofoto website using the email and password supplied in the
constructor or through the C<email> and C<passwd> accessors. Returns true
if the login was successful.

=item $ofoto->list_albums()

  	my $albums = $ofoto->list_albums;

Retrieves a summary the user's photo albums from the Ofoto website. Which
is returned as a reference to a hash of hashes. Croaks or returns an
empty hash if there is an error.

The photo album titles are the keys to the hash, and C<count>, C<date>,
and C<link> are the keys to the value hash:

  for my $album (keys %$albums){
	my $album = $albums->{$name};
	printf "Album %s has %d photos and was created on %s\n",
		   $name, $album->{count}, $album->{date}->mdy;
  }

=item $ofoto->upload_new_album()

  $count = $ofoto->upload_new_album( {
			title => 'Nov 2005 Beach',
			desc  => 'Pictures from my beach vacation',
			date  => DateTime->now,
			pics  => [ 'pic1.jpg', 'pic2.jpg' ],
		} );

Takes a the relevant data, creates a new album and uploads the pictures
to the Ofoto site. A large number of photos may be sent with each call to
C<upload_new_album>. The method will break the photos into smaller groups
and upload each. 

Will most likely croak if there is any error. The number of photos uploaded
is returned.

=item $ofoto->upload_to_album()

  $result = $ofoto->upload_to_album( {
			title => 'Nov 2005 Beach',
			pics  => [ 'pic3.jpg', 'pic4.jpg'],
		} );

Uploads pictures to an existing photo album based on the c<title>. Otherwise
functions identically to C<upload_new_album>.

Will most likely croak if there is any error. The number of photos uploaded
is returned.

=item $ofoto->email() 

=item $ofoto->passwd() 

=item $ofoto->debug()

Accessors to retrieve or set their internal values.

=item $ofoto->dump2file()

Utility function to print the last webpage loaded by C<WWW::Ofoto>
as is stored via C<content()> in the C<WWW::Mechanize> agent.
See the C<WWW::Mechanize> documentation for more information.

If an arguement is supplied, it is used as the filename to write to
with C<.html> added as an an extention. If not arguement is provied,
it will write to C<t.html>. Any existing file will be overwritten.

=back

=head1 SEE ALSO

The C<WWW::Mechanize> module. C<WWW::KodakGallery> module, which is
just a wrapper around this module.

=head1 AUTHOR

Mark Grimes, E<lt>mgrimes@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Grimes

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
