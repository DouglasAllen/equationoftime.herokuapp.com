# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package BlockYear;
use strict;

use CGI;
use Calendar::DisplayFilter;

# Either Normal or Fiscal year, depending on what class passed date is
# If amount is Quarter, show only 3 months

sub new {
    my ($class, $op, $date, $amount) = @_;
    my $self = {op => $op};
    bless $self, $class;

    my $db    = $op->db;
    my $prefs = $self->{prefs} = $op->prefs;
    my $i18n  = $self->{i18n}  = $op->I18N;
    my $cgi   = $self->{cgi}   = CGI->new;

    my $isFiscal  = $self->{isFiscal} = $date->isa ('Date::Fiscal');
    my $isQuarter = $amount =~ /quarter/i;

    $self->{_colorBy} = $op->getParams ('YearViewColor')
                                       || $prefs->YearViewColor || 'Category';

    if ($prefs->inBWPrintMode) {
        $self->{_colorBy} = 'none';
    }

    my ($yearStart, $yearEnd);
    if ($isFiscal) {
        $yearStart = $date->startOfYear;
        $yearEnd   = $date->endOfYear;
    } else {
        $yearStart = $date->new ($date->year,  1, 1);
        $yearEnd   = $date->new ($date->year, 12, 31);
    }

    $self->{startWeekDay} = $prefs->StartWeekOn || 7;
    $self->{showWeekNum}  = $prefs->ShowWeekNums;
    $self->{numCols} = $self->{showWeekNum} ? 8 : 7;
    $self->{_isBW} = $prefs->inBWPrintMode;

    # Weekday names
    my @weekdays = map {substr ($i18n->get (Date->dayName ($_, 'abbrev')),
                                0, 1)} 1..7;
    for (my $i=1; $i<$self->{startWeekDay}; $i++) {
        push @weekdays, shift @weekdays
    }

    unshift @weekdays, '&nbsp;' if $self->{showWeekNum};
    $self->{weekdays} = \@weekdays;

    $self->{events} = $db->getEventDateHash ($yearStart, $yearEnd, $prefs);

    my @months;

    if ($isQuarter) {
        my $base = $date->startOfQuarter;
        foreach my $per (1..3) {
            my $start;
            if ($isFiscal) {
                $start = $base->startOfPeriod ($per);
            } else {
                $start = Date->new ($base);
                $start = $start->addMonths ($per-1);
            }
            $months[$per] = $self->_makeMonth ($start);
        }
    } else {
        my $mnum = 1;
        foreach my $q (1..4) {
            my $qstart;
            $qstart = $date->startOfQuarter ($q) if ($isFiscal);
            foreach my $per (1..3) {
                my $start;
                if (!$qstart) {      # i.e. if !Fiscal
                    $start = Date->new ($date->year, $mnum, 1);
                } else {
                    $start = $qstart->startOfPeriod ($per);
                }
                $months[$mnum++] = $self->_makeMonth ($start);
            }
        }
    }

    my $rows;
    if ($isQuarter) {
        $rows = $cgi->Tr ({valign => 'TOP'},
                          [$cgi->td ([@months[1..3]])]);
    }
    elsif (!$isFiscal) {
        $rows = $cgi->Tr ({valign => 'TOP'},
                          [$cgi->td ([@months[1..3]]),
                           $cgi->td ([@months[4..6]]),
                           $cgi->td ([@months[7..9]]),
                           $cgi->td ([@months[10..12]])]);
#     } elsif ($isQuarter) {
#         $rows = $cgi->Tr ({valign => 'TOP'},
#                           [$cgi->td ([@months[1..3]])]);
    } else {                    # fiscal year
        $rows = $cgi->Tr ({valign => 'TOP'},
                          [$cgi->td ([@months[1,4,7,10]]),
                           $cgi->td ([@months[2,5,8,11]]),
                           $cgi->td ([@months[3,6,9,12]])]);
    }

    my $width = $isFiscal ? "95%" : '';
    my $yearTable = $cgi->table ({align => 'center', width => $width}, $rows);


    # Print legend
    my (@legendRows, $legend);

    my $loc = 'right';
    $loc = 'bottom' if ($isQuarter);

    if ($self->{_colorBy} =~ /categories/i) {
        my $catHash = $prefs->getCategories (1);
        my (@tds, @rows);
        foreach my $name (sort keys %$catHash) {
            my ($bg, $fg) = ($catHash->{$name}->bg, $catHash->{$name}->fg);
            my $td = $cgi->td ({bgcolor => $bg},
                               "<font color=$fg>$name</font>");
            if ($loc eq 'bottom') {
                push @tds, $td;
                if (@tds == 10) {
                    push @rows, $cgi->Tr ({align => 'center'}, @tds);
                    @tds = ();
                }
            } else {
                push @rows, $cgi->Tr ($td);
            }
        }
        if ($loc eq 'bottom') {
            @legendRows = (@rows,  $cgi->Tr ({align => 'center'}, @tds));
        } else {
            @legendRows = @rows;
        }
    }
    elsif ($self->{_colorBy} =~ /count/i) {
        my @tds = ($cgi->td ({bgcolor => '#999999'},
                             $cgi->font ({color => 'black'}, "0 Events")),
                   $cgi->td ({bgcolor => '#CCCCCC'},
                             $cgi->font ({color => 'black'}, "1 Event")),
                   $cgi->td ({bgcolor => '#EEEEEE'},
                             $cgi->font ({color => 'black'}, "2 Events")),
                   $cgi->td ({bgcolor => '#FFFFFF'},
                             $cgi->font ({color => 'black'}, ">2 Events")));
        if ($loc eq 'bottom') {
            @legendRows = $cgi->Tr ({align => 'center'}, @tds);
        } else {
            @legendRows = map {$cgi->Tr($_)} @tds;
        }
    }

    my @x = map {$i18n->get ($_)} ('Color by Category',
                                   'Color by Event Count', 'No Color');
    my $catLink = $self->{_colorBy} =~ /categories/i ? $x[0] :
        $cgi->a ({href => $op->makeURL ({YearViewColor => 'Categories'})},
                 $x[0]);
    my $countLink = $self->{_colorBy} =~ /count/i ? $x[1] :
        $cgi->a ({href => $op->makeURL ({YearViewColor => 'Count'})},
                 $x[1]);
    my $noneLink = $self->{_colorBy} =~ /none/i ? $x[2] :
        $cgi->a ({href => $op->makeURL ({YearViewColor => 'None'})},
                 $x[2]);

    if ($loc eq 'right') {
        if (@legendRows) {
            unshift @legendRows, ($cgi->Tr ($cgi->td ('<hr>')),
                                  $cgi->Tr ($cgi->th ({align => 'center'},
                                          $i18n->get ('Color Legend'))));
        }
        $legend = $cgi->table ({align       => 'center',
                                cellspacing => 3},
                               $cgi->Tr
                               ($cgi->th ({align => 'center'},
                                          $i18n->get ('Event Colors'))),
                               $cgi->Tr ($cgi->td ($catLink)),
                               $cgi->Tr ($cgi->td ($countLink)),
                               $cgi->Tr ($cgi->td ($noneLink)),
                               @legendRows);
    } elsif (@legendRows) {
        $legend = $cgi->table ({align       => 'center',
                                width       => $width,
                                cellspacing => 3}, @legendRows);
    } else {
        $legend = '';
    }

    if ($loc eq 'right') {
        $self->{html} = $cgi->table ($cgi->Tr ({-valign => 'top'},
                                               $cgi->td ($yearTable),
                                               $cgi->td ($legend)));
    } else {
        $self->{html} = $cgi->table ({-align => 'center'},
                                     $cgi->Tr ($cgi->td ($yearTable)),
                                     $cgi->Tr ($cgi->td ($legend)));
    }

    if ($loc eq 'bottom' and !$prefs->PrintPrefs) {
        $self->{html} .= $cgi->table
            ($cgi->Tr
             ($cgi->td
              ($cgi->small ([$i18n->get ("Colors:"),
                             $catLink, $countLink, $noneLink]))));
    }
    $self;
}

sub _makeMonth {
    my ($self, $start) = @_;
    my $html;

    my $prefs  = $self->{prefs};
    my $op     = $self->{op};
    my $cgi    = $self->{cgi};
    my $i18n   = $self->{i18n};
    my $events = $self->{events};

    my $amount = $self->{isFiscal} ? 'FPeriod' : 'Month';
    my $url = $op->makeURL ({Op     => 'ShowIt',
                             Date   => $start,
                             Amount => $amount});


    # Month (or Period) header
    my $name = $self->{isFiscal} ? $start->periodName ($i18n)
                                 : $i18n->get ($start->monthName);
    my $link = $cgi->a ({href => $url}, $cgi->span ($name));

    my $monthHead = $cgi->Tr ($cgi->td ({class   => 'MonthHeader',
                                         colspan => $self->{numCols},
                                         align   => 'center'},
                                        $link));
    my $daysHead = $cgi->Tr ($cgi->td ({align => 'center'},
                                       $self->{weekdays}));

    # Find what day of the week the 1st is, spit out some blank cells
    my $weekStart = $start->firstOfWeek ($self->{startWeekDay});
    my $delta = $weekStart->deltaDays ($start);
    my $x;

    my $whichWeekNum;
    if ($self->{showWeekNum}) {
        $whichWeekNum = $prefs->WhichWeekNums;
        my $url = $op->makeURL ({Op     => 'ShowIt',
                                 Date   => $weekStart,
                                 Amount => 'Week'});
        $x .= $cgi->td
               ($cgi->a
                ({href => $url},
                 $cgi->font ({-size => -1}, '<i>' .
                             $start->weekNumber ($whichWeekNum,
                                                 $self->{startWeekDay})
                             . '</i>')));
    }

    my $tdMethod = '_colorByNumber';
    if ($self->{_colorBy} =~ /categories/i) {
        $self->{_masterPrefs} = MasterDB->new->getPreferences;
        $tdMethod = '_colorByCategories';
    } elsif ($self->{_colorBy} =~ /count/i) {
        $tdMethod = '_colorByNumber';
    } else {
        $tdMethod = '_colorBW';
    }

    my $date = $start;

    for (my $i=0; $i<$delta; $i++) {
        $x .= $cgi->td ('&nbsp;');
    }
    for (my $i=$delta; $i<7; $i++) {
        my $dayEvents = $events->{"$date"} ? $events->{"$date"} : [];
        my $url = $op->makeURL ({Op   => 'ShowDay', Date => $date});
        my $link = $cgi->a ({href => $url}, $date->day);
        $x .= $self->$tdMethod ($dayEvents, $link);
        $date++;
    }

    my $firstRow = $cgi->Tr ($x);

    # And finally, the remaining rows for the month
    my $notFirst;
    my (@rows, $tds);

    while ($self->_inThisMonth ($start, $date)) {
        if ($date->dayOfWeek == $self->{startWeekDay}) {
            if ($tds) {
                push @rows, $cgi->Tr  ($tds);
                undef $tds;
            }
            if ($self->{showWeekNum}) {
                my $url = $op->makeURL ({Op     => 'ShowIt',
                                         Date   => $date,
                                         Amount => 'Week'});
                $tds .= $cgi->td
                         ($cgi->a
                          ({href => $url},
                           $cgi->font ({-size => -1}, '<i>' .
                                       $date->weekNumber ($whichWeekNum,
                                                         $self->{startWeekDay})
                                       . '</i>')));
            }
        }
        my $dayEvents = $events->{"$date"} ? $events->{"$date"} : [];
        my $url = $op->makeURL ({Op   => 'ShowDay',
                                 Date => $date});
        my $link = $cgi->a ({href => $url}, $date->day);
        $tds .= $self->$tdMethod ($dayEvents, $link);
        $date++;
    }
    push @rows, $cgi->Tr  ($tds) if $tds;

    return $cgi->table ({-align => 'center', -border => 1,
                         -cellspacing => 2, -cellpadding => 2},
                        $monthHead, $daysHead, $firstRow, @rows);
}

sub _inThisMonth {
    my ($self, $start, $date) = @_;
    if ($self->{isFiscal}) {
        return ($start->startOfPeriod == $date->startOfPeriod);
    } else {
        return ($start->month == $date->month);
    }
}


sub _colorBW {
    my ($self, $events, $linkText) = @_;
    my $bg;
    return qq (<td bgcolor="white">$linkText</td>);
}

sub _colorByNumber {
    my ($self, $events, $linkText) = @_;
    my $bg;
    if ($self->{_isBW}) {
        $bg = 'white';
    } else {
        $events = $self->_filterEvents ($events);
        my $num = $events ? @$events : 0;
        $bg = "#999999";
        $bg = "#CCCCCC" if ($num == 1);
        $bg = "#EEEEEE" if ($num == 2);
        $bg = "#FFFFFF" if ($num > 2);
    }
    return qq (<td bgcolor="$bg">$linkText</td>);
}
sub _colorByCategories {
    my ($self, $events, $linkText) = @_;
    my $x;
    $events ||= [];

    $events = $self->_filterEvents ($events);

    my %eventsByCat;
    foreach (@$events) {
        my $primary =  $_->primaryCategory;
        $eventsByCat{$primary} = $_
            if ($primary);
    }

    foreach my $cat (keys %eventsByCat) {
        my ($fg, $bg, $border) =
            $eventsByCat{$cat}->getCategoryOverrides ($self->{prefs},
                                                      $self->{_masterPrefs});
        $bg = '' if (!defined $bg);
        if ($x) {
            $x = qq (<td bgcolor="$bg" align="center">
                      <table cellspacing=0 cellpadding=2><tr>$x</tr></table>
                     </td>);
        } else {
            $x = qq (<td bgcolor="$bg" align="center">$linkText</td>);
        }
    }

    # if no events, or no events w/category
    $x ||= qq (<td align="center">$linkText</td>);

    return $x;
}

# Pass list of events; remove ones we don't really want
sub _filterEvents {
    my ($self, $events) = @_;
    return [] unless $events;

    # Filter out tentative/private events, setting privacy display flag too
    $self->{_display_filter} ||= DisplayFilter->new (operation => $self->{op});
    $events = [$self->{_display_filter}->filterTentative ($events)];
    $events = [$self->{_display_filter}->filterPrivate ($events)];
    my @keepers = $self->{_display_filter}->filter_from_params ($events);
    return \@keepers;
}

sub getHTML {
    return '<div class="Year">' . shift->{html} . '</div>';
}

1;
