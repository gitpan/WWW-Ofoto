require 5.000;
use ExtUtils::MakeMaker;

WriteMakefile (
	NAME			=> 'WWW::Ofoto',
	VERSION_FROM	=> 'lib/WWW/Ofoto.pm',
	($[ >= 5.005) ?
		(AUTHOR		=> 'Mark V. Grimes (mgrimes@cpan.org)',
		 ABSTRACT	=> 'A perl module to interact with the ofoto website.'
		) : (),
	PREREQ_PM		=> {
						'Carp'			=> 0,
						'Hash::Util'	=> 0,
						'DateTime'		=> 0,
						'WWW::Mechanize'=> 1.0,
					   },
	dist			=> { 
						PREOP	=> ('cvs2cl.pl; '.
									'cp -f ChangeLog $(DISTVNAME);'.
									'rm -f README; '.  								 
									'cp README.head README; '.
									'pod2text -80 < lib/WWW/Ofoto.pm >> README; '.
									'cp -f README $(DISTVNAME); '	# Changes 
								   ),
						},
);

