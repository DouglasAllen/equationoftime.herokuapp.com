# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Utils for day or week block views, with vertical time blocks

package TimeBlock;
use strict;

use CGI;

sub new {
  my ($class, %args) = @_;
  my $self = {cgi     => CGI->new,
              op      => undef,
              dates   => [],
              headers => {},
              events  => {},
              %args};
  $self->{numHeaders} = keys %{$self->{headers}};
  bless $self, $class;
  $self->_initialize;
  $self;
}

sub hourLabels {
    shift->{hourLabels};
}

sub _initialize {
    my $self = shift;
    my $op = $self->{op};
    my $prefs = $op->prefs;
    my ($startHour, $numHours, $increment) =
        $op->getParams (qw (DayViewStart DayViewHours DayViewIncrement));

    $numHours  = $prefs->DayViewHours     || 8 unless defined $numHours;
    $startHour = $prefs->DayViewStart          unless defined $startHour;
    $startHour = 9 unless defined $startHour;
    $increment = $prefs->DayViewBlockSize unless defined $increment;
    $increment = 1 unless ($increment and
                           int (60 / $increment) == 60 / $increment);

    if ($startHour + $numHours > 24) {
        $startHour = 24 - $numHours;
    } elsif ($startHour < 0) {
        $startHour = 0;
    }

    # Convert integer hours to hour strings
    my $milTime = $prefs->MilitaryTime;
    my @hours = ($startHour .. ($startHour + $numHours - 1));
    $self->{_rowClassNames} = [map {"TimeBlockRow$_"} @hours];
    @hours = map {_timeLabel ($_, $milTime)} @hours;
    if ($increment != 1) {
        do {s/:00//} foreach @hours;
    }

    $self->{startHour}  = $startHour;
    $self->{numHours}   = $numHours;
    $self->{increment}  = $increment;
    $self->{minPerRow}  = int (60 / $increment);

    $self->{hourLabels} = \@hours;

    return $self;
}

sub render {
    my $self = shift;
    my $cgi = $self->{cgi};

    my %tablesPerDay;           # key is date; val is "table"
    my %colsPerDay;             # number of columns each day needs
    my %colSpansPerDay;         # colspans for each days events

    my %untimedEvents;
    my $untimedCount = 0;

    # "Process" events for each day; 1 (or more) columns per day
    foreach my $date (@{$self->{dates}}) {
        my $events = $self->{events}->{"$date"};
        my $untimed;
        ($events, $untimed) = $self->filterAndMungeEvents ($events, $date);

        $untimedEvents{"$date"} = $untimed;
        $untimedCount += @$untimed;

        my @colsForDate;         # different columns for this single date
        my (@table, @occupied);
        foreach my $event (@$events) {
            my ($startRow, $numRows) = $self->getRowsForEvent ($event);
            next unless defined $startRow;
            my $column = $self->getColumnForEvent ($event, \@colsForDate);
            $table[$startRow][$column] = [$event, $numRows];

            # Keep track of occupied slots for each event. Used later to
            # determine colspan, if there are multiple columns in day; only
            # conflicting events actually need separate columns.
            for (my $i=0; $i<$numRows; $i++) {
                $occupied[$startRow+$i][$column]++;
            }

            # keep track so we don't put nbsp fillers later
            for (my $i=1; $i<$numRows; $i++) {
                $table[$startRow + $i][$column] = 'fnord';
            }
        }
        $colsPerDay{$date} = @colsForDate || 1; # don't want 0, if no events
        $tablesPerDay{$date} = \@table;

        # Compute colspans
        my @colSpans;
        if ($colsPerDay{$date} > 1) {
            for (my $row=0; $row<@table; $row++) {
                foreach (my $col=1; $col<=$colsPerDay{$date}; $col++) {
                    my $evInfo = $table[$row][$col];
                    next unless ref $evInfo; # skip if no event
                    my $span = 1;
                    COLUMN: for (my $i=$col+1; $i<=$colsPerDay{$date}; $i++) {
                        # check all rows for this event. gack.
                        for (my $r=0; $r<$evInfo->[1]; $r++) {
                            last COLUMN if $occupied[$row+$r][$i];
                        }
                        $span++;
                        for (my $r=0; $r<$evInfo->[1]; $r++) {
                            $table[$row+$r][$i] = 'fnord';
                        }
                    }
                    $colSpans[$row][$col] = $span;
                }
            }
        }
        $colSpansPerDay{$date} = \@colSpans;
    }

    my @rows;

    my $op      = $self->{op};
    my $calName = $op->calendarName;

    my $helpLink = '&nbsp;';
    my $help;
    if ($op->userPermitted ('Edit')) {
        $help = $op->I18N->get ('TimeBlock_DoubleClickEdit');
        if ($help eq 'TimeBlock_DoubleClickEdit') {
            $help = 'You can double-click on an empty cell to add a new ' .
                    'event, or on an existing event to edit it. Look for ' .
                    'the crosshair pointer.';
        }
    }
    elsif ($op->userPermitted ('Add')) {
        $help = $op->I18N->get ('TimeBlock_DoubleClickAdd');
        if ($help eq 'TimeBlock_DoubleClickAdd') {
            $help = 'You can double-click on an empty cell to add a new ' .
                    'event. Look for the crosshair pointer.';
        }
    }
    $helpLink = $cgi->a ({-href => "Javascript:alert (\'$help\')"}, '?')
        if $help;

    # Do header row; first item is cells above hour labels
    my $span = $self->{increment} > 1 ? 2 : 1;
    my @tds = ($cgi->td ({class   => 'HourColumn',
                          colspan => $span}, $helpLink));
    my @untimedTds = ($cgi->td ({class   => 'HourColumn',
                          colspan => $span},
                         '&nbsp;'));
    my $rowSpan = ($self->{numHours} * $self->{increment}) + 1
                  + ($untimedCount ? 1 : 0);
    my $colWidth = int (100 / $self->{numHeaders}) - 1 . '%';
    my $today = Date->todayForTimezone ($op->prefs->Timezone);
    foreach my $date (@{$self->{dates}}) {
        my $headerClassName = ($date == $today) ? 'TodayHeader' : 'DayHeader';
        push @tds, $cgi->td ({class   => $headerClassName,
                              colspan => $colsPerDay{$date},
                              width   => $colWidth,     # IE needs this
                             },
                             $self->{headers}->{$date});
        push @tds, $cgi->td ({class   => 'BlankColumn',
                              rowspan => $rowSpan,
                              width   => '0%'}, ' ')
            unless ($date == $self->{dates}->[-1]);

        my $untimedHTML = '';
        foreach my $ev (Event->sort ($untimedEvents{$date} || [],
                                     $op->prefs->EventSorting)) {
            my ($fg, $bg) = $ev->colors ($calName, $op->prefs, 'no default');
            # Just for $textID
            my ($blah, $textID);
            my $incFrom = $ev->includedFrom || '';
            if ($incFrom ne $calName) {
                ($blah, $blah, $blah, $textID) =
                            $ev->getIncludedOverrides ($op->prefs->Includes);
            }

            my $html = $ev->getHTML ({op => $op,
                               calName   => $calName,
                               date      => $date,
                               prefs     => $op->prefs,
                               i18n      => $op->I18N,
                               textFG    => $fg,
                               textID    => $textID});
            my $cat_class = $ev->primaryCategory || '';
            if ($cat_class) {
                $cat_class =~ s/\W//g; # cats can have wacky chars in them
                $cat_class = "c_$cat_class";
            }
            $untimedHTML .= $cgi->table ({-width => '100%',
                                          -class => $cat_class},
                                         $cgi->Tr ($cgi->td ({bgcolor => $bg},
                                                             $html)));
        }

        my ($ondbl, $cursor);
        unless ($untimedHTML or !$op->userPermitted ('Add')) {
            $ondbl  = $self->_addEventJS ($date, -1, $op);
            $cursor = 'cursor:crosshair;';
        }
        $untimedHTML ||= '&nbsp;';

        push @untimedTds, $cgi->td ({-class   => 'UntimedEventRow',
                                     -style   => $cursor,
                                     -ondblclick => $ondbl,
                                     -colspan => $colsPerDay{$date}},
                                    $untimedHTML);
    }

    push @rows, $cgi->Tr ({align => 'center'}, @tds);
    push @rows, $cgi->Tr ({valign => 'top'}, @untimedTds) if $untimedCount;

    my $showTimes = $op->prefs->TimePlanShowTimes || 'always';

    # And build up the table, one row at a time
    my @hourLabels = @{$self->hourLabels};
    my $multiplier = $self->{increment};
    my @rowClassNames = @{$self->{_rowClassNames}};
    for (my $row=0; $row<($self->{numHours} * $multiplier); $row++) {
        # First, the leftmost hour cell
        my @tds;
        @tds = ($cgi->td ({-class   => 'HourColumn',
                           -width   => '5%',
                           -valign  => 'top',
                           -rowspan => $multiplier},
                          shift @hourLabels))
            unless ($row % $multiplier);

        push @tds, $cgi->td ({-class   => 'MinuteColumn',
                              -width   => '1%',
                              -valign  => 'top'},
                             sprintf (":%02d",    # minute label
                                      $row % $multiplier * 60/$multiplier))
            unless ($multiplier == 1);

        # Then, cells for each day. 1 (or more) columns per day.
        foreach my $date (@{$self->{dates}}) {
            my $nbspSpan = 0;
            for (my $col=1; $col<=$colsPerDay{$date}; $col++) {
                my $eventInfo = $tablesPerDay{$date}[$row][$col];
                if (ref $eventInfo) {
                    # If needed, put spaces which come before event this row
                    if ($nbspSpan) {
                        push @tds, $cgi->td ({-colSpan => $nbspSpan},
                                             '&nbsp;');
                        $nbspSpan = 0;
                    }
                    my $ev = $eventInfo->[0];
                    my ($fg, $bg) = $ev->colors ($calName, $op->prefs);

                    # Just for $textID
                    my ($blah, $textID);
                    my $incFrom = $ev->includedFrom || '';
                    if ($incFrom ne $calName) {
                        ($blah, $blah, $blah, $textID) =
                            $ev->getIncludedOverrides ($op->prefs->Includes);
                    }

                    # Maybe don't display times
                    my $hideTimes;
                    if (lc ($showTimes) eq 'never') {
                        $hideTimes = 1;
                    } elsif (lc ($showTimes eq 'unaligned')) {
                        $hideTimes = 1 unless (($ev->startTime || 0) % 60
                                               or
                                               ($ev->endTime   || 0) % 60);
                    }

                    # If there are conflicting events in a day, there are
                    # multiple columns; but not all events need multiple
                    # cols, so compute colspan.
                    my $colSpan = $colSpansPerDay{$date}[$row][$col];
                    $colSpan ||= 1;

                    my $cat_class = $ev->primaryCategory || '';
                    if ($cat_class) {
                        $cat_class =~ s/\W//g;
                        $cat_class = "c_$cat_class";
                    }

                    push @tds, $cgi->td ({-rowSpan => $eventInfo->[1] || 1,
                                          -colSpan => $colSpan,
#                                          -class   => $cat_class,
                                          -bgcolor => $bg},
                                         $ev->getHTML ({op => $op,
                                                        class => $cat_class,
                                             calName   => $calName,
                                             date      => $date,
                                             prefs     => $op->prefs,
                                             i18n      => $op->I18N,
                                             textFG    => $fg,
                                             textID    => $textID,
                                             hideTimes => $hideTimes,
                                                       }));
                } elsif ($eventInfo and $eventInfo eq 'fnord') {
                    if ($nbspSpan) {
                        my ($ondbl, $cursor);
                        if ($op->userPermitted ('Add')) {
                            $ondbl  = $self->_addEventJS ($date, $row, $op);
                            $cursor = 'cursor:crosshair;';
                        }
                        push @tds, $cgi->td ({-colSpan => $nbspSpan,
                                              -style   => $cursor,
                                              -ondblclick => $ondbl},
                                             '&nbsp;');
                        $nbspSpan = 0;
                    }
                } else {
                    $nbspSpan++; # fill in for multi-row events in other cols.
                }
            }
            if ($nbspSpan) {
                my $data = '&nbsp; &nbsp;'; # workaround for goofy browsers
                my ($ondbl, $cursor);
                if ($op->userPermitted ('Add')) {
                    $ondbl  = $self->_addEventJS ($date, $row, $op);
                    $cursor = 'cursor:crosshair;';
                }
                push @tds, $cgi->td ({-colSpan => $nbspSpan,
                                      -style   => $cursor,
                                      -ondblclick => $ondbl},
                                     $data);
                $nbspSpan = 0;
            }
        }
        push @rows, $cgi->Tr ({-class => shift @rowClassNames},
                              @tds);
    }

     my $html = $cgi->table ({class       => 'EventCells',
                              border      => 1,
                              cellpadding => 2,
                              cellspacing => 1,
                              width       => '100%',
                              cols        => $self->{numHeaders} * 2
                             },
                            @rows);

    # Javascript code for adding events via popup window
    if ($op->userPermitted ('Add')) {
        my $addURL  = "?Op=AddEvent&PopupWin=1&CalendarName=$calName";
        my $jscript = <<END_JS;
<script language="JavaScript">
<!--
    if (editWidth < 100) {
       editWidth = Math.round (screen.width * editWidth / 100);
    }
    if (editHeight < 100) {
       editHeight = Math.round (screen.height * editHeight / 100);
    }
    function addEvent (date, start, end) {
        win = window.open ("$addURL" + "&Date=" + date
                            + "&StartTime=" + start + "&EndTime=" + end,
                           "EditWindow$calName",
                           "scrollbars,resizable," +
                           "width="  + editWidth + "," +
                           "height=" + editHeight);
        win.focus();
    }
// -->
</script>
END_JS

        $html = "$jscript\n$html";
    }

    return $html;
}

sub filterAndMungeEvents {
    my ($self, $events, $date) = @_;

    my (@events, @untimed);

    # First, keep only events with times
    foreach my $event (@$events) {
        if (defined $event->startTime) {
            push @events, $event;
        } else {
            push @untimed, $event;
        }
    }

    my %munged;

    # Keep track of which events (if any) start on previous day.
    foreach (@events) {
        if ($_->Date and $_->Date != $date) {
            my $key = _makeMungedKey ($_);     # incFrom, id, Date
            $munged{$key} ||= 1;
        }
    }

    $self->{displayAtMidnight} = \%munged;

    my $sortOn = $self->{op}->prefs->EventSorting || '';
    my $sorter = EventSorter->new (split ',', $sortOn);

    # Sort on time; if starts on previous day, start time is 0
    # For events that start at same time, sort on sort criteria
    @events = sort {if    ($munged{_makeMungedKey ($a)}) {-1}
                    elsif ($munged{_makeMungedKey ($b)}) {1}
                    else { $a->startTime <=> $b->startTime or
                           $sorter->sortByCriteria ($a, $b) }} @events;
    return (\@events, \@untimed);
}

sub getRowsForEvent {
    my ($self, $event) = @_;
    my $startTime = $self->_displayTime ($event);
    my $endTime   = $event->endTime;

    my $startHour = $self->{startHour};
    my $numHours  = $self->{numHours};

    $endTime = $startTime if (defined $startTime and !defined $endTime);

    $endTime = 1440 if ($endTime < $startTime); # it ends on next day

    # out of bounds; just return;
    return if ($startTime >= ($startHour + $numHours) * 60 or
               $endTime   <  $startHour * 60               or
               ($endTime != $startTime and $endTime == $startHour * 60));

    my ($startRow, $rowSpan, $blah);
    $startRow = int ($startTime / $self->{minPerRow}) -
                                      $startHour * $self->{increment};
    $startRow = 0 if ($startRow < 0);

    my $numRows = $numHours * $self->{increment};

    # round end time to next row increment
    $blah = $endTime / $self->{minPerRow}; # num of rows, if starting at 0
    my $endRow = int $blah;
    $endRow++ unless ($endRow == $blah);

    $endRow -= $startHour * $self->{increment};
    $endRow = $numRows if ($endRow > $numRows);
    $rowSpan = $endRow - $startRow;
    $rowSpan = 1 if $rowSpan == 0;  # for cases where endtime unspecified
    return ($startRow, $rowSpan);
}

# Find which column an event goes in for a particular day; only multiple
# columns per day if there are time conflicts in that day.
# Returns the number of the column, e.g. '3'
sub getColumnForEvent {
    my ($self, $event, $columns) = @_;

    # $columns is list of list of events already placed in each column

    my ($isInColumn, $i);
    foreach my $thisColumn (@$columns) {
        $i++;
        next if $self->_conflicts ($event, $thisColumn);
        push @$thisColumn, $event;
        $isInColumn = $i;
        last;
    }
    unless ($isInColumn) {
        push @$columns, [$event]; # put new listref, w/event in it
        $isInColumn = @$columns;
    }
    return $isInColumn;
}

sub hourControls {
    my ($self, %args) = @_;

    my $cgi   = $self->{cgi};
    my $op    = $self->{op};
    my $i18n  = $op->I18N;
    my $prefs = $op->prefs;
    my $startHour = $self->{startHour};
    my $numHours  = $self->{numHours};
    my $increment = $self->{increment};
    my $showIncrement = $args{ShowIncrement};

    return '' if (($prefs->DayViewControls || '') eq 'hide');

    my $milTime = $prefs->MilitaryTime;

    my @startAtValues = (0..23);
    my %startAtLables = map {$_ =>_timeLabel ($_, $milTime)} @startAtValues;
    my ($hours18, $hour18) = ($i18n->get ('hours'), $i18n->get ('hour'));
    my %displayLabels = map {$_ => "$_ $hours18"} (1..24);
    $displayLabels{1} = "1 $hour18";

    my @increments = $self->getBlockSizeList;
    my %incrementLabels = $self->getBlockSizeLabels ($i18n, \@increments);

    my ($full, $half) = ($numHours, int ($numHours / 2));
    my $backFull = $op->makeURL ({DayViewStart => $startHour - $full});
    my $backHalf = $op->makeURL ({DayViewStart => $startHour - $half});
    my $foreHalf = $op->makeURL ({DayViewStart => $startHour + $half});
    my $foreFull = $op->makeURL ({DayViewStart => $startHour + $full});

    my @links =
        ($cgi->a ({href => $backFull}, "<$full " . $i18n->get ('hours')),
         '&nbsp;',
         $cgi->a ({href => $backHalf}, "<$half " . $i18n->get ('hours')),
         '&nbsp;',
         $cgi->b ($i18n->get ('Shift Hours')),
         '&nbsp;',
         $cgi->a ({href => $foreHalf}, "$half " . $i18n->get('hours') . '>'),
         '&nbsp;',
         $cgi->a ({href => $foreFull}, "$full " . $i18n->get('hours') . '>'));

    my $hourShifts = $cgi->td (\@links);


    # On change, get values and do a GET, not a POST, so can reload
    # from popups w/out annoying "are you aure?" messages from browser
    my $getURL = $op->makeURL ({Op     => 'ShowIt',
                                DayViewIncrement => undef,
                                DayViewStart     => undef,
                                DayViewHours     => undef});
    my $onChangeJS = qq {timeBlockSubmit ()};
    my $html = <<ENDJS;
<script language="Javascript"><!--
function timeBlockSubmit () {
    var xtra = '';
    for (var i=0; i<3; i++) {
        var item = document.TimeBlockControls.elements[i];
        if (item.name == "DayViewIncrement" ||
            item.name == "DayViewStart"     ||
            item.name == "DayViewHours") {
          xtra = xtra + "&" + item.name + "=" + item[item.selectedIndex].value;
        }
    }
    window.location = '$getURL' + xtra;
}
//--></script>
ENDJS


    $html .= $cgi->startform (-name => 'TimeBlockControls');

    if (!$prefs->PrintPrefs) {
        my $incTd = $showIncrement ?
                      $cgi->td ($i18n->get ('Block size: '),
                         $cgi->popup_menu (-name     => 'DayViewIncrement',
                                           -onChange => $onChangeJS,
                                           -default  => $increment,
                                           -values   => \@increments,
                                           -labels   => \%incrementLabels))
                          : '';

        $html .= $cgi->table
            ({align       => 'center',
              width       => '100%',
              cellspacing => 0,
              cellpadding => 0,
              border      => 0},
             $cgi->Tr ({-class => 'DayViewControls',
                        -align   => 'left'},
                       $cgi->td
                       ('&nbsp;' . $i18n->get ('Start at: ') .
                        $cgi->popup_menu (-name     => 'DayViewStart',
                                          -onChange => $onChangeJS,
                                          -default  => $startHour,
                                          -values   => \@startAtValues,
                                          -labels   => \%startAtLables)),
                       $cgi->td
                       ($i18n->get ('Display: '),
                        $cgi->popup_menu (-name     => 'DayViewHours',
                                          -onChange => $onChangeJS,
                                          -default  => $numHours,
                                          -values   => [1..24],
                                          -labels   => \%displayLabels)),
                       $incTd,
                       $hourShifts));
    }

    $html .= $cgi->hidden (-name  => 'CalendarName',
                           -value => $op->calendarName);
    $html .= $op->hiddenDisplaySpecs;
    $html .= $cgi->endform;
    return $html;
}

sub getBlockSizeList {
    my $class = shift;
    return (1,2,3,4,5,6,10,12,15,20,30,60);
}
sub getBlockSizeLabels {
    my ($class, $i18n, $increments) = @_;
    my %labels;
    foreach (@$increments) {
        $labels{$_} = 60 / $_;
        if ($_ != 1) {
            $labels{$_} .= ' ' . $i18n->get ('minute');
        } else {
            $labels{$_} = '1 ' . $i18n->get ('hour');
        }
    }
    return %labels;
}


sub _timeLabel {
    my ($hour, $milTime) = @_;
    my $amPm = '';
    if (!$milTime) {
        $amPm = $hour < 12 ? 'am ' : 'pm ';
        $hour = 12 if $hour == 0;
        $hour -= 12 if ($hour > 12);
    }
    return "$hour:00" . $amPm;
}

# ------------------------------------------------------------------


sub _conflicts {
    my ($self, $event, $col) = @_;
    my ($evStart, $evEnd) = $self->_normTime ($event);
    foreach my $ev (@$col) {
        my ($start, $end) = $self->_normTime ($ev);
        next if ($evStart >= $end);
        next if ($evEnd   <= $start);
        return 1;
    }
    return undef;
}

# Round time to nearest displayed increment
sub _normTime {
    my ($self, $event) = @_;
    my $startTime = $self->_displayTime ($event);
    my $start = int ($startTime / $self->{minPerRow});
    my $blah = defined $event->endTime ? $event->endTime
                                       : ($startTime + 1);
    $blah /= $self->{minPerRow};
    my $end  = int $blah;
    $end++ unless ($end == $blah);
    $end = 24 * $self->{increment} if ($end < $start); # if it ends tomorrow
    return ($start, $end);
}

sub _displayTime {
    my ($self, $event) = @_;
    my $key = _makeMungedKey ($event);
    return $self->{displayAtMidnight}->{$key} ? 0 : $event->startTime;
}

sub _addEventJS {
    my ($self, $date, $row, $op) = @_;
    my ($startTime, $endTime) = (-1, -1);
    if ($row >= 0) {
        $startTime = $self->{startHour} * 60 + $row * $self->{minPerRow};
        $endTime   = $startTime + ($self->{minPerRow} || 60);
    }
    my $js;
    $js = sprintf ("addEvent ('%s', %d, %d)", $date, $startTime, $endTime);
    return $js;
}

sub _makeMungedKey {
    my $event = shift;
    return sprintf ("%s %d %s", $event->includedFrom || '',
                                $event->id, $event->Date || '');

}

1;
