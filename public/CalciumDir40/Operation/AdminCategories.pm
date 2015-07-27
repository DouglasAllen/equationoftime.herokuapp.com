# Copyright 2000-2006, Fred Steinberg, Brown Bear Software

# Admin for defining Categories
package AdminCategories;
use strict;
use CGI (':standard');
use Calendar::Javascript;
use Calendar::TableEditor;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));
    my ($calName) = $self->calendarName;

    if ($cancel) {
        my $op = $calName ? 'AdminPage' : 'SysAdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $prefs = $self->prefs;

    my $masterPrefs;
    if ($calName) {
        $masterPrefs = MasterDB->new->getPreferences;
    } else {
        $masterPrefs = $prefs;
    }

    my @columns = qw (CatName BGColor FGColor Border ShowName);

    my $message;

    if ($save) {
        $self->{audit_formsaved}++;

        $self->{audit_categoryDeleted} = [];
        $self->{audit_categoryAdded}   = [];
        $self->{audit_categoryOld}     = {};
        $self->{audit_categoryNew}     = {};

        my $ted = TableEditor::ParamParser->new (columns    => \@columns,
                                                 key        => 'CatName',
                                                 numAddRows => 5,
                                                 params     =>
                                                     $self->rawParams);
        my @deletedKeys = $ted->getDeleted;
        my $rowHashes   = $ted->getRows;
        my $newRows     = $ted->getNewRows;

        my $savePrefs;

        foreach (@deletedKeys) {
            push @{$self->{audit_categoryDeleted}}, $_;
            $prefs->deleteCategory ($_);
            $savePrefs++;
        }

        while (my ($key, $vals) = each %$rowHashes) {
            my $name = $key;
            # strip whitespace from name, colors, display text
            foreach ($name, $vals->{BGColor}, $vals->{FGColor},
                     $vals->{ShowName}) {
                next unless defined;
                s/^\s+//;
                s/\s+$//;
            }
            $name =~ s/^\s*//;
            my $oldCat = $self->prefs->category ($name);
            my $newCat = Category->new (name     => $name,
                                        bg       => $vals->{BGColor},
                                        fg       => $vals->{FGColor},
                                        border   => $vals->{Border},
                                        showName => $vals->{ShowName});
            next unless $oldCat;
            if (!$oldCat->sameAs ($newCat)) {
                $self->{audit_categoryOld}->{$name} = $oldCat;
                $self->{audit_categoryNew}->{$name} = $newCat;
                $prefs->category ($name, $newCat);
                $savePrefs++;
            }
        }

        foreach my $rowHash (@$newRows) {
            my $newName = $rowHash->{CatName};
            # strip whitespace from name, colors
            foreach ($newName, $rowHash->{BGColor}, $rowHash->{FGColor},
                     $rowHash->{ShowName}) {
                next unless defined;
                s/^\s+//;
                s/\s+$//;
            }
            next unless defined ($newName);
            if ($prefs->category ($newName)) {
                $message = "$newName: " . $i18n->get ('already exists');
                next;
            }
            my $newCat = Category->new (name     => $newName,
                                        bg       => $rowHash->{BGColor},
                                        fg       => $rowHash->{FGColor},
                                        border   => $rowHash->{Border},
                                        showName => $rowHash->{ShowName});
            $prefs->category ($newName, $newCat);
            $savePrefs++;
            push @{$self->{audit_categoryAdded}}, $newCat;
        }

        if ($ted->renamed) {
            my $oldName = $ted->renamedOldName;
            my $newName = $ted->renamedNewName;
            $newName =~ s/^\s+//;
            $newName =~ s/\s+$//;
            if ($prefs->category ($newName)) {
                $message .= $i18n->get ('Warning') . ': ';
                $message .= $i18n->get ('Category already exists') .
                            ": $newName<br>";
            } elsif (!$prefs->category ($oldName)) {
                $message .= $i18n->get ('Warning') . ': ';
                $message .= $i18n->get ('Category not found') .
                            ": $oldName<br>";
            } else {
                $self->{audit_categoryRenamed} = [$oldName, $newName];
                $self->db->renameCategory ($oldName, $newName);
            }
        }

        $self->db->setPreferences ($prefs) if ($savePrefs);
    }

    print GetHTML->startHTML (title  => $i18n->get ('Categories') . ': ' .
                                        ($calName ||
                                             $i18n->get ('System Defaults')),
                              op     => $self);

    if ($calName) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $calName,
                                    section => 'Event Categories');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Event Categories', 1);
    }

    print '<center>';
    print $message if $message;
    print '</center>';
    print '<br>';

    my %colLabels = (CatName  => $i18n->get ('Category Name'),
                     BGColor  => $i18n->get ('Background Color'),
                     FGColor  => $i18n->get ('Foreground Color'),
                     Border   => $i18n->get ('Draw Border?'),
                     ShowName => $i18n->get ('Identifying Text'));
    my %controlTypes = (Border   => 'checkbox');

    my $sysTitle = $i18n->get ('System Defined Categories');

    # If we're in a calendar, first do System Categories table
    if ($calName) {
        my $ted = TableEditor->new (columns      => \@columns,
                                    key          => 'CatName',
                                    columnLabels => \%colLabels,
                                    tableTitle   => $sysTitle,
                                    viewOnly     => 1,
                                   );

        my @sysCats = $masterPrefs->getCategoryNames;

        # sort by start time
        my @cats = sort {lc($a) cmp lc($b)} @sysCats;
        foreach my $catName (@cats) {
            my $cat = $masterPrefs->category ($catName);
            my ($bg, $fg) = ($cat->bg, $cat->fg);
            my $row = $ted->addRow (CatName  => $catName,
                                    BGColor  => $bg,
                                    FGColor  => $fg,
                                    Border   => $cat->border   ? 'Yes' : 'No',
                                    ShowName => $cat->showName);
            $row->setStyles (CatName => "background-color: $bg; color: $fg;");
        }
        print $ted->render;
        unless (@{$ted->rows}) {
            print '<center>-none defined-</center>';
        }
        print '<br><br>';
    }

    print startform;

    my $tableTitle = $sysTitle;
    if ($calName) {
        $tableTitle  = $i18n->get ('Categories for This Calendar Only');
        $tableTitle .= '<br><small>' .
                        $i18n->get ('Note: you can override System ' .
                                    'Categories by adding a local one ' .
                                    'with the same name') . '</small>';
    }

    my $ted = TableEditor->new (columns      => \@columns,
                                key          => 'CatName',
                                columnLabels => \%colLabels,
                                types        => \%controlTypes,
                                numAddRows   => 5,
#                                deleteLabel  => 'Delete Category?',
                                tableTitle   => $tableTitle);

    my @myCats = sort {lc($a) cmp lc($b)} $self->prefs->getCategoryNames;
    my @names;
    foreach my $catName (@myCats) {
        my $cat = $self->prefs->category ($catName);
        next unless $cat;
        my ($bg, $fg) = ($cat->bg, $cat->fg);
        push @names, $catName;
        my $row = $ted->addRow (CatName  => $catName,
                                BGColor  => $bg,
                                FGColor  => $fg,
                                Border   => $cat->border,
                                ShowName => $cat->showName);
        $row->setStyles (CatName => "background-color: $bg; color: $fg;");
#                                     . 'text-align: left');

    }
    print $ted->render;

    print '<center>';
    print Javascript->ColorPalette ($self);
    print a ({-href   => "Javascript:ColorWindow()"},
             $i18n->get ('See Available Colors'));
    print '</center><br>';

    print $ted->renderRenameRow (title => $i18n->get ("Rename a Category"),
                                 names => \@names);
    print '<br><br>';

    print submit (-name => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print '&nbsp;';
    print reset  (-value => 'Reset');

    print hidden (-name => 'Op',           -value => __PACKAGE__);
    print hidden (-name => 'CalendarName', -value => $calName) if $calName;

    print endform;
    print '<hr/>';

    my @help_strings;
    my $string = $i18n->get ('AdminCategories_HelpString_1');
        if ($string eq 'AdminCategories_HelpString_1') {
            $string =  qq {If "Identifying Text" is specified, it will display
                           above each event that is in the category.
                           HTML is allowed here; for example, you could
                           display an icon with something like
                           <i>&lt;img src="/images/myicon.gif"&gt;</i>
                           or <nobr> <i>&lt;img
                           src="http://www.domain.com/icons/myicon.gif"&gt;
                           </i></nobr>
};
        }
    push @help_strings, $string;

    print '<br><div class="AdminNotes">';
    print span ({-class => 'AdminNotesHeader'}, $i18n->get ('Notes') . ':');
    print ul (li ([@help_strings]));
    print '</div>';

    print end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    my @newCats = map {$_->name            . ',' .
                       ($_->bg       || '-') . ',' .
                       ($_->fg       || '-') . ',' .
                       ($_->border   || '')  . ',' .
                       ($_->showName || '')}
                  @{$self->{audit_categoryAdded}};
    my $newCats = join ' | ', @newCats;
    $line .= " New[$newCats]" if $newCats;

    my $deletedCats = join ', ', @{$self->{audit_categoryDeleted}};
    $line .= " Deleted[$deletedCats]" if $deletedCats;

    my @changed;
    foreach my $name (keys %{$self->{audit_categoryOld}}) {
        my $old = $self->{audit_categoryOld}->{$name};
        my $new = $self->{audit_categoryNew}->{$name};
        my @mods;
        foreach my $field ( qw /bg fg border/) {
            push @mods, "$field:" .
                        ($old->$field() || '') . "->" . ($new->$field() || '');
        }
        push @changed, join (' ', ($name, @mods));
    }

    my $changedCats = join ', ', @changed;
    $line .= " Changed[$changedCats]" if $changedCats;

    if (my $names = $self->{audit_categoryRenamed}) {
        $line .= " Renamed: from '$names->[0]' to '$names->[1]'";
    }

    return $line;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
