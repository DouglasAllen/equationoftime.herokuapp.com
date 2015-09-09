# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Non-fancy but much more useful Colors Administration

package AdminColorsAlternate;
use strict;

use CGI (':standard');
use Calendar::Javascript;
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

    my ($calendars, $preferences) = $self->getCalsAndPrefs;

    my %nameMap =
        (Title              => $i18n->get ('Title'),
         Header             => $i18n->get ('Header'),
         Footer             => $i18n->get ('Footer'),
         SubFooter          => $i18n->get ('Sub-Footer'),
         MainPage           => $i18n->get ('Page'),
         WeekHeader         => $i18n->get ('Block View - Week Header'),
         DayHeader          => $i18n->get ('Block View - Day Header'),
         Today              => $i18n->get ('Block View - Today Header'),
         Event              => $i18n->get ('Block View - Day'),
         Link               => $i18n->get ('Link'),
         VLink              => $i18n->get ('Visited Link'),
         Popup              => $i18n->get ('Popup Window'),
         PopupDate          => $i18n->get ('Popup Date'),
         BottomBar          => $i18n->get ('Bottom Menus'),
         BottomBarSelected  => $i18n->get ('Bottom Menu - Selected Item'),
         ListViewDate       => $i18n->get ('List View - Date'),
         ListViewDay        => $i18n->get ('List View - Day'),
         ListViewEvent      => $i18n->get ('List View - Event'),
         ListViewPopup      => $i18n->get ('List View - Popup'),
         MonthTail          => $i18n->get ('Block View - Previous/Next Month'),
         NavLabel           => $i18n->get ('Navigation Bar - Outside'),
         NavLink            => $i18n->get ('Navigation Bar - Inside'),
         DayViewControls    => $i18n->get ('Day View Controls'),
         BannerShadow       => $i18n->get ('Block View - "Bannered" Event ' .
                                           'Shadow'),
        );

    my @names = keys %nameMap;
    my (@itemOrder) = qw (Title Header Footer SubFooter
                          NavLabel NavLink MainPage
                          WeekHeader DayHeader Today Event MonthTail
                          BannerShadow
                          BottomBar BottomBarSelected Popup PopupDate Link
                          VLink ListViewDate ListViewDay ListViewEvent
                          ListViewPopup DayViewControls);

    my $override = 1;
    my $message = $self->adminChecks;
    if (!$message and $save) {
        $override = 0;

        my %newColors;
        foreach my $item (@names) {
            foreach (qw /BG FG/) {
                my $param = $item . $_;
                my $color = $self->{params}->{$param};
                $color =~ s/^\s+//;
                $color =~ s/\s+$//;
                $newColors{$param} = $color;
            }
        }

        if ($self->isMultiCal) {
            my %map = map {$_ => [$_ . 'BG', $_ . 'FG']} @names;
            my @modified = $self->removeIgnoredPrefs (map   => \%map,
                                                      prefs => \%newColors);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => \%nameMap);
        }

        # Set prefs for each specified calendar
        if (keys %newColors) {
            foreach (@$calendars) {
                my $thePrefs = Preferences->new ($self->dbByName ($_));
                my $colors = $thePrefs->Colors;
                my %orig;
                foreach (keys %newColors) {
                    $orig{$_}     = $colors->{$_};
                    $colors->{$_} = $newColors{$_};
                }
                # if master DB, there's no real name
                my $name = $_ ? $_ : MasterDB->new->name;
                $self->{audit_info}->{$name} = \%orig;
                $self->dbByName ($_)->setPreferences ({Colors => $colors});
            }
            $self->{audit_formsaved}++;
#           $preferences = Preferences->new ($calendars->[0]); # re-get
            $preferences = $self->prefs ('force');
        }
    }

    my %colors = %{$preferences->Colors};

    # And display (or re-display) the form
    print GetHTML->startHTML (title  => $i18n->get ('Colors'),
                              op     => $self);
    print '<center>';
    if (!$self->isSystemOp) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Color Settings');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Color Settings');
    }
    print '<br>';
    print "<h3>$message</h3>" if $message;
    print '</center>';

    print $cgi->startform;

    # If group, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $message) = $self->calendarSelector;
        print $message if $message;

        foreach (@names) {
            $onChange{$_} = $self->getOnChange ($_);
        }
        print $calSelector if $calSelector;
    }

    my (@rows, %seen);
    foreach my $item (@itemOrder) {
        next if $seen{$item}++;
        my ($bg, $fg) = ($colors{$item . 'BG'}, $colors{$item . 'FG'});
        $bg ||= '';
        $fg ||= '';
        my $label = '';
        if ($fg and $bg) {
            $label = "$fg on $bg";
        } elsif ($fg or $bg) {
            $label = $fg || $bg;
        }
        push @rows, Tr ($self->groupToggle (name  => $item),
                        td (b ($nameMap{$item})),
                        td (textfield (-name    => $item . 'BG',
                                       -default => $bg,
                                       -onChange => $onChange{$item},
                                       -override => $override,
                                       -size    => 15)),
                        td (textfield (-name    => $item . 'FG',
                                       -default => $fg,
                                       -onChange => $onChange{$item},
                                       -override => $override,
                                       -size    => 15)),
                        td ({bgcolor => $bg},
                            font ({color => $fg}, $label)));
    }

    my ($setAlljs, $setAllRow) = $self->setAllJavascript;
    print $setAlljs;
    push @rows, Tr (td ({-align => 'center'}, $setAllRow)) if $setAllRow;

    my @headers = qw /Item Background Foreground Example/;
    unshift @headers, '&nbsp;' if $self->isMultiCal;

    print table ({-align  => 'center',
                  -border => 2},
                 Tr (th {-bgcolor => "#cccccc"},
                     [map {$i18n->get ($_)} @headers]),
                 @rows);

    print Javascript->ColorPalette ($self);
    print '<br>' . a ({-href => "Javascript:ColorWindow()"},
                      $i18n->get ('See Available Colors'));

    print '<hr>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Save Colors'));
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

    my $summary = $self->basicAuditString ($short);

    my $cal       = $self->currentCal || MasterDB->new->name;
    my $oldColors = $self->{audit_info}->{$cal};

    my $newColors = Preferences->new ($cal)->Colors;
    my $message = '';

    foreach my $item (sort {lc($a) cmp lc($b)} keys %$oldColors) {
        my $old = $oldColors->{$item} || '';
        my $new = $newColors->{$item} || '';
        next if ($old eq $new);
        if ($short) {
            $message .= "[$item: $old->$new] ";
        } else {
            $message .= "Changed $item from '$old' to '$new'\n";
        }
    }
    return $summary . ($short ? ' ' : "\n\n") . $message;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
