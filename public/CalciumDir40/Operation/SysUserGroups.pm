# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

package SysUserGroups;
use strict;
use CGI (':standard');
use Calendar::GetHTML;
use Calendar::TableEditor;
use Calendar::UserGroup;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($save, $cancel) = $self->getParams (qw (Save Cancel));

    if ($cancel or $self->calendarName) {
        print $self->redir ($self->makeURL ({Op => 'SysAdminPage'}));
        return;
    }

    my $cgi   = CGI->new;
    my $i18n  = $self->I18N;
    my $message;

    my @columns = qw (GroupName Description);
    my $numAddRows = 3;

    my %colLabels = (GroupName   => $i18n->get ('Group Name'),
                     Description => $i18n->get ('Description'),
                     );

    my %colParams = (Description => {size => 40});

    if ($save) {
        $self->{audit_formsaved}++;

        my @groups = MasterDB->getUserGroups;
        my %nameMap;
        foreach (@groups) {
            $nameMap{$_->name} = $_;
        }

        my $ted = TableEditor::ParamParser->new (columns    => \@columns,
                                                 key        => 'GroupName',
                                                 numAddRows => $numAddRows,
                                                 params  => $self->rawParams);
        my @deletedKeys = $ted->getDeleted;
        my $rowHashes   = $ted->getRows;
        my $newRows     = $ted->getNewRows;

        foreach my $groupName (@deletedKeys) {
            MasterDB->removeUserGroup ($nameMap{$groupName});
        }

        # save modified groups
        while (my ($key, $vals) = each %$rowHashes) {
            my $name = $key;
            my $desc = $vals->{Description};
            my $group = $nameMap{$name};
            next unless $group;
            # skip if not modified
            next if ($group->name        eq $name and
                     $group->description eq $desc);
            $group->name ($name);
            $group->description ($desc);
            MasterDB->replaceUserGroup ($group);
        }

        foreach my $rowHash (@$newRows) {
            my $name = $rowHash->{GroupName};
            my $desc = $rowHash->{Description};
            next unless defined ($name);
            if (grep {$name eq $_->name} @groups) {
                $message = "$name: " . $i18n->get ('already exists');
                next;
            }
            my $group = UserGroup->new (name        => $name,
                                        description => $desc);
            my $id = MasterDB->addUserGroup ($group);
        }

        if ($ted->renamed) {
            my $oldName = $ted->renamedOldName;
            my $newName = $ted->renamedNewName;
            my @groups = MasterDB->getUserGroups;
            my ($oldGroup, $foundNew);
            foreach (@groups) {
                $oldGroup = $_
                    if ($_->name eq $oldName);
                $foundNew++
                    if ($_->name eq $newName);
            }
            if ($foundNew) {
                $message .= $i18n->get ('Group already exists') .
                    ": '$newName'";
            } elsif (!$oldGroup) {
                $message .= $i18n->get ('Group not found') .
                    ": '$oldName'";
            } else {
                $oldGroup->name ($newName);
                MasterDB->replaceUserGroup ($oldGroup);
            }
        }
    }

    my $ted = TableEditor->new (columns       => \@columns,
                                key           => 'GroupName',
                                columnLabels  => \%colLabels,
                                controlparams => \%colParams,
                                numAddRows    => $numAddRows,
                                tableTitle    => $i18n->get ('User Groups')
                               );
    my @groups = sort {lc ($a->name) cmp lc ($b->name)}
                      MasterDB->getUserGroups;
    my @groupNames;
    foreach (@groups) {
        my $row = $ted->addRow (GroupName   => $_->name,
                                Description => $_->description);
        push @groupNames, $_->name;
    }

    print GetHTML->startHTML (title => $i18n->get ('User Groups'),
                              op    => $self);
    print GetHTML->SysAdminHeader ($i18n, 'Manage User Groups', 1);

    print "<h3><center>$message</center></h3>" if $message;

    print '<br>';
    print $cgi->startform;
    print $ted->render;

    print '<br>';
    print $ted->renderRenameRow (title => $i18n->get ("Rename a User Group"),
                                 names => \@groupNames);
    print '<br><br>';

    print $cgi->submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;&nbsp;&nbsp;';
    print $cgi->reset  (-value => 'Reset');
    print $cgi->hidden (-name => 'Op', -value => __PACKAGE__);
    print $cgi->endform;

    print "<hr>\n";
    my $url = $self->makeURL ({Op => undef});
    print $cgi->startform (-action => $url);
    my $groupList = $cgi->scrolling_list (-name   => 'GroupName',
                                          -values => \@groupNames,
                                          -size   => 10);
    my @userNames = sort {lc ($a) cmp lc ($b)} User->getUserNames;
    my $userList = $cgi->scrolling_list (-name   => 'UserName',
                                         -values => \@userNames,
                                         -size   => 10);

    my $head   = '<b>' . $i18n->get ('User Groups') . '</b><br><small>' .
                 $i18n->get ('Select a group to view or edit the users in it')
                 . '</small>';
    my $gStuff = $head . '<br>' . $groupList . '<br><br>';
    $gStuff   .= $cgi->submit (-name  => 'ByGroup',
                               -value => $i18n->get ('View/Edit Users'));

    $head      = '<b>' . $i18n->get ('Users') . '</b><br><small>' .
                 $i18n->get ('Select a user to view or edit their groups') .
                 '</small>';
    my $uStuff = $head . '<br>' . $userList . '<br><br>';
    $uStuff   .= $cgi->submit (-name  => 'ByUser',
                               -value => $i18n->get ('View/Edit Groups'));
    print $cgi->table ({align => 'center',
                        width => '75%',
                        cellpadding => 10},
                       $cgi->Tr ({align => 'center',
                                  valign => 'top'},
                                 $cgi->td ($gStuff),
                                 $cgi->td ($uStuff)));
    print $cgi->hidden (-name     => 'Op',
                        -override => 1,
                        -value    => 'SysUserGroupAdmin');
    print $cgi->endform;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $summary =  $self->SUPER::auditString ($short);
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
