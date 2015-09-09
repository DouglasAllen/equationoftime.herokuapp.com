# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# The NavigationBar is a string of http links. It comes in two styles:
#  - Last Year, Jan, Feb, ..., Dec., Next Year
# or
#  - <Year, <Month, <2 Weeks, <Week, Today, Week>, 2 Weeks>, Month>, Year>
#
# We call the first "absolute", the second "relative"

package NavigationBar;
use strict;
use CGI qw(:standard *table);
use Calendar::Date;

# Pass an operation obj and a date.
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    my ($operation, $date, $location) = @_;

    my ($amount, $style, $type) = $operation->ParseDisplaySpecs;
    return if ($style =~ /neither/i);

    my $prefs = $operation->prefs;
    my $i18n =  $operation->I18N;

    return unless ($prefs->NavBarSite eq 'both' or
                   $prefs->NavBarSite eq $location);

    my $hrefBase = $operation->makeURL ({Op   => 'ShowIt',
                                         Date => undef});

    my $both = ($style =~ /both/i) ? 1 : 0;

    my (@monthNames, @linkNames, @hrefs,
        @absLinkNames, @absHrefs, @relLinkNames, @relHrefs);

    @monthNames = map { $i18n->get (Date->monthName ($_, 'abbrev')) } (1..12);

    # For Absolute, start with last year, stick on the months, add next year
    if ($style =~ /absolute|both/i) {
        if ($amount =~ /Day/i) {
            my $startOn = $prefs->StartWeekOn || 7;
            my $weekStart = $date->firstOfWeek ($startOn);
            my $lastWeek = (Date->new ($date))->addWeeks (-1);
            my $nextWeek = (Date->new ($date))->addWeeks (1);
            my @dayNames = map {$i18n->get (Date->dayName ($_))} (1..7);
            if ($startOn != 1) {
                unshift @dayNames, pop @dayNames;
            }
            my $week = $i18n->get ('Week');
            @linkNames = ("&lt; $week", @dayNames, "$week &gt;");
            push @hrefs, $lastWeek;
            for (my $i=0; $i<7; $i++) {
                push @hrefs, $weekStart + $i;
            }
            push @hrefs, $nextWeek;
            @absLinkNames = @linkNames;
            @absHrefs = @hrefs;
        }
        elsif ($amount =~ /Week/i) {
            for (my $i=-4; $i<=4; $i++) {
                my $d = Date->new ($date)->addWeeks ($i);
                push @hrefs, $i ? $d : undef;
                push @absLinkNames, $d->pretty ($i18n, 'abbrev');
            }
            @absHrefs = @hrefs;
        }
        elsif ($amount =~ /Quarter/i) {
            my $lastYear = (Date->new($date))->addYears(-1);
            my $nextYear = (Date->new($date))->addYears(1);
            my @qnames = map {$i18n->get ("$_ Quarter")}
                             qw /First Second Third Fourth/;
            @linkNames = ($lastYear->year, @qnames, $nextYear->year);
            push @hrefs, $lastYear;
            for (my $i=1; $i<=4; $i++) {
                push @hrefs, $date->startOfQuarter ($i);
            }
            push @hrefs, $nextYear;
            @absLinkNames = @linkNames;
            @absHrefs = @hrefs;
        }
        elsif ($amount =~ /FPeriod/i) {
            my $lastYear = (Date->new($date))->addYears(-1);
            my $nextYear = (Date->new($date))->addYears(1);
            my @pnames = map {substr ($i18n->get ("Period"), 0, 1) . $_}
                            1..12;
            @linkNames = ($lastYear->year, @pnames, $nextYear->year);
            push @hrefs, $lastYear;
            for (my $q=1; $q<=4; $q++) {
                my $quart = $date->startOfQuarter ($q);
                for (my $p=1; $p<=3; $p++) {
                    push @hrefs, $quart->startOfPeriod ($p);
                }
            }
            push @hrefs, $nextYear;
            @absLinkNames = @linkNames;
            @absHrefs = @hrefs;
        }
        elsif ($amount !~ /Year/i) {
            my ($lastYear, $nextYear);
            $lastYear = (Date->new($date))->addYears(-1);
            $nextYear = (Date->new($date))->addYears(1);
            @linkNames = ($lastYear->year, @monthNames, $nextYear->year);
            push @hrefs, $lastYear;
            for (my $i=1; $i<=12; $i++) {
                push @hrefs, Date->new ($date->year . "/$i/1");
            }
            push @hrefs, $nextYear;
            @absLinkNames = @linkNames;
            @absHrefs = @hrefs;
        } else {
            @absLinkNames = (($date->year - 5)..($date->year + 5));
            foreach (@absLinkNames) {
                push @absHrefs, $_ . "/1/1";
            }
        }
    }

    if ($style =~ /relative|both/i) {
        my $year18   = $i18n->get ('Year');
        my $years18  = $i18n->get ('Years');
        my $week18   = $i18n->get ('Week');
        my $weeks18  = $i18n->get ('Weeks');
        my $month18  = $i18n->get ('Month');
        my $q18      = $i18n->get ('Quarter');
        my $qs18     = $i18n->get ('Quarters');
        my $p18      = $i18n->get ('Period');
        my $ps18     = $i18n->get ('Periods');
        if ($amount =~ /Day/i) {
            my $days = $i18n->get ('Days');
            my $day  = $i18n->get ('Day');
            @linkNames = ("&lt; $week18", "&lt; 3 $days", "&lt; 2 $days",
                          "&lt; 1 $day",
                          $i18n->get ('Today'),
                          "1 $day &gt;",
                          "2 $days &gt;", "3 $days &gt;", "$week18 &gt;");
            @hrefs = ($date - 7, $date - 3, $date - 2, $date - 1, $date->new,
                      $date + 1, $date + 2, $date + 3, $date + 7);
            @relLinkNames = @linkNames;
            @relHrefs = @hrefs;
        }
        elsif ($amount =~ /Quarter/i) {
            @linkNames = ("&lt; $year18", "&lt; 3 $qs18", "&lt; 2 $qs18",
                          "&lt; $q18", $i18n->get('Today'), "$q18 &gt;",
                          "2 $qs18 &gt;", "3 $qs18 &gt;", "$year18 &gt;");
            my $lastYear = $date->new ($date)->addYears (-1);
            my $nextYear = $date->new ($date)->addYears (1);
            my %qs;
#            if ($date->isa ('Date::Fiscal')) {
                foreach (-3..3) {
                    $qs{$_} = $date->new ($date)->addQuarters ($_);
                }
#             } else {
#             }
            @hrefs =($lastYear, $qs{-3}, $qs{-2}, $qs{-1},
                     Date->new(),
                     $qs{1}, $qs{2}, $qs{3},, $nextYear);
            @relLinkNames = @linkNames;
            @relHrefs = @hrefs;
        }
        elsif ($amount =~ /FPeriod/i) {
            @linkNames = ("&lt; $year18", "&lt; $q18", "&lt; 2 $ps18",
                          "&lt; $p18", $i18n->get('Today'), "$p18 &gt;",
                          "2 $ps18 &gt;", "$q18 &gt;", "$year18 &gt;");
            my $lastYear  = ($date->new ($date))->addYears(-1);
            my $nextYear  = ($date->new ($date))->addYears(1);
            my $lastq =  $date->addPeriods (-3);
            my $nextq =  $date->addPeriods (3);
            my $lastp2 = $date->addPeriods (-2);
            my $lastp  = $date->addPeriods (-1);
            my $nextp  = $date->addPeriods (1);
            my $nextp2 = $date->addPeriods (2);
            @hrefs =($lastYear, $lastq, $lastp2, $lastp,
                     Date->new(),
                     $nextp, $nextp2, $nextq, $nextYear);
            @relLinkNames = @linkNames;
            @relHrefs = @hrefs;
        }
        elsif ($amount !~ /Year/i) {
            @linkNames = ("&lt; $year18", "&lt; $month18", "&lt; 2 $weeks18",
                          "&lt; $week18", $i18n->get('Today'), "$week18 &gt;",
                          "2 $weeks18 &gt;", "$month18 &gt;", "$year18 &gt;");
            my ($lastYear, $lastMonth, $nextMonth, $nextYear);
            $lastYear  = ($date->new($date))->addYears(-1);
            $lastMonth = ($date->new($date))->addMonths(-1);
            $nextYear  = ($date->new($date))->addYears(1);
            $nextMonth = ($date->new($date))->addMonths(1);
            @hrefs =($lastYear, $lastMonth, $date - 14, $date - 7,
                     Date->new(),
                     $date + 7, $date + 14, $nextMonth, $nextYear);
            @relLinkNames = @linkNames;
            @relHrefs = @hrefs;
        } else {
            my (@offsets) = (-10, -5, -1, 1, 5, 10);
            @relLinkNames = ("&lt; 10 $years18", "&lt; 5 $years18",
                             "&lt; 1 $year18",
                             $i18n->get ('This Year'),
                             "1 $year18 &gt;", "5 $years18 &gt;",
                             "10 $years18 &gt;");
            foreach (@offsets) {
                push @relHrefs, Date->new($date)->addYears ($_);
            }
            splice @relHrefs, 3, 0, Date->new;
        }
    }

    my (@absTds, @relTds, $absTable, $relTable);
    foreach (@absLinkNames) {
        my $startDate = (shift @absHrefs);
        my $text = $_;
        if ($startDate) {
            $startDate =~ s|/|%2F|g;
            push @absTds, a ({href => "$hrefBase&Date=$startDate"}, $text);
        } else {
            push @absTds, "<b>$text</b>";
        }
    }
    foreach (@relLinkNames) {
        my $startDate = (shift @relHrefs);
        $startDate =~ s|/|%2F|g;
        push @relTds, a ({href => "$hrefBase&Date=$startDate"}, $_);
    }
    $absTable = table ({-class  => 'Absolute',
                        -width  => '100%',
                        -border => 0},
                       Tr (td ({align => "center"}, \@absTds)));
    $relTable = table ({-class  => 'Relative',
                        -width  => '100%',
                        -border => 0},
                       Tr (td ({align => "center"}, \@relTds)));

    my @rows;
    if ($both) {
        push @rows, (Tr ({-class  => 'NavigationBarInside'}, td ($absTable)),
                     Tr ({-class  => 'NavigationBarInside'}, td ($relTable)));
    } else {
        push @rows, Tr ({-class  => 'NavigationBarInside'},
                        td ($absTable)) if ($style =~ /absolute/i);
        push @rows, Tr ({-class  => 'NavigationBarInside'},
                        td ($relTable)) if ($style =~ /relative/i);
    }

    # If a Day, put 1..31 links in, to boot.
    if ($amount =~ /day/i) {
        my $lastMonth = $date->firstOfMonth->addMonths(-1);
        my $nextMonth = $date->firstOfMonth->addMonths(1);
        my ($y, $m) = ($date->year, $date->month);
        my @links;

        # get days of week
        my $dom = $date->firstOfMonth;
        my $today = Date->new;
        foreach (1..$date->daysInMonth) {
            my $dow = lc substr ($i18n->get ($dom->dayName('abbrev')),0,1);
            my $isToday = $dom == $today ? 'class="Today"' : '';
            my $weekend = $dom->isWeekend ? 'class="Weekend"' : '';
            $links[$_-1] = "<span $weekend>$dow</span><br>" .
                           a ({-href => "$hrefBase&Date=$y%2F$m%2F$_"},
                              "<span $isToday>$_</span>") . '&nbsp;';
            $dom++;
        }

        my ($lastEscaped, $nextEscaped) = ("$lastMonth", "$nextMonth");
        foreach ($lastEscaped, $nextEscaped) {
            s|/|%2F|g;
        }

        my $tab = table ({-class => 'NavigationBarInside',
                          -width       => '100%',
                          -cellspacing => 0,
                          -border      => 0},
                         Tr ({-align => 'center'},td ('&nbsp;<small>' .
                                 a ({-href => "$hrefBase&Date=$lastEscaped"},
                                      $i18n->get ($lastMonth->monthName(1)))
                                . '</small>'),
                             map {td ("<small>$_</small>")} @links,
                             td ('<small>' .
                                 a ({-href => "$hrefBase&Date=$nextEscaped"},
                                    $i18n->get ($nextMonth->monthName (1)))
                                 . '</small>')));
        push @rows, Tr (td ($tab));
    }

    my $navTable = table ({-width => '100%',
                           -border => 0, -cellpadding => 0,
                           -cellspacing => 0}, @rows);
    my $rowCount = @rows + 0;

    my @tds = td ($navTable);
    my $label = $prefs->NavBarLabel;
    if ($label) {
        unshift @tds, td ({-rowspan => $rowCount,
                           -align   => 'center'},
                          b ($label));
    }

    $self->{html} = table ({-class       => 'NavigationBar',
                            -width       => '100%',
                            -border      => 0,
                            -cellspacing => 0},
                           Tr (@tds));
    $self;
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;

    my ($navFace, $navSize) = $prefs->font ('NavLabel');
    my ($relFace, $relSize) = $prefs->font ('NavRel');
    my ($absFace, $absSize) = $prefs->font ('NavAbs');

    $css .= Operation->cssString ('.NavigationBar',
                           {bg            => $prefs->color ('NavLabelBG'),
                            color         => $prefs->color ('NavLabelFG'),
                            'font-family' => $navFace});

    $css.= Operation->cssString ('.NavigationBarInside',
                                 {color => $prefs->color ('NavLinkFG')});
    $css.= Operation->cssString ('.NavigationBarInside table',
                             {bg    => $prefs->color ('NavLabelBG')});
    $css.= Operation->cssString ('.NavigationBarInside td',
                             {bg    => $prefs->color ('NavLinkBG')});
    $css.= Operation->cssString ('.NavigationBarInside A',
                             {color => $prefs->color ('NavLinkFG')});

    $css .= Operation->cssString ('.NavigationBar .Relative',
                                  {'font-family' => $relFace,
                                   'font-size'   => $relSize});
    $css .= Operation->cssString ('.NavigationBar .Absolute',
                                  {'font-family' => $absFace,
                                   'font-size'   => $absSize});
    $css.= Operation->cssString ('.NavigationBar .Weekend',
                                 {color => 'red'});
    $css.= Operation->cssString ('.NavigationBar .Today',
                                 {color => '#ffffff',
                                  bg    => 'blue'});
    return $css;
}

sub getHTML {
  my $self = shift;
  $self->{'html'};
}

1;
