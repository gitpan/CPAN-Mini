use strict;
use warnings;

package CPAN::Mini::App;
BEGIN {
  $CPAN::Mini::App::VERSION = '1.111';
}

# ABSTRACT: the guts of the minicpan command


use CPAN::Mini;
use File::HomeDir;
use File::Spec;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage 1.00;

sub _display_version {
  my $class = shift;
  no strict 'refs';
  print "minicpan",
    ($class ne 'CPAN::Mini' ? ' (from CPAN::Mini)' : q{}),
    ", powered by $class ", $class->VERSION, "\n\n";
  exit;
}


sub run {
  my $version;

  my %commandline;
  GetOptions(
    "c|class=s"   => \$commandline{class},
    "C|config=s"  => \$commandline{config_file},
    "h|help"      => sub { pod2usage(1); },
    "v|version"   => sub { $version = 1 },
    "l|local=s"   => \$commandline{local},
    "r|remote=s"  => \$commandline{remote},
    "d|dirmode=s" => \$commandline{dirmode},
    "qq"          => sub { $commandline{quiet} = 2; $commandline{errors} = 0; },
    'offline'     => \$commandline{offline},
    "q+"          => \$commandline{quiet},
    "f+"          => \$commandline{force},
    "p+"          => \$commandline{perl},
    "x+"          => \$commandline{exact_mirror},
    "t|timeout=i" => \$commandline{timeout},
  ) or pod2usage(2);

  my %config = CPAN::Mini->read_config(\%commandline);
  $config{class} ||= 'CPAN::Mini';

  foreach my $key (keys %commandline) {
    $config{$key} = $commandline{$key} if defined $commandline{$key};
  }

  eval "require $config{class}";
  die $@ if $@;

  _display_version($config{class}) if $version;
  pod2usage(2) unless $config{local} and $config{remote};

  $|++;
  $config{dirmode} &&= oct($config{dirmode});

  $config{class}->update_mirror(
    remote         => $config{remote},
    local          => $config{local},
    trace          => (not $config{quiet}),
    force          => $config{force},
    offline        => $config{offline},
    also_mirror    => $config{also_mirror},
    exact_mirror   => $config{exact_mirror},
    module_filters => $config{module_filters},
    path_filters   => $config{path_filters},
    skip_cleanup   => $config{skip_cleanup},
    skip_perl      => (not $config{perl}),
    timeout        => $config{timeout},
    ignore_source_control => $config{ignore_source_control},
    (defined $config{dirmode} ? (dirmode => $config{dirmode}) : ()),
    (defined $config{errors}  ? (errors  => $config{errors})  : ()),
  );
}


1;

__END__
=pod

=head1 NAME

CPAN::Mini::App - the guts of the minicpan command

=head1 VERSION

version 1.111

=head1 SYNOPSIS

  #!/usr/bin/perl
  use CPAN::Mini::App;
  CPAN::Mini::App->run;

=head1 METHODS

=head2 run

This method is called by F<minicpan> to do all the work.  Don't rely on what it
does just yet.

=head1 SEE ALSO 

Randal Schwartz's original article, which can be found here:

  http://www.stonehenge.com/merlyn/LinuxMag/col42.html

=head1 AUTHORS

=over 4

=item *

Ricardo SIGNES <rjbs@cpan.org>

=item *

Randal Schwartz <merlyn@stonehenge.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2004 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
