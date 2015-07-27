# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

# View/Set Calendar in a calendar group

package SysGroupAdmin;
use strict;
use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($groupName, $calName, $save, $cancel) =
                 $self->getParams (qw (GroupName CalName Save Cancel));
    my $i18n  = $self->I18N;

    # If both specified, decide based on button pressed to get here
    if (defined $calName and defined $groupName) {
        undef $calName   if param ('ByGroup');
        undef $groupName if param ('ByCalendar');
    }

    if ($cancel or $self->calendarName or (!$groupName and !$calName)) {
        print $self->redir ($self->makeURL ({Op => 'SysGroups'}));
        return;
    }

    my @calendars = sort {lc($a) cmp lc($b)} MasterDB->getAllCalendars;

    if ($save) {
        $self->{audit_formsaved}++;
        my @selectedItems = param ('SelectionList');
        my %selected = map {$_ => 1} @selectedItems;

        # If modifying calendars for a group:
        #   modify each cal if its membership for this group changed
        if ($groupName) {
            foreach my $thisCal (@calendars) {
                my $db = Database->new ($thisCal);
                my $prefs = $db->getPreferences;
                my %wasInGroup = map {$_ => 1} $prefs->getGroups;
                my $wasInGroup = $wasInGroup{$thisCal} || 0;
                my $nowInGroup = $selected{$thisCal}   || 0;
                next if ($wasInGroup == $nowInGroup);

                $nowInGroup ? $prefs->addGroup ($groupName)
                    : $prefs->deleteGroup ($groupName);

                $db->setPreferences ($prefs);
            }
        }

        # If modifying groups for a calendar:
        if ($calName) {
            my $calDb = Database->new ($calName);
            my $calPrefs = $calDb->getPreferences;
            my @origGroups = sort {lc($a) cmp lc($b)} $calPrefs->getGroups;
            my @newGroups  = sort {lc($a) cmp lc($b)} @selectedItems;

            # if groups changed, save new prefs
            my $orig = join ',', @origGroups;
            my $new  = join ',', @newGroups;
            if ($orig ne $new) {
                $calPrefs->setGroups (@newGroups);
                $calDb->setPreferences ($calPrefs);
            }
        }
    }

    my $title;
    my (@items, @selected);   # either cals in group, or groups for a cal
    my ($head, $subHead);

    if ($calName) {
        $title   = 'Groups for a Calendar';
        $head    = $i18n->get ('Calendar') . ": $calName";
        $subHead = $i18n->get ('Assign Groups');
        @items    = sort {lc($a) cmp lc($b)} MasterDB->getGroups;
        @selected = Preferences->new ($calName)->getGroups;
    } else {
        $title   = 'Calendar Group Members';
        $head    = $i18n->get ('Group') . ": $groupName";
        $subHead = $i18n->get ('Assign Calendars');
        my ($calsInGroup, $none) = MasterDB->getCalendarsInGroup ($groupName);
        @items    = @calendars;
        @selected = @$calsInGroup;
    }

    # And display (or re-display) the form
    print GetHTML->startHTML (title => $i18n->get ($title));
    print GetHTML->SysAdminHeader ($i18n, $title, 1);

    print startform;

    print '<center>';
    print h2 ($head);
    print h3 ($subHead);

    print scrolling_list (-name     => "SelectionList",
                          -Values   => \@items,
                          -defaults => \@selected,
                          -size     => 10,
                          -multiple => 'true');

    print '<br>';
    print '<small><b>' . $i18n->get ('Note') . ': </b>';
    print $i18n->get ('control-click to choose multiple items.');
    print '</small>';
    print '</center>';

    print '<hr>';
    print submit (-name  => 'Save',
                  -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset (-value  => 'Reset');
    print hidden (-name => 'Op',       -value => __PACKAGE__);
    print hidden (-name => 'GroupName',  -value => $groupName)
        if (defined $groupName);
    print hidden (-name => 'CalName', -value => $calName)
        if (defined $calName);

    print endform;
    print end_html;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $summary =  $self->SUPER::auditString ($short);
}

1;
