# Copyright 2002-2006, Fred Steinberg, Brown Bear Software
package vCalendar;
use strict;

use Calendar::vCalendar::vEvent;

# Parse vCalendar Events, and only vCalendar Events. Does not attempt to
# support the entire spec, just enough for our purposes!

# Pass a file name, file handle, array of lines, string, or array of vEvents
sub new {
    my ($class, %params) = @_;
    my $self = bless {file     => undef,        # file name, or opened handle
                      lines    => undef,        # array of lines
                      string   => undef,        # scalar; lots of lines
                      rawLines => [],           # array of lines of raw data
                      events   => [],           # array of vEvent objects
                      version  => '2.0',        # 1.0 - vCalendar; 2.0 - iCal
                      info     => {},       # header info e.g. PRODID (ignored)
                      %params}, $class;
    if ($self->{file}) {
        $self->parseFile ($self->{file});
    } elsif ($self->{lines}) {
        $self->parseLines ($self->{lines});
    } elsif ($self->{string}) {
        $self->parseString ($self->{string});
    }
    return $self;
}

# self->{info} is { [ [param=val, param=val...], value] }
#   e.g. self->{info}->{X-WR-CALNAME} is [ ['VALUE=TEXT'], 'US Holidays' ]
#   so calname is $self->{info}->{X-WR-CALNAME}->[1]

# return string
sub textDump {
    my ($self, %params) = @_;
    my $text = "BEGIN:VCALENDAR\n";
    $text .= "PRODID:-//Brown Bear Software//Calcium 3.10//EN\n";
    $text .= "VERSION:$self->{version}\n";
    while (my ($key, $val) = each %params) {
        $text .= "$key:$val\n";
    }
    foreach my $vevent (@{$self->events}) {
        $text .= $vevent->textDump;
    }
    $text .= "END:VCALENDAR\n";
    $text;
}

# Return ref to list of raw data lines
sub raw {
    return shift->{rawLines};
}

# Return ref to list of vEvent objs
sub events {
    return shift->{events};
}

# Return X-WR-CALNAME value, if any
sub getName {
    my ($self) = @_;
    my $name = $self->{info}->{'X-WR-CALNAME'};
    return unless $name;
    return $name->[1];
}

sub error {
    return shift->{error};
}

# Return undef on error; set $self->{error}
sub parseFile {
    my ($self, $file) = @_;
    my $handle;
    if (ref $file) {            # for now, assume a filehandle
        $handle = $file;
    } else {
        require IO::File;
        $handle = IO::File->new ("<$file");
        unless ($handle) {
            $self->{error} = "Can't open $file: $!\n";
            return;
        }
    }

    my @lines = <$handle>;
    $self->parseLines (\@lines);
}

sub parseLines {
    my ($self, $lines) = @_;
    $self->{rawLines} = $lines;

    # merge continuations; slowish, but easy
    my $all = join '', @$lines;
    $all =~ s/\n //g;
    my @lines = split /\r?\n/, $all;

    my @events;

    while (@lines) {
        # keep info until we get to a VEVENT
        my $line;
        do {
            $line = shift @lines;
            if ($line) {
                my ($left, $right) = split /:/, $line;
                my ($name, @params) = split /;/, $left;
                $self->{info}->{$name} = [\@params, $right];
            }
        } while (defined $line and $line !~ /^\s*BEGIN:VEVENT\s*$/i);
        unshift @lines, $line;      # put BEGIN back

        last unless ($line);

        # grab till END:VEVENT
        my @eventLines;
        undef $line;
        do {
            $line = shift @lines;
            push @eventLines, $line;
        } while (defined $line and $line !~ /^\s*END:VEVENT\s*$/i);

        # parse the event!
        my $event = vEvent->parseLines (\@eventLines);
        if ($event->error) {
            $self->{error} = 'Event parse error: ' . $event->error;
            return undef;
        }

        push @events, $event;
    }

    $self->{events} = \@events;
    return 1;
}

sub parseString {
    my ($self, $lines) = @_;
    # parseLines expects newlines at end of each line
    my @lines = map {$_ .= "\n"} split /\r?\n/, $lines;
    $self->parseLines (\@lines);
}

1;
