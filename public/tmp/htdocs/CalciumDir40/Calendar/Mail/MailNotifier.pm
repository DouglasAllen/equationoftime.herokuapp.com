# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# MailNotifier.pm

use strict;
package MailNotifier;

use Calendar::Mail::MailSender;
use Calendar::Event;
use Calendar::EventFormatter;
use Calendar::MasterDB;         # for mail prefs
use Calendar::User;
use CGI (':standard');

# Pass an Operation, Event, Date, and true for edited event, otherwise new
sub send {
#    my ($class, $op, $event, $date, $editedP) = @_;
    my $class = shift;
    my %args = (op     => undef,
                event  => undef,
                date   => undef,
                edited => undef,
                TO     => undef,
                CC     => undef,
                BCC    => undef,
                @_);
    my $op      = $args{op};
    my $event   = $args{event};
    my $date    = $args{date};
    my $editedP = $args{edited};

    my $i18n    = $op->I18N;
    my $calName = $op->calendarName;
    my $prefs   = $op->prefs;
    my $cgi     = CGI->new;

    my $self = {};
    bless $self, $class;
    $self->{event} = $event;

    my $subject;
    if (defined $editedP) {
        $subject = $prefs->NotifyModSubject;
        $subject ||= $i18n->get ('Calcium event modified');
    } else {
        $subject = $prefs->NotifyNewSubject;
        $subject ||= $i18n->get ('Calcium event added');
    }

    # check for TZ offset
    # Get first address; if > 1 in list, just use TZ of first....
    my $offset;
    if ($event->mailTo) {
        $event->mailTo =~ /([^, ]*)/;
        my $address = $1;
        if (my $user = User->userFromAddress ($address)) {
            $offset = $user->timezone || 0;
        }
    }
    if (!defined $offset) {
        $offset = $prefs->DefaultTimezone;
        $offset ||= 0;
    }
    my $dateChange = $event->adjustForTimezone ($date, $offset);
    my $theDate = $date + $dateChange;

    my $prettyDate = $theDate->pretty ($i18n),
    my $time = $event->getTimeString ('both', $prefs);

    # Evaluate special strings in the subject
    $subject = $event->expandString ($subject, $date, $i18n);
    $subject =~ s/[\r\n]/ /g; # remove newlines or mail gets munged

    my %header = (text => "Calcium Event Notification\n$prettyDate" .
                          ($time ? "\n$time\n" : ''),
                  html => $cgi->table ({bgcolor => 'yellow'},
#                                        width   => '100%'},
                                       Tr (td (b ('Event Notification')),
                                           td ($prettyDate),
                                           ($time ? td ($time) : ''))));

    my @links;
    my $url = $op->makeURL ({FullURL => 1,
                             Op      => 'ShowIt',
                             Date    => "$date"});
    $url =~ s/localhost/$ENV{SERVER_NAME}/;
    push @links, {text => "\nA link to the '$calName' calendar:\n$url\n",
                  html => 'Go to the ' .
                          $cgi->a ({href => $url}, "$calName calendar")};

    if (($prefs->MailAddLink || '') !~ /hide/) {
        my $prompt = $i18n->get ("Add this event to your web calendar");

        my %repHash;
        if ($event->isRepeating) {
            my $info = $event->repeatInfo;
            my $endDate = ($info->endDate == Date->openFuture ? undef
                                                             : $info->endDate);
            my $period = $info->period;
            if (ref $period) {
                $period = join (' ', @$period);
            }

            my $monthWeek = $info->monthWeek;
            if (ref $monthWeek) {
                $monthWeek = join (' ', @$monthWeek);
            }

            my $exList = join (' ', map {"$_"} @{$info->exclusionList});
            $exList ||= undef;      # don't want ''
            %repHash = (Repeat       => 1,
                        EndDate      => $endDate,
                        Period       => $period,
                        Frequency    => $info->frequency,
                        MonthWeek    => $monthWeek,
                        MonthMonth   => $info->monthMonth,
                        SkipWeekends => $info->skipWeekends,
                        Exclusions   => $exList
                       );
        }

        my ($primaryCat, @moreCats) = $event->getCategoryList;

        # Avoid huge URLs; truncate text at 500 chars, Details at 2000
        my $text = $event->text;
        if (length ($text) > 500) {
            $text = substr ($text, 0, 500);
            $prompt .= ' (' . $i18n->get ("Event text truncated") . ')';
        }
        my $details = $event->popup || $event->link;
        if ($details and length ($details) > 2000) {
            $details = substr ($details, 0, 2000);
            $prompt .= ' (' . $i18n->get ("Event details truncated") . ')';
        }

        $url = $op->makeURL ({FullURL    => 1,
                              Op         => 'AddEventExternal',
                              CalendarName => undef,
                              Date       => "$date",
                              Text       => $text,
                              Details    => $details,
                              StartTime  => $event->startTime,
                              EndTime    => $event->endTime,
                              TimePeriod => $event->timePeriod,
                              Category   => $primaryCat,
                              %repHash});

        foreach (@moreCats) {
            $url .= '&MoreCategories=' . $cgi->escape ($_);
        }

        $url =~ s/localhost/$ENV{SERVER_NAME}/;

        push @links, {text => "\n$prompt:\n$url\n",
                      html => $cgi->a ({href => $url}, $prompt)};
    }

    my $addedComments = $event->mailText || '';
    if ($prefs->EventHTML =~ /none/i) {
        $addedComments =~ s/</&lt;/g;    # Escape HTML if we don't want it
        $addedComments =~ s/>/&gt;/g;
    }
    $addedComments =~ s/\r//g;  # remove ^Ms

    my $modOrEdit = $editedP ? 'Modified by' : 'Created by';
    my $user = $op->getUsername || 'Anonymous User';
    my $comments = $addedComments ? "Comments: $addedComments" : '';

    my ($fromAddr, $userObj);
    $userObj  = User->getUser ($user) if (defined $user);
    $fromAddr = $userObj->email if ($userObj);

    my $commentsRow = '';
    if ($addedComments) {
        $commentsRow = Tr ({-valign => 'top'},
                           td (b ($i18n->get ('Comments:'))),
                           td (Event::_escapeThis ($addedComments,
                                                   undef, 1)));
    }
    my $userTable = table (Tr (td (b ($modOrEdit . ':')),
                               td ($user)),
                           $commentsRow);
    my %userID = (text => "$modOrEdit $user\n$comments\n",
                  html => $userTable);

    my $repeat = '';
    if ($event->isRepeating) {
        my $frequency = $event->repeatInfo->frequency;
        if ($frequency) {
            $repeat = $i18n->get ('This event repeats every') . ' ';
            my $label = (qw (0 0
                             other third fourth fifth sixth))[$frequency];
            $repeat .= ($i18n->get ($label) . ' ') if $label;

            my $period = $event->repeatInfo->period;
            if (ref ($period) eq 'ARRAY') {
                my @days = map {$i18n->get (Date->dayName ($_))} @$period;
                $repeat .= join ', ', @days;
            } elsif ($period) { # something like 'week'
                $period = 'day' if ($period eq 'dayBanner');
                $repeat .= $i18n->get ($period);
            }
        } else {
            $repeat = $i18n->get ('This event repeats on the') . ' ';
            my @weeks = @{$event->repeatInfo->monthWeek};
            $repeat .= join (' ' . $i18n->get ('and') . ' ',
                           map {(qw (undef
                                     first second third fourth last))[$_]}
                           @weeks);
            $repeat .= ' ';
            $repeat .= $i18n->get (Date->dayName
                                              ($event->repeatInfo->monthDay));
            $repeat .= ' ' . $i18n->get ('every') . ' ';
            my $freq = (qw (0 0 second third fourth fifth sixth seventh
                            eighth ninth tenth eleventh twelfth))
                                            [$event->repeatInfo->monthMonth];
            $repeat .= $freq ? $i18n->get ($freq) : '';
            $repeat .= ' ' . $i18n->get ('month');
        }
        my $end = $event->repeatInfo->endDate;
        if ($end == Date->openFuture) {
            $repeat .= ' ' . $i18n->get ('forever') . ".\n";
        } else {
            $repeat .= ' ' . $i18n->get ('until') . ' ';
            $repeat .= $end->pretty ($i18n) . "\n";
        }
    }

    my ($textBody, $htmlBody) = $event->formatForMail ($theDate, $calName,
                                                       $prefs, $i18n);
    if ($repeat) {
        $textBody .= "\n$repeat";
        $htmlBody .= "<p>$repeat</p>";
    }

    my %info = (text => $textBody, html => $htmlBody);

    my $mPrefs = Preferences->new (MasterDB->new);
    my %params;
    $params{To}  = $args{TO}  if defined $args{TO};
    $params{CC}  = $args{CC}  if defined $args{CC};
    $params{BCC} = $args{BCC} if defined $args{BCC};
    $params{SMTP} = $mPrefs->MailSMTP if defined $mPrefs->MailSMTP;
    $params{From} = $fromAddr ||
                    $prefs->MailFrom ||
                    (defined ($mPrefs->MailFrom) && $mPrefs->MailFrom) ||
                    "calcium\@$ENV{SERVER_NAME}";

    my ($plainText, $htmlText);
    foreach (\%header, \%userID, \%info) {
        $plainText .= $_->{text} . "\n";
        $htmlText  .= $_->{html} . '<hr align="left" width="25%">';
    }
    foreach (@links) {
        $plainText .= $_->{text} . "\n";
        $htmlText  .= $_->{html} . '<hr align="left" width="25%">';
    }

    my $sig = ($prefs->MailSignature || $mPrefs->MailSignature || '');
    $sig =~ s/\r//g;

    $plainText .= "\n";
    $plainText .= $sig;

    $htmlText  = '<!DOCTYPE HTML PUBLIC ' .
                 '"-//W3C//DTD HTML 4.0 Transitional//EN"' . "\n" .
                 '        "http://www.w3.org/TR/REC-html40/loose.dtd">' .
                 "\n<html><head><title>Calcium Email Notification</title>" .
                 "</head>\n<body>$htmlText" .
                 (Event::_escapeThis ($sig, undef, 1) || '')
                 . "</body></html>\n";

    my $mailer = MailSender->new (%params);

    my $format = $prefs->MailFormat || 'both';
    my %contents = (text => $plainText,
                    html => $htmlText);
    if (lc ($format) eq 'text') {
        delete $contents{html};
    } elsif (lc ($format) eq 'html') {
        delete $contents{text};
    }

    if (lc ($prefs->MailiCalAttach || 'include') eq 'include') {
        require Calendar::EventvEvent;
        require Calendar::vCalendar::vCalendar;
        my $vevent = $event->vEvent ($date);
        my $vCal = vCalendar->new (events  => [$vevent],
                                   version => '2.0');
        my $vcaltext = $vCal->textDump (METHOD => 'PUBLISH');
        $vcaltext =~ s/\r//g;
        $contents{attachment} = {type        => 'text/calendar',
                               encoding    => '7bit',
                               disposition =>
                                    'attachment; filename="CalciumEvent.ics"',
                               contents    => $vcaltext};
    }

    my $ok = $mailer->send ($subject, \%contents);

    die "Mail notification failed! " . $mailer->error . "\n" unless $ok;
    $self;
}

1;
