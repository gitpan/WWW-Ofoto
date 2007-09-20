use Module::Build;

my $class = Module::Build->subclass(
    class => 'My::Builder',
    code  => q{
                 sub ACTION_dist {
                     print "Running svn2cl to create ChangeLog\n";
                     system( 'svn2cl' );
                     shift->SUPER::ACTION_dist(@_);
                 }
              },
);

my $build = $class->new(

	module_name		=> 'WWW::Ofoto',
	license			=> 'perl',
	create_readme	=>  1,
	requires		=> {
						'Carp'			=> 0,
						'Hash::Util'	=> 0,
						'DateTime'		=> 0,
						'WWW::Mechanize'=> 1.0,
                        'Class::Accessor::Fast' => 0,
                        'Crypt::SSLeay' => 0,
					},
	recommends		=> {
						'AppConfig'		=> 0,
					},
	);

$build->create_build_script;



