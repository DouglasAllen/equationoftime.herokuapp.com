# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Display events for single week for multiple calendars

package MultiView;
use strict;

use CGI;
use Calendar::Date;
use Calendar::Event;
use Calendar::Preferences;
use Calendar::BlockView;

sub new {
    my $class = shift;
    my ($op, $startDate, $endDate) = @_;
    my $self = {};
    bless $self, $class;

    my $cgi   = CGI->new;
    my $i18n  = $op->I18N;
    my $prefs = $op->prefs;

    my $printMode = $prefs->PrintPrefs;

    $op->{params}->{Amount} = 'Week';    # hack

    # Make sure we have exactly a week.
    if ($startDate + 6 != $endDate) {
        $startDate = $startDate->firstOfWeek ($prefs->StartWeekOn || 7);
        $endDate   = Date->new ($startDate) + 6;
    }

    my @calNames = $prefs->getIncludedCalendarNames;

    # Can also specify calendars w/param; names joined with dashes,
    # e.g. cal1-cal2-cal3
    my @rawCalNames = $cgi->param ('Calendars');
    foreach (@rawCalNames) {
        push @calNames, split /-/, $_;
    }

    # unique-ify, and sort
    my %calendars = map {$_ => 1} @calNames;
    @calNames = sort {lc($a) cmp lc($b)} keys %calendars;

    # And maybe include this calendar, too
    if (!$prefs->PlannerHideSelf) {
        unshift @calNames, $op->calendarName;
    }

    my @weekTRs;

    my $colorFG = $prefs->color ('MainPageFG');
    my $colorBG = $prefs->color ('MainPageBG');

    my $weekNum = '&nbsp;';
    my $rowSpan = 1;
    if ($prefs->ShowWeekNums) {
        $weekNum = $startDate->weekNumber ($prefs->WhichWeekNums,
                                           $prefs->StartWeekOn);
        $weekNum = $cgi->font ({color => $colorFG},
                               $i18n->get ('Week') . " $weekNum");
        $rowSpan = 1;
    }

    my $wnTD = $cgi->td ({bgcolor => $colorBG,
                          colspan => 2,
                          rowspan => $rowSpan,
                          align   => 'center'}, $weekNum);

    my $headers = BlockView->new ($op, $startDate, $endDate,
                                  {settings => 'weekPlanner onlyDays'});
    my $headerHTML = $headers->getHTML;
    # This is rather gross...
    $headerHTML =~ s{<TH}{$wnTD<TH}i;

    push @weekTRs, $headerHTML;

    # See which cals we can Add to
    my %addPerm;
    foreach (@calNames) {
        $addPerm{$_} = 1
            if Permissions->new ($_)->permitted ($op->getUsername, 'Add');
    }

    my $showWeekend = $prefs->ShowWeekend;

    # Buttons to add new event
    my @buttons;
    my $theDay = Date->new ($startDate);
    while ($theDay <= $endDate) {
        # skip weekends if not showing
        if (!$showWeekend and $theDay->dayOfWeek > 5) {
            $theDay++;
            next;
        }

        if (keys %addPerm and !$printMode) {
            push @buttons,
                $cgi->font ({-size => -1},
                            $cgi->submit (-name  => "AddEvent-$theDay",
                                          -value => $i18n->get ('Add Event')));
        } else {
            push @buttons, '&nbsp;';
        }
        $theDay++;
    }

    my $helpText = qq {
The Planner view displays a separate row for each\\n
calendar that is included into the main calendar.\\n};

    if (keys %addPerm) {
    $helpText .= qq {\\n
If you have Add permission in one or more of the\\n
calendars, you can add an event to multiple\\n
calendars; select checkboxes to specify the\\n
calendars, then press the \\'Add Event\\' button for\\n
the day you want to add events to.};

    $helpText .= "\\n\\nNote: each calendar will get its own copy " .
                 "of the new event.";
}

    if (!$printMode) {
        my $help = $cgi->a ({-href => "Javascript:alert ('$helpText')"},
                            $cgi->font ({size  => -1,
                                         color => $colorFG},
                                        $i18n->get ('Help')));
        push @weekTRs, $cgi->Tr ($cgi->td ({colspan => 2,
                                            align   => 'center'}, $help),
                                 $cgi->td ({-colspan => 2,
                                            -align   => 'center'}, \@buttons));
    }

    # OK, first get all events and build hashes to be passed to BlockView
    my $events = $op->db->getEventDateHash ($startDate, $endDate, $prefs);
    my %byCalendar;
    while (my ($date, $evList) = each %$events) {
        foreach my $event (@$evList) {
            my $cal = $event->includedFrom;
            $cal = $op->calendarName if (!defined $cal);
            $byCalendar{$cal} ||= {};
            $byCalendar{$cal}->{$date} ||= [];
            push @{$byCalendar{$cal}->{$date}}, $event;
        }
    }

    my $savedCalendar = $op->calendarName; # hack!
    my $savedIncludes = $prefs->Includes;  # hack!
    $prefs->Includes (undef);              # hack!

    my $calNameBG = $prefs->color ('WeekHeaderBG') || '""';
    my $calNameFG = $prefs->color ('WeekHeaderFG') || '""';

    my $colSpan = $showWeekend ? 16 : 12;

    my $isIncluded = '';
    if ($prefs->PlannerHideSelf) {
        $isIncluded = 'IsIncluded';
    }

    foreach (@calNames) {
        next unless defined;

        my $title = $cgi->font ({-color => $calNameFG}, $_);

        $op->{params}->{CalendarName} = $_;    # hack
        my $viewOp = ShowIt->new ($op->{params}, 'View', $op->getUser);
        $viewOp->{Preferences} = $prefs;                  # hack!

        # First calendar should show Private events...
        my $weekView = BlockView->new ($viewOp, $startDate, $endDate,
                           {settings => "weekPlanner noDayNames $isIncluded",
                            plannerEvents => $byCalendar{$_},
                            includeInfo   => $savedIncludes});

        # Rest should not! (They're included.)
        $isIncluded ||= 'IsIncluded';

        # Get the rows out of the table they're in.
        my $weekHTML = $weekView->getHTML;
        my $extraRows = $weekView->numRowsLastWeek - 1; # banners cause extras
        $extraRows = 0 if ($extraRows < 0);

        my $calNameSpan = $printMode ? 2 : 1;
        my $url = $op->makeURL ({Date   => $startDate,
                                 Amount => undef,        # use default
                                 Type   => undef});
        my $calLinkTD = $cgi->td ({class   => 'CalendarLabels',
                                   rowspan => 2 + $extraRows,
                                   colspan => $calNameSpan,
                                   bgcolor => $calNameBG},
                                  $cgi->a ({-href => $url}, $title));

        my $checkboxTD = '&nbsp;';
        if (!$printMode) {
            if (Permissions->new ($_)->permitted ($op->getUsername, 'Add')) {
                $checkboxTD = $cgi->checkbox (-name => "Cal-$_",
                                              -label => '');
            }
            $checkboxTD = $cgi->td ({class   => 'AddCheckbox',
                                     rowspan => 2 + $extraRows,
                                     bgcolor => $calNameBG,
                                     align   => 'center'}, $checkboxTD);
        }

        # This is rather gross...
        $weekHTML =~ s{<TR>}{<TR>$calLinkTD$checkboxTD}i;

        push @weekTRs, $weekHTML;

        push @weekTRs, $cgi->Tr ($cgi->td ({-colspan => $colSpan}, '&nbsp;'));
    }

    $prefs->Includes ($savedIncludes);                 # hack!
    $op->{params}->{CalendarName} = $savedCalendar;    # hack

    pop @weekTRs;     # remove last empty row

    push @weekTRs, $cgi->td ("No Calendars Specified!") unless @weekTRs;


    my $script = <<'    END_JAVASCRIPT';
    :    <script language="JavaScript">
    :    <!-- start
    :    // Make sure at least one calendar selected
    :    function submitCheck (theForm) {
    :        for (var i=0; i<theForm.elements.length; i++) {
    :            if (theForm.elements[i].checked) {
    :                return true;
    :            }
    :        }
    :        alert ('Please select one or more calendars to add an event to.');
    :        return false;
    :    }
    :    // End -->
    :    </script>
    END_JAVASCRIPT
    $script =~ s/^\s*:\s*//mg;

    $self->{html} = $script;

    $self->{html} .= $cgi->startform (-onSubmit => 
                                              "return submitCheck(this)");
    $self->{html} .= $cgi->table ({align => 'center',
                                   class => 'BlockView',
                                   cols  => 16, border => 1, cellspacing => 0},
#                                  width => '100%'},
                                  @weekTRs);

    $self->{html} .= $cgi->hidden (-name     => 'CalendarName',
                                   -value    => $savedCalendar);
    $self->{html} .= $cgi->hidden (-name     => 'NextOp',
                                   -value    => $cgi->url (-query => 1));
    $self->{html} .= $cgi->hidden (-name     => 'Op',
                                   -override => 1,
                                   -value    => 'ShowMultiAddEvent');
    $self->{html} .= $cgi->endform;
    $self;
}

sub getHTML {
  my $self = shift;
  $self->{html};
}

1;
