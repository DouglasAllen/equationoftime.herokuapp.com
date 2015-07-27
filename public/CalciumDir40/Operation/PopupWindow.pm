# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Popup Window

package PopupWindow;
use strict;
use CGI (':standard');

use Calendar::Date;
use Calendar::Javascript;

use vars ('@ISA');
@ISA = ('Operation');

# Require 'Edit' perm instead of 'View' if setting for that is set
sub new {
    my $class = shift;
    my $self = $class->SUPER::new (@_);
    if ($self->prefs->HideDetails) {
        $self->{AuthLevel} = 'Edit';
    }
    return $self;
}

sub perform {
    my $self = shift;
    my ($date, $id, $source, $doneURL) = $self->getParams (qw (Date ID Source
                                                               DoneURL));

    # DoneURL used if no JS

    unless (defined ($date) && defined ($id)) {
        warn "Bad Params to Popup Window";
        return;
    }

    my $cgi  = CGI->new;
    my $name  = $self->calendarName();
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;

    # Get the colors
    my $fg = $prefs->color ('PopupFG') || 'black';
    my $dateFG = $prefs->color ('PopupDateFG') || 'black';
    my $dateBG = $prefs->color ('PopupDateBG') || 'white';

    # Get the Event; if no source, not an included event
    # Some browsers (Opera) set source to ' ' instead of ''
    undef $source if ($source =~ /^\s+$/);
    my ($db, $sourceName, $addInName);
    if (!$source) {
        $db         = $self->db;
        $sourceName = $name;
    } else {
        $sourceName = $source;
        if ($source !~ /^ADDIN /) {
            $db = Database->new ($source);
        } else {
            $sourceName =~ s/^ADDIN //;
            $addInName = $sourceName;
            $sourceName = $name;
            $db = AddIn->new ($addInName, $self->db);
        }
    }

    my $event = $db->getEvent ($date, $id);

    # If TZ offset, might not have right date.
    unless ($event) {
        ($event, $date) = $db->getEventById ($id);
    }

    $date = Date->new ($date);

    $self->{audit_date} = $date;
    $self->{audit_eventtext} = $event ? $event->text : 'event not found';

    # And display everything
    print GetHTML->startHTML (title  => $sourceName,
                              class  => 'EventPopup',
                              op     => $self);

    my $offset = $prefs->Timezone || 0;
    my $displayDate = $date;
    # But if repeating event, we are sure to have the display date already.
    if ($event and $offset and !$event->isRepeating) {
        $displayDate = $event->getDisplayDate ($date, $offset);
    }

    my $theDate = $displayDate->pretty ($i18n);

    if ($event and $event->isRepeating and $event->repeatInfo->bannerize) {
        my $start = $event->getDisplayDate ($event->repeatInfo->startDate);
        my $end   = $event->getDisplayDate ($event->repeatInfo->endDate);
        $theDate = $start->pretty ($i18n) . ' - ' . $end->pretty ($i18n);
        $date = $start;
    }

    if ($event && $event->hasTime) {
        my $text;
        if (!$offset) {
            $text = $event->getTimeString ('both', $prefs) || '';
        } else {
            my $milTime = $prefs->MilitaryTime;
            my ($start, $end) = $event->getDisplayTime ($offset);
            $text = Event->getTimeString ($start, $milTime) || '';
            if (defined $end) {
                $text .= ' - ' . Event->getTimeString ($end, $milTime);
            }
        }
        if ($event->timePeriod) {
            my ($name, $s, $e, $which) =
                                $prefs->getTimePeriod ($event->timePeriod);
            if ($name) {
                $text = $name . ": $text";
            }
        }
        $theDate .= "<br/>$text";
    }

    print qq (<div id="DateHeader" class="Date">$theDate</div>);
    print '<p>';

    if ($event) {
        my $escapeIt = $prefs->EventHTML =~ /none/;
        my $text = $event->escapedText ($escapeIt, 'newWindow');
        print qq (<div id="EventSummary" class="Summary">$text</div>);

        print '<p>';
        $text = $event->escapedPopup ($escapeIt, 'newWindow');
        print qq (<div id="EventDetails" class="Details">$text</div>);

        if (Defines->has_feature ('custom fields')) {

            require Calendar::Template;
            my $templ = Template->new (name     => 'Popup',
                                       cal_name => $sourceName,
                                       convert_newlines => 1);

            # If included, get custom field info from included calendar
            #  (but not if it's from an Add-In)
            my $custom_prefs = $source && !$addInName
                                       ? Preferences->new ($source)
                                       : $prefs;
            if (my $custom_html =
                $event->custom_fields_display (template => $templ,
                                               prefs    => $custom_prefs,
                                               escape   => $escapeIt)) {
                print $custom_html;
            }
        }

        print '</p>';

        my $today = Date->new;
        if (Defines->mailEnabled and $prefs->RemindersOn and $date > $today) {
            print '<hr width="50%">';

            my ($email, $doIt) = $self->getParams (qw (EmailAddress
                                                       SubscribeMe));
            if ($doIt) {
                my $message;
                SUBSCRIBE: {
                    if (!$email or $email =~ /[\s,]/) {
                        $message = 
                           $i18n->get ("Please enter a single email address.");
                        last SUBSCRIBE;
                    }

                    my @all = $prefs->getRemindAllAddresses;
                    if (grep {lc($email) eq lc ($_)} @all) {
                        $message = "'$email' " .
                               $i18n->get ('is already signed up to receive ' .
                                           'mail for all events in this ' .
                                           'calendar.');
                        last SUBSCRIBE;
                    }

                    if (my @eventCats = $event->getCategoryList) {
                        my $cats = $prefs->getRemindByCategory;
                        foreach my $thisCat (@eventCats) {
                            my $addrs = $cats->{$thisCat};
                            next unless $addrs;
                            if (grep {lc($email) eq lc ($_)} @$addrs) {
                                $message = "'$email' " .
                                      $i18n->get ('is already signed up to ' .
                                            'receive mail for all events in ' .
                                            'this category.');
                                last SUBSCRIBE;
                            }
                        }
                    }

                    if ($event->isSubscribed ($email, $name)) {
                        $message = "'$email' " .
                            $i18n->get ('is already signed up to receive' .
                                        ' mail for this event.');
                        last SUBSCRIBE;
                    }

                    $event->addSubscriber ($email, $name);
                    $db->replaceEvent ($event, $date);
                    $message = $i18n->get ("Email will be sent to") .
                               "'$email'" . '.';

                    $self->{audit_subscribed} = $email;
                }
                print qq (<span class="Message">$message</span>)
                    if $message;
            }

            print '<div class="EmailSection">';
            print '<center>';

            print $cgi->startform;
            my $user = User->getUser ($self->getUsername); # must re-get DB
            my $userEmail = $user ? $user->email : '';
            print '<b>';
            print $i18n->get ('Email Address:') . ' ';
            print '</b>';
            print $cgi->textfield (-name      => 'EmailAddress',
                                   -default   => $userEmail,
                                   -size      => 20,
                                   -maxlength => 100);
            print '&nbsp;';
            print $cgi->submit (-name  => 'SubscribeMe',
                                -value => $i18n->get ('Remind Me'));
            print '<br/>&nbsp;&nbsp;&nbsp;';

            my $num_days_string = '';
            if (my $numDays = $prefs->RemindDays) {
                my @numDays = split ' ', $numDays;
                if (@numDays > 1) {
                    $num_days_string = join (', ', @numDays);
                    $num_days_string =~ s/, ([\d]+)$/ and $1/;
                    $num_days_string .= ' days';
                }
                else {
                    $num_days_string = $numDays[0] == 1 ? '1 day'
                                                        : "$numDays[0] days";
                }
            }
            my $signup = $i18n->get ('Sign up to be notified by email %s ' .
                                     'before this event takes place.');
            print '<small>' . sprintf ($signup, $num_days_string) . '</small>';

            print $cgi->hidden (-name => 'Op',          -value => __PACKAGE__);
            print $cgi->hidden (-name => 'CalendarName',-value => $name);
            print $cgi->hidden (-name => 'Date',-value => "$date");
            print $cgi->hidden (-name => 'ID',-value => $id);
            print $cgi->hidden (-name => 'Source',-value => $source);
            print $cgi->hidden (-name => 'DoneURL', -value => $doneURL)
                if ($doneURL);
            print $cgi->endform;
            print '</center>';
            print '</div>';
        }

        if ($prefs->PopupExportOn) {
            print '<hr width="50%">';
            my $url = $self->makeURL ({Op           => 'vCalEventExport',
                                       CalendarName => $sourceName,
                                       IncludedInto => $name,
                                       Date         => $date,
                                       ID           => $id,
                                       AddInName    => $addInName,
                                       FullURL      => 1});
            print '<div class="iCalSection">';
            print '<center>';
            print $cgi->a ({-href => $url},
                           "<font color='$fg'>" .
                           $i18n->get ('Download as iCalendar') . '</font>');
            print '</center>';
            print'</div><br/>';
        }

    } else {
        print $i18n->get ('Warning! This Event has been Deleted.');
    }

    print '</p>';

    if ($doneURL) {
        my $font = "<font color='$fg' size='+1'>";
        print $cgi->a ({-href => $doneURL},
                       $font . $i18n->get ('Done') . '</font>');
    } else {
        print $cgi->startform;
        print $cgi->button ({-value   => $i18n->get ('Close'),
                             -onClick => 'window.close()'});
        print $cgi->endform;
    }

    print $cgi->end_html;
}

# if it was a subscription request, override the 'View' default
sub auditType {
    if (shift->{audit_subscribed}) {
        return 'Subscribe';
    }
    return 'View';
}

sub auditString {
    my ($self, $short) = @_;
    my $line =  $self->SUPER::auditString ($short);
    $self->{audit_eventtext} =~ s/\n/\\n/g;
    $line .= ' ' . $self->{audit_date} . ' ' . $self->{audit_eventtext};

    $line .= "\nSubscribed: $self->{audit_subscribed}"
        if ($self->{audit_subscribed});
    return $line;
}

sub cssDefaults {
    my $self = shift;
    my $prefs = $self->prefs;

    my $css = $self->SUPER::cssDefaults;

    $css .= $self->cssString ('BODY', {bg     => $prefs->color ('PopupBG'),
                                       color  => $prefs->color ('PopupFG')});

    my ($face, $size) = $prefs->font ('PopupDate');
    $css .= $self->cssString ('.EventPopup .Date',
                          {width => '100%',
                           bg    => $prefs->color ('PopupDateBG'),
                           color => $prefs->color ('PopupDateFG'),
                           'font-family' => $face,
                           'font-size'   => $size});

    ($face, $size) = $prefs->font ('PopupEvent');
    $css .= $self->cssString ('.EventPopup .Summary',
                          {width => '100%',
                           'font-family' => $face,
                           'font-size'   => $size});
    ($face, $size) = $prefs->font ('PopupText');
    $css .= $self->cssString ('.EventPopup .Details',
                          {width => '100%',
                           'font-family' => $face,
                           'font-size'   => $size});

    $css .= $self->cssString ('.EventPopup .EmailSection',
                          {'font-family' => $face});

    $css .= $self->cssString ('.EventPopup .iCalSection',
                          {'font-family' => $face});

#     $css .= $self->cssString ('.EventPopup .Message',
#                           {'font-family' => $face});
    return $css;
}

1;
