# Copyright 2002-2006, Fred Steinberg, Brown Bear Software
package vEvent;
use strict;

# access subs: summary, startDate, endDate, startTime, duration, recurrence

my %validProps = (
                  summary     => 'text',
                  description => 'popup',
                  categories  => 'category',
                  class       => 'export',   # PUBLIC/PRIVATE/CONFIDENTIAL
                  dtstart     => 'date',     # startDate, time
                  dtend       => '',         # used for end time, maybe
                  rrule       => 'repeat info',
                  exdates     => 'exclusions',
                 );

# Fields will either be scalars, or ref to hashes for props w/params
# E.g.
# (DTSTART => {params => {VALUE => 'DATE'},
#              value  => '20020907'}
#  RRULE   => {value  => 'FREQ=YEARLY;INTERVAL=1;BYMONTH=1;UNTIL=20021031'}
# )

# Pass w/lowercase keys, i.e. not parsed from vCal data
sub new {
    my ($class, %params) = @_;
    foreach (keys %params) {
        if (!exists $validProps{$_}) {
            warn "Bad Prop to vEvent constructor: $_\n";
            return undef;
        }
        # omit undefs
        delete $params{$_} unless defined $params{$_};
    }
    my $self = bless \%params, $class;
}

sub textDump {
    my ($self) = @_;
    return unless defined $self->summary;

    "$self" =~ /.*\(0x(\w+)\)/; # use address for uniqueness
    my $uid = time . "-$1-$$\@$ENV{SERVER_NAME}";

    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday) = gmtime(time);
    my $stamp = sprintf ("%04d%02d%02dT%02d%02d%02dZ",
                         $year + 1900, $mon + 1, $mday, $hour, $min, $sec);

    my %data = (UID         => $uid,
                SUMMARY     => _escape ($self->summary),
                DTSTAMP     => $stamp,
                DTSTART     => $self->startDate,
                );

    $data{DTEND} = $self->endDate
        if defined ($self->endDate);

    $data{DESCRIPTION} = _escape ($self->description)
        if defined ($self->description);

#     $data{CATEGORIES} = _escape ($self->categories)
#         if defined ($self->categories);

    if (defined $self->categories) {
        $data{CATEGORIES} = join ',', map {_escape ($_)} @{$self->categories};
    }

    $data{RRULE} = $self->{rrule}
        if defined ($self->{rrule});

    $data{EXDATE} = $self->{exdates}
        if defined ($self->{exdates});

    $data{ORGANIZER} = $self->{organizer}
        if defined ($self->{organizer});

    my %params;
    foreach (qw/DTSTART DTEND/) {
        if (exists $data{$_} and $data{$_} !~ /T/) {
            $params{$_} = ';VALUE=DATE';
        }
    }

    my $text = "BEGIN:VEVENT\n";
    while (my ($k, $v) = each %data) {
        my $params = $params{$k} || '';
        $text .= "$k$params:$v\n";
    }
    $text .= "END:VEVENT\n";
    $text;
}

# Constructor.
# Pass ref to list of lines, or single string
# Should start w/BEGIN:VEVENT, and end w/END:VEVENT
# Always returns vEvent obj; $self->{error} set on errors
sub parseLines {
    my ($class, $lines) = @_;
    my @lines = ref $lines ? @$lines : split /\r?\n/, $lines;

    my $self = bless {}, $class;
    $self->{raw} = \@lines;

    my ($begunEvent, $begunAlarm);
    foreach my $line (@lines) {
        next if ($line =~ /^\s*$/);     # skip blanks

        my ($propName, $value);
        $line =~ /^\s*([^:]+):(.*)/;
        $propName = $1, $value = $2;

        # if value is empty string, let's just skip it
        next if ($value eq '');

        # This is wrong actually; don't check.

        # name limited to alpha|digit|-|_|/|\s|" before ; and then =/.
#         if ($propName =~ /[^-"\w;=\/\s\.]/) {                # "
#             $self->{error} = "bad LHS: $propName";
#             return $self;
#         }

        # BEGIN
        if (uc($propName) eq 'BEGIN') {
            my $type = $value;
            if ($type !~ /VEVENT|VALARM/i) {
                $self->{error} = 'bad type: $type';
                return $self;
            }
            if ($begunAlarm and uc ($type) eq 'VALARM') {
                $self->{error} = 'too many BEGIN:VALARMs';
                return $self;
            }
            if ($begunEvent and uc ($type) eq 'VEVENT') {
                $self->{error} = 'too many BEGIN:VEVENTs';
                return $self;
            }
            if (uc ($type) eq 'VEVENT') {
                $begunEvent++;
            } else {
                $begunAlarm++;
            }
            next;
        } elsif (!$begunEvent) {
            $self->{error} = 'missing BEGIN';
            return $self;
        }

        if (uc($propName) eq 'END') {
            if (uc($value) eq 'VALARM') {
                $begunAlarm--;
                next;
            }
            return $self;       # END:VEVENT
        }

        # if Name (lhs of :) has params, parse them out into a hash
        if ($propName =~ /;/) {
            my $hash;
            ($propName, $hash) = _parsePropParams ($propName);
            $self->{$propName}->{params} = $hash;
        }

        # And store the value, if it's not just an empty string
        $self->{$propName}->{value} = $value;
        next;
    }
    $self->{error} = 'missing END';
#    $self->{error} .= join ("\n", @{$self->{raw}});
    return $self;
}
sub _parsePropParams {
    my $string = shift;
    my ($propName, @assigns) = split /;/, $string;
    my %params;
    foreach (@assigns) {
        my ($lhs, $rhs) = split /=/;
        $params{$lhs} = $rhs;
    }
    return ($propName, \%params);
}


sub error {
    my $self = shift;
    return undef unless $self->{error};
    return 'vEvent ' . $self->{error} . "\n" . join ("\n", @{$self->{raw}});
}

sub dump {
    my $self = shift;
    my $d = '';

    foreach my $k (sort keys %$self) {
        next if ($k eq 'raw');
        my $v = $self->{$k};
        $d .= sprintf ("%-35s %s\n", $k, $v->{value});
    }
    $d;
}

###########################################################################

sub summary {
    my $self = shift;
    return $self->{summary} if exists ($self->{summary});
    if (defined $self->{SUMMARY}) {
        $self->{summary} = _unescape ($self->{SUMMARY}->{value});
    } else {
        $self->{summary} = undef;
    }
    return $self->{summary};
}

# return undef on parse error, else arrayref of [year, month, day]
sub startDate {
    my $self = shift;
    return $self->{dtstart} if exists ($self->{dtstart});
    if (!exists $self->{DTSTART}) {
        $self->{error} = "DTSTART does not exist";
        return undef;
    }
    ($self->{dtstart}, $self->{startTime}) = $self->_parseDateProp ('DTSTART');
    return $self->{dtstart};
}
sub endDate {
    my $self = shift;
    return $self->{dtend} if exists ($self->{dtend});
    return undef if (!exists $self->{DTEND});
    ($self->{dtend}, $self->{endTime}) = $self->_parseDateProp ('DTEND');
    return $self->{dtend};
}

# return string like "203000";
sub startTime {
    my $self = shift;
    return $self->{startTime} if exists ($self->{startTime});
    $self->startDate;           # parse startDate to get time (if not already)
    return $self->{startTime};
}
# return string like "203000";
sub endTime {
    my $self = shift;
    return $self->{endTime} if exists ($self->{endTime});
    $self->endDate;           # parse endDate to get time (if not already)
    return $self->{endTime};
}
# always return as seconds
# TODO - needs support for weeks; e.g. P2W.
sub duration {
    my $self = shift;
    return $self->{duration} if exists ($self->{duration});
    my $dur = $self->{DURATION}->{value};
    if ($dur) {
        $dur =~ /P(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?/;
        my ($days, $allTime, $hours, $minutes, $seconds) = ($1,$2,$3,$4,$5);
        my $total;
        my %map = (D => 86400,
                   H => 3600,
                   M => 60,
                   S => 1);
        foreach ($days, $hours, $minutes, $seconds) {
            next unless defined;
            /(\d+)(.)/;
            my ($num, $unit) = ($1, $2);
            $total += $num * $map{$unit};
        }
        $self->{duration} = $total;
    } else {
        $self->{duration} = undef;
    }
    return $self->{duration};
}
sub description {
    my $self = shift;
    return $self->{description} if exists ($self->{description});
    if (exists $self->{DESCRIPTION}) {
        $self->{description} = _unescape ($self->{DESCRIPTION}->{value});
    } else {
        $self->{description} = undef;
    }
    return $self->{description};
}

sub categories {
    my $self = shift;
    return $self->{categories} if exists ($self->{categories});
    if (exists $self->{CATEGORIES}) {
        my $x = $self->{CATEGORIES}->{value};
        $x =~ s/([^\\]),/$1$;/g;     # change comma seps to $;
        my @cats = split ($;, $x);
        $self->{categories} = [map {_unescape ($_)} @cats];
    } else {
        $self->{categories} = undef;
    }
    return $self->{categories};
}

# Needed for exporting single vEvent
sub setOrganizer {
    my ($self, $organ) = @_;
    return unless (defined $organ);
    $self->{organizer} = $organ;
}

# clean all this up; self is using things wackily (see end of EventvEvent)
# Modify anything with a Time, shift by $offsetHours (subtract hours)
# Assumes offset is <= 23!
sub convertToUTC {
    my ($self, $offsetHours) = @_;
    return unless defined $self->{dtstart};
    return unless $offsetHours;
    foreach (qw /DTSTART DTEND/) {
        $self->{$_} = {value => $self->{lc ($_)}};
        my ($yymmdd, $time) = $self->_parseDateProp ($_);
        return unless defined $time;
        my ($hh, $mm, $ss) = unpack ("A2A2A2", $time);
        $hh -= $offsetHours;
        if ($hh < 0) {
            my $date = Date->new (@$yymmdd) - 1;
            $yymmdd = [$date->ymd];
            $hh += 24;
        } elsif ($hh > 23) {
            my $date = Date->new (@$yymmdd) + 1;
            $yymmdd = [$date->ymd];
            $hh -= 24;
        }
        $self->{lc ($_)} = sprintf ("%04d%02d%02dT%02d%02d%02dZ",
                                    @$yymmdd, $hh, $mm, $ss);
    }
}

# return ([y,m,d], $time) ; time can be undef
sub _parseDateProp {
    my ($self, $propName) = @_;
    # parse value, depending on params

    my $value = $self->{$propName}->{value};

    my ($yymmdd, $time) = split /T/, $value;

    # TODO params ignored for now!
#    if (exists $self->{$propName}->{params}) {
#         if (($self->{$propName}->{params}->{VALUE} || '') eq 'DATE') {
#             $yymmdd = $self->{$propName}->{value};
#         }
#         elsif ($self->{$propName}->{params}->{TZID}) {
#             # ignore timezone for now! TODO
#             ($yymmdd, $time) = split /T/, $self->{$propName}->{value};
#         }
#    }

    if ($yymmdd) {
        my ($y, $m, $d) = unpack ("A4A2A2", $yymmdd);
        return wantarray ? ([$y, $m, $d], $time) : [$y, $m, $d];
    }

    my $err = '';
    while (my ($l, $r) = %{$self->{$propName}->{params}}) {
        $err .= ";$l=$r";
    }
    $self->{error} = "Unexpected param: $propName$err";
    return;
}
sub _parseDate {
    my $string = shift;
    my ($yymmdd, $time) = split /T/, $string;
    if ($yymmdd) {
        my ($y, $m, $d) = unpack ("A4A2A2", $yymmdd);
        return wantarray ? ([$y, $m, $d], $time) : [$y, $m, $d];
    }
}


# return hash of {key => value} pairs, or undef
sub recurrence {
    my $self = shift;
    return undef unless $self->{RRULE};
    my $retHash = {};
    my @assigns = split /;/, $self->{RRULE}->{value};
    foreach (@assigns) {
        my ($lhs, $rhs) = split /=/;
        if ($lhs eq 'UNTIL') {
            $rhs = _parseDate ($rhs);
        }
        $retHash->{$lhs} = $rhs;
    }
    $retHash;
}

sub exceptionDates {
    my $self = shift;
    return $self->{exdates} if exists ($self->{exdates});
    if (exists $self->{EXDATE}) {
        my @exs;
        foreach my $date (split /;/, $self->{EXDATE}->{value}) {
            push @exs, scalar (_parseDate ($date));
        }
        return \@exs;
    } else {
        $self->{exdates} = undef;
    }
    return $self->{exdates};
}

# remove backslash from \, \; \" \\ and convert \N to "\n"
sub _unescape {
    my $text = shift;
    $text =~ s{\\([,;"\\])}{$1}g;
    $text =~ s{\\N}{\n}g;
    $text;
}

# ESCAPED-CHAR = "\\"   "\;"   "\,"   "\N"   "\n"
sub _escape {
    my $text = shift;
    $text =~ s{([\\;,])}{\\$1}g;
    $text =~ s{\n}{\\n}g;
    $text;
}

1;
