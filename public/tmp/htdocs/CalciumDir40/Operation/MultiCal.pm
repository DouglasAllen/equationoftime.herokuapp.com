# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

# Operation::MultiCal - Operation that deals with multiple calendars

package Operation::MultiCal;
use strict;

use vars ('@ISA');
@ISA = ('Operation');

sub new {
    my $class = shift;
    my $self = $class->SUPER::new (@_);
    bless $self, $class;
}

sub groupName {
    my $self = shift;
    defined $self->{params} ? $self->{params}->{Group} : undef;
}

# goob = Group Out Of Band
sub goob {
    my $self = shift;
    defined $self->{params} ? $self->{params}->{GOOB} : undef;
}

sub goobLabel {
    my $self = shift;
    return unless $self->goob;

    return $self->I18N->get ('for all calendars')
        if ($self->goob eq 'all');

    return $self->I18N->get ('for calendars not in any group')
        if ($self->goob eq 'nogroup');
}

sub isMultiCal {
    my $self = shift;
    return (defined ($self->groupName) or $self->goob);
}

sub isSystemOp {
    my $self = shift;
    return undef if ($self->isMultiCal or $self->calendarName);
    return 1;
}

sub cgi {
    my $self = shift;
    $self->{_CGI} ||= CGI->new;
    return $self->{_CGI};
}

sub hiddenParams {
    my $self = shift;
    my $cgi = $self->cgi;
    my $x = $cgi->hidden (-name  => 'Op', -value => $self->opName);
    $x   .= $cgi->hidden (-name  => 'CalendarName',
                          -value => $self->calendarName)
              if $self->calendarName;
    $x .= $cgi->hidden (-name => 'Group', -value => $self->groupName)
              if $self->groupName;
    $x .= $cgi->hidden (-name => 'GOOB',  -value => $self->goob)
              if $self->goob;
    return $x;
}

# Anybody must be allowed to do MultiCal operations; must check perms when
# listing calendars, and then on a save too.
sub authenticate {
    my $self = shift;
    return 1 if ($self->isMultiCal);
    return $self->SUPER::authenticate (@_);
}

sub makeURL {
    my ($self, $params) = @_;
    $params->{Group} = $self->groupName;
    $params->{GOOB}  = $self->goob;
    return $self->SUPER::makeURL ($params);
}

# Return ref to list; which calendars from list have been selected
# (If not doing multi cals, return ref to list of single cal)
# If Master, ref to empty list
sub whichCalendars {
    my $self = shift;
    return $self->{WhichCalendars} if defined ($self->{WhichCalendars});
    my @cals;
    if ($self->isMultiCal) {
        @cals = $self->cgi->param ('WhichCalendars');
    } else {
        @cals = ($self->calendarName);
    }
    $self->{WhichCalendars} = \@cals;
}

# Return ref to list of selected cals, and a preferences obj.
sub getCalsAndPrefs {
    my $self = shift;

    my $calendars = $self->whichCalendars;
    my $preferences = $self->isMultiCal ? Preferences->new ($calendars->[0])
                                        : $self->prefs;
    return ($calendars, $preferences);
}

sub dbByName {
    my ($self, $calName) = @_;
    return MasterDB->new if (!defined $calName);
    $self->{_DatabaseHash} ||= {};
    $self->{_DatabaseHash}->{$calName} ||= Database->new ($calName);
    return $self->{_DatabaseHash}->{$calName};
}

# Return list of which selected calendars we _don't_ have specified
# permissions in
sub checkPermissions {
    my ($self, $username, $level) = @_;
    my @noPerms;
    my $calendars = $self->whichCalendars;
    foreach (@$calendars) {
        my $db = $self->dbByName ($_);
        push @noPerms, $_
            unless (Permissions->new ($db)->permitted ($username, $level));
    }
    return @noPerms;
}

sub relevantCalendars {
    my $self = shift;
    my %args = (@_);

    my $group = $args{group} || $self->groupName;
    my $goob  = $args{goob}  || $self->goob || '';

    my $cals = [];
    if ($goob eq 'all') {       # all calendars
        $cals = [MasterDB->getAllCalendars];
    } elsif ($goob eq 'nogroup') {
        my $ig;
        ($ig, $cals) = MasterDB->getCalendarsInGroup;
    } elsif ($group) {
        my $ig;
        ($cals, $ig) = MasterDB->getCalendarsInGroup ($group);
    }
    return $cals;
}

# HTML control to select one or more calendars
# Return HTML, or ('', 'error message') if no cals available
sub calendarSelector {
    my $self = shift;
    my %args = (@_);

    my $cgi  = $args{cgi}  || $self->cgi;
    my $i18n = $args{i18n} || $self->I18N;
    my $user = $args{user} || $self->getUsername;

    my $cals = $self->relevantCalendars;

    my @theCals = sort {lc ($a) cmp lc ($b)}
                    grep {Permissions->new ($self->dbByName ($_))
                                 ->permitted ($user, 'Admin')}
                      @{$cals};

    if (!@theCals) {
        my $html  = '<center><p>';
        $html .= $cgi->font ({-color => 'red'}, $i18n->get ('Warning: '));
        $html .= $i18n->get ("you don't have permission to edit any " .
                             'calendars in this group.') . '</p></center>';
        return ('', $html);
    }

    my $whichCals = $cgi->scrolling_list (-name     => 'WhichCalendars',
                                          -Values   => \@theCals,
                                          -size     => 5,
                                          -multiple => 'true');
    my $getPrefs = $cgi->submit (-name  => 'GetPrefs',
                                 -value => $i18n->get ('Get Settings')) .
                   '<br><small>' .
                   $i18n->get ('(Only if a single calendar is selected)') .
                   '</small>';

    my $html = $cgi->table ({width => '90%',
                             align => 'center'},
                 $cgi->Tr ({-align => 'center'},
                            [$cgi->td ($i18n->get ('Apply changes to which ' .
                                                   'calendars:')),
                             $cgi->td ($whichCals),
                             $cgi->td ($getPrefs),
                             $cgi->td ('<hr width="75%">')]));
    return $html;
}

# Return undef if ok, message otherwise
sub adminChecks {
    my $self = shift;
    my %args = (@_);

    my $save     = $args{save}     || $self->getParams (qw (Save));
    my $getPrefs = $args{getPrefs} || $self->getParams (qw (GetPrefs));
    my $user     = $args{user}     || $self->getUsername;
    my $i18n     = $self->I18N;

    if ($self->isMultiCal) {
        my $calendars = $self->whichCalendars;
        if ($save or $getPrefs) {
            # Make sure we've got at least 1 calendar selected.
            if (!@$calendars) {
                $self->{audit_error} = 'no calendar selected';
                return $i18n->get ('Error: no calendars selected.');
            }
        }

        if ($getPrefs) {
            if (@$calendars != 1) {
                my $message = $i18n->get ('Must select exactly one calendar ' .
                                          'to get settings.');
                $self->{audit_error} = 'single calendar not selected';
                return $message;
            }
        }
    }

    # If saving, (re)check permissions for all selected calendars
    if ($save) {
        my @noPerms = $self->checkPermissions ($user, 'Admin');
        if (@noPerms) {
            my $mess;
            if (@noPerms > 1) {
                $mess= $i18n->get ('Error - no Admin permission for ' .
                                   'calendars: ');
            } else {
                $mess= $i18n->get ('Error - no Admin permission for ' .
                                   'calendar: ');
            }
            $mess .= join ',', sort {lc ($a) cmp lc ($b)} @noPerms;
            return $mess;
        }
    }

    return undef;
}

# HTML control for "change"/"ignore" toggle
sub groupToggle {
    my $self = shift;

    return '' unless $self->isMultiCal;

    my %args = (name  => undef,
                bg    => undef,
                @_);
    my $i18n  = $self->I18N;
    my $cgi   = $self->cgi;
    my $name  = $args{name} || 'unnamed';

    my $labels = {change => $i18n->get ('Change'),
                  ignore => $i18n->get ('Ignore')};

    $name = $self->getOnChangeName ($name);

    return $cgi->td ({-align   => 'center',
                      -bgcolor => $args{bg}},
                     $cgi->popup_menu (-name     => $name,
                                       -values   => ['ignore', 'change'],
                                       -override => 1,
                                       -labels   => $labels));
}

sub getOnChange {
    my ($self, $name) = @_;
    my $n = $self->getOnChangeName ($name);
    return "this.form.${n}.value='change'";
}
sub getOnChangeName {
    my ($self, $name) = @_;
    return "x${name}Toggle";   # JS doesn't like names that start with digits?
}


sub setAllJavascript {
    my $self = shift;

    return ('', '') unless ($self->isMultiCal);

    my $i18n = $self->I18N;
    my $cgi  = $self->cgi;

    my $jsRow = $cgi->font ({-size => -2},
                            $i18n->get ('Set all:') . ' <nobr>"' .
                            $cgi->a ({-href =>
                                      "javascript:SetGroupToggle ('change')"},
                                     $i18n->get ('Change')) . '" "' .
                            $cgi->a ({-href =>
                                      "javascript:SetGroupToggle ('ignore')"},
                                     $i18n->get ('Ignore')) . '"</nobr>');
    my $script = q {
       <script language="JavaScript">
       <!--
       function SetGroupToggle (setTo) {
           theform=document.forms[0];
           for (i=0; i<theform.elements.length; i++) {
               if (theform.elements[i].name.search ('Toggle\$') != -1) {
                   theform.elements[i].value = setTo;
               }
           }
       }
       //-->
       </script>
                   };             # '

    return ($script, $jsRow);
}

# Remove ignored items from the prefs hash that's passed in.
# Return list of items that are _not_ ignored
sub removeIgnoredPrefs {
    my $self = shift;
    my %args = (map   => {},
                prefs => {},
                @_);
    my @notIgnored;
    foreach my $name (keys %{$args{map}}) {
        my $n = $self->getOnChangeName ($name);
        if ($self->{params}->{$n} eq 'ignore') {
            foreach my $pref (@{$args{map}->{$name}}) {
                delete $args{prefs}->{$pref};
            }
        } else {
            push @notIgnored, $name;
        }
    }
    return @notIgnored;
}

# Return message to display after multi-cal modification
sub getModifyMessage {
    my $self = shift;
    return unless $self->isMultiCal;

    my %args = (cals   => [],
                mods   => [],
                labels => {},
                @_);
    my $i18n = $self->I18N;
    my $message = (@{$args{cals}} > 1 ? $i18n->get ('Calendars')
                                      : $i18n->get ('Calendar'));
    $message .= ': ' . join (', ', @{$args{cals}});
    $message .= '<br>';
    my $which = join (', ', map {$args{labels}->{$_} || $_} @{$args{mods}});
    $message .= $i18n->get ("Changed Settings: ") .
                ($which || $i18n->get ('none - all ignored!'));
    return $message;
}

sub helpNotes {
    my $self = shift;
    return '' unless ($self->isMultiCal);

    my $i18n = $self->I18N;

    my $html = $i18n->get ('MultiCal_HelpString');
    return $html unless ($html eq 'MultiCal_HelpString');

    $html = '<br><b>To change settings for multiple calendars:</b>';
    $html .= '<ul>';
    $html .= q {<li>Select one or more calendars in the list at top.
                    (Control-click to choose multiple calendars.)</li>};
    $html .= q {<li>Make the changes you want</li>};
    $html .= q {<li>Be sure the selection at far left is set to 'Change';
                    any item with 'Ignore' will not be modified.</li>};
    $html .= q {<li>Press the 'Save' button</li>};
    $html .= '</ul>';

    $html .= q {<b>You can also view the current settings for a single
                calendar</b>};
    $html .= '<ul>';
    $html .= q {<li>Select one - and only one - calendar from the list.</li>};
    $html .= q {<li>Press the 'Get Settings' button.</li>};
    $html .= q {<li>You can then use those settings for modifications in
                    that - or other - calendars.</li>};
    $html .= '</ul>';

    return "<small>$html</small>";
}


# Override default Auditing from Operation.pm
sub audit {
    my $self = shift;
    my $type = $self->auditType;

    my @auditTypes;

    my @cals = @{$self->whichCalendars};
    push @cals, undef unless @cals;    # If Master, need undef

    foreach my $cal (@cals) {
        my $db = $self->dbByName ($cal);
        @auditTypes = $db->getAuditing ($type);
        next unless @auditTypes;
        $self->currentCal ($cal);
        my @auditObjs = map {AuditFactory->create ($_)} @auditTypes;
        foreach (@auditObjs) {
            $_->perform ($self, $db);
        }
    }
}

sub basicAuditString {
     my ($self, $short) = @_;     # 'short' ignored in this default version

     my ($sec, $min, $hour, $mday, $mon, $year, @etc) = localtime (time);
     my $date = sprintf '%d/%.2d/%.2d %.2d:%.2d:%.2d',
                        $year+1900, $mon+1, $mday, $hour, $min, $sec;
     my $calName = $self->currentCal;
     return "$date " .
            "$ENV{REMOTE_ADDR} " . 
            ($self->getUsername || '-') . ' ' .
            ($calName           || '-') . ' ' .
            ref ($self);
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->basicAuditString ($short);

    my $cal = $self->currentCal;
    $cal = MasterDB->new->name unless (defined $cal);
    my $old = $self->{audit_info}->{$cal};
    my $new = Preferences->new ($cal);

    my $info;
    foreach (sort keys %$old) {
        my $orig = $old->{$_} || 0;
        my $gnu  = $new->{$_} || 0;
        next if ($orig eq $gnu);

        my $item = "$_: $orig -> $gnu";
        if ($short) {
            $item = "[$item]";
        } else {
            $item = "\n $item";
        }
        $info .= $item;
    }
    return unless $info;     # don't report if nothing changed
    return $line . $info;
}

# Auditing Stuff
# Bit of a hack so we can avoid passing it around (for auditing mostly)
sub currentCal {
    my ($self, $calName) = @_;
    $self->{CurrentCalendar} = $calName if (defined $calName);
    $self->{CurrentCalendar};
}


sub saveForAuditing {
    my ($self, $calName, $newPrefs) = @_;

    my $prefs = $self->dbByName ($calName)->getPreferences;

    my %orig;
    foreach (keys %$newPrefs) {
        next if (($newPrefs->{$_} || '') eq ($prefs->$_() || ''));
        $orig{$_} = $prefs->$_();
    }
    $calName = MasterDB->new->name unless (defined $calName);
    $self->{audit_info}->{$calName} = \%orig;
}


1;
