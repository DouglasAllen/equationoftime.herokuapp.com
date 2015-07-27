# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Font Administration

package AdminFonts;
use strict;

use CGI (':standard');
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    my $i18n = $self->I18N;
    my $cgi  = new CGI;

    # if we've been cancel-ed, go back
    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my %nameMap =
        (Body     => $i18n->get ('Overall Default Font'),
         NavLabel => $i18n->get ('Navigation Bar Label'),
         NavRel   => $i18n->get ('Nav. Bar - Relative Links'),
         NavAbs   => $i18n->get ('Nav. Bar - Absolute Links'),
         MonthYear => $i18n->get ('Month/Year'),
         BlockDayOfWeek => $i18n->get ('Block View - Day of Week'),
         BlockDayDate   => $i18n->get ('Block View - Date Link'),
         BlockEvent     => $i18n->get ('Block View - Event Text'),
         BlockEventTime => $i18n->get ('Block View - Event Time Text'),
         BlockCategory  => $i18n->get ('Block View - Category Label'),
         BlockInclude   => $i18n->get ('Block View - Included From Label'),
         ListDate       => $i18n->get ('List View - Date'),
         ListDay        => $i18n->get ('List View - Day of Week'),
         ListEvent      => $i18n->get ('List View - Event Text'),
         ListDetails    => $i18n->get ('List View - Details Text'),
         ListEventTime  => $i18n->get ('List View - Event Time Text'),
         ListCategory   => $i18n->get ('List View - Category Label'),
         ListInclude    => $i18n->get ('List View - Included From Label'),
         PopupDate      => $i18n->get ('Popup - Date and Time'),
         PopupEvent     => $i18n->get ('Popup - Event Text'),
         PopupText      => $i18n->get ('Popup - Text'),
         BottomBars     => $i18n->get ('Bottom Menu Bars'),
         DayViewControls => $i18n->get ('Day View Controls'),
        );
    my @names = keys %nameMap;

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message  = $self->adminChecks;

    if (!$message and $save) {
        $override = 0;

        my %newFonts;
        foreach my $item (@names) {
            my $face = $self->{params}->{$item . 'FACE'};
            my $size = $self->{params}->{$item . 'SIZE'};
            $face =~ s/^\s+//;
            $face =~ s/\s+$//;
            $newFonts{$item . 'FACE'} = $face || '';
            $newFonts{$item . 'SIZE'} = $size;
        }

        if ($self->isMultiCal) {
            my %map = map {$_ => [$_ . 'FACE', $_ . 'SIZE']} @names;
            my @modified = $self->removeIgnoredPrefs (map   => \%map,
                                                      prefs => \%newFonts);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%nameMap);
        }

        # Set prefs for each specified calendar
        foreach (@$calendars) {
            my $thePrefs = Preferences->new ($self->dbByName ($_));
            my $fonts = $thePrefs->Fonts;
            my %orig;
            foreach (keys %newFonts) {
                $orig{$_}    = $fonts->{$_};
                $fonts->{$_} = $newFonts{$_};
            }
            # if master DB, there's no real name
            my $name = $_ ? $_ : MasterDB->new->name;
            $self->{audit_info}->{$name} = \%orig;
            $self->dbByName ($_)->setPreferences ({Fonts => $fonts});
        }
        $self->{audit_formsaved}++;
#        $preferences = Preferences->new ($calendars->[0]); # re-get
        $preferences = $self->prefs ('force');
    }

    my %fonts = %{$preferences->Fonts};

    # And display (or re-display) the form
    print GetHTML->startHTML (title  => $i18n->get ('Font Settings'),
                              op     => $self);
    print '<center>';
    if ($self->isSystemOp) {
        print GetHTML->SysAdminHeader ($i18n, 'Font Settings');
    } else {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Font Settings');
    }

    my $today = Date->new;

    print '<br>';
    print "<h3>$message</h3>" if $message;
    print '</center>';

    my (@itemOrder) = qw (Body NavLabel NavAbs NavRel MonthYear
                          BlockDayOfWeek BlockDayDate BlockEvent BlockEventTime
                          BlockInclude BlockCategory
                          ListDate ListDay ListEvent ListDetails ListEventTime
                          ListInclude ListCategory
                          PopupDate PopupEvent PopupText
                          BottomBars DayViewControls);

    my %exampleMap =
        (Body     => '&nbsp;',
         NavLabel => '<b>' . $i18n->get ('Navigate:') . '</b>',
         NavRel   => u ('< 2 ' . $i18n->get ('Weeks')),
         NavAbs   => u ($i18n->get (Date->monthName (1, 'abbrev'))) . ' ' .
                     u ($i18n->get (Date->monthName (2, 'abbrev'))),
         MonthYear => '<b>' . $i18n->get($today->monthName) . ' ' .
                              $today->year() . '</b>',
         BlockDayOfWeek => $i18n->get ('Wednesday'),
         BlockDayDate   => u ('23 ' . $i18n->get ('Dec')),
         BlockEvent     => $i18n->get ('Event Example Text'),
         BlockEventTime => '9:45 - 14:45',
         BlockCategory  => $i18n->get ('Vacation'),
         BlockInclude   => $i18n->get ('OtherCalendar'),
         ListDate       => u ($i18n->get ('Dec') . ' 23'),
         ListDay        => u ($i18n->get ('Wed')),
         ListEvent      => $i18n->get ('Example Event Text'),
         ListDetails    => $i18n->get ('Popup/Link Column Text'),
         ListEventTime  => '9:45 - 14:45',
         ListCategory   => $i18n->get ('Vacation'),
         ListInclude    => $i18n->get ('OtherCalendar'),
         PopupDate      => $today->pretty ($i18n). '<br>1:00am - 3:00am',
         PopupEvent     => $i18n->get ('Popup Header Text'),
         PopupText      => $i18n->get ('Popup Text'),
         BottomBars     => $i18n->get ('Settings'),
         DayViewControls => $i18n->get ('Start at:'),
        );

    print $cgi->startform;

    # If multi-cal, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $message) = $self->calendarSelector;
        print $message if $message;

        foreach (@names) {
            $onChange{$_} = $self->getOnChange ($_);
        }
        print $calSelector if $calSelector;
    }

    my @sizes = ('.6em','.6em','.75em', '1em', '1.2em', '1.5em', '2em', '3em');

    my (@rows, %seen);
    foreach my $item (@itemOrder) {
        my ($face, $size) = ($fonts{$item . 'FACE'},
                             $fonts{$item . 'SIZE'});
        $size ||= 3;
        $face ||= '';
        push @rows, Tr ($self->groupToggle (name => $item),
                        td (b ($nameMap{$item})),
                        td (textfield (-name     => $item . 'FACE',
                                       -default  => $face,
                                       -override => $override,
                                       -onChange => $onChange{$item},
                                       -size     => 20)),
                        td (popup_menu (-name     => $item . 'SIZE',
                                        -default  => $size,
                                        -override => $override,
                                        -onChange => $onChange{$item},
                                        -values   => [1..7],
                                        -labels   =>
                                    {1 => $i18n->get ('Smallest'),
                                     2 => $i18n->get ('Smaller'),
                                     3 => $i18n->get ('Normal'),
                                     4 => $i18n->get ('Bigger'),
                                     5 => $i18n->get ('Even Bigger'),
                                     6 => $i18n->get ('Bigger Still'),
                                     7 => $i18n->get ('Huge!')})),
                        td ({-align => 'center'},
                            span ({-style => "font-family: $face; " .
                                             "font-size: $sizes[$size];"},
                                  "$exampleMap{$item}")));
    }

    my ($setAlljs, $setAllRow) = $self->setAllJavascript;

    print $setAlljs;
    push @rows, Tr (td ({-align => 'center'}, $setAllRow)) if $setAllRow;

    my @headers = ('Item', 'Font Face', 'Font Size', 'Example');
    unshift @headers, '&nbsp;' if $self->isMultiCal;

    print table ({border  => 2,
                  align   => 'center'},
                 Tr (th {-bgcolor => "#cccccc"},
                     [map {$i18n->get ($_)} @headers]),
                 @rows);

    print '<hr>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => 'Reset');

    print $self->hiddenParams;

    print $cgi->endform;
    print $self->helpNotes;
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $summary =  $self->basicAuditString ($short);

    my $cal = $self->currentCal || MasterDB->new->name;
    my $old = $self->{audit_info}->{$cal};
    my $new = Preferences->new ($cal)->Fonts;

    my $message = '';

    foreach (sort {lc($a) cmp lc($b)} keys %$old) {
        my $orig = $old->{$_} || '';
        my $gnu  = $new->{$_} || '';
        next if ($orig eq $gnu);
        if ($short) {
            $message .= "[$_ $orig->$gnu] "
        } else {
            $message .= "\nChanged $_ from '$orig' to '$gnu'";
        }
    }

    return unless $message;     # don't report if nothing changed
    return $summary . ($short ? " $message" : "\n$message");
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
