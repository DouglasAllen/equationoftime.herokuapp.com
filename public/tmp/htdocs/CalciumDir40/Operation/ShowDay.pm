# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Display a days events, with form for adding a new event.

package ShowDay;
use strict;
use CGI (':standard');
use Calendar::Date;
use Calendar::Event;
use Calendar::EventSorter;
use Calendar::GetHTML;
use Calendar::EventEditForm;
use Calendar::Javascript;
use Calendar::DisplayFilter;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($date, $viewCal, $addedTentative) =
                          $self->getParams ('Date', 'ViewCal', 'IsTentative');

    $date = Date->new ($date);
    if (!$date->valid) {
        GetHTML->errorPage ($self->I18N,
                            message => $self->I18N->get ('Invalid Date') .
                            ": $date");
        return;
    }

    $self->{view_cal}   = $viewCal;
    $self->{audit_date} = $date;

    # Open the database, and get the prefs hash.
    my $name        = $self->calendarName();
    my $db          = $self->db;
    my $preferences = $self->prefs;
    my $i18n        = $self->I18N;

    my $addPerm  = $self->permission->permitted ($self->getUsername, 'Add');
    my $editPerm = $self->permission->permitted ($self->getUsername, 'Edit');
    my $onLoad   = '';
    my $onUnload = '';
    if ($addPerm) {
        $onLoad   = 'document.EventEditForm.EventText.focus()';
        $onUnload = 'cleanUpPopups()';
    }

    my $cgi = new CGI;

    print GetHTML->startHTML (title    => $i18n->get ('Create, Edit, or ' .
                                                      'Delete Events:') .
                                          " $name",
                              op       => $self,
                              class    => $self->opName,
                              onLoad   => $onLoad,
                              onUnload => $onUnload);

    # Stick in the javascript code we'll need
    print Javascript->PopupWindow ($self);
    print Javascript->EditEvent ($self);


    # First, spit out the links for every day of this month across the top
    my $dayURL  = $self->makeURL ({Op      => 'ShowDay',
                                   Date    => undef,
                                   ViewCal => $viewCal});
    my $viewURL = $self->makeURL ({Op   => 'ShowIt',
                                   Date => $date,
                                   CalendarName => $viewCal || $name});
    print $self->_linearMonth ($date, $dayURL, $viewURL, $i18n);

    print $self->_dateHeader ($i18n, $preferences->Title, $date);

    my @events = $db->getApplicableEvents ($date, $preferences);

    # Get Tentative/Privacy obj. to filter events, and filter them
    my $filter = DisplayFilter->new (operation => $self);
    @events = $filter->filterTentative (\@events);
    @events = $filter->filterPrivate (\@events);

    if (@events) {
        print GetHTML->SectionHeader ($i18n->get ('Existing Events'));
        # And print them out, with "Delete, Edit, etc. buttons"
        print $self->_eventTable ($date, \@events);
        print '<br>';
    }

    # Print message if just added a tentative event.
    if ($addedTentative) {
        print '<p><center><b>' . $i18n->get ('Event submitted for approval.') .
              '</b></p></center>';
    }
    if ($preferences->TentativeSubmit and
        !$self->permission->permitted ($self->getUsername, 'Edit')) {
        print '<p><center><i>';
        print $i18n->get ('Note: new events will not appear on the ' .
                          'calendar until they are approved.');
        print '</i></center></p>';
    }

    # And finally, print out the event editing widgets, if we've got permission
    if ($addPerm) {
        my %params;
        $params{'date'}       = $date;
        $params{'allOrOne'}   = 'all'; # so repeat stuff shows; fix this
        $params{'noCancel'}   = 1;     # don't show the Cancel button
        $params{'mainHeader'} = $i18n->get ('Add New Event');
        $params{'newOrEdit'}  = 'new';
        $params{'viewCal'}    = $viewCal;

        # edit a *new* event
        print EventEditForm->eventEdit ($self, \%params);
    }
    print $cgi->end_html;
}

# Pass:
#   date
#   a ref to a list of events
sub _eventTable {
    my $self = shift;
    my ($date, $eventListRef) = @_;

    my $prefs = $self->prefs;
    my $i18n  = $self->I18N;
    my $calName = $self->calendarName;

    my ($html, $eventID, $owner);
    my ($bgcolor, $bg2);
    $bgcolor = '#cccccc';
    $bg2     = '#eeeeee';
    $html = '<center>';
    $html .= '<table width="100%" cellspacing="0" cellpadding="0" ' .
             'bgcolor="#aaaaaa">';
    $html .= '<tr><td><table width="100%" border="0" cellpadding="2" ' .
             'cellspacing="0">';

    my $editDeleteURL = $self->makeURL ({Op           => 'EventEditDelete',
                                         CalendarName => undef});

    my $allOrOne = $prefs->RepeatEditWhich;

    # sort events, based on sort pref
    my @sortedEvents = Event->sort ($eventListRef, $prefs->EventSorting);

    foreach (@sortedEvents) {
        next unless defined;

        # Get date right, if it actually starts on different date
        my $theDate = Date->new ($date);
        if ($_->TZoffset) {
            $_->TZoffset > 0 ? $theDate-- : $theDate++;
        }

        ($bgcolor, $bg2) = ($bg2, $bgcolor);

        $eventID = $_->id;
        $owner   = $_->owner || '';

        $html .= "<tr bgcolor=\"$bgcolor\">";
        $html .= '<td>';
        $html .= $_->getHTML ({calName      => $calName,
                               op           => $self,
                               date         => $theDate,
                               prefs        => $prefs,
                               i18n         => $i18n,
                               timeFace     => undef,
                               timeSize     => 'smaller',
                               categoryFace => undef,
                               categorySize => 'smaller'});
        $html .= '</td>';
        $html .= '<td>';
        my $notes;
        $notes = '<font size="-2" color="darkred">' . $i18n->get ('Repeating')
            if $_->isRepeating;
        if (!$_->includedFrom || $_->includedFrom eq $calName) {
            my $theNote = $_->displayString ($i18n); # private, unavail., etc.
            if ($theNote) {
                $notes .= '<br>' if $notes;
                $notes .= font ({size => "-2", color => "darkred"}, $theNote);
            }
        }
        # add owner, if there is one
        if ($owner) {
            $notes .= '<br>' if ($notes);
            $notes .= font ({size => "-2", color => "darkred"},
                            $i18n->get ('Created by') . ": $owner");
        }

        # category, if there is one
        my @categories = $_->getCategoryList;
        if (@categories) {
            my $label = (@categories > 1) ? 'Categories' : 'Category';
            my $cats = join (',', @categories);
            $notes .= '<br>' if ($notes);
            $notes .= font ({size => "-2", color => "darkred"},
                            $i18n->get ($label) . ": $cats");
        }

        # "tentative", if tentative
        if ($_->isTentative) {
            $notes .= '<br>' if $notes;
            $notes .= font ({size => "-2", color => "darkred"},
                            $i18n->get ('Pending Approval'));
        }

        $html .= $notes || '&nbsp;';
        $html .= '</td>';

        my $incFrom = $_->includedFrom;

        # "Included from" column.
        $html .= '<td align="center" HEIGHT="40">';
        if ($incFrom) {
            my $incName;
            ($incName = $incFrom) =~ s/^ADDIN //;
            $html .= '<font size="-2" color="darkred">'
                     . $i18n->get('Included from')
                     . " '" . $incName . "'";
            $html .= '</font></td>';
        } else {
            $html .= '&nbsp;</td>';
        }

        # Edit/Delete buttons. Don't display if we don't have permission
        # for whatever calendar this event lives in, or if we're not the
        # owner and the "only owner can edit" pref is in force

        my $weCanDoIt;

        if ($incFrom) {
            if ($incFrom !~ /^ADDIN /) {
                my $db = Database->new ($incFrom);
                my $perm = Permissions->new ($db);
                $weCanDoIt++
                    if $perm->permitted ($self->getUsername, 'Edit');
            }
        } else {
            $weCanDoIt++
                if $self->permission->permitted ($self->getUsername, 'Edit');
        }

        if ($weCanDoIt             and
            $prefs->EventOwnerOnly and
            $owner                 and
            ($self->getUsername || '') ne $owner and
            !$self->permission->permitted ($self->getUsername, 'Admin')) {
            undef $weCanDoIt;
        };

        if ($weCanDoIt) {
            # Maybe put up an "are you sure?" message
            my $delete_onclick = EventEditForm->delete_confirm (op    => $self,
                                                                event => $_);
            my $whichCal = $incFrom || $calName;
            $html .= '<td>';
            $html .= startform ({-action => $editDeleteURL});
            $html .= '<nobr>';
            $html .= submit (-name => 'Edit',  -value => $i18n->get('Edit'));
            $html .= '&nbsp;';
            $html .= submit (-name => 'Delete',
                             -value => $i18n->get('Delete'),
                             -onClick => $delete_onclick);
            $html .= '</nobr>';
            $html .= hidden (-name     => 'Op',
                             -override => 1,
                             -value    =>'EventEditDelete');
            $html .= hidden (-name     => 'CalendarName',
                             -override => 1,
                             -value    => $whichCal);
            $html .= hidden (-name     => 'DisplayCal',
                             -override => 1,
                             -value    => $calName);
            $html .= hidden (-name     => 'ViewCal',
                             -override => 1,
                             -value    => $self->{view_cal})
                if defined $self->{view_cal};
            $html .= hidden (-name     => 'Date',
                             -override => 1,
                             -value    => "$theDate");
            $html .= hidden (-name     => 'EventID',
                             -override => 1,
                             -value    => $eventID);
            $html .= $self->hiddenDisplaySpecs;
            $html .= '</td><td align="left">';
            if ($_->isRepeating()) {
                $html .= $i18n->get ('Which instances') . ': ';
                $html .= popup_menu (-name    => 'AllOrOne',
                                     -default => $allOrOne,
#                                     -style   => 'text-align: left',
                                     -values  => ['All', 'Only', 'Past',
                                                  'Future'],
                                     -labels  =>
                             {'All'    => $i18n->get ('All'),
                              'Only'   => $i18n->get ('Only this date'),
                              'Past'   => $i18n->get ('This date, and all ' .
                                                      'before'),
                              'Future' => $i18n->get ('This date, and all ' .
                                                      'after')});
            } else {
                $html .= ' &nbsp; ';
            }
            $html .= "</td>";
            $html .= endform();
        } else {
            $html .= '<td colspan=2>&nbsp;</td>';
        }
        $html .= "</tr>\n";
    }

    $html .= "</table>\n";
    $html .= "</td></tr></table></center>\n";

    $html;
}

# Looks something like this:
#    t f s s m t w ...  w  t  f    (in current language, of course)
#    1 2 3 4 5 6 7 ... 28 29 30
sub _linearMonth {
    my $self = shift;
    my ($date, $url, $viewURL, $i18n) = (@_);

    my ($html, $numDays, $firstDay, @dayList, @dowList,
        $normalD, $todayD, @fnord);

    $html = '<center>';

    $numDays = $date->daysInMonth;
    $firstDay = $date->firstOfMonth->dayOfWeek;

    @dayList = (1..$numDays);
    @dowList = map {($_ + $firstDay - 2) % 7 + 1} @dayList;

    $normalD = {-align => 'center'};
    $todayD = {-align => 'center', -bgcolor => 'blue', -fgcolor => 'white'};
    @dayList = map {td ((($_ == $date->day) ? $todayD : $normalD),
                        "<a href=\"$url&Date=" .
                        Date->new ($date->year, $date->month, $_) .
                        '"><font size=-2 color=' .
                        (($_ == $date->day) ? '"white"' : '"black"') .
                        ">$_</font>")}
                    @dayList;
    @fnord = map {td ({-align => 'center'},
                      '<font size=-2 color=' .
                      (($_ == 6 || $_ == 7) ? '"red"' : '"black"') . '>' .
                      (lc substr ($i18n->get(Date->dayName($_, 'abbreviated')),
                                  0, 1)) .
                      '</font>')}
                 @dowList;

    my $lastMonth = $date->firstOfMonth->addMonths(-1);
    my $nextMonth = $date->firstOfMonth->addMonths(1);


    $html .= table ({-class       => 'LinearMonth',
                     -width       => '100%',
                     -border      => 0,
                     -cellspacing => 0,
                     -cellpadding => 2},
                    Tr (td ({-id => 'ViewCalendarLink',
                             -rowspan => 2,
                             -align   => 'center'},
                            a ({-href => $viewURL},
                               $i18n->get ('View<br>Calendar'))),
                        @fnord,
                        td ('&nbsp; &nbsp;'),
                        td (a ({-href => "$url&Date=$lastMonth"},
                               $i18n->get ($lastMonth->monthName)))),
                    Tr (@dayList,
                        td ('&nbsp; &nbsp;'),
                        td (a ({-href => "$url&Date=$nextMonth"},
                               $i18n->get ($nextMonth->monthName)))));

    $html .= '</center>';
    $html;
}

# Something like: Tuesday, February 16, 1999
sub _dateHeader {
    my $self = shift;
    my ($i18n, $title, $date) = @_;

    $title ||= '';
    $title =~ s/\n/<br>/g unless ($title =~ /<[^>]*>/);

    my $monthName = $i18n->get ($date->monthName);
    my $dateString;
    if ($i18n->getLanguage ne 'English') {
        $dateString = $date->day . " $monthName " . $date->year;
    } else {
        $dateString = "$monthName " . $date->day . ', ' . $date->year;
    }

    my $html;
    $title = qq (<div class="DateHeaderTitle">$title</div>)
        if $title;
    my $dayName = $i18n->get ($date->dayName);
    $html .= qq {<div class="DateHeader">$title$dayName $dateString</div>};
    return $html;
}

sub auditString {
    my ($self, $short) = @_;
    my $line =  $self->SUPER::auditString ($short);
    $line .= ' ' . $self->{audit_date};
}

sub cssDefaults {
    my $self = shift;
    my $prefs = $self->prefs;

    my $css = $self->SUPER::cssDefaults;
    $css .= $self->cssString ('.LinearMonth', {'font-size'   => 'x-small',
                                               bg            => '#ccc'});
    $css .= $self->cssString ('#ViewCalendarLink', {bg => 'yellow',
                                                    'font-size'  => 'larger',
                                                    'font-weight' => 'bold'});
    $css .= $self->cssString ('.DateHeader', {'font-size'   => 'large',
                                              'font-weight' => 'bold',
                                              'text-align'  => 'center'});
    $css .= $self->cssString ('.DateHeaderTitle', {'font-size' => 'x-large'});


    return $css;
}

1;
