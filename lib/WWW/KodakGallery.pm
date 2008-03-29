package WWW::KodakGallery;

###########################################################################
# WWW::KodakGallery
# Mark Grimes
# $Id: KodakGallery.pm,v 1.4 2007/05/04 18:26:05 mgrimes Exp $
#
# A perl module to interact with the ofoto website.
# Copyright (c) 2005  (Mark Grimes).
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.
#
# Formatted with tabstops at 4
#
###########################################################################

use strict;
use warnings;

use base qw(WWW::Ofoto);

our $VERSION = '1.28';

1;

__END__

=head1 NAME

WWW::KodakGallery - A module to interact with the Kodakgallery website

=head1 DESCRIPTION

This module provides a basic interface to the KodakGallery 
website (C<http://wwww.kodakgallery.com/>). It simply subclasses the
C<WWW::Ofoto> module, which provides all the functionality. See
C<WWW::Ofoto> for documentation. You should be able to subsitute C<KodakGallery>
for C<Ofoto>. Or, you could just use the C<WWW::Ofoto> directly; they are
interechangable.

=head1 SEE ALSO

The C<WWW::Ofoto> module.

=head1 AUTHOR

Mark Grimes, E<lt>mgrimes@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by mgrimes

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
