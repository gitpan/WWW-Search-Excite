use ExtUtils::MakeMaker;
WriteMakefile(
              'NAME'	=> 'WWW::Search::Excite',
              'VERSION_FROM' => 'Excite.pm', # finds $VERSION
              'PREREQ_PM' => {
                              'HTML::Form' => 0,
                              'HTML::TreeBuilder' => 0,
                              'WWW::Search' => 2.09,
                             },
             );
