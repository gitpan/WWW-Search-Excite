use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
              'NAME'	=> 'WWW::Search::Excite',
              'VERSION_FROM' => 'Excite.pm', # finds $VERSION
              'PREREQ_PM' => {
                              'WWW::Search' => 2,
                             },
             );
