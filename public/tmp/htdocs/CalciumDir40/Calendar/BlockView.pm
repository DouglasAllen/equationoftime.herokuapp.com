# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# add CSS class names so you can hang scrollbars on a day
# e.g. .DayWithEvents {height: 10em; overflow: auto;}

package BlockView;
use strict;

use CGI;
use Calendar::Date;
use Calendar::Event;
use Calendar::Preferences;
use Calendar::Javascript;
use Calendar::DisplayFilter;

# A BlockView is a big table, representing a bunch of days. It has weekdays (or
# months, years) across the top, and a bunch of days below
# It is composed of 1 or more weeks. Each week is composed of 7 days. (Wow!)

# The constructor expects an Operation object, start date, and end date.
sub new {
    my $class = shift;
    my ($operation, $startDate, $endDate, $params) = @_;
    my $self = {};
    bless $self, $class;

    my $db       = $operation->db;
    my $prefs    = $operation->prefs;
    my $i18n     = $operation->I18N;
    my $username = $operation->getUsername;

    my ($amount, $navType, $type) = $operation->ParseDisplaySpecs ($prefs);

    $self->{_operation} = $operation;
    $self->{_prefs}     = $prefs;
    $self->{_addPerm}   = $operation->permission->permitted ($username, 'Add');

    # If we're looking at a Year (or Quarter), do the special Year thing.
    if ($amount =~ /year/i or $amount =~ /quarter/i) {
        require Calendar::BlockYear;
        my $y = BlockYear->new ($operation, $startDate, $amount);
        $self->{html} = $y->getHTML;
        return $self;
    }

    # Check for special cases; planner view
    if ($params and $params->{settings}) {
        my $displayControl = $params->{settings};
        $self->{_isWeekPlanner}  = $displayControl =~ /weekPlanner/;
        $self->{_plannerInclude} = $displayControl =~ /Included/;
        $self->{_hideDayNames}   = $displayControl =~ /noDayNames/;
        $self->{_onlyDays}       = $displayControl =~ /onlyDays/;
        $self->{_includeInfo}    = $params->{includeInfo};
        $self->{_plannerEvents}  = $params->{plannerEvents};
    }

    # Stick the javascript code we'll need in. Only do first time for
    # planner view.
    $self->{html} = '';
     unless ($self->{_hideDayNames}) {
        $self->{html}  = Javascript->PopupWindow ($operation);
        $self->{html} .= Javascript->EditEvent ($operation);
        if ($self->{_addPerm}) {
            $self->{html} .= Javascript->AddEvent;
        }
    }
    $self->{html} .= "\n";

    # See if we are displaying Weekends
    my $showWeekend = $prefs->ShowWeekend;

    if ($amount !~ /day/i and !$showWeekend) {
        while ($startDate->dayOfWeek > 5) {     # don't start on weekend
            $startDate++;
        }
    }

    # First, create the open table def (unless Weekly Planner view)
    unless ($self->{_isWeekPlanner}) {
        my $cols = $showWeekend ? 14 : 10;
        $cols = 2 if ($amount =~ /day/i);
        $self->{html} .= '<table border="1" width="100%" cellspacing="0"'
                         . qq ( cols="$cols" class="CalBlock">);
    }

    # Now stick the header on, with days of the week; no links for these
    # babys, and always start on either Sunday or Monday, depening on prefs
    my $startWeekOn = $showWeekend ? $prefs->StartWeekOn || 7 : 1; # 7,1-6
    my $weekStart;
    $weekStart = $startDate->firstOfWeek ($startWeekOn);
    if ($amount =~ /day/i) {
        $weekStart = $startDate->new ($startDate);
    }

    my $displayingDate = $startDate;
    if ($amount !~ /day/i) { # DAY
        $startDate = $weekStart->new ($weekStart);
    }

    my $weekLength = $showWeekend ? 7 : 5;
    if ($amount =~ /day/i) { # DAY
        $weekLength = 1;
    }

    unless ($self->{_hideDayNames} or $amount =~ /day/i) {
        $self->{html} .= '<tr class="WeekHeader">';
        my $pct = int (100/$weekLength);
        for (my $i=0; $i<$weekLength; $i++) {
            $self->{html} .= qq {<th width="$pct%" colspan="2"><span>} .
                             $i18n->get (($weekStart + $i)->dayName()) .
                             '</span></th>';
        }
        $self->{html} .= '</tr>';
    }

    # Fixup end date, since we add extra days to fill out the last week
    # Rather silly, but it works.
    my $addedSomething;
    while ($endDate->dayOfWeek() != $startDate->dayOfWeek()) {
        $endDate++;
        $addedSomething = 1;
    }
    $endDate-- if $addedSomething;

    # If we got passed events (from MultiView for Planner), use those.
    # Otherwise, get a hash of list of events which apply in this date
    # range. This may include events from other calendars. We add an extra
    # 6 days on, since we may need them to fill out the last week. And we
    # need an extra day at both ends, in case of timezone shift.
    my $events = $self->{_isWeekPlanner} ? $self->{_plannerEvents} :
                    $db->getEventDateHash ($startDate-1, $endDate+6+1, $prefs);

    my $monthIfTail;
    $monthIfTail = $displayingDate->month if ($amount =~ /month/i and
                                              $displayingDate->day == 1);

    # And spit out rows for the entire month. Each row consists of 7 Days. We
    # need to output 1 table row for a weeks worth of day numbers, then a row
    # for the weeks worth of days data.
    for (; $startDate <= $endDate; $startDate->addWeeks (1)) {
        unless ($self->{_onlyDays}) {
            unless ($weekLength == 1) { # no day/month row for day view
                $self->{html} .= '<tr>';
                $self->{html} .= $self->_weeksHeaderHTML ($operation,
                                                        $displayingDate,
                                                        $startDate, $weekStart,
                                                        $weekLength);
            }
            $self->{html} .= '</tr>';
            $self->{html} .= $self->_weeksDataHTML ($operation->calendarName,
                                                  $startDate, $prefs, $events,
                                                  $i18n, $monthIfTail,
                                                  $weekLength);
        }
    }

    unless ($self->{_isWeekPlanner}) {
        $self->{'html'} .= '</table>';
    }
    $self;
}

sub _weeksHeaderHTML {
    my ($self, $operation, $displayingDate, $date, $useMonth,
        $weekLen) = @_;
    my ($html, $theDayNum);
    my $prefs = $operation->prefs;
    my $i18n  = $operation->I18N;

    # if a tz offset, and localtime + offset different day, use different day
    my $today = Date->todayForTimezone ($prefs->Timezone);

    my $weekNum;
    $weekNum = $date->weekNumber ($prefs->WhichWeekNums,
                                  $prefs->StartWeekOn)
        if ($prefs->ShowWeekNums);

    for (my $i=0; $i<$weekLen; $i++) {
        $theDayNum = $date->day();

        # Display the numbered day of month as an href.
        my $colspan = 2;
        if ($theDayNum == 1 || $date == $useMonth) {
            $colspan = 1;
        }

        # If print view, we don't want special "today" colors
        my $class = (!$prefs->PrintPrefs and $date == $today) ? 'TodayHeader'
                                                              : 'DayHeader';

        my $on_double = '';
        if ($self->{_addPerm} and my $cal_name = $operation->calendarName) {
            $on_double = qq /ondblclick="addEvent ('$cal_name', '$date')"/;
        }
        $html .= qq (<td class="$class" $on_double colspan="$colspan">);
        $html .= '<span>';
        my $didA;
        if ($self->{_addPerm} and $operation->calendarName
            and !$prefs->PrintPrefs) {
            my $url = $operation->makeURL ({Op   => 'ShowDay',
                                            Date => $date});
            $html .= "<a href='$url'>";
            $didA++;
        }
        $html .= "$theDayNum";
        $html .= '</a>' if $didA;
        $html .= "<small><small>[$weekNum]</small></small>"
                     if ($i == 0 and defined $weekNum);
        $html .= '</span>';
        $html .= '</td>';

        if ($theDayNum == 1 || $date == $useMonth) {
            # Display abbreviated month names if it's the first of any month,
            # or if we're explicitly told to. Also, make the name be an href to
            # that month, unless it's the month we're already in.
            my $tdstart = '<td class="MonthAbbrev" align="center">';
            my $tdend   = '<span><b>' .
                          $i18n->get ($date->monthName ('abbrev')) .
                          '</b></span>';

            if ($theDayNum == 1 && $date->month() == $displayingDate->month()){
                $html .= $tdstart . $tdend . '</td>';
            } else {
                my $url = $operation->makeURL ({Op  => 'ShowIt',
                                                Date => $date->firstOfMonth});
                $html .= $tdstart . "<a href=\"$url\">" . $tdend . '</a></td>';
            }
        }
        $date++;
    }
    $html;
}

sub _weeksDataHTML {
    my $self = shift;
    my ($calName, $date, $prefs, $events, $i18n, $thisMonthForTail,
        $weekLen) = @_;
    my $html;
    my ($eventBG, $eventFG, $linkBG, $linkFG, $tailBG, $tailFG,
        $bannerBG, $bannerFG) = ($prefs->color ('EventBG'),
                                 $prefs->color ('EventFG'),
                                 $prefs->color ('LinkBG'),
                                 $prefs->color ('LinkFG'),
                                 $prefs->color ('MonthTailBG'),
                                 $prefs->color ('MonthTailFG'),
                                 $prefs->color ('BannerShadowBG'),
                                 $prefs->color ('BannerShadowFG'));
    $bannerFG ||= 'gray';
    $bannerBG ||= 'black';

    my $skip_tail_events = $prefs->HideMonthTails;

    my %regColors =  (EventBG => $eventBG,
                      EventFG => $eventFG,
                      LinkFG  => $linkFG,
                      LinkBG  => $linkBG);
    my %tailColors = (EventBG => $tailBG,
                      EventFG => $tailFG,
                      LinkFG  => $tailFG,
                      LinkBG  => $tailBG);

    # set up array for colors
    my @colors;
    my $theDate = Date->new ($date);
    for (my $i=0; $i<$weekLen; $i++) {
        $colors[$i] = ($thisMonthForTail and
                       $theDate->month != $thisMonthForTail) ? \%tailColors
                                                             : \%regColors;
        $theDate++;
    }

    # First, make a pass through, finding which events to bannerize, which
    # also tells us the number of rows we'll need. (Since we bannerize, it
    # could be any number.)
    my @bannerThese;            # which events to banner
    my @bannerCount;            # how many bannered on each day

    my @unbanneredEvents;       # other events for each day

    my $endOfWeekDate = $date + ($weekLen - 1);
    $theDate = Date->new ($date);
    my $numRows = 1;

    for (my $i=0; $i<$weekLen; $i++) {

        my $daysEvents;

        # Skip events in prev/next months, if we want to skip them.
        if ($skip_tail_events and $thisMonthForTail and
            $thisMonthForTail != $theDate->month) {
            $daysEvents = [];
        }
        else {
            $daysEvents = $events->{"$theDate"};

            # Eliminate events we don't really want
            $daysEvents = $self->_filterEvents ($daysEvents);
        }

        $bannerCount[$i] = 0;
        $unbanneredEvents[$i] = [];

        EVENT: foreach (@$daysEvents) {

            my $newStart;       # banner start, if yesterday was excluded

            # If not bannering, just save events
            if (!$_->isRepeating or !$_->repeatInfo->bannerize) {
                push @{$unbanneredEvents[$i]}, $_;
                next EVENT;
            }

            # If event has excluded dates...
            foreach my $exDate (@{$_->repeatInfo->exclusionList}) {
                # If this day is exluded, just skip it
                next EVENT if ($exDate == $theDate); # (won't happen, actually
                                                     # event won't ever appear)
                # If yesterday was excluded, make today the start. We
                # know today is not excluded, as we wouldn't get here
                if ($exDate == $theDate - 1) {
                    $newStart = $theDate;
                    last;
                }
            }


            # If event skips weekends and today is Monday, start it.
            if ($_->repeatInfo->skipWeekends and $theDate->dayOfWeek == 1) {
                    $newStart = 1;
            }

            # Otherwise, it's a bannered repeater
            $bannerCount[$i]++;

            # If start of week, or first instance of event, or
            # first day after exclusion, bannerize
            if ($i == 0                                  # first day of week
                or $_->repeatInfo->startDate == $theDate # first day of event
                or $newStart                             # after an exclusion
                ) {

                my $eventEnd = $_->repeatInfo->endDate;

                # If exclusions, see if we end this banner early
                if ($_->repeatInfo->exclusionList->[0]) {
                    foreach (@{$_->repeatInfo->exclusionList}) {
                        next if ($_ <= $theDate or $_ > $endOfWeekDate);
                        if ($_ < $eventEnd) {
                            $eventEnd = ($_ - 1);
                        }
                    }
                }

                # If skip weekends, maybe end this banner early
                if ($_->repeatInfo->skipWeekends) {
                    my $endDate = $eventEnd;
                    if ($endDate > $endOfWeekDate) {
                        $endDate = $endOfWeekDate;
                    }
                    while ($endDate->isWeekend) {
                        $endDate--;
                    }
                    $eventEnd = $endDate;
                }

                my $endCol;
                if ($eventEnd < $endOfWeekDate) {
                    $endCol = $date->deltaDays ($eventEnd);
                } else {
                    $endCol = $weekLen - 1;
                }

                my %item = (event    => $_,
                            startCol => $i,
                            endCol   => $endCol);
                push @bannerThese, \%item;
            }
        }

        my $x = $bannerCount[$i] + 1;
        $numRows = $x if ($x > $numRows);
        $theDate++;
    }

    my @weekTable = map {[]} (0..$numRows-1); # array of rows; each ref to cols

    # First, put bannered events in weekTable
    foreach (sort {$a->{event}->repeatInfo->startDate <=>
                   $b->{event}->repeatInfo->startDate}
             @bannerThese) {
      ROW: foreach my $row (0..$numRows - 1) {
          COL: foreach my $col ($_->{startCol}..$_->{endCol}) {
                next ROW if $weekTable[$row]->[$col]; # next row if can't fit
            }
            my $col  = $_->{startCol};
            my $span = ($_->{endCol} - $_->{startCol} + 1) * 2;
            my ($contents, $bgColor) =
                $self->_formatEvents ([$_->{event}], $calName, $date, $i18n,
                                      \%regColors, 'noTable!');
            $contents = '&nbsp;' unless $contents; # shouldn't happen

            my $style = 'margin: 3px;' .
                        'border-top:    solid 1px;'  .
                        'border-left:   solid 1px;'  .
                        'border-bottom: outset 2px;' .
                        'border-right:  outset 2px;' .
                        "border-color:  $bannerBG $bannerFG $bannerFG " .
                                        "$bannerBG;";
            # Note; IE breaks if table width is 100% here
#            $weekTable[$row]->[$col] = "<td colspan=$span" .

            my $class = '';
            if ($span <= 2) {
                my $dayName = ($date+$col)->dayName;
                $class = qq {class="$dayName"};
            }

#            my $cat_classes = join ' ',
#                                map {'c_' . $_} $_->{event}->getCategoryList;
#            $cat_classes = $cat_classes ? qq {class="$cat_classes"} : '';
            my $cat_classes = $_->{event}->primaryCategory || '';
            if ($cat_classes) {
                $cat_classes =~ s/\W//g; # cats can have wacky chars in them
                $cat_classes = qq {class="c_$cat_classes"};
            }

            $weekTable[$row]->[$col] = qq (<td $class colspan="$span" ) .
                                       qq (bgcolor="$regColors{EventBG}">) .
             qq (<table $cat_classes style="$style" border="0" width="99%" )
             . 'cellspacing="0" cellpadding="0">'
             . "<tr><td align=\"center\" bgcolor=\"$bgColor\">"
             .           "$contents</td></tr></table></td>";

            foreach my $col ($_->{startCol}..$_->{endCol}) {
                $weekTable[$row]->[$col] ||= '1';
            }
            last ROW;
        }
    }

    my @lastBannerRow;          # last row w/banner in it

    # And fill 'holes' at end of banners, if there are banners beneath them
    foreach my $i (0..$weekLen-1) {
        $lastBannerRow[$i] = undef;
        foreach my $row (0..$numRows-1) {
            $lastBannerRow[$i] = $row if ($weekTable[$row]->[$i]);
        }
        if ($lastBannerRow[$i] and $bannerCount[$i] <= $lastBannerRow[$i]) {
            my $bg = $colors[$i]->{EventBG};
            $bg = defined $bg ? "bgcolor=\"$bg\"" : '';
            my $row = 0;
            while ($row < $lastBannerRow[$i]) {
                if ($weekTable[$row]->[$i]) { # occupied by banner
                    $row++;
                    next;
                }
                my $rowSpan = 1;
                my $maxSpan = $lastBannerRow[$i] - $row;
                while ($rowSpan < $maxSpan and
                       !$weekTable[$row+$rowSpan]->[$i]) {
                    $rowSpan++;
                }
                $weekTable[$row]->[$i] ||= "<td $bg rowSpan=\"$rowSpan\" " .
                                             "colspan=\"2\">&nbsp;</td>";
                $row += $rowSpan;
            }
        }
    }

    my $maxUnbannered = 0;

    # Then put unbannered events in first unoccupied row each column
    $theDate = Date->new ($date);
    for (my $i=0; $i<$weekLen; $i++) {
        my $bg = $colors[$i]->{EventBG};
        $bg = defined $bg ? "bgcolor=\"$bg\"" : '';
        my $row = defined $lastBannerRow[$i] ? $lastBannerRow[$i] + 1 : 0;
        my $rowSpan = $numRows - $row;
        my $contents = $self->_formatEvents ($unbanneredEvents[$i], $calName,
                                             $theDate, $i18n, $colors[$i]);

        my $day_class = $contents ? 'class="DayWithEvents"' : '';

        my $height = ($rowSpan == $numRows ? 'height="80"' : '');
        $contents ||= '&nbsp;';

        my $dayName = $theDate->dayName;
        $weekTable[$row]->[$i] = qq {<td class="$dayName" rowspan="$rowSpan" }
                                 . qq {$height $bg colspan="2" valign="top"> }
                                 . qq {<div $day_class>$contents</div></td>};
#                                 "$contents</td>";
        $theDate++;
        my $numEvents = @{$unbanneredEvents[$i]};
        $maxUnbannered = $numEvents if ($numEvents > $maxUnbannered);
    }

    # And finally, create the HTML rows
    my $num = (@weekTable + $maxUnbannered) || 1;
    my $thisRow = 1;
    foreach my $row (@weekTable) {
        # if only 1 row, set height. If multi-rows (i.e. one or more
        # banners), set height of all but last row to 1px, so for Mozilla,
        # excess space is forced to last row. Still broken for IE.
        # Still works, as always, in Safari, Opera.
        my $height = '';
        if (@weekTable == 1) {
            $height = 'height: ' . int (80/$num) . 'px';
        } elsif ($thisRow++ != @weekTable) {
            $height = 'height: 1px';
        }
        $html .= qq /<tr style="$height;">/;
        foreach my $col (@$row) {
            next if (!$col or $col eq '1'); # just an 'occupied' flag
            $html .= $col;
        }
        $html .= '</tr>';
    }

    $self->{_numRowsLastWeek} = scalar (@weekTable); # for weekly planner view

    $html;
}

sub numRowsLastWeek {
    return shift->{_numRowsLastWeek} || 0;
}


# Pass list of events; remove ones we don't really want, and sort
sub _filterEvents {
    my ($self, $events) = @_;
    return [] unless $events;

    $self->{_display_filter} ||= DisplayFilter->new (operation =>
                                                         $self->{_operation});

    # First, eliminate Tentative events we don't have Edit perm for;
    $events = [$self->{_display_filter}->filterTentative ($events)];

    # if Planner view and not looking at main calendar, all are
    #  actually included, set "includedFrom" so privacy filter takes
    #  effect (possibly)
    my @orig_events;
    if ($self->{_plannerInclude}) {
        my $this_cal_name = $self->{_operation}->calendarName;
        foreach my $event (@$events) {
            push @orig_events, [$event, $event->includedFrom];
            $event->includedFrom ($this_cal_name);
        }
        # Also need to set prefs in the DisplayFilter, since we
        # have a different calendar w/different prefs. Oy.
        $self->{_display_filter}->prefs (Preferences->new ($this_cal_name));
    }

    # And remove Private events we shouldn't see, also setting
    #     "display privacy" for each event
    $events = [$self->{_display_filter}->filterPrivate ($events)];

    # If we changed it, change includedFrom back...probably doesn't
    # matter, but just in case.
    foreach my $pair (@orig_events) {
        my ($event, $incFrom) = @$pair;
        $event->includedFrom ($incFrom);
    }

    # And filter on Category and/or Text
    my @keepers = $self->{_display_filter}->filter_from_params ($events);

    my @sorted = Event->sort (\@keepers, $self->{_prefs}->EventSorting);
    return \@sorted;
}

# Pass list of events; return HTML to display in a day
sub _formatEvents {
    my ($self, $events, $calName, $date, $i18n, $colors, $noTable) = @_;

    my $incInfo = $self->{_prefs}->Includes;
    if ($self->{_plannerInclude} and $self->{_includeInfo}) {
        $incInfo = $self->{_includeInfo}
    }
    my ($bgEvent, $fgEvent, $bgLink, $fgLink) = ($colors->{EventBG},
                                                 $colors->{EventFG},
                                                 $colors->{LinkBG},
                                                 $colors->{LinkFG});

    my ($html, $bgColor);

    foreach (@$events) {

        my ($fgColor, $border, $textID);

        # If planner view, this event might actually be an included one
        $_->includedFrom ($calName) if ($self->{_plannerInclude});

        if ($self->{_plannerInclude} or
            ($_->includedFrom || '' ne $calName)) {
            ($fgColor, $bgColor, $border, $textID) =
                $_->getIncludedOverrides ($incInfo);
        }

        my $thisOnesBG = $_->bgColor;
        my $thisOnesFG = $_->fgColor;

        if ((!$fgColor || !$bgColor) && $_->primaryCategory) {
            my @prefList = ($self->{_prefs}, MasterDB->new->getPreferences);
            # use category colors from included calendar if we're included
            if (my $inc_from = $_->includedFrom) {
                if ($inc_from !~ /^ADDIN/ and $inc_from ne $calName) {
                    my $incPrefs = Preferences->new ($_->includedFrom);
                    unshift @prefList, $incPrefs if $incPrefs;
                }
            }
            ($fgColor, $bgColor, $border) =
                                        $_->getCategoryOverrides (@prefList);
            $fgColor = $thisOnesFG if $thisOnesFG;
            $bgColor = $thisOnesBG if $thisOnesBG;
        }

        if ($self->{_prefs}->inPrintMode ('none')) { # use colors for 'some'
            $fgColor = 'black';
            $bgColor = 'white';
        }

        if (!$bgColor) {
            my $bg = ($_->popup || $_->link) ? $bgLink : $bgEvent;
            $bgColor = $thisOnesBG || $bg || '';
        }
        if (!$fgColor) {
            my $fg = ($_->popup || $_->link) ? $fgLink : $fgEvent;
            $fgColor = $thisOnesFG || $fg || 'black';
        }

        $border = ($_->drawBorder ? 1 : 0) unless defined $border;

        # If planner view, this event might actually be an included one
        # (Space needed to workaround Event::getHTML cache fix)
        $_->includedFrom ($calName . ' ') if ($self->{_plannerInclude});

        if (!$noTable) {
#            my $classes = join ' ', map {'c_' . $_} $_->getCategoryList;
#            $classes = $classes ? "class=\"$classes\"" : '';
            my $classes = $_->primaryCategory || '';
            if ($classes) {
                $classes =~ s/\W//g; # cats can have wacky chars in them
                $classes = qq {class="c_$classes"};
            }
            $html .= qq (<table $classes border="$border" width="98%" )
                     . qq (align="center" cellpadding="0" cellspacing="0" )
                     . qq (bgcolor="$bgColor"><tr><td>);
        }
        $html .= $_->getHTML ({op        => $self->{_operation},
                               calName   => $calName,
                               date      => $date,
                               prefs     => $self->{_prefs},
                               i18n      => $i18n,
                               textFG    => $fgColor,
                               textID    => $textID});
        if (!$noTable) {
            $html .= '</td></tr></table>';
        }

        # Undo workaround, if we did it
        $_->includedFrom ($calName) if ($self->{_plannerInclude});
    }
    wantarray ? ($html, $bgColor) : $html;     # undef if no events
}

sub getHTML {
    my $self = shift;
    return qq (<div class="BlockView">$self->{html}</div>);
}

1;
