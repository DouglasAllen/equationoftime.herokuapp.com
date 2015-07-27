# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

# Import Events from ASCII file.
# Currently supports iCal export, Calcium 3.0, MS Outlook formats.

# Fields
#    - type            ('ical', 'calcium30_usa', 'calcium30_euro',
#                       'msoutlook', 'vcalendar')
#    - source          (arrayref or glob)
#    - lines           (arrayref)
#    - errors          (arrayref)
#    - regularEvents   (arrayref)
#    - repeatingEvents (arrayref)

package EventImporter;
use strict;
use vars '$AUTOLOAD';

# Takes a filehandle glob, or ref to a list of lines, and optional type.
# (Or pass hash with specified args.)
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my ($source, $type);
    if (ref ($_[0])) {
        ($source, $type) = @_;
        $type ||= 'calcium30_usa';
    } else {
        my %args = (source => '',
                    type   => 'calcium30_usa',
                    @_);
        $type   = $args{type};
        $source = $args{source};
    }

    $self->{type}   = $type;
    $self->{source} = $source;
    $self->{ignoredCount} = 0;

    $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;                 # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY 

    # Make sure it's a valid field, eh wot?
    die "Bad Field Name to EventImporter! '$name'\n"
        unless {regularEvents   => 1,
                repeatingEvents => 1,
                badLines        => 1,
                lines           => 1,
                errors          => 1,
                ignoredCount    => 1}->{$name};

    $self->{$name} = shift if (@_);
    $self->{$name};
}

# Pass name of who will own events if not specified; undef if none
# Returns list of 3 array refs; (\@regularEvents, \@repeatingEvents, \@bad)
# (@regularEvents is actually list of ($event, $date) pairs)
sub parseEvents {
    my $self = shift;
    my $owner = shift;

    my ($determineSeparator, $parseLine, $parseFirstLine, $preprocessLines,
        $extraArgs);
    if (lc ($self->{type}) eq 'ical') {
        $determineSeparator = \&_iCalSeparator;
        $parseLine = \&_iCalParser;
    } elsif (lc ($self->{type}) =~ /calcium30/) {
        require Text::ParseWords;
        $determineSeparator = \&_calcium30Separator;
        $parseLine = \&_calcium30Parser;
        $extraArgs = ($self->{type} =~ /usa/i);
    } elsif (lc ($self->{type}) =~ 'msoutlook') {
        require Text::ParseWords;
        $determineSeparator = \&_outlookSeparator;
        $parseLine          = \&_outlookParser;
        $parseFirstLine     = \&_outlookFirstLine;
        $preprocessLines    = \&_outlookPreprocess;
        $extraArgs          = ($self->{type} =~ /usa/i);
    } elsif (lc ($self->{type}) eq 'vcalendar') {
        require Calendar::EventvEvent;
        require Calendar::vCalendar::vCalendar;
        my $vcal = vCalendar->new (file => $self->{source});
        my $events = $vcal->events || [];
        my (@repEvents, @regEvents, @badLines);
        foreach my $vEvent (@$events) {
            my ($event, $date) = Event->newFromvEvent ($vEvent);
            unless ($event) {
                if (ref $date eq 'ARRAY') {
                    push @badLines, $date->[0]; # summary
                    $self->{errors}->{$date->[0]} = $date->[1];
                }
                next;
            }
            if ($event->isRepeating) {
                push @repEvents, $event;
            } else {
                push @regEvents, ($event, $date);
            }
        }
        $self->{lines}           = $vcal->raw;
        $self->{regularEvents}   = \@regEvents;
        $self->{repeatingEvents} = \@repEvents;
        $self->{badLines}        = \@badLines;
        return (\@regEvents, \@repEvents, \@badLines);
    } else {
        return;
    }

    # If we don't have the lines yet, suck them all in
    unless ($self->{lines}) {
        if (ref ($self->{source}) eq 'ARRAY') {
            $self->{lines} = $self->{source};
        } elsif (ref ($self->{source})) {         # assume it's an FH
            my $handle = $self->{source};
            my @lines = <$handle>;

            # Sometimes we get a single line separated by control-Ms. Oy.
            @lines = split /\r/, $lines[0] if (@lines == 1);

            $self->{lines} = \@lines;
        } else {
            $self->{lines} = [];
        }
    }

    my (@repEvents, @regEvents, $linenum, @badLines);

    # First check to see if we're splitting on tabs or commas or whatever
    my $separator = &$determineSeparator ($self->{lines});
    # assume error if sep is a word char
    return (\@regEvents, \@repEvents, $separator)
        if (!defined $separator or $separator =~ /\w/);

    # Some formats (Outlook) require preprocessing to handle weirdness
    if ($preprocessLines) {
        $self->{lines} = &$preprocessLines ($self->{lines}, $separator);
    }

    $linenum = -1;      # I prefer doing this to using a for loop. So there.

    # Some formats have special first line
    if ($parseFirstLine) {
        my $firstLine = shift @{$self->{lines}};
        chomp $firstLine;
        $firstLine =~ s/\r+$//;                # some browers stick these on?
        my $status = &$parseFirstLine ($firstLine, $separator);
        $linenum++;
    }

    # Then parse each line!
    foreach (@{$self->{lines}}) {
        $linenum++;
        chomp;
        s/\r+$//;                # some browers stick these on?

        my %fields;

        # Turn off warnings; bad data can cause many undefs
        my $warnState = $^W;
        local $^W = 0;

        my $status = &$parseLine ($_, $separator, \%fields, $extraArgs);

        $^W = $warnState;

        if ($status =~ /^(empty|comment)/) {
            $self->{ignoredCount}++;
            next;
        }
        elsif ($status =~ /^bad/) {
#            warn "Line #$linenum - Error: $status\n";
            push (@badLines, $linenum);
            $self->{errors}->{$linenum} = $status;
            next;
        }
        elsif ($status =~ /^iCalMultiple/) {
            push @repEvents, @{$fields{multipleEvents}};
            next;
        }
        elsif ($status =~ /^skipit/) {
            next;
        }

        my $repeatObject;
        if ($fields{endDate}) {
            $repeatObject = RepeatInfo->new ($fields{theDate},
                                             $fields{endDate},
                                             $fields{period},
                                             $fields{frequency},
                                             $fields{monthWeek},
                                             $fields{monthMonth});
            $repeatObject->exclusionList ($fields{exclusions});
        }

        my $newEvent = Event->new ('text'       => $fields{text},
                                   'link'       => $fields{link},
                                   'popup'      => $fields{popup},
                                   'export'     => $fields{export},
                                   'startTime'  => $fields{startTime},
                                   'endTime'    => $fields{endTime},
                                   'repeatInfo' => $repeatObject,
                                   'drawBorder' => $fields{drawBorder},
                                   'owner'      => $fields{owner} || $owner,
                                   'category'   => $fields{category},
                                   'bgColor'    => $fields{bgColor},
                                   'fgColor'    => $fields{fgColor});

        if ($repeatObject) {
            push @repEvents, $newEvent;
        } else {
            push @regEvents, ($newEvent, $fields{theDate});
        }
    }

    $self->{regularEvents}   = \@regEvents;
    $self->{repeatingEvents} = \@repEvents;
    $self->{badLines}        = \@badLines;

    return (\@regEvents, \@repEvents, \@badLines);
}

sub _iCalSeparator {
    my $lines = shift;
    my ($firstLine, $i);
    do {
        $firstLine = $lines->[$i++];
    } while (defined $firstLine and $firstLine =~ /^$/);
    return substr ($firstLine, 1, 1);
}

sub _iCalParser {
    my ($line, $separator, $hr) = @_;       # hr = "hash ref"
    my ($type, @fields) = split $separator, $line;

    return 'empty' if ($line =~ /^$/);
    return 'bad type' unless ($type =~ /^[SDP]$/i);

    my ($date, $endDate, $text, $popup, $link, $repeatObject,
        $startTime, $startAMPM, $endTime, $endAMPM,
        $border, $bgColor, $fgColor, $category, $skipWeekend,
        $repeatBy, $weekEnd, $monthDays, $daysOfWeek, $repeatType);

    # < Date >< Event Text >[ Popup Text or URL ]
    # [ Start Time ][ AMPM ][ End Time ][ AMPM ]
    # [ Border ][ BgColor ][ FgColor ] [ Category ]
    if ($type =~ /S/i) {
        ($date, $text, $popup,
         $startTime, $startAMPM, $endTime, $endAMPM,
         $border, $bgColor, $fgColor, $category) = @fields;
    }
    # < Start Date >< End Date >< Event Text >[ Popup Text or URL ]
    # [ Start Time ][ AMPM ][ End Time ][ AMPM ]
    # [ Border ][ BgColor ][ FgColor ][ Skip WkEnd ] [ Category ]
    elsif ($type =~ /D/i) {
        ($date, $endDate, $text, $popup,
         $startTime, $startAMPM, $endTime, $endAMPM,
         $border, $bgColor, $fgColor, $skipWeekend, $category) = @fields;
    }
    # < Start Date >< End Date >< Event Text >[ Popup Text or URL ]
    # [Start Time ][ AMPM ][ End Time ][ AMPM ]
    # [ Border ][ BgColor ][ FgColor ]
    # [ RepeatBy ][ WeekEnd ][Month Days ][ Days of Week ][ Repeat Type ] 
    elsif ($type =~ /P/i) {
        ($date, $endDate, $text, $popup,
         $startTime, $startAMPM, $endTime, $endAMPM,
         $border, $bgColor, $fgColor,
         $repeatBy, $weekEnd, $monthDays, $daysOfWeek, $repeatType)
            = @fields;
    }

    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return 'bad text' unless $text;

    my $theDate = Date->new (unpack ('a4a2a2', $date));
    return 'bad date' unless ($theDate->valid);

    $bgColor =~ s/\s//g if $bgColor;     # get rid of spaces
    $fgColor =~ s/\s//g if $fgColor;

    $border = ($border && $border eq 'Y' ? 1 : 0);

    ($link, $popup) = _checkPopup ($popup); # popup might really be a link

    undef $startTime unless $startTime;
    undef $endTime   unless ($startTime and $endTime);

    my ($hour, $minute);
    if ($startTime) {
        if ($startTime =~ /:/) {
            ($hour, $minute) = split (/:/, $startTime);
        } else {
            my $format = (length ($startTime) > 3) ? 'a2a2' : 'a1a2';
            ($hour, $minute) = unpack ($format, $startTime);
        }
        $hour += 12 if ($hour <=12 and $startAMPM =~ /pm/i);
        $startTime = $hour * 60 + $minute;
    }
    if ($endTime) {
        if ($endTime =~ /:/) {
            ($hour, $minute) = split (/:/, $endTime);
        } else {
            my $format = (length ($endTime) > 3) ? 'a2a2' : 'a1a2';
            ($hour, $minute) = unpack ($format, $endTime);
        }
        $hour += 12 if ($hour <=12 and $endAMPM =~ /pm/i);
        $endTime = $hour * 60 + $minute;
    }

    # If there's an endDate, it's repeating
    my ($theEndDate, $period, $frequency, $monthWeek, $monthMonth);

    if ($endDate) {
        $theEndDate = Date->new (unpack ('a4a2a2', $endDate));
        return 'bad end date'        unless ($theEndDate->valid);
        return 'bad start/end dates' unless ($theEndDate >= $theDate);

        # set period
        if ($type =~ /D/) {
            $period = 'day';
        } else {
            $period = 'month' if $repeatBy =~ /M/i;
            $period = 'week'  if $repeatBy =~ /W/i;
            $period = 'year'  if $repeatBy =~ /Y/i;
        }
        if ($daysOfWeek) {  # list of days of the week
            my @days = split /\+/, $daysOfWeek;
            foreach (@days) {
                $_ -= 1;
                $_ = 7 if ($_ == 0);
            }
            $period = join ' ', @days;
        }

        # set frequency, which is ignored if repeating by nth week of month
        $repeatType ||= 1;
        $frequency = 1;
        $frequency = 2 if ($repeatType == 2);
        $frequency = 4 if ($repeatType == 3);

        $monthWeek = 1 if ($repeatType == 4);
        $monthWeek = 2 if ($repeatType == 5);
        $monthWeek = 3 if ($repeatType == 6);
        $monthWeek = 4 if ($repeatType == 7);

        $monthMonth = ($period eq 'month' ? 1 : undef);

        # if $monthDays is set, we need multiple events, since it means
        # we need to repeat on multiple days of the month (or year).
        # oy. Also, don't use $theDate as is, which will always be the
        # 1st of the month.
        if ($monthDays) {
            my @days = split /\+/, $monthDays;
            foreach (@days) {
                $theDate->day ($_);
                $repeatObject = RepeatInfo->new ($theDate, $theEndDate,
                                                 $period, 1);
                my $newEvent = Event->new ('text'       => $text,
                                           'link'       => $link,
                                           'popup'      => $popup,
                                           'export'     => 'Public',
                                           'startTime'  => $startTime,
                                           'endTime'    => $endTime,
                                           'repeatInfo' => $repeatObject,
                                           'drawBorder' => $border,
                                           'owner'      => undef,
                                           'category'   => $category,
                                           'bgColor'    => $bgColor,
                                           'fgColor'    => $fgColor);
                push @{$hr->{multipleEvents}}, $newEvent;
            }
            return 'iCalMultiple';
        }
    }

    $hr->{theDate}    = $theDate;
    $hr->{text}       = $text;
    $hr->{link}       = $link;
    $hr->{popup}      = $popup;
    $hr->{export}     = 'Public';
    $hr->{startTime}  = $startTime;
    $hr->{endTime}    = $endTime;
    $hr->{drawBorder} = $border;
    $hr->{owner}      = undef;
    $hr->{bgColor}    = $bgColor;
    $hr->{fgColor}    = $fgColor;
    $hr->{category}   = $category;

    $hr->{endDate}    = $theEndDate;
    $hr->{period}     = $period;
    $hr->{frequency}  = $frequency;
    $hr->{monthWeek}  = $monthWeek;
    $hr->{monthMonth} = $monthMonth;

    return 'ok';
}

# Find first char that is non-alphanumeric and not a / and not a "
sub _calcium30Separator {
    my $lines = shift;
    my ($firstLine, $i);
    return unless defined $lines->[0];
    do {
        $firstLine = $lines->[$i++];
    } while (defined $firstLine and $firstLine =~ /^$/ or $firstLine =~ /^\#/);
    if ($firstLine =~ m-([^\w/"])-) { # "
        return $1;
    }
    return;
}

sub _calcium30Parser {
    my ($line, $separator, $hr, $isUSA) = @_;       # hr = "hash ref"

    return 'empty'   if ($line =~ /^$/);
    return 'comment' if ($line =~ /^\#/);

    # Quotes might not be escaped, but ParseWords requires
    # them to be. Also, it gets confused by nested \ t pairs. Oy.
#    if ($separator eq "\t") {
        $line =~ s/(?<!\\)(['"])/\\$1/g;  # add \ to ' not preceded by \
        $line =~ s/\\t/\\\\ t/g;
        $line =~ s/\\n/\\\\ n/g;
#    }

    my @fields;
    if ($Text::ParseWords::VERSION > 3.0) {
        @fields = Text::ParseWords::parse_line ($separator, 0, $line);
    } else {
        local($^W) = 0;
        $separator = '\t' if ($separator eq "\t");
        if ($separator =~ /^\s/) {
            @fields = Text::ParseWords::shellwords ($line);
        } else {
            @fields = Text::ParseWords::parse_line ($separator, 0, $line);
        }
    }

    my ($date, $text, $linkOrPopup, $startTime, $startMeridian,
        $endTime, $endMeridian, $border, $bgColor, $fgColor, $export,
        $owner, $category, $includedFrom,
        $endDate, $period, $frequency, $weekOfMonth, $monthPeriod,
        $exclusions);

    if ($isUSA) {
        ($date, $text, $linkOrPopup, $startTime, $startMeridian, $endTime,
         $endMeridian, $border, $bgColor, $fgColor, $export, $owner,
         $category, $includedFrom,
         $endDate, $period, $frequency, $weekOfMonth, $monthPeriod,
         $exclusions) = @fields;
    } else {
        ($date, $text, $linkOrPopup, $startTime, $endTime, $border,
         $bgColor, $fgColor, $export, $owner, $category, $includedFrom,
         $endDate, $period, $frequency, $weekOfMonth, $monthPeriod,
         $exclusions) = @fields;
    }

    my $theDate;
    my ($m, $d, $y);
    if ($isUSA) {
        ($m, $d, $y) = split /[\/\.]/, $date;
    } else {
        ($d, $m, $y) = split /[\/\.]/, $date;     # . or / for date sep.
    }
    $theDate = Date->new ($y, $m, $d);
    return 'bad date' unless ($theDate->valid);

    $text =~ s/^\s+//; $text =~ s/\s+$//;
    return 'bad text' unless $text;

    $bgColor ||= '';
    $fgColor ||= '';
    $bgColor =~ s/^\s+//; $bgColor =~ s/\s+$//;
    $fgColor =~ s/^\s+//; $fgColor =~ s/\s+$//;

    undef $startTime unless $startTime;
    undef $endTime   unless ($startTime and $endTime);

    if ($startTime) {
        my ($h, $m) = split /:/, $startTime;
        return 'bad start time' if ($h < 0 or $h > 23 or $m < 0 or $m > 59);
        if ($isUSA) {
            return 'bad start time' if ($h > 12 and $startMeridian =~ /m/);
            $h += 12 if ($h != 12 and $startMeridian =~ /pm/i);
            $h = 0   if ($h == 12 and $startMeridian =~ /am/i);
        }
        $startTime = $h * 60 + $m;

        if ($endTime) {
            ($h, $m) = split /:/, $endTime;
            return 'bad end time' unless (defined $h and defined $m);
            return 'bad end time' if ($h < 0  or $h > 23 or $m < 0 or $m>59);
            if ($isUSA) {
                return 'bad end time' if (($h > 12 or $h < 1) and
                                          $endMeridian =~ /m/);
                $h += 12 if ($h != 12 and $endMeridian =~ /pm/i);
                $h = 0   if ($h == 12 and $endMeridian =~ /am/i);
            }
            $endTime = $h * 60 + $m;
#            return 'bad start/end times' if ($startTime > $endTime);
        }
    } else {
        undef $startTime;
        undef $endTime;
    }

    $border = (defined ($border) && ($border =~ /[1y]/i)); # 1 or y or Y

    my ($link, $popup) = _checkPopup ($linkOrPopup);

    # Handle multiple categories; caret separated (so - no carets allowed
    # in categories)
    my @cats = split /\^/, $category;
    foreach (@cats) {
        s/^\s+//;               # strip leading/trailing whitespace
        s/\s+$//;
    }
    $category = @cats > 1 ? \@cats : $category;

    # If sep is a TAB, convert \t to actual TAB char.
#    if ($separator eq "\t") {
        $text  =~ s/\\ t/\t/g;
        $popup =~ s/\\ t/\t/g;
        $text  =~ s/\\ n/\n/g;
        $popup =~ s/\\ n/\n/g;
#    }

    $hr->{theDate}    = $theDate;
    $hr->{text}       = $text;
    $hr->{link}       = $link;
    $hr->{popup}      = $popup;
    $hr->{export}     = lc ($export);
    $hr->{startTime}  = $startTime;
    $hr->{endTime}    = $endTime;
    $hr->{drawBorder} = $border;
    $hr->{owner}      = $owner;
    $hr->{bgColor}    = $bgColor;
    $hr->{fgColor}    = $fgColor;
    $hr->{category}   = $category;
    $hr->{incFrom}    = $includedFrom;

    if ($endDate) {
        my $theEndDate;
        my ($m, $d, $y);
        if ($isUSA) {
            ($m, $d, $y) = split /\//, $endDate;
        } else {
            ($d, $m, $y) = split /\//, $endDate;
        }
        $theEndDate = Date->new ($y, $m, $d);

        return "bad end date '$endDate'" unless ($theEndDate->valid);
        return 'bad start/end dates' unless ($theEndDate >= $theDate);

        my @excludedStrings = split /;/, $exclusions if ($exclusions);

        my @exclusions;
        foreach (@excludedStrings) {
            my ($m, $d, $y);
            if ($isUSA) {
                ($m, $d, $y) = split /\//;
            } else {
                ($d, $m, $y) = split /\//;
            }
            my $theEx = Date->new ($y, $m, $d);
            return 'bad exclusion date' unless ($theEx->valid);
            push @exclusions, Date->new ($y, $m, $d);
        }


        if ($period) {
            $weekOfMonth = $monthPeriod = undef;
            if ($period =~ /\d+/) { # for periods like 135 (i.e. mon, wed, fri)
                if ($isUSA) {
                    $period =~ tr/1234567/7123456/;  # Sunday == 1
                }
                $period =~ s/(\d)/$1 /g;
            }
        } elsif ($weekOfMonth) {
            $period = $frequency = undef;
            if ($weekOfMonth =~ /\d+/) {
                $weekOfMonth =~ s/(\d)/$1 /g;
            }
        }

        $period = 'day' unless ($period or $weekOfMonth);
        $frequency += 0;        # make sure numeric
        $frequency = 1  unless ($frequency or $weekOfMonth);

        $hr->{endDate}    = $theEndDate;
        $hr->{period}     = lc ($period);
        $hr->{frequency}  = $frequency;
        $hr->{monthWeek}  = $weekOfMonth;
        $hr->{monthMonth} = $monthPeriod;
        $hr->{exclusions} = $exclusions ? \@exclusions : undef;
    }

    return 'ok';
}

# Assume if any TAB or comma there, it's the separator. (Yes, not too robust.)
sub _outlookSeparator {
    my $lines = shift;
    my ($firstLine, $i);
    return unless defined $lines->[0];
    do {
        $firstLine = $lines->[$i++];
    } while (defined $firstLine and $firstLine =~ /^$/);
    if ($firstLine =~ /([,\t])/) {
        return $1;
    }
    return;
}

# Join lines that break inside double quotes; Outlook 2002 does this?
sub _outlookPreprocess {
    my ($lines, $separator) = @_;
    return $lines if ($separator ne "\t");
    my (@retLines, $previousLine);
    foreach my $line (@$lines) {
        if ($previousLine) {
            $line = $previousLine . $line;
        }
        my $numQuotes = $line =~ tr/\"//; # count double quotes
        my $oddQuotes = ($numQuotes != int ($numQuotes / 2) * 2);
        if ($oddQuotes) {
            $previousLine = $line;
            next;
        }
        undef $previousLine;
        push @retLines, $line;
    }
    return \@retLines;
}

{
 my @fieldNames;
 my %nameMap = ('Subject'          => 'text',
                'Start Date'       => 'theDate',
                'Start Time'       => 'startTime',
                'End Date'         => 'endDate',
                'End Time'         => 'endTime',
                'All day event'    => 'ignoreTimes_outlook',
                'Categories'       => 'category',
                'Reminder on/off'  => undef,
                'Reminder Date'    => undef,
                'Reminder Time'    => undef,
                'Description'      => 'popup',
                'Private'          => undef);

my %popupFields = ('Meeting Organizer'   => undef,
                   'Required Attendees'  => undef,
                   'Optional Attendees'  => undef,
                   'Meeting Resources'   => undef,
                   'Billing Information' => undef,
                   'Location'            => undef);

 sub _outlookFirstLine {
     my ($line, $separator) = @_;
     @fieldNames = Text::ParseWords::parse_line ($separator, 0, $line);
#     @fieldNames = split $separator, $line;
     map {s/\"//g} @fieldNames;
 }

 my $previousLine;

 sub _outlookParser {
     my ($line, $separator, $hr, $isUSA) = @_;       # hr = "hash ref"

     # account for multi-line stuff (only from Yahoo! ?)
     if (defined $previousLine) {
         $line = $previousLine . $line;
         undef $previousLine;
     }

     return 'empty' if ($line =~ /^$/);

     # If sep is a TAB, quotes might not be escaped, but ParseWords requires
     # them to be. Also, it gets confused by nested \ t pairs. Oy.
     if ($separator eq "\t") {
         $line =~ s/([^\\]?)(['"])/$1\\$2/g;         # '
         $line =~ s/\\t/\\\\ t/g;
         $line =~ s/\\n/\\\\ n/g;
     }
     my @fields = Text::ParseWords::parse_line ($separator, 0, $line);

     unless (@fields) {
         $previousLine = $line;
         return 'skipit';
     }

     my ($date, $endDate, $text, $popup, $link, $repeatObject,
         $startTime, $startAMPM, $endTime, $endAMPM,
         $border, $bgColor, $fgColor, $skipWeekend,
         $repeatBy, $weekEnd, $monthDays, $daysOfWeek, $repeatType);

     foreach my $fieldname (@fieldNames) {
         my $value = shift @fields;
         if ($nameMap{$fieldname}) {
             $hr->{$nameMap{$fieldname}} = $value;
         }

         # These are special, and get appended to popup text
         elsif ($value and exists $popupFields{$fieldname}) {
             $hr->{popup} .= "\n$fieldname: $value";
         }
     }

     return 'bad date - blank' unless ($hr->{theDate});
     foreach my $name (qw (theDate endDate)) {
         next unless $hr->{$name};
         my ($m, $d, $y) = split /[\/-]/, $hr->{$name};
#         ($d, $m) = ($m, $d) if ($hr->{$name} =~ /-/);
         ($d, $m) = ($m, $d) if (!$isUSA);
         $hr->{$name} = Date->new ($y, $m, $d);
         return 'bad date' unless ($hr->{$name}->valid);
     }

     # Don't allow end date before start date
     if ($hr->{endDate} and $hr->{endDate} < $hr->{theDate}) {
         return 'bad start/end dates';
     }

     # If it's an "All Day Event", ignore times and fix end date
     if ($hr->{ignoreTimes_outlook} =~ /true/i) {
         delete $hr->{startTime};
         delete $hr->{endTime};
         $hr->{endDate}-- if ($hr->{endDate} and
                              $hr->{endDate} != $hr->{theDate});
     }

     foreach (keys %$hr) {
         next unless defined $hr->{$_};
         $hr->{$_} =~ s/^"//;
         $hr->{$_} =~ s/"$//;
     }

     foreach (qw (text popup)) {
         next unless $hr->{$_};
         $hr->{$_} =~ s/^\s+//;
         $hr->{$_} =~ s/\s+$//;
     }
     return 'bad text' unless $hr->{text};

     # Handle multi-categories; separated by semi-colons
     if ($hr->{category} and $hr->{category} =~ /;/) {
         my @cats = split /;/, $hr->{category};
         $hr->{category} = \@cats;
     }

     # For now, if an event spans days, we just say it ends at midnight. Doh!
#      if (($hr->{endDate} ne $hr->{theDate}) and $hr->{endTime}) {
#          $hr->{endTime} = "11:59:59 PM";
#      }
#      delete $hr->{endDate};

     # If an event spans days, we'll make it repeating, and ignore the end
     # time. (Note that this only happens for MS events w/start time, end
     # time on different days, not actual repeating events.)
     if ($hr->{endDate} and $hr->{endDate} == $hr->{theDate}) {
         delete $hr->{endDate};
     } else {
         delete $hr->{endTime};
         $hr->{period}    = 'day';
         $hr->{frequency} = 1;
     }

#     delete $hr->{endTime} if ($hr->{endTime} eq $hr->{startTime});

     foreach (qw (startTime endTime)) {
         next unless $hr->{$_};
         my ($hour, $min, $sec, $merid) = split /[: ]/, $hr->{$_};
         $merid = $sec if ($sec =~ /m/i); # seconds may or may not be present
         $hour  = 0  if ($hour == 12 and $merid =~ /am/i);
         $hour += 12 if ($hour < 12 and $merid =~ /pm/i);
         $hr->{$_} = $hour * 60 + $min;
     }

     return 'ok';
 }
}

# see if text is link or popup, return them set appropriately
sub _checkPopup {
    my $string = shift;
    my ($popup, $link) = Event->textToPopupOrLink ($string);
    $popup =~ s/^\s+//; $popup =~ s/\s+$//;
    $popup =~ s/\\n/\n/g;
    return ($link, $popup);
}

1;
