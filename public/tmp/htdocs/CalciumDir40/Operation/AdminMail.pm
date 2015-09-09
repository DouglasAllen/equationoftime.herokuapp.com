# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Per-calendar Mail Settings

package AdminMail;
use strict;

use CGI (':standard');
use Calendar::GetHTML;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    my %nameMap = (MailFormat       => $i18n->get ('Mail Format')    . ': ',
                   MailFrom         => $i18n->get ('"From" Address') . ': ',
                   MailSignature    => $i18n->get ('Signature Text') . ': ',
                   NotifyNewSubject => $i18n->get ('New Event')      . ': ',
                   NotifyModSubject => $i18n->get ('Event Modified') . ': ',
                   SubscribeSubject => $i18n->get ('Subscription')   . ': ',
                   RemindSubject    => $i18n->get ('Reminder')       . ': ',
                   MailiCalAttach   => $i18n->get ('iCalendar attachment') .
                                                                        ': ',
                   MailAddLink      => $i18n->get ('Add Event Link') . ': ');

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message = $self->adminChecks;

    if (!$message and $save) {
        $override = 0;

        my ($format, $from, $sig, $notifyNew, $notifyMod, $subscribe,
            $remind, $mailAddLink, $mailiCal)
                = $self->getParams (qw (MailFormat MailFrom MailSignature
                                        NotifyNewSubject NotifyModSubject
                                        SubscribeSubject RemindSubject
                                        MailAddLink MailiCalAttach));
        $sig =~ s/\r\n/\n/g;

        my %newPrefs = (MailFormat       => $format,
                        MailFrom         => $from,
                        MailSignature    => $sig,
                        NotifyNewSubject => $notifyNew,
                        NotifyModSubject => $notifyMod,
                        SubscribeSubject => $subscribe,
                        RemindSubject    => $remind,
                        MailiCalAttach   => $mailiCal,
                        MailAddLink      => $mailAddLink);
        if ($self->isMultiCal) {
            my %prefMap = map {$_ => [$_]} keys %nameMap;
            my @modified = $self->removeIgnoredPrefs (map   => \%prefMap,
                                                      prefs => \%newPrefs);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%nameMap);
        }
        foreach (@$calendars) {
            $self->saveForAuditing ($_, \%newPrefs);
            $self->dbByName ($_)->setPreferences (\%newPrefs);
        }
        $self->{audit_formsaved}++;
    }

    # and display (or re-display) the form
    print GetHTML->startHTML (title  => $i18n->get ('Email Settings'),
                              op     => $self);
    print '<center>';
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Email Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Email Settings');
    }
    print "<h3>$message</h3>" if $message;
    print '</center>';
    print '<br>';

    print $cgi->startform;

    # If group, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $mess) = $self->calendarSelector;
        print $mess if $mess;
        print $calSelector;

        foreach (keys %nameMap) {
            $onChange{$_} = $self->getOnChange ($_);
        }
    }

    my %formatLabels = (text => $i18n->get ('Text only'),
                        HTML => $i18n->get ('HTML only'),
                        both => $i18n->get ('Text and HTML'));
    my @rows;

    my %tdParams = (-align => 'right');

    push @rows, Tr ($self->groupToggle (name => 'MailFormat'),
                    td (\%tdParams, b ($nameMap{MailFormat})),
                    td ({-colspan => 2},
                        popup_menu (-name     => 'MailFormat',
                                    -default  => $preferences->MailFormat
                                                                    || 'both',
                                    -values   => ['text', 'HTML', 'both'],
                                    -onChange => $onChange{MailFormat},
                                    -override => $override,
                                    -labels   => \%formatLabels)));
    push @rows, Tr (td ('&nbsp;'));

    push @rows, Tr ($self->groupToggle (name => 'MailFrom'),
                    td (\%tdParams, b ($nameMap{MailFrom})),
                    td ({-colspan => 2},
                        textfield (-name     => 'MailFrom',
                                   -default  => $preferences->MailFrom,
                                   -onChange => $onChange{MailFrom},
                                   -override => $override,
                                   -size     => 45)));
    push @rows, Tr ($self->groupToggle (name => 'MailSignature'),
                    td (\%tdParams, b ($nameMap{MailSignature})),
                    td ({-colspan => 2},
                        textarea  (-name     => 'MailSignature',
                                   -default  => $preferences->MailSignature,
                                   -onChange => $onChange{MailSignature},
                                   -override => $override,
                                   -rows     => 4,
                                   -cols     => 50)));

    push @rows, Tr (td ('&nbsp;'));
    push @rows, Tr (td (b ($i18n->get ('"Subject" Lines'))));

    foreach my $item (qw/NotifyNewSubject NotifyModSubject
                         SubscribeSubject RemindSubject/) {
        push @rows, Tr ($self->groupToggle (name => $item),
                        td (\%tdParams, b ($nameMap{$item})),
                        td ({-colspan => 2},
                            textfield (-name     => $item,
                                       -default  => $preferences->$item(),
                                       -onChange => $onChange{$item},
                                       -override => $override,
                                       -size     => 65)));
    }

    push @rows, Tr (td ('&nbsp;'));
    push @rows, Tr (td ({-colspan => 3}, '<b>' .
                        $i18n->get ('Event Notification Mail') . '</b>'));
    push @rows, Tr ($self->groupToggle (name => 'MailAddLink'),
                    td ({-align => 'right'},
                        '<nobr>' .
                        b ($i18n->get ('"Add Event" link') . ': ') .
                        '</nobr>'),
                    td (popup_menu (-name     => 'MailAddLink',
                                    -default  => $preferences->MailAddLink
                                                                    || 'show',
                                    -values   => ['show', 'hide'],
                                    -onChange => $onChange{MailAddLink},
                                    -override => $override,
                                    -labels   => {show =>
                                                  $i18n->get ('Include'),
                                                  hide =>
                                               $i18n->get ("Don't Include")})),
                    td ('<small>' .
                        $i18n->get ('Include a link to add the ' .
                                    "event to the recipient's default " .
                                    'Calcium calendar?') . '</small>'));

    push @rows, Tr ($self->groupToggle (name => 'MailiCalAttach'),
                    td ({-align => 'right'}, '<nobr>' .
                        b ($i18n->get ('iCalendar attachment') . ': ') .
                        '</nobr>'),
                    td (popup_menu (-name     => 'MailiCalAttach',
                                    -default  => $preferences->MailiCalAttach
                                                                  || 'include',
                                    -values   => ['include', 'exclude'],
                                    -onChange => $onChange{MailiCalAttach},
                                    -override => $override,
                                    -labels   => {include =>
                                                    $i18n->get ('Include'),
                                                  exclude =>
                                            $i18n->get ("Don't include")})),
                    td ('<small>' .
                        $i18n->get ('Include an iCalendar attachment? ' .
                                    'This allows users to easily add ' .
                                    'an event to their desktop calendar, ' .
                                    'like Microsoft Outlook or ' .
                                    "Apple's iCal") . '</small>'));

    # Javascript for 'set all', 'ignore all'
    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    print $setAlljs;
    push @rows, Tr (td ({-align => 'center'}, $setAllRow)) if $setAllRow;

    print $cgi->table ({border => 0}, @rows);

    print '<hr>';
    print $cgi->submit (-name  => 'Save',
                        -value => $i18n->get ('Save Settings')), '&nbsp;';
    print $cgi->submit (-name  => 'Cancel',
                        -value => $i18n->get ('Done')), '&nbsp;';
    print '&nbsp;';
    print $cgi->reset  (-value => 'Reset');

    print $self->hiddenParams;

    print $cgi->endform;

    print '<b>' . $i18n->get ('Notes') . ':</b>';
    my $descript = 'You can use special strings in the Subject lines to ' .
                   'automatically insert information specific to the event.';
    print "<p>$descript</p><blockquote>";
    print $cgi->table ({-border => 1, -cellpadding => 5},
                       $cgi->Tr ($cgi->th (['String', 'Produces'])),
                       $cgi->Tr ($cgi->td ('$text'),
                                 $cgi->td ('the event Text')),
                       $cgi->Tr ($cgi->td ('$date'),
                                 $cgi->td ('the event Date')),
                       $cgi->Tr ($cgi->td ('$category'),
                                 $cgi->td ('the event Category')),
                       $cgi->Tr ($cgi->td ('$user'),
                                 $cgi->td ('the event User'))
                       );
    print "</blockquote>";
    print '<p>So, a "New Event" subject line specified as ';
    print '"<b>Event Added: $text, on $date</b>"';
    print ' might produce a subject line like: ';
    print '"<b>Event Added: Important Meeting, on Saturday, March 19 2005</b>"';
    print '</p>';

    print $self->helpNotes;
    print $cgi->end_html;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
