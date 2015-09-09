# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Display events for single day for multiple calendars

package DayPlanner;
use strict;

use CGI;
use Calendar::Date;
use Calendar::Event;
use Calendar::Javascript;
use Calendar::Preferences;
use Calendar::Permissions;
use Calendar::DisplayFilter;
use Calendar::TimeBlock;         # for _dayViewControls

sub new {
    my $class = shift;
    my ($op, $startDate, $endDate) = @_;
    my $self = {};
    bless $self, $class;

    my $cgi   = CGI->new;
    my $i18n  = $op->I18N;
    my $prefs = $op->prefs;
    my $milTime = $prefs->MilitaryTime;

    my ($startHour, $numHours) = $op->getParams (qw (DayViewStart
                                                     DayViewHours));

    # Get prefs we need
    $numHours  = $prefs->DayViewHours     || 8 unless defined $numHours;
    $startHour = $prefs->DayViewStart          unless defined $startHour;
    $startHour = 9 unless defined $startHour;

    # if > 12, numhours must be mult. of 2
    if ($numHours > 12) {
        $numHours += $numHours % 2;
    }

    if ($startHour + $numHours > 24) {
        $startHour = 24 - $numHours;
    } elsif ($startHour < 0) {
        $startHour = 0;
    }
    my $minsPerCell = $numHours > 12 ? 10 : 5; # num minutes per table cell

    my $displayStartTime = $startHour * 60;
    my $displayEndTime   = ($startHour + $numHours) * 60;

    my $showTimes = $prefs->TimePlanShowTimes || 'always';

    # Colors and Fonts
    my %fonts;

    $fonts{Event} = [$prefs->font ('BlockEvent')];

    $fonts{Time}     = [$prefs->font ('BlockEventTime')];
    $fonts{Category} = [$prefs->font ('BlockCategory')];

    # Cellsize must be factor or multiple of 60
    if ($minsPerCell !~ /^(1|2|3|5|6|10|12|15|20|30|60|120)$/) {
        $minsPerCell = 10;
    }

    # number cols in hour display portion of table (there is actually 1
    # extra column at left for cal names
    my $numColumns = $numHours * 60 / $minsPerCell;

    my $mainCal  = $op->calendarName;

    my @calNames = sort {lc($a) cmp lc($b)} $prefs->getIncludedCalendarNames;

    unless ($prefs->PlannerHideSelf) {
        unshift @calNames, $mainCal;
    }

    # First row is for hour headers, but if we have multi-hour blocks, use
    # fewer headers
    my @hours;
    my $headHours;
    if ($numHours < 13) {
        $headHours = 1;
        @hours = ($startHour .. ($startHour + $numHours - 1));
    } else {
        $headHours = 2;
        for (my $i=0; $i<$numHours; $i+=2) {
            push @hours, $startHour + $i;
        }
    }

    # Convert integer hours to hour strings
    @hours = map {_timeLabel ($_, $milTime)} @hours;

    my $colWidthPercent = 100 / ($numHours + 1);

    my $row = $cgi->Tr ({-class => 'HourLabels'},
                        $cgi->td ({-align => 'left'},
                                  $i18n->get ('Calendar')),
                        (map {$cgi->td ({-colSpan =>
                                          $numColumns * $headHours / $numHours,
#                                         -width   => $colWidthPercent . '%',
                                        }, $_)} @hours));
    my @theRows = ($row);

    # Get events for all calendars, and make list for each calendar.
    my @allEvents = $op->db->getApplicableEvents ($startDate, $prefs,
                                                  'yesterday');
    my %calEvents;
    foreach my $thisEvent (@allEvents) {
        my $cal = $thisEvent->includedFrom;
        $cal = $mainCal if (!defined $cal);
        $calEvents{$cal} ||= [];
        push @{$calEvents{$cal}}, $thisEvent;
    }

    my $display_filter = DisplayFilter->new (operation => $op);

    # Each calendar gets at least one row; might be more if there are
    # overlapping events. Ignore untimed events for now - FIXME
    foreach my $thisCal (@calNames) {
        my $db   = Database->new ($thisCal);
        my $pref = Preferences->new ($db);
        $pref->Timezone ($prefs->Timezone); # set timezone from user pref
        my @events = @{$calEvents{$thisCal} || []};

        # Filter tentative and private events
        $display_filter->prefs ($pref); # different for each calendar
        @events = $display_filter->filterTentative (\@events);
        @events = $display_filter->filterPrivate (\@events);
        @events = $display_filter->filter_from_params (\@events);

        # Filter out included events, privacy issues
        my @keepers;
        foreach my $event (@events) {
            next unless defined $event;

            # skip included events
            next if defined $event->includedFrom
                        and $event->includedFrom ne $thisCal;

            # if not main cal, check for Privacy
            if ($thisCal ne $mainCal) {
                next if $event->private;
            }
            push @keepers, $event;
        }
        @events = @keepers;

        # Try putting each event in the row. If it conflcts with any events
        # already in the row, go to next row.
        my @rows = ([]);
        foreach my $event (@events) {
            next unless (defined $event->startTime);

            my $startTime = $event->startTime;
            my $endTime = defined $event->endTime ? $event->endTime
                                                  : $startTime;
            $endTime = 1440 if ($endTime < $startTime); # it ends on next day

            next if     ($startTime >= $displayEndTime or
                         $endTime   <= $displayStartTime);

            my $addedIt;
            foreach my $thisRow (@rows) {
                next if _conflicts ($event, $thisRow);
                push @$thisRow, $event;
                $addedIt++;
                last;
            }

            unless ($addedIt) {
                my $newRow = [];
                push @$newRow, $event;
                push @rows, $newRow;
            }
        }

        # Now we have array of rows for this calendar. Make them into Trs
        my $numRows = @rows;
        my $firstRow = 1;
        my @trs;
        foreach my $thisRow (@rows) {
            my $lastCol = 0;
            my @tds;

            # Make sure events in the row are sorted by time!
            $thisRow = [sort {$a->startTime <=> $b->startTime} @$thisRow];

            foreach my $event (@$thisRow) {
                my ($start, $span, $blah);

                my $startTime = $event->startTime;
                my $endTime   = $event->endTime;

                $endTime = 1440 if (defined $endTime and
                                    $endTime < $startTime); # ends on next day

                $endTime ||= $startTime;

                $start = int (($startTime - $startHour * 60) / $minsPerCell);
                $blah = ($endTime - $startTime) / $minsPerCell;
                $span = int ($blah);
                $span++ unless ($span == $blah);
                $span = 1 if ($span <= 0);
                if ($lastCol < $start) {
                    my %args = (-colSpan => $start - $lastCol);
                    if ($op->userPermitted ('Add')) {
                        my $x = $startHour * 60 + $lastCol * $minsPerCell;
                        $args{-ondblclick} = sprintf (
                                          "addEvent ('%s', '%s', %d, %d)",
                                          $thisCal, $startDate, $x, $x + 60);
                        $args{-style} = 'cursor:crosshair;';
#                        $args{-style} = 'cursor:move;';
                    }
                    push @tds, $cgi->td (\%args, '&nbsp;');
                    $lastCol = $start;
                }

                # See where we really started
                if ($start < $lastCol) {
                    $span -= $lastCol - $start;
                    $start = $lastCol;
                }

                # Don't go past the edge
                if ($lastCol + $span > $numColumns) {
                    $span = $numColumns - $lastCol;
                }

                my ($fg, $bg) = $event->colors ($thisCal, $prefs);

                # Maybe don't display times
                my $hideTimes;
                if (lc ($showTimes) eq 'never') {
                    $hideTimes = 1;
                } elsif (lc ($showTimes eq 'unaligned')) {
                    $hideTimes = 1 unless (($event->startTime || 0) % 60
                                           or
                                           ($event->endTime   || 0) % 60);
                }

                my %eventSettings = (calName => $thisCal,
                                     op      => $op,
                                     date    => $startDate,
                                     prefs   => $prefs,
                                     i18n    => $i18n,
                                     textFG  => $fg,
                                     hideTimes    => $hideTimes,
                                     eventFace    => $fonts{Event}->[0],
                                     eventSize    => $fonts{Event}->[1],
                                     timeFace     => $fonts{Time}->[0],
                                     timeSize     => $fonts{Time}->[1],
                                     categoryFace => $fonts{Category}->[0],
                                     categorySize => $fonts{Category}->[1]);

                # to get privacy stuff right; cache problem in Event::GetHTML
                $event->includedFrom ($thisCal . ' ');

                my $td = $cgi->td ({-align   => 'center',
                                    -colSpan => $span,
                                    -bgColor => $bg},
                                   $event->getHTML (\%eventSettings));
                $lastCol += $span;
                push @tds, $td;
            }
            if ($lastCol < $numColumns) {
                my %args = (-colSpan => $numColumns - $lastCol);
                if ($op->userPermitted ('Add')) {
                    my $x = $startHour * 60 + $lastCol * $minsPerCell;
                    $args{-ondblclick} = sprintf (
                                          "addEvent ('%s', '%s', %d, %d)",
                                          $thisCal, $startDate, $x, $x + 60);
                    $args{-style} = 'cursor:crosshair;';
                }
                push @tds, $cgi->td (\%args, '&nbsp;');
            }
            my $calName = '';
            if ($firstRow) {
                my $data;
                if (Permissions->new ($thisCal)->permitted ($op->getUsername,
                                                            'Add')) {
                    $data = $cgi->a ({-href =>
                                      $op->makeURL ({Op   => 'ShowDay',
                                                     Date => $startDate,
                                                     ViewCal     => $mainCal,
                                                     CalendarName=>$thisCal})},
                                      "<span>$thisCal</span>");
                } else {
                    $data = "<span>$thisCal</span>";
                }
                $calName = $cgi->td ({-class   => 'CalendarLabels',
                                      -rowSpan => $numRows,
                                      -width   => '10%'},
                                     $data);
                undef $firstRow;
            }
            push @theRows, $cgi->Tr ($calName, @tds);
        }
    }

    sub _conflicts {
        my ($event, $row) = @_;
        my ($start, $end) = ($event->startTime, $event->endTime);
        if (!defined $end) {
            $end = $start + 60;
        } elsif ($end < $start) {
            $end = 1440; # if it ends tommorrow
        }
        foreach my $ev (@$row) {
            my ($evStart, $evEnd) = ($ev->startTime, $ev->endTime);
            if (!defined $evEnd) {
                $evEnd = $evStart + 60;
            } elsif ($evEnd < $evStart) {
                $evEnd = 1440; # if it ends tommorrow
            }
            next if ($start >= $evEnd);
            next if ($end   <= $evStart);
            return 1;
        }
        return undef;
    }

    my $bgcolor = $prefs->inBWPrintMode ? 'white' : '#aaaaaa';

    # First, the javascript code we'll need
    $self->{html}  = Javascript->PopupWindow ($op);
    $self->{html} .= Javascript->EditEvent ($op);
    if ($op->userPermitted ('Add')) {
        # editWidth and editHeight defined in Javascript->EditEvent
        $self->{html} .= qq {
<script language="JavaScript">
<!--
    function addEvent (calName, date, start, end) {
        win = window.open ("?Op=AddEvent&PopupWin=1" +
                            "&CalendarName=" + calName + "&Date=" + date +
                            "&StartTime=" + start + "&EndTime=" + end,
                           "EditWindow" + calName,
                           "scrollbars,resizable," +
                           "width="  + editWidth + "," +
                           "height=" + editHeight);
        win.focus();
    }
// -->
</script>
                            };
    }

    $self->{html} .= $cgi->table ({align       => 'center',
                                   class       => 'DayPlannerTable',
                                   border      => 1,
                                   cellpadding => 2,
                                   cellspacing => 1,
                                   bgcolor     => $bgcolor,
                                   width       => '100%'},
                                  @theRows);

    # Controls
    my $tb = TimeBlock->new (cgi => $cgi,
                             op  => $op);
    $self->{html} .= '<br>' . $tb->hourControls;
    $self;
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


sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;
    my ($face, $size) = $prefs->font ('BlockDayOfWeek');
    $size += 1;
    $css .= Operation->cssString ('.HourLabels',
                              {bg    => $prefs->color ('WeekHeaderBG'),
                               color => $prefs->color ('WeekHeaderFG'),
                               'font-family' => $face,
                               'font-size'   => $size});
    $css .= Operation->cssString ('.CalendarLabels',
                              {bg    => $prefs->color ('DayHeaderBG')});
    $css .= Operation->cssString ('.CalendarLabels span',
                              {color => $prefs->color ('DayHeaderFG'),
                               'font-family' => $face,
                               'font-size'   => $size});

    my %font_to_css_map = (BlockEvent     => '.CalEvent',
                           BlockInclude   => '.IncludeTag',
                           BlockCategory  => '.EventTag.Category',
                           BlockEventTime => '.TimeLabel');
    while (my ($font_name, $css_specifier) = each %font_to_css_map) {
        ($face, $size) = $prefs->font ($font_name);
        $css .= Operation->cssString ('.DayPlannerView ' . $css_specifier,
                                      {'font-size'  => $size,
                                       'font-family'=> $face});
    }

    return $css;
}

sub getHTML {
  my $self = shift;
  return qq (<div class="DayPlannerView">$self->{html}</div>);
}

1;
