use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'PerlPDB',
    AUTHOR          => q{Hane Liu},
    VERSION_FROM    => 'lib/PerlPDB.pm',
    ABSTRACT_FROM   => 'lib/PerlPDB.pm',
    PL_FILES        => {},
    PREREQ_PM       => { 'Test::More' => 0, }
);
