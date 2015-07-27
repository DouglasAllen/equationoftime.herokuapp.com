# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Perform some maintenance on possibly broken databases.

package SysMaintenance;
use strict;
use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;
    my $message;

    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    if ($save) {
        my (%calFixes, %badRepeats);

        my @calendars = sort {lc($a) cmp lc($b)} MasterDB->getAllCalendars;


        # First, if Calendar datafiles exist but calendar not in Master,
        # add it to Master.
        my $dataDir = Defines->baseDirectory . '/data';
        opendir (DIR, $dataDir) or die "Error: Can't read dir: $dataDir: $!\n";
        my @files = readdir(DIR);
        closedir DIR;

        my (%events, %prefs, %dbm);
        foreach (@files) {
            next unless /^(.*)\.(Events|Preferences|dbm)$/;
            $events{$1}++ if ($2 eq 'Events');
            $prefs{$1}++  if ($2 eq 'Preferences');
            $dbm{$1}++    if ($2 eq 'dbm');
        }

        my $isDBM = Defines->databaseType eq 'DBM';
        my @calNamesByFile;
        if ($isDBM) {
            @calNamesByFile = keys %dbm;
        } else {
            @calNamesByFile = keys %events;
        }

        my @reAddedCalendars;
        foreach my $cal (sort @calNamesByFile) {
            next if (!$isDBM and !$prefs{$cal});
            next if ($cal =~ /\W/); # Don't add cals w/bad names
            next if (grep {$cal eq $_} @calendars);
            push @reAddedCalendars, $cal;
            MasterDB->_addNewCalendar ($cal);
        }


        # Next, ensure calendars listed in Master actually exist. If not,
        # remove from Master list...
        my (%calendars, @missingFiles);
        foreach (@calendars) {
            my $db = Database->new ($_);
            if ($$db->{Imp}->dbExists) {     # Danger Will Robinson!
                $calendars{$_} = $db;
                next;
            }

            # Datafiles do not exist
            push @missingFiles, $_;

            # MasterDB->deleteCalendar dies since files are gone; so, do
            # what's in there here
            AddIn->removeCalendarDir ($db);

            # Delete entries in reminder file
            if (Defines->mailEnabled) {
                require Calendar::Mail::MailReminder;
                MailReminder->deleteAllForCalendar ($_);
            }

            # Delete from Master list
            my $incHash = MasterDB->new->getPreferences ('Includes');
            delete $incHash->{$_};
            MasterDB->new->setPreferences ({'Includes' => $incHash});
        }

        #...and remove missing cals from existing calendars' include lists
        if (@missingFiles) {
            while (my ($name, $db) = each %calendars) {
                my $prefs = $db->getPreferences;
                my $includes = $prefs->{Includes};
                my $changed;
                foreach (@missingFiles) {
                    if ($includes && defined $includes->{$_}) {
                        delete $includes->{$_};
                        $changed++;
                    }
                }
                $db->setPreferences ({Includes => $includes}) if ($changed);
            }
        }

        @calendars = sort {lc($a) cmp lc($b)} keys %calendars;

        # Check each database for:
        #  - repeating events w/no info
        #  - events w/duplicate IDs; only can happen for repeaters.
        foreach my $calName (@calendars) {
            my $db = Database->new ($calName);

            # If it's DBM, first check for referenced events that don't exist
            # WARNING: This gets into the guts of Database and DB_DBM classes!
            if ($isDBM) {
                my $imp = $$db->{Imp};
                $imp->{db}->openDatabase ('readwrite');
                my @ids = split ' ', ($imp->{tiedHash}->{Repeaters} || '');
                foreach my $id (@ids) {
                    my $string = $imp->{tiedHash}->{$id};
                    next if defined $string;
                    warn "Bad repeating event: $id\n";
                    $badRepeats{$calName}++;
                    $imp->{tiedHash}->{Repeaters} =~ s/ $id / /;
                }
                $imp->{db}->closeDatabase ('force');
            }

            my $regHash = $db->getAllRegularEvents;
            my $repeats = $db->getAllRepeatingEvents;

            my %idMap;

            foreach my $event (@$repeats) {
                my $id = $event->id;
                unless ($event->repeatInfo) {
                    $db->deleteEvent ('', $id, 'all');
                    $calFixes{$calName}++;
                    next;
                }
                if (!$idMap{$id}) {
                    $idMap{$id} = $event;
                } else {
                    my ($deleted, $date) = $db->getEventById ($id);
                    while ($deleted) {
                        $db->insertEvent ($deleted); # gets new id
                        $db->deleteEvent ('', $id, 'all');
                        $idMap{$deleted->id} = $deleted;
                        ($deleted, $date) = $db->getEventById ($id);
                        last unless ($deleted->isRepeating);
                    }
                    $calFixes{$calName}++;
                }
            }
            my (@idDatePairsToDelete, @reinsert);
            foreach my $date (keys %$regHash) {
                foreach (@{$regHash->{$date}}) {
                    next unless ($idMap{$_->id});
                    # ID found, delete it, re-insert to get new ID
#                    $db->deleteRegularEvent ($date, $_->id);
                    push @idDatePairsToDelete, [$_->id, $date];
                    push @reinsert, ($_, $date);
#                    $db->insertEvent ($_, $date);
                    $calFixes{$calName}++;
                }
            }
            $db->deleteEventsBulk (\@idDatePairsToDelete);
            $db->insertEvents (\@reinsert);
        }

        # Fix any category names that have leading/trailing space
        my %categoryNames;
        foreach my $calName (@calendars, undef) { # under for MasterDB
            my $db = $calName ? Database->new ($calName) : MasterDB->new;
            my $prefs = $db->getPreferences;
            my $cats = $prefs->getCategories;
            while (my ($name, $cat) = each %$cats) {
                next unless ($name =~ /^\s+/ or $name =~ /\s+$/);
                my $newName = $name;
                $newName =~ s/^\s+//;
                $newName =~ s/\s+$//;
                $db->renameCategory ($name, $newName, 'prefs');
                $categoryNames{$calName} ||= [];
                push @{$categoryNames{$calName}}, $name;
            }
        }

        # Set up message to display
        $message = '';
        if (@reAddedCalendars) {
            $message = 'These calendars have data files, but were not in ' .
                       'the Master list. ' .
                       "They've been re-added.<br>";
            $message .= join ', ', @reAddedCalendars;
            $message = "<p>$message</p>";
        }
        if (@missingFiles) {
            $message = 'These calendars were in the Master list, ' .
                       "but no data files were found. They've been
                       removed.<br>";
            $message .= join ', ', @missingFiles;
            $message = "<p>$message</p>";
        }
        if (keys %categoryNames) {
            $message = 'Removed leading/trailing whitespace from ' .
                       'category names: ';
            foreach (sort {lc ($a) cmp lc ($b)} keys %categoryNames) {
                $message .= '<p>';
                $message .= "$_ - " . join (',', @{$categoryNames{$_}});
                $message .= '</p>';
            }
        }
        while (my ($cal, $count) = each %calFixes) {
            next unless $count;
            $message .= "<p>$cal - fixed ID problem for $count events<br></p>";
        }
        while (my ($cal, $count) = each %badRepeats) {
            next unless $count;
            $message .= "<p>$cal - removed $count invalid repeating " .
                        "event(s)<br></p>";
        }

        $message = 'No problems found.' unless $message;
        $message .= '<hr width="50%">';
    }

    # And display (or re-display) the form
    print GetHTML->startHTML (title => $i18n->get ('System Maintenance'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'System Maintenance', 1);

    print '<center>';

    print ("<br><b><big>$message</big></b>") if $message;

    print h3 qq {<p>This will check your datafiles for possible problems, and
                 repair them.</p>};
    print h3 qq {You normally shouldn't need to do this, unless instructed
                 to by tech support.};     # '
    print qq {(But it won't hurt anything.)};    # '
    print startform;

    print submit (-name  => 'Save',
                  -value => $i18n->get ('Check and Repair'));
    print '&nbsp;';

    print '</center>';

    print '<hr>';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Back'));

    print hidden (-name => 'Op', -value => __PACKAGE__);

    print endform;
    print end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $summary =  $self->SUPER::auditString ($short);
    return $summary;
}

# We need to do some special stuff for DBM files.
package Database;
sub deleteRegularEvent {
    my ($self, $date, $id) = @_;
    $$self->{'Imp'}->deleteRegularEvent ($date, $id);
}

package DB_DBM;
sub deleteRegularEvent {
    my ($self, $date, $eventID) = @_;

    $self->{db}->openDatabase ('readwrite');

    my @eventList = $self->_getRegularEvents ($date);
    my $i;
    for ($i=0; $i<@eventList; $i++) {
        last if ($eventList[$i]->id == $eventID);
    }

    # If we found it, delete it
    if ($i < @eventList) {
        splice @eventList, $i, 1;
        $self->_setRegularEvents ($date, @eventList);
    }

    $self->{db}->closeDatabase;
}

package DB_Serialize;
sub deleteRegularEvent {
    my ($self, $date, $id) = @_;
    $self->deleteEvent ($date, $id);
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

# --------------------------------------------
package Database;
sub deleteEventsBulk {
    my ($self, $idDatePairs) = @_;      # if date null, it's a repeater
    my $ids = $$self->{Imp}->deleteEventsBulk ($idDatePairs);
#     if ($self->getPreferences ('IsSyncable') and
#         $self->getPreferences ('LastRMSyncID')) {
#         require Calendar::SyncInfo;
#         my $syncinfo = SyncInfo->new ($self->name);
#         foreach (@$idDatePairs) {
#             my $id = $_->[0];
#             $syncinfo->eventDeleted ($id);
#         }
#     }
    if (Defines->mailEnabled) {
        require Calendar::Mail::MailReminder;
        MailReminder->deleteEventReminders ($ids, $self->name);
    }

}

package DB_Serialize;
sub deleteEventsBulk {
    my ($self, $idDatePairs) = @_;

    $self->{db}->openDatabase ('readwrite', 'Events');

    foreach (@$idDatePairs) {
        my $id   = $_->[0];
        my $date = $_->[1];

        my $listRef = $date ? $self->{'Data'}->{'Events'}->{"$date"} || []
                            : [];

        my $i;

        for ($i=0; $i<@$listRef; $i++) {
            last if ($listRef->[$i]->id() == $id);
        }

        # If we found it, delete it
        if ($i < @$listRef) {
            splice @$listRef, $i, 1;
            $self->{'Data'}->{'Events'}->{"$date"} = $listRef;
        } # otherwise, check the repeating events
#         else {
#             $listRef = $self->{'Data'}->{'Repeating'} || [];
#             for ($i=0; $i<@$listRef; $i++) {
#                 last if ($listRef->[$i]->id() == $id);
#             }
#             if ($i <@$listRef) {
#                 # Delete all, or mark single instance as an exclusion
#                 splice @$listRef, $i, 1;
#                 $self->{'Data'}->{'Repeating'} = $listRef;
#             }
#         }
    }

    $self->{db}->closeDatabase;

}

1;
