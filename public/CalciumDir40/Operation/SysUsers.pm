# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Add/Delete users, set passwords
package SysUsers;
use strict;
use CGI;

use Calendar::AdminPager;
use Calendar::GetHTML;
use Calendar::TableEditor;
use Calendar::User;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL({Op => 'SysAdminPage'}));
        return;
    }

    my $cgi  = CGI->new;
    my $i18n = $self->I18N;

    my @columns   = qw (Username Email DefaultCal TimeZone Password IsLocked);
    my %colLabels = (Username   => $i18n->get ("Username"),
                     Email      => $i18n->get ("Email Address"),
                     DefaultCal => $i18n->get ("Default Calendar"),
                     TimeZone   => $i18n->get ("Timezone Offset"),
                     Password   => $i18n->get ("Set New Password"),
                     IsLocked   => $i18n->get ("Locked"),
                     );
    my %colTypes = (DefaultCal => 'popupMenu',
                    TimeZone   => 'popupMenu',
                    IsLocked   => 'checkbox');
    my $numAddRows = 3;

    my @calendars = sort {lc($a) cmp lc($b)} MasterDB->getAllCalendars;

    my $stet = ' - - - ';

    my (@messages, @errors);

    if ($save) {
        $self->{audit_formsaved}++;
        my $ted = TableEditor::ParamParser->new (columns    => \@columns,
                                                 key        => 'Username',
                                                 numAddRows => $numAddRows,
                                                 params  => $self->rawParams);
        my @deletedKeys = $ted->getDeleted;
        my $rowHashes   = $ted->getRows;
        my $newRows     = $ted->getNewRows;

        my @deletedUsers;
        foreach my $username (@deletedKeys) {
            my $me = $self->getUsername || '';
            if ($username eq $me) {
                push @errors, $i18n->get ('You cannot delete yourself.');
                next;
            }
            push @deletedUsers, $username;
            MasterDB->removeUser ($username);
        }

        # And remove the deleted user permissions from each calendar
        if (@deletedUsers) {
            foreach (@calendars, undef) {
                my $perms = defined $_ ? Permissions->new ($_)
                                       : Permissions->new (MasterDB->new);
                my $uhash = $perms->getUserHash;
                foreach my $user (@deletedUsers) {
                    delete $uhash->{$user};
                }
                $perms->setUserHash ($uhash) if (@deletedUsers);
            }
            my $x = @deletedUsers > 1 ? 'Deleted Users' : 'Deleted User';
            push @messages, $i18n->get ($x) . ': ' .
                            join ', ', sort {lc $a cmp lc $b} @deletedUsers;
            $self->{audit_deletedUsers} = \@deletedUsers;
        }

        # Modify existing ones
        $self->{audit_modifiedUsers} = {};
        while (my ($name, $vals) = each %$rowHashes) {
            my $user = User->getUser ($name);
            next unless $user;
            my @mods;
            if (($vals->{Email} || '') ne ($user->email || '')) {
                $user->setEmail ($vals->{Email});
                push @mods, 'Email';
            }
            if (($vals->{TimeZone} || 0) != ($user->timezone || 0)) {
                $user->setTimezone ($vals->{TimeZone});
                push @mods, 'TimeZone';
            }
            my $defaultCal = $vals->{DefaultCal} eq $stet ? undef
                                                         : $vals->{DefaultCal};
            if (($defaultCal || '') ne ($user->defaultCalendar || '')) {
                $user->setDefaultCalendar ($defaultCal);
                push @mods, 'DefaultCal';
            }
            if ($vals->{Password} ne $stet) {
                $user->setPassword ($vals->{Password});
                push @mods, 'Password';
            }
            if ($vals->{IsLocked} xor $user->isLocked) {
                $user->setLocked ($vals->{IsLocked});
                push @mods, 'IsLocked';
            }
            if (@mods) {
                push @messages, $i18n->get ('Changed User') . ": $name; " .
                                       join (', ', map {$colLabels{$_}} @mods);
                $self->{audit_modifiedUsers}->{$name} = \@mods;
            }
        }

        # Add new ones
        my @newNames;
        foreach my $row (@$newRows) {
            my $name = $row->{Username};
            next if (!$name);
            if ($name =~ /\W/) {
                my $blah = $name;
                $blah =~ s/[-@\.\\]//g;
                if ($blah =~ /\W/) {
                    push @errors, "$name: " .
                                  $i18n->get ('Invalid Username') . '; ' .
                                  $i18n->get ('Only letters, digits, ' .
                                              'underscores, periods, @, and ' .
                                              'backslashes are allowed in ' .
                                              'user names.');
                    next;
                }
            }
            my $defaultCal = $row->{DefaultCal} eq $stet ? undef
                                                         : $row->{DefaultCal};
            my $password   = $row->{Password} eq $stet ? undef
                                                         : $row->{Password};
            my $newUser = User->create (name       => $name,
                                        email      => $row->{Email},
                                        defaultCal => $defaultCal,
                                        zoneOffset => $row->{TimeZone},
                                        isLocked   => $row->{IsLocked},
                                        password   => $password);

            if ($newUser->addUser) {
                push @newNames, $name;
            } else {
                push @errors, "<font color=red>" . $i18n->get ('Error') .
                              ":</font> " . $i18n->get ('User') .
                              " <b>$name</b> " . $i18n->get('already exists!');
            }
        }
        if (@newNames) {
            my $x = @newNames > 1 ? 'Added Users' : 'Added User';
            push @messages, $i18n->get ($x) . ': ' .
                            join ', ', sort {lc $a cmp lc $b} @newNames;
            $self->{audit_addedUsers} = \@newNames;
        }
    }

    unshift @calendars, $stet;

    my $h = $i18n->get ('hours');
    my %tzLabels;
    foreach (-23..23) {
        $tzLabels{$_} = "$_ $h";
    }

    my %colParams = (Email      => {size => 25},
                     DefaultCal => {values => \@calendars},
                     TimeZone   => {values  => [-23..23],
                                    default => 0,
                                    labels  => \%tzLabels});

    my $ted = TableEditor->new (columns       => \@columns,
                                key           => 'Username',
                                columnLabels  => \%colLabels,
                                types         => \%colTypes,
                                controlparams => \%colParams,
                                tableTitle    => $i18n->get ('Users'),
                                numAddRows    => $numAddRows,
                               );

    my @users = sort {lc($a->name) cmp lc($b->name)} User->getUsers;
    my $pager = AdminPager->new (op       => $self,
                                 contents => \@users,
                                 itemName => $i18n->get ('users'));
    my @displayThese = $pager->getDisplayList;

    foreach my $user (@displayThese) {
        next unless $user;
        my $row = $ted->addRow (Username   => $user->name,
                                Email      => $user->email,
                                DefaultCal => $user->defaultCalendar,
                                TimeZone   => $user->timezone || 0,
                                Password   => $stet,
                                IsLocked   => $user->isLocked);
    }

    print GetHTML->startHTML (title => $i18n->get ('User Administration'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'Add, Modify, or Delete Users', 1);

    if (@errors) {
        print '<p>', join ('<br>', @errors), '</p>'
    }
    if (@messages) {
        print '<p>', join ('<br>', @messages), '</p>'
    }

    print '<br>';
    print $cgi->startform;
    print $ted->render;

    print $pager->controls;

    print $cgi->submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;&nbsp;&nbsp;';
    print $cgi->reset  (-value => 'Reset');
    print $cgi->hidden (-name => 'Op', -value => __PACKAGE__);
    print $cgi->endform;

    print '<br><b>' . $i18n->get ('Notes') . ':</b>';

    print $cgi->ul (
            $cgi->li ($i18n->get (
               "The 'Default Calendar' is the calendar that is displayed " .
               "after the user logs in. It's also the calendar events are " .
               "added to for this user, via the 'Add Event' link in event " .
               "notification email.")),
            $cgi->li ($i18n->get ("'Locked' users cannot change any of " .
                                  'their own user settings.'))
                   );

    print $cgi->end_html;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= $self->cssString ('.PasswordInput',  {'text-align' => 'center'});
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    my $i18n = $self->I18N;

    my $space = $short ? '' : ' ';
    my $newl  = $short ? ' ' : "\n";

    $line .= $newl;

    if (my $x = $self->{audit_deletedUsers}) {
        $line .= $i18n->get ('Deleted') . ":$space" . join ",$space", @$x;
        $line .= $newl;
    }

    my $x = $self->{audit_modifiedUsers};
    if (keys %$x) {
        while (my ($name, $mods) = each %$x) {
            $line .= $i18n->get ('Modified') . ":$space$name$space-$space" .
                     join ",$space", @$mods;
            $line .= $newl;
        }
    }

    if (my $x = $self->{audit_addedUsers}) {
        $line .= $i18n->get ('Added') . ":$space" . join ",$space", @$x;
        $line .= $newl;
    }

    return $line;
}

1;
