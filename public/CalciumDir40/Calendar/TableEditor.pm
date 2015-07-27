# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

# TODO: implement multi-column keys
#       fix "renderAddRow" stuff in TableEditor::Row
#       allow multiple "New" Rows
#       borken if colname is "NEW" or "key"
#       - in column name NOT ALLOWED!

package TableEditor;
use strict;
use CGI;

my $deleteName = 'TABLE_EDITOR_DELETE';
sub new {
    my ($class, %params) = @_;
    my $self = {columns      => [],
                columnLabels => {},
                key          => '', # non-editable key fields
                types        => {}, # control type; defaults to 'textfield'
                controlparams => {}, # params for certain control types
                rows         => [], # array of hashes; {colname => value}
                deleteLabel  => 'Delete?',
                newLabel     => 'Or add new <nobr>--&gt;</nobr>',
                tableTitle   => undef,
                viewOnly     => undef,
                numAddRows   => 1,
                %params};

    # copy colums array, since we might modify it
    $self->{columns} = [@{$self->{columns}}];

    unless ($params{viewOnly}) {
        unshift @{$self->{columns}}, $deleteName;
        $self->{columnLabels}->{$deleteName} = $self->{deleteLabel};
        $self->{types}->{$deleteName} = 'checkbox';
    }

    bless $self, $class;
}

# Return arrayref
sub columns {
    return shift->{columns};
}

# Return arrayref
sub rows {
    return shift->{rows} || [];
}

sub addRow {
    my ($self, %dataHash) = @_;
    $self->{rows} ||= [];
    my $id = scalar (@{$self->{rows}});
    my $row = TableEditor::Row->new ($self, $id, \%dataHash);
    push @{$self->{rows}}, $row;
    return $row;
}

sub renderHeader {
    my $self = shift;
    return unless defined ($self->columns->[0]);
    my $row;
    foreach (@{$self->columns}) {
        $row .= '<th>' . ($self->{columnLabels}->{$_} || $_) . '</th>';
    }
    return qq (<tr class="AdminTableColumnHeader">$row</tr>);
}

sub render {
    my $self = shift;
    my %params = (align       => 'center',
                  border      => 1,
                  cellpadding => 3,
                  width       => '90%',
                  class       => 'alternatingTable',
                  @_);
    my @rows;
    if ($self->{tableTitle}) {
        my $numCols = @{$self->columns};
        push @rows, qq (<tr class="AdminTableHeader">
                            <th colspan=$numCols>
                            $self->{tableTitle}</th></tr>);
    }
    push @rows, $self->renderHeader;
    return unless @rows;
    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    foreach my $row (@{$self->rows}) {
        push @rows, $row->render ($thisRow);
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
    }

    unless ($self->{viewOnly}) {
        for (my $id=0; $id<$self->{numAddRows}; $id++) {
            my $addRow = TableEditor::Row->newAddRow ($id, $self);
            push @rows, $addRow->render ('addRow');
        }
    }

    my $params = join ' ', map {"$_=$params{$_}"} keys %params;
    return qq (<table $params>@rows</table>);
}

sub renderRenameRow {
    my $self = shift;
    my %params = (align       => 'center',
                  border      => 1,
                  cellpadding => 3,
                  width       => '90%',
                  title       => 'Rename',
                  names       => [],
                  existLabel  => 'Existing Name',
                  newLabel    => 'New Name',
                  oldName     => 'OldName',
                  newName     => 'NewName',
                  @_);
    my $params = join ' ', map {"$_=$params{$_}"} keys %params;

    my $title = qq (<tr class="AdminTableColumnHeader">
                    <th>$params{title}</th></tr>);

    my $cgi = CGI->new;
    my $popup = $cgi->popup_menu (-name   => $params{oldName},
                                  -Values => $params{names});

    my $html = "<table $params>$title";
    $html .= qq (<tr><td align="center">$params{existLabel}:
                     $popup
                     &nbsp;&nbsp;&nbsp;
                     $params{newLabel}:
                     <input type="text" name="$params{newName}"></td></tr>);
    $html .= '</table>';
    return $html;
}

sub isKey {
    my ($self, $colName) = @_;
    return ($colName eq $self->{key});
}


# ------------

package TableEditor::Row;
sub new {
    my ($class, $tableEditor, $id, $dataHash) = @_;
    my $self = {table => $tableEditor,
                id    => $id,
                data  => $dataHash};
    bless $self, $class;
}

sub newAddRow {
    my ($class, $id, $tableEditor) = @_;
    my $self = {table => $tableEditor,
                id    => $id,
                isAdd => 1};
    bless $self, $class;
}


# Return value of key column
sub keyValue {
    my $self = shift;
    return $self->{data}->{$self->{table}->{key}};
}

sub setStyles {
    my ($self, %styleHash) = @_;
    $self->{CSS} = \%styleHash;
}

sub render {
    my ($self, $thisThatRow) = @_;
    return $self->renderAddRow ($thisThatRow)
        if ($self->{isAdd});

    my $cgi = CGI->new;         # so we don't have to deal with encoding

    my $html;
    my $t = $self->{table};
    my $keyValue = $self->keyValue;
    my $key = $self->{id};
    foreach my $colName (@{$t->columns}) {

        my $style = $self->{CSS}->{$colName};
        $style = $style ? qq (style="$style") : '';

        my $val = $self->{data}->{$colName};
        $val = '' unless defined $val;

        my $type = $t->{types}->{$colName} || 'textfield';
        if ($t->{viewOnly} or !$type or $t->isKey ($colName)) {
            $html .= "<td ID=\"$key-cell\" $style>";
            $val = $cgi->escapeHTML ($val);
            $html .= $val || '&nbsp;'; # display only
            if ($t->isKey ($colName)) {
                $html .= $cgi->hidden (-name     => "key-$key",
                                       -override => 1,
                                       -value    => "$keyValue");
            }
            $html .= '</td>';
        } else {
            $html .= "<td $style>";
            my $colParams = $t->{controlparams}->{$colName} || {};
            if ($type eq 'textfield') {
                my $size = $colParams->{size} || 10;
                $html .= $cgi->textfield (-name     => "$colName-$key",
                                          -override => 1,
                                          -default  => $val,
                                          -size     => $size,
                                          -class    => "${colName}Input");
            }
            elsif ($type eq 'checkbox') {
                $html .= qq (<input type="checkbox" name="$colName-$key");
                $html .= $val ? ' checked>' : '>';
            }
            elsif ($type eq 'popupMenu') {
                $html .= qq (<select name="$colName-$key">);
                foreach my $name (@{$colParams->{values}}) {
                    my $label = $colParams->{labels}->{$name} || $name;
                    my $s = ($val eq $name) ? 'selected' : '';
                    $html .= qq(<option $s value="$name">$label</option>);
                }
                $html .= qq (</select>);
            }
            else {
                $html .= $val;  # default to 'view only'
            }
            $html .= '</td>';
        }
    }
    return $cgi->Tr ({-class => $thisThatRow, -align => 'center'}, $html);
}

sub renderAddRow {
    my ($self, $style) = @_;
    my $html;
    my $t  = $self->{table};
    my $id = $self->{id};
    my $first = 1;
    foreach my $colName (@{$t->columns}) {
        my $colParams = $t->{controlparams}->{$colName} || {};
        my $type = $t->{types}->{$colName} || 'textfield';

        if ($first++ == 1) {
            undef $type;
        }

        my $name = "NEW-$id-$colName";

        $html .= '<td>';
        if (!defined $type) {
            my $prompt = ($self->{id} == 0) ? $t->{newLabel}
                                            : '<nobr>--&gt;</nobr>';
            $html .= qq (<span class="AddLabel"><b>$prompt</b></span>);
        }
        elsif ($type eq 'textfield') {
            my $size = $colParams->{size} || 10;
            $html .= qq (<input type="text" name="$name" size=$size>);
        }
        elsif ($type eq 'checkbox') {
            $html .= qq (<input type="checkbox" name="$name");
        }
        elsif ($type eq 'popupMenu') {
            $html .= qq (<select name="$name">);
            foreach my $name (@{$colParams->{values}}) {
                my $label = $colParams->{labels}->{$name} || $name;
                my $def = $colParams->{default};
                my $sel = (defined $def and $name eq $def) ? 'selected' : '';
                $html .= qq(<option value="$name" $sel>$label</option>);
            }
            $html .= qq (</select>);
        }
        $html .= '</td>';
    }
    return "<tr align=\"center\" class=\"$style\">$html</tr>";
}


package TableEditor::ParamParser;
sub new {
    my ($class, %params) = @_;
    my %self = (columns    => [],
                key        => '',
                params     => {},
                numAddRows => 1,
                %params);

    # copy colums array, since we modify it
    $self{columns} = [@{$self{columns}}];

    # parser not used if view only...
    unshift @{$self{columns}}, $deleteName;

    bless \%self, $class;
}

# Convert raw CGI params into hash of hashes.
# One hash per row, indexed by key column. (colname => value)
sub parseParamHash {
    my ($self) = @_;
    return if ($self->{parsed}++); # only do it once

    my $params = $self->{params};

    my @newRows;

    # First, grab entries from new rows (if any)
    # New Rows have keys like 'NEW-1-Background', i.e. "NEW-$index-colname'
    for (my $id=0; $id<$self->{numAddRows}; $id++) {
        my $prefix = "NEW-$id";
        my $key = $params->{"$prefix-$self->{key}"};
        next unless (defined ($key) and $key ne '');
        my %rowHash;
        foreach (@{$self->{columns}}) {
            $rowHash{$_} = $params->{"$prefix-$_"};
        }
        push @newRows, \%rowHash;
    }
    $self->{newRows} = \@newRows;

    my %isColumn = map {$_ => 1} @{$self->{columns}};
    my %rowHashes;

    # hash keys look like 'Background-0', i.e. "colname-rowindex"
    foreach (keys %$params) {
        my ($column, $id) = split '-', $_, 2;
        next unless $isColumn{$column};
        my $key = $params->{"$self->{key}-$id"};
        $key = $params->{"key-$id"};
        if ($column eq $deleteName) {
            $self->{deletedKeys} ||= [];
            push @{$self->{deletedKeys}}, $key;
            next;
        }
        $rowHashes{$key} ||= {};
        $rowHashes{$key}->{$column} = $params->{$_};
    }

    # remove deleted items
    foreach (@{$self->{deletedKeys}}) {
        delete $rowHashes{$_};
    }

    $self->{rows} = \%rowHashes;
}

# Return keys for rows which were deleted
sub getDeleted {
    my $self = shift;
    $self->parseParamHash;
    return $self->{deletedKeys} ? @{$self->{deletedKeys}} : ();
}

# Return listref of hashes for all new rows
sub getNewRows {
    my $self = shift;
    $self->parseParamHash;
    return $self->{newRows} || [];
}

sub getRows {
    my $self = shift;
    $self->parseParamHash;
    return $self->{rows} ? $self->{rows} : {};
}

sub renamed {
    my $self = shift;
    return ($self->renamedOldName and $self->renamedNewName);
}

sub renamedOldName {
    my $self = shift;
    my %args = (oldName => 'OldName',
                @_);
    return $self->{params}->{$args{oldName}};
}
sub renamedNewName {
    my $self = shift;
    my %args = (newName => 'NewName',
                @_);
    return $self->{params}->{$args{newName}};
}


1;
