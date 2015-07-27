# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package ListView;
use strict;

use CGI qw (:standard *table);
use Calendar::Event;
use Calendar::Javascript;
use Calendar::Preferences;
use Calendar::DisplayFilter;

# A List View is a table with 4 columns: Date, Day of Week Name, Event
#   Text, Popup Text

sub new {
    my $class = shift;
    my ($operation, $startDate, $endDate, $params) = @_;
    my $self = {};
    bless $self, $class;

    my $calName = $operation->calendarName;
    my $db      = $operation->db;
    my $prefs   = $operation->prefs;
    my $i18n    = $operation->I18N;
    my $uname   = $operation->getUsername;

    my $addPerm  = $operation->permission->permitted ($uname, 'Add');
    my $editPerm = $operation->permission->permitted ($uname, 'Edit');

    my ($amount, $navBar, $type) = $operation->ParseDisplaySpecs;

    my $mode = $params->{mode} || '';
    my $isApprovalMode = ($mode eq 'Approval');
    undef $isApprovalMode unless $editPerm;
    $self->{isApprovalMode} = $isApprovalMode;
    $self->{_has_add_perm}  = $addPerm;

    my $searchMode = ($mode eq 'Search');

    my $isCondensed = $isApprovalMode || $searchMode || $type =~ /condensed/i;

    # Stick the javascript code we'll need in
    my $html = Javascript->PopupWindow ($operation);
    $html   .= Javascript->EditEvent ($operation);
    if ($addPerm) {
        $html .= Javascript->AddEvent;
    }

    # Store some stuff so we can get if from other methods
    $self->{escapeIt}   = $prefs->EventHTML =~ /none/;
    $self->{_operation} = $operation;

    # Show or hide the popup column?
    my $hidePopup = (($prefs->ListViewPopup || 1) < 0);
    $hidePopup = $operation->{params}->{HideDetails}
        if (defined $operation->{params}->{HideDetails});
    if ($prefs->HideDetails and !$editPerm) {
        $hidePopup = 1;
    }

    # Popup col width
    if ($hidePopup) {
        $self->{popupWidth} = 0;
    } else {
        $self->{popupWidth} = $prefs->ListViewPopup;
        $self->{popupWidth} = 65 if (!defined $self->{popupWidth} or
                                     $self->{popupWidth} < 5); # used to be '1'
        # If we have custom fields, see if we've got a template for popup column
        if (Defines->has_feature ('custom fields')) {
            require Calendar::Template;
            $self->{listcol_template} = Template->new (name     => 'List',
                                                       cal_name => $calName,
                                                       convert_newlines => 1);
        }
    }

    $html .= startform (-name => 'ApprovalForm') if ($isApprovalMode);

    my $border = ($prefs->PrintPrefs ? 1 : 0);

    # First, create the open table def
    $html .= "<table width='100%' border=$border cellspacing=1 cellpadding=1>";

    # Then, for each day, add a row. Each row can have many 'sub-rows',
    # since there may be > 1 event per day.

    # Get a hash of list of events which apply in this date range, or all
    # tentative events if in approval mode.
    my $eventHash;
    if ($isApprovalMode) {
        # Tentatives for this calendar
        $eventHash = $db->getTentativeEvents;

        # And tentative events from all included calendars that we have at
        # least Edit permission in
        $db->addIncludedTentativeEvents ($uname, $eventHash);

        # Adjust events for timezone. (Still problem if date changes.)
        if (my $offsetHours = $prefs->Timezone) {
            while (my ($dateString, $list) = each %$eventHash) {
                my $dateObj = Date->new ($dateString);
                foreach my $event (@$list) {
                    $event = $event->copy;
                    $event->adjustForTimezone ($dateObj, $offsetHours);
                }
            }
        }

        my @dates = sort map {sprintf "%4s/%02s/%02s", split '/'}
                             keys %$eventHash;
        if (@dates) {
            $startDate = Date->new ($dates[0]);
            $endDate   = Date->new ($dates[-1]);
        }
    } else {
        # Need extra day at both ends, in case of timezone shift
        $eventHash = $db->getEventDateHash ($startDate-1, $endDate+1, $prefs);
    }

    my ($event, $numEvents, @events);

    my ($eventFG, $eventBG) = ($prefs->color ('ListViewEventFG') || 'black',
                               $prefs->color ('ListViewEventBG'));

    my $showWeekend  = $prefs->ShowWeekend;
    $showWeekend ||= ($isCondensed or $startDate == $endDate);

    my $showWeekNum  = $prefs->ShowWeekNums;
    my $whichWeekNum = $prefs->WhichWeekNums;
    my $startWeekOn  = $prefs->StartWeekOn;

    my $printedSomething;

    my $sortBy = $prefs->EventSorting;

    my $previousDate = $startDate;

    for (my $date = $startDate; $date <= $endDate; $date++) {
        next unless ($showWeekend or $date->dayOfWeek < 6);

        # If we care about weeknums, see if this gets one.
        my $weekNum;
        $weekNum = $date->weekNumber ($whichWeekNum, $startWeekOn)
            if ($showWeekNum && ($date->dayOfWeek == $startWeekOn));

        my $listRef = $eventHash->{"$date"};
        my @unsortedEvents = $listRef ? @$listRef : ();

        $self->{_display_filter} ||= DisplayFilter->new (operation =>
                                                                  $operation);

        if ($isApprovalMode) {  # get ONLY tentative events
            @unsortedEvents = grep {$_->isTentative} @unsortedEvents;
        } else {
            # Filter OUT tentative events
            @unsortedEvents =
                  $self->{_display_filter}->filterTentative (\@unsortedEvents);
        }
        # Filter out private events, setting privacy display flag too
        @unsortedEvents =
                  $self->{_display_filter}->filterPrivate (\@unsortedEvents);

        # Filter out based on text and/or category
        @unsortedEvents =
              $self->{_display_filter}->filter_from_params (\@unsortedEvents);

        # sort events, based on sort pref
        my @events = Event->sort (\@unsortedEvents, $sortBy);

        $numEvents = @events;
        next if (!$numEvents && $isCondensed);
        $printedSomething ||= 1;

        $event = shift @events;
        my $url;
        if ($addPerm) {
            if ($searchMode) {
                # clear filter stuff if searching, not filtering
                $url = $operation->makeURL ({Op         => 'ShowDay',
                                             NavType    => undef,
                                             TextFilter => undef,
                                             FilterIn   => undef,
                                             IgnoreCase => undef,
                                             UseRegex   => undef,
                                             FilterCategories => undef,
                                             Type       => undef,
                                             Date       => $date});
            } else {
                $url = $operation->makeURL ({Op   => 'ShowDay',
                                             Date => $date});
            }
        }

        my $dateHTML = $date->pretty ($i18n, 'abbrev');

        if ($searchMode or $isApprovalMode) {
            $dateHTML .= ', ' . $date->year;
        }

        if ($addPerm) {
            $dateHTML = "<a href='$url'>" . $dateHTML . "</a>";
        }

        $dateHTML .= "<small>&nbsp;[$weekNum]</small>" if defined ($weekNum);

        my %dateVals = (-class   => 'DateCol',
                        -width   => '5%',
#                       -valign  => 'top',
                        -nowrap  => 1);
        $dateVals{-rowSpan} = $numEvents if ($numEvents > 1);

        my %dayVals = (-class   => 'DayCol',
                       -width   => '5%',
                       -align   => 'center');
        $dayVals{-rowSpan} = $numEvents if ($numEvents > 1);

        my $popupData = '';
        if (!$hidePopup) {
            $popupData = $self->_eventPopupTableData ($event);
        }

        my $isFiscal = $date->isa ('Date::Fiscal');
        my $dayNum = '';
        if ($isFiscal) {
            $dayNum = td (\%dayVals, $date->dayNumber);
        }

        # If first of the month, add a space
        if ($date->month != $previousDate->month) {
            $html .= Tr (td ('&nbsp;'));
        }

        # Columns: Date, DayOfWeek, FiscalDay (if fiscal), Text, Popup

        my %dayRowVals = (-class => $date->dayName);

        # If no events, double-click anywhere for 'add event' popup.
        # If there are events on this day, only in first two columns.
        my $on_dbl = "addEvent ('$calName', '$date')";
        if ($addPerm and !$event) {
            $dayRowVals{-ondblclick} = $on_dbl;
        }
        elsif ($addPerm) {
            $dateVals{-ondblclick} = $dayVals{-ondblclick} = $on_dbl;
        }

        $html .= Tr (\%dayRowVals,
                     $isApprovalMode ? approvalStuff ($event, $i18n) : '',
                     td (\%dateVals, $dateHTML),
                     td (\%dayVals, $i18n->get ($date->dayName ('abbrev'))),
                     $dayNum,
                     $self->_eventTextTableData  ($calName, $event, $date,
                                                  $prefs, $i18n,
                                                  $eventFG, $eventBG),
                     $popupData);

        # Do the rest of the events for this day
        foreach (@events) {
            my $popupData = '';
            if (!$hidePopup) {
                $popupData = $self->_eventPopupTableData ($_);
            }
            $html .= Tr ($isApprovalMode ? approvalStuff ($_, $i18n) : '',
                         $self->_eventTextTableData ($calName, $_, $date,
                                                     $prefs, $i18n,
                                                     $eventFG, $eventBG),
                         $popupData);
        }

        $previousDate = $date;
    }

    sub approvalStuff {
        my ($event, $i18n) = @_;

        my @values = qw /approve delete pending/;
        my %labels = (approve => $i18n->get ('Approve'),
                      delete  => $i18n->get ('Delete'),
                      pending => $i18n->get ('Pending'),
                     );

        my @tds;
        my @idents = ('Approve', $event->id, ($event->includedFrom || ''));
        my $ident = join '-', @idents;
        push @tds, td ({-bgcolor => 'gray'},
                       popup_menu (-name    => $ident,
                                   -default => 'pending',
                                   -values  => \@values,
                                   -labels  => \%labels));
        my $categories = $event->getCategoryScalar;
        my @notes;
        push @notes, $event->owner            if defined $event->owner;
        push @notes, $categories              if $categories;
        push @notes, $i18n->get ('Repeating') if $event->isRepeating;
        push @notes, ('<nobr>Included from:</nobr> ' . $event->includedFrom)
            if $event->includedFrom;
        push @notes, '&nbsp;' unless @notes;
        push @tds, td ({-class => 'EventTag'}, join '<br>', @notes);
        @tds;
    }

#    $html .= end_table();
    $html .= '</table>';

    if ($isApprovalMode and $printedSomething) {
        $html .= <<END_SCRIPT;
    <script language="JavaScript">
    <!--
        function SetAll (index) {
           theform=document.ApprovalForm;
           for (i=0; i<theform.elements.length; i++) {
              if (theform.elements[i].type=='select-one') {
                 theform.elements[i].selectedIndex=index;
              }
           }
        }
    //-->
    </script>
END_SCRIPT

        my @x = $i18n->get ("Set all to: ");
        push @x, a ({-href => "javascript:SetAll(0)"}, $i18n->get ('Approve'));
        push @x, a ({-href => "javascript:SetAll(1)"}, $i18n->get ('Delete'));
        push @x, a ({-href => "javascript:SetAll(2)"}, $i18n->get ('Pending'));
        $html .= '<span class="ApproveSetAll">' . join ('&nbsp;&nbsp;', @x) .
                 '</span>';

        $html .= '<br><center>';
        my $label = $i18n->get (' Approve / Delete ');
        $html .= submit (-name => 'ApproveIt', -value => $label);
        $html .= '</center>';

        $html .= hidden (-name     => 'Op',
                         -override => 1,
                         -value    => 'ApproveEvents');
        $html .= hidden (-name => 'CalendarName', -value => $calName);
        $html .= endform;
    }

    if (!$printedSomething) {
        if (!$isApprovalMode) {
            my $start = $searchMode ? 'Search Results' : 'Condensed Mode';
            $html .= h3 ({-align => 'center'},
                         $i18n->get ($start) . ': ' .
                         $i18n->get ('There were no events found in the ' .
                                     'specified date range'));
        } else {
            $html .= h3 ({-align => 'center'},
                         $i18n->get ('There are no events pending approval' .
                                     ' for this calendar.'));
        }
    }

    if ($isApprovalMode or $searchMode) {
        if ($searchMode) {
            delete $operation->{params}->{TextFilter};
            delete $operation->{params}->{FilterIn};
            delete $operation->{params}->{FilterCategories};
        }
        $html .= p ('&nbsp;',
                    a ({-href => $operation->makeURL ({Op => 'ShowIt'})},
                       'Return to the Calendar'));
    }

    $self->{html} = $html;
    $self;
}

sub _eventTextTableData {
    my $self = shift;
    my ($calName, $event, $date, $prefs, $i18n, $fg, $bg) = (@_);
    my ($fgColor, $bgColor, $border, $textID);
    if ($event) {
        if ($event->includedFrom || '' ne $calName) {
            ($fgColor, $bgColor, $border, $textID) =
                $event->getIncludedOverrides ($prefs->Includes);
        }

        my $thisOnesBG = $event->bgColor;
        my $thisOnesFG = $event->fgColor;

        if ((!$fgColor || !$bgColor) && $event->primaryCategory) {
            my @prefList = ($prefs, MasterDB->new->getPreferences);
            # use category colors from included calendar if we're included
            if (my $inc_from = $event->includedFrom) {
                if ($inc_from !~ /^ADDIN/ and $inc_from ne $calName) {
                    my $incPrefs = Preferences->new ($event->includedFrom);
                    unshift @prefList, $incPrefs if $incPrefs;
                }
            }
            ($fgColor, $bgColor, $border) =
                                       $event->getCategoryOverrides (@prefList);
            $fgColor = $thisOnesFG if $thisOnesFG;
            $bgColor = $thisOnesBG if $thisOnesBG;
        }
        $bgColor ||= $thisOnesBG;
        $fgColor ||= $thisOnesFG;
    }
    $fgColor ||= $fg;
    $bgColor ||= $bg;

    if ($prefs->inPrintMode ('none')) { # use colors for 'some'
        $fgColor = 'black';
        $bgColor = 'white';
    }

    my $td;
    my $the_class = 'TextCol';
    if ($event) {
        my %eventSettings = (calName => $calName,
                             op      => $self->{_operation},
                             date    => $date,
                             prefs   => $prefs,
                             i18n    => $i18n,
                             textID  => $textID,
                             textFG  => $fgColor);
        $td = $event->getHTML (\%eventSettings) || '&nbsp;';
        my $ev_class = $event->primaryCategory || '';
        $ev_class =~ s/\W//g; # cats can have wacky chars in them
        $the_class .= " c_$ev_class";
    } else {
        $td = '&nbsp;';
    }

    my %vals = (-width => 100 - $self->{popupWidth} . '%',
                -class => $the_class);
    $vals{-bgcolor} = $bgColor if $bgColor;
    my $stuff = td (\%vals, $td);
    $stuff;
}

sub _eventPopupTableData {
    my ($self, $event) = @_;
    my $escapeIt = $self->{escapeIt};
    my $popup;
    my $the_class = 'DetailsCol';
    if ($event and !$event->display_privacy_string) {
        $popup = $event->escapedPopup ($escapeIt, 'dohrefs') || $event->link;

        my $ev_class = $event->primaryCategory || '';
        $ev_class =~ s/\W//g; # cats can have wacky chars in them
        $the_class .= " c_$ev_class";

        # Custom fields - if any
        if (Defines->has_feature ('custom fields')) {
            my $prefs = $self->{_operation}->prefs;
            my $template = $self->{listcol_template};
            my $is_addin;
            if (my $inc_from = $event->includedFrom) {
                if ($inc_from =~ /^ADDIN /) {
                    $is_addin = 1;
                }
                else {
                    $prefs = Preferences->new ($inc_from);
                    $self->{listcol_template_hash}->{$inc_from}
                                      ||= Template->new (name     => 'List',
                                                         cal_name => $inc_from,
                                                         convert_newlines => 1);
                    $template = $self->{listcol_template_hash}->{$inc_from};
                }
            }
            if (!$is_addin) {
                my $custom_html =
                  $event->custom_fields_display (template => $template,
                                                 prefs    => $prefs,
                                                 escape   => $escapeIt) || '';
                $popup .= $custom_html;
            }
        }
    }

    my %vals = (-width => $self->{popupWidth} . '%',
                -class => $the_class);

    my $stuff = td (\%vals, $popup || '&nbsp;');
    $stuff;
}

sub getHTML {
    my $self = shift;
    return qq (<div class="ListView">$self->{html}</div>);
}

sub cssDefaults {
    my ($self, $prefs) = @_;
    my $css;

    my ($face, $size) = $prefs->font ('ListDate');
    $css .= Operation->cssString ('.DateCol', {
              'color'            => $prefs->color ('ListViewDateFG', 'some')
                                    || 'black',
              'background-color' => $prefs->color ('ListViewDateBG', 'some')});
    $css .= Operation->cssString ('.DateCol a',
               {color              => $prefs->color ('ListViewDateFG', 'some')
                                      || 'black',
                'font-family' => $face,
                'font-size'   => $size,
               });

    ($face, $size) = $prefs->font ('ListDay');
    $css .= Operation->cssString ('.DayCol', {
              'background-color' => $prefs->color ('ListViewDayBG', 'some'),
              'color'            => $prefs->color ('ListViewDayFG', 'some')
                                              || 'black',
              'font-family' => $face,
              'font-size'   => $size});

    ($face, $size) = $prefs->font ('ListDetails');
    $css .= Operation->cssString ('.DetailsCol',
                      {'background-color' => $prefs->color ('ListViewPopupBG'),
                       color              => $prefs->color ('ListViewPopupFG')
                                             || 'black',
                       'font-family' => $face,
                       'font-size'   => $size,
                       });

    ($face, $size) = $prefs->font ('ListInclude');
    $css .= Operation->cssString ('.ListView .IncludeTag',
                                  {'font-family' => $face,
                                   'font-size'   => $size});
    ($face, $size) = $prefs->font ('ListCategory');
    $css .= Operation->cssString ('.ListView .EventTag.Category',
                                  {'font-family' => $face,
                                   'font-size'   => $size});
    ($face, $size) = $prefs->font ('ListEventTime');
    $css .= Operation->cssString ('.ListView .TimeLabel',
                                  {'font-family' => $face,
                                   'font-size'   => $size});

    if ($self->{isApprovalMode}) {
        $css .= Operation->cssString ('.ApproveSetAll',
                                  {color       => 'black',
                                   'font-size' => 'smaller'});
    }

    # Cursor for double-click adding events...assuming we can add
    if ($self->{_has_add_perm}) {
        $css .= Operation->cssString ('.DayCol', {cursor => 'crosshair'});
    }

    return $css;
}

1;
