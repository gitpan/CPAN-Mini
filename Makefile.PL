
use strict;
use warnings;

 BEGIN { require 5.006; } 

use ExtUtils::MakeMaker 6.11;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'CPAN::Mini',
                       'DISTNAME' => 'CPAN-Mini',
                       'AUTHOR' => 'Ricardo SIGNES <rjbs@cpan.org>, Randal Schwartz <merlyn@stonehenge.com>',
                       'ABSTRACT' => 'create a minimal mirror of CPAN',
                       'EXE_FILES' => [
                                        'bin/minicpan'
                                      ],
                       'VERSION' => '1.100593',
                       'LICENSE' => 'perl',
                       'PREREQ_PM' => {
                                        'File::Copy' => 0,
                                        'Getopt::Long' => 0,
                                        'Compress::Zlib' => '1.20',
                                        'URI' => '1',
                                        'Pod::Usage' => '1.00',
                                        'File::HomeDir' => '0.57',
                                        'ExtUtils::MakeMaker' => '6.11',
                                        'File::Spec' => 0,
                                        'Carp' => 0,
                                        'Test::More' => 0,
                                        'LWP::UserAgent' => '5',
                                        'File::Find' => 0,
                                        'File::Temp' => 0,
                                        'File::Path' => '2.04',
                                        'File::Basename' => 0
                                      }
                     );


delete $WriteMakefileArgs{LICENSE}
  unless eval { ExtUtils::MakeMaker->VERSION(6.31) };

WriteMakefile(%WriteMakefileArgs);



