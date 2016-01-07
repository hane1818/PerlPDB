use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => q{PDB},
    AUTHOR          => q{Hane Liu},
    VERSION_FROM    => 'lib/PDB.pm',
    ABSTRACT_FROM   => 'lib/PDB.pm',
    PL_FILES        => {},
    PREREQ_PM       => { 'Test::More' => 0, }
);
