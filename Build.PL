use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(

	module_name		=> 'WWW::Ofoto',
	license			=> 'perl',
	create_readme	=>  1,
    create_makefile_pl => 'passthrough',
	requires		=> {
						'Carp'			=> 0,
						'Hash::Util'	=> 0,
						'DateTime'		=> 0,
						'WWW::Mechanize'=> 1.0,
                        'Class::Accessor::Fast' => 0,
                        'Crypt::SSLeay' => 0,
					},
    build_requires  => {        
                        'Test::More'        => 0,
                        'File::Spec'        => 0,
                    },       
	recommends		=> {
						'AppConfig'		=> 0,
					},
	);

$build->create_build_script;



