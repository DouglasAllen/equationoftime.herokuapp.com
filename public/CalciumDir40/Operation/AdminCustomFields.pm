# Copyright 2005-2006, Fred Steinberg, Brown Bear Software

# Admin for defining Custom Fields
package AdminCustomFields;
use strict;
use CGI;

use Calendar::CustomField;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;
    my $cgi  = CGI->new;

    my ($save, $cancel) = $self->getParams (qw (Save Cancel));
    my $calName = $self->calendarName;

    if ($cancel) {
        my $op = $calName ? 'AdminPage' : 'SysAdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my  %labels = (name     => $i18n->get ('Name') . ':',
                   default  => $i18n->get ('Default Value') . ':',
                   label    => $i18n->get ('Label') . ':',
                   required => $i18n->get ('Required?'),
                   order    => $i18n->get ('Display Order') . ':',
                   display  => $i18n->get ('Display the value') . ':',
                   cols     => $i18n->get ('Columns') . ':',
                   rows     => $i18n->get ('Rows') . ':',
                   width    => $i18n->get ('Width') . ':',
                   limit    => $i18n->get ('Maximum Length') . ':',
                   values   => $i18n->get ('Items') . ':'
                              . '<br><small>'
                              . $i18n->get ('(enter each value on a new line)')
                              . '</small>',
                   multidefault =>
                                $i18n->get ('Default Values') . ':'
                              . '<br><small>'
                              . $i18n->get ('(enter each value on a new line)')
                              . '</small>',
                  );
    $self->{form_labels} = \%labels;


    my $prefs = $self->prefs;

    my $masterPrefs;
    if ($calName) {
        $masterPrefs = MasterDB->new->getPreferences;
    } else {
        $masterPrefs = $prefs;
    }

    my @columns = qw (Name Type Default Required);

    my $message;

    # Check for "Delete"s
    my $delete_params = $self->get_matching_params ('^Delete-.*');
    foreach my $param_name (keys %$delete_params) {
        $param_name =~ /^Delete-(.*)$/;
        my $id = $1;
        $prefs->delete_custom_field ($id);

        my @field_order = split ',', ($prefs->CustomFieldOrder || '');
        @field_order = grep {$_ ne $id} @field_order;
        $prefs->CustomFieldOrder (join ',', @field_order);

        $self->db->setPreferences ($prefs);

        $self->{audit_fieldDeleted} ||= [];
        push @{$self->{audit_fieldDeleted}}, $id;
    }

    # Handle "modify field" - it's a separate popup window
    my ($modify, $modify_field_id)  = $self->getParams (qw /Modify FieldID/);
    if ($modify and defined $modify_field_id) {
        # Put up modify fields for the field; on save, refresh opener
        $self->display_modify_stuff ($modify_field_id);
        return;
    }

    # And handle the actual "Modify"; reload the opening window
    ($modify, $modify_field_id)  = $self->getParams (qw /SaveModify FieldID/);
    if ($modify and defined $modify_field_id) {
        my ($modified_field, $order) = $self->field_from_form_params;
        $modified_field->id ($modify_field_id);
        if ($message = $self->_check_new_field_name ($modified_field, 1)) {
            $self->display_modify_stuff ($modify_field_id, $message);
            return;
        }
        $order ||= 1;
        $prefs->set_custom_field ($modified_field);
        my @field_order = split ',', ($prefs->CustomFieldOrder || '');
        @field_order = grep {$_ ne $modify_field_id} @field_order;
        if ($order > @field_order) {
            $order = @field_order + 1;
        }
        splice @field_order, $order - 1, 0, $modify_field_id;
        $prefs->CustomFieldOrder (join ',', @field_order);
        $self->db->setPreferences ($prefs);
        my $url = $self->makeURL ({Op => __PACKAGE__});
        print GetHTML->startHTML;
        print <<END_OPENER_JS;
        <script type="text/javascript"><!--
        window.opener.location = "$url;"
        window.close();
        //--></script>
        </body></html>

END_OPENER_JS
    }

    # New Field added
    if ($self->getParams ('AddNewButton')) {
        my ($new_field, $order) = $self->field_from_form_params;
        $message = $self->_check_new_field_name ($new_field);
        if (!$message) {
            $order ||= 1;
            $prefs->new_custom_field ($new_field);
            my @field_order = split ',', ($prefs->CustomFieldOrder || '');
            splice @field_order, $order - 1, 0, $new_field->id;
            $prefs->CustomFieldOrder (join ',', @field_order);
            $self->db->setPreferences ($prefs);
        }
    }

    print GetHTML->startHTML (title  => $i18n->get ('Custom Fields') . ': ' .
                                        ($calName ||
                                             $i18n->get ('System Defaults')),
                              op     => $self);

    my $modify_url = $self->makeURL ({Op     => __PACKAGE__,
                                      Modify => 1}) . '&FieldID=';
    print <<END_MODIFY_JS;
<script type="text/javascript"><!--
  function modify_field (field_id) {
    var width  = Math.round (screen.width/2);
    var height = Math.round (screen.height/2);
    var win = window.open ("$modify_url" + field_id, "ModifyField",
                 "scrollbars,resizable,width=" + width + ",height=" + height);
    win.focus();
  }
//-->
</script>
END_MODIFY_JS

    if ($calName) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $calName,
                                    section => 'Custom Fields');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Custom Fields', 1);
    }

    if ($message) {
        print '<center>';
        print qq (<p class="ErrorHighlight">$message</p>);
        print '</center>';
    }
    print '<br>';

    # Display existing fields, with "Modify/Delete" buttons.
    my %colLabels = (Name     => $i18n->get ('Field Name'),
                     Example  => $i18n->get ('Example Edit Form control'),
                     Type     => $i18n->get ('Input Type'),
                     Default  => $i18n->get ('Default Value'),
                     Required => $i18n->get ('Required?'));
    my %type_names = (textfield   => 'Text - Single Line',
                      textarea    => 'Text - Multiple Line',
                      select      => 'Popup Menu - Choose One',
                      multiselect => 'Popup Menu - Choose Many',
                      checkbox    => 'Checkbox');
    my @type_names = qw /textfield textarea select multiselect checkbox/;

    print $cgi->startform;

    my $fields_lr = $self->prefs->get_custom_fields (system => undef);
    my %fields = map {$_->id => $_} @$fields_lr;
    my @order = split ',', ($self->prefs->CustomFieldOrder || '');
    my @names;
    my @rows = ($cgi->Tr ({-class => 'AdminTableColumnHeader'},
                          $cgi->th ([$colLabels{Name},
                                     $colLabels{Example},
                                     $colLabels{Required},
                                     '&nbsp;'])));
    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');
    my $tabindex = 1;
    foreach my $field_id (@order) {
        my $field = $fields{$field_id};
        next unless $field;
        my $field_id = $field->id;
        push @names, $field->name;
        my $example = $field->make_html (disabled =>
                                             $field->input_type !~ /select/);
        if (my $label = $field->label) {
            $example = "<table><tr><td><b>$label</b></td>"
                     . "<td>$example</td></tr></table>";
        }

        my $modify = $cgi->submit (-name  => "Modify-$field_id",
                                   -value => $i18n->get ('Modify'),
                                   -tabindex => $tabindex++,
                                   -onClick =>
                                      "modify_field ($field_id);return false;");
        my $delete = $cgi->submit (-class => 'DeleteButton',
                                   -tabindex => $tabindex++,
                                   -style => 'font-size: .6em',
                                   -name  => "Delete-$field_id",
                                   -value => $i18n->get ('Delete'));
        my $required = $field->required ? $i18n->get ('yes')
                                        : $i18n->get ('no');
        if ($field->input_type eq 'checkbox') {
            $required = ' - ';
        }
        push @rows, $cgi->Tr ({-class => $thisRow},
                              $cgi->td ($field->name),
                              $cgi->td ($example),
                              $cgi->td ({-align => 'center'}, $required),
                              $cgi->td ("$modify &nbsp; $delete"));
        ($thisRow, $thatRow) = ($thatRow, $thisRow);
    }
    print $cgi->table ({-class => 'alternatingTable',
                        -align  => 'center',
                        -cellpadding => 5,
                        -border => 1}, @rows);

    if (@rows == 1) {
        print $cgi->p ({-align => 'center'}, ' - ' .
                       $i18n->get ('No Custom Fields have been defined')
                       . ' - ');
    }

    # Create New Field Section
    print '<br/>';


    print '<center><div style="border-width: 1px; border-style: solid; '
          . 'text-align: center; padding: 5px; width: 50%">';
    print $i18n->get ('New Field Type') . ': ';
    print $self->_field_setting_divs (CGI   => $cgi,
                                      I18N  => $i18n,
                                      default_type => 'textfield',
                                      field_count  => scalar (@order));

    print '<br/>';
    print $cgi->submit (-name     => 'AddNewButton',
                        -tabindex => 40,
                        -value    => $i18n->get ('Create New Field'));
    print '</div></center>';
    print '<br><br>';

    print '&nbsp;';
    print $cgi->submit (-name     => 'Cancel',
                        -value    => $i18n->get ('Done'),
                        -tabindex => 105);

    print $cgi->hidden (-name => 'Op',           -value => __PACKAGE__);
    print $cgi->hidden (-name => 'CalendarName', -value => $calName)
      if $calName;

    print $cgi->endform;
    print '<hr/>';

    my @help_strings;
    my %help;

    $help{general} = <<HELP_STRING;
        You can define templates for custom display of your custom
        fields; templates are available for: the Event Entry form,
        Event Popup windows, the List View "details" column,
        notification Mail, and RSS feeds. (See the Templates settings
        page.)
HELP_STRING

    $help{required} = <<HELP_STRING;
        If a field is marked "Required", new events will not be
        accepted unless a value is set for that field.
HELP_STRING

    $help{popup} = <<HELP_STRING;
        For Popup Menus, a value of - will be ignored. (That's a
        single hyphen.) You can include this as a choice and make it
        the default value for a required field  - this will require that the
        user make a valid choice from the popup menu, instead of
        defaulting to any particular choice.
HELP_STRING

    $help{unused} = <<HELP_STRING;
        The "Label" and "Display Order" are not used if an output
        output template is defined.
HELP_STRING

    foreach my $name (qw /general required popup unused/) {
        my $string_name = "AdminCustomFields_HelpString_$name";
        my $string = $i18n->get ($string_name);
        if ($string eq $string_name) {
            $string = $help{$name};
        }
        push @help_strings, $string;
    }

    print '<br><div class="AdminNotes">';
    print $cgi->span ({-class => 'AdminNotesHeader'},
                      $i18n->get ('Notes') . ':');
    print $cgi->ul ($cgi->li (\@help_strings));
    print '</div>';

    print $cgi->end_html;
}

# Return undef if new name ok, message otherwise
sub _check_new_field_name {
    my ($self, $field, $modifying) = @_;
    my $fields_lr = $self->prefs->get_custom_fields (system => undef);
    my %fields_by_name = map {$_->name, $_} @$fields_lr;
    if (!$field->name) {
        return $self->I18N->get ('Sorry - a field name is required.');
    }
    # If adding a new field w/same name as existing, or changing an existing
    #  name to the name of another field
    my $existing_field = $fields_by_name{$field->name};
    if ($existing_field
        and (!$modifying or ($field->id ne $existing_field->id))) {
        return sprintf $self->I18N->get ("Sorry, there's already a field "
                                         . "named '%s'"), $field->name;
    }
    return;
}


sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);
    return $line;
}

sub field_from_form_params {
    my $self = shift;

    # Get params based on type of new field
    my $field_type = $self->getParams ('FieldTypeSelector');

    # These should be defined for all field types
    my ($name, $default, $label, $required, $display, $order) =
      $self->getParams (map {$field_type . $_}
                        qw /Name Default Label Required Display Order/);

    # Some of these will be undef, based on field type
    my ($cols, $rows, $max_size) =
              $self->getParams (map {$field_type . $_} qw /Cols Rows Max/);

    # Input Values only for drop down menus; text area, split on newlines
    my $input_values;
    if ($field_type =~ 'select') {
        my $values = $self->getParams ($field_type . 'InputValues');
        $values =~ s/\r//g;      # get rid of carriage returns
        $input_values = [split "\n", $values];
    }

    # Multi select might have arrayref for default values
    if ($field_type eq 'multiselect') {
        my $values = $self->getParams ('multiselectDefault');
        $values =~ s/\r//g;      # get rid of carriage returns
        $default = [split "\n", $values];
    }

    my $new_field = CustomField->new (name         => $name,
                                      input_type   => $field_type,
                                      default      => $default,
                                      required     => $required,
                                      display      => $display ? 1 : undef,
                                      label        => $label,
                                      input_values => $input_values,
                                      cols         => $cols,
                                      rows         => $rows,
                                      max_size     => $max_size);
    return ($new_field, $order);
}

# Return hash of form entry controls common to all field types
sub _common_form_fields {
    my %params = @_;
    my $name        = $params{name};
    my $cgi         = $params{cgi};
    my $defaults    = $params{defaults} || {};
    my $field_count = $params{field_count};
    my $tab_index   = $params{tab_index};

    my %controls;
    $controls{name} = $cgi->textfield (-name      => $name . 'Name',
                                       -default   => $defaults->{name},
                                       -tabindex  => $tab_index->{name},
                                       -size      => 20,
                                       -maxlength => 60);
    $controls{order} = $cgi->popup_menu (-name      => $name . 'Order',
                                         -default   => $defaults->{order},
                                         -tabindex  => $tab_index->{order},
                                         -override  => 1,
                                         -values    => [1..$field_count+1]);
    $controls{label} = $cgi->textfield (-name     => $name . 'Label',
                                        -default  => $defaults->{label},
                                        -tabindex  => $tab_index->{label},
                                        -size     => 20);
    $controls{required} = $cgi->checkbox (-name    => $name . 'Required',
                                          -default  => $defaults->{required},
                                          -tabindex  => $tab_index->{required},
                                          -label => '');
    $controls{display} =  $cgi->popup_menu (-name     => $name . 'Display',
                                            -default  =>
                                                  $defaults->{display} ? 1 : 0,
                                            -tabindex => $tab_index->{display},
                                            -values   => [0, 1],
                                            -labels   => {0 =>
                                               'in Event Details',
                                                          1 =>
                                               'in Event Summary and Details'});
    return %controls;
}


# Single-line text field
sub _new_textfield_div {
    my $self = shift;
    my %args = @_;
    my ($cgi, $i18n, $field, $display, $display_order, $field_count)
             = @args{qw /cgi i18n field display display_order field_count/};
    my %defaults;
    if ($field) {
        $defaults{name}     = $field->name;
        $defaults{default}  = $field->default;
        $defaults{required} = $field->required;
        $defaults{display}  = $field->display;
        $defaults{label}    = $field->label;
        $defaults{width}    = $field->cols;
        $defaults{max}      = $field->max_size;
        if (ref $defaults{default}) {
            $defaults{default} = join ',', @{$defaults{default}};
        }
    }
    $defaults{order} = $display_order;

    my @display_order = qw /name default required label width limit
                            display order/;
    my $order_index = ($field_count * 2) + 1;
    my %tab_index = map {$_ => $order_index++} @display_order;

    # Get Name, Required, Display?, Label, Order
    my %common_fields = _common_form_fields (name        => 'textfield',
                                             defaults    => \%defaults,
                                             field_count => $field_count,
                                             tab_index   => \%tab_index,
                                             cgi         => $cgi);

    my $default  = $cgi->textfield (-name      => 'textfieldDefault',
                                    -default   => $defaults{default},
                                    -tabindex  => $tab_index{default},
                                    -size      => 20,
                                    -maxlength => 60);
    my $width    = $cgi->textfield (-name      => 'textfieldCols',
                                    -default   => $defaults{width} || '20',
                                    -tabindex  => $tab_index{width},
                                    -size      => 3,
                                    -maxlength => 4);
    my $limit    = $cgi->textfield (-name      => 'textfieldMax',
                                    -default   => $defaults{max} || '',
                                    -tabindex  => $tab_index{limit},
                                    -size      => 3,
                                    -maxlength => 5);
    my %controls = (name     => $common_fields{name},
                    default  => $default,
                    required => $common_fields{required},
                    display  => $common_fields{display},
                    label    => $common_fields{label},
                    order    => $common_fields{order},
                    width    => $width,
                    limit    => $limit);

    my @rows;
    foreach my $item (@display_order) {
        push @rows, $cgi->Tr ($cgi->td ({-align => 'right'},
                                        $self->{form_labels}->{$item}),
                              $cgi->td ({-align => 'left'},  $controls{$item}));
    }
    my $table = $cgi->table ({-align => 'center'}, @rows);
    my $hide  = $display ? '' : 'style = "display: none"';
    return qq (<div id="New_textfield_div" $hide>$table</div>);
}

# Multi-line text area
sub _new_textarea_div {
    my $self = shift;
    my %args = @_;
    my ($cgi, $i18n, $field, $display, $display_order, $field_count)
             = @args{qw /cgi i18n field display display_order field_count/};
    my %defaults;
    if ($field) {
        $defaults{name}     = $field->name;
        $defaults{default}  = $field->default;
        $defaults{required} = $field->required;
        $defaults{display}  = $field->display;
        $defaults{label}    = $field->label;
        $defaults{cols}     = $field->cols;
        $defaults{rows}     = $field->rows;
        if (ref $defaults{default}) {
            $defaults{default} = join "\n", @{$defaults{default}};
        }
    }
    $defaults{order} = $display_order;

    my @display_order = qw /name default required label cols rows
                            display order/;
    my $order_index = ($field_count * 2) + 1;
    my %tab_index = map {$_ => $order_index++} @display_order;

    my $default  = $cgi->textarea (-name     => 'textareaDefault',
                                   -default  => $defaults{default},
                                   -tabindex => $tab_index{default},
                                   -rows     => 6,
                                   -cols     => 40,
                                   -wrap     => 'SOFT');
    my $cols     = $cgi->textfield (-name      => 'textareaCols',
                                    -default   => $defaults{cols} || '40',
                                    -tabindex => $tab_index{cols},
                                    -size      => 3,
                                    -maxlength => 4);
    my $rows     = $cgi->textfield (-name      => 'textareaRows',
                                    -default   => $defaults{rows} || '6',
                                    -tabindex => $tab_index{rows},
                                    -size      => 3,
                                    -maxlength => 4);
    # Get Name, Order, etc.
    my %common_fields = _common_form_fields (name        => 'textarea',
                                             defaults    => \%defaults,
                                             field_count => $field_count,
                                             tab_index   => \%tab_index,
                                             cgi         => $cgi);
    my %controls = (name     => $common_fields{name},
                    default  => $default,
                    label    => $common_fields{label},
                    required => $common_fields{required},
                    display  => $common_fields{display},
                    order    => $common_fields{order},
                    cols     => $cols,
                    rows     => $rows);

    my @rows;
    foreach my $item (@display_order) {
        push @rows, $cgi->Tr ($cgi->td ({-align => 'right'},
                                        $self->{form_labels}->{$item}),
                              $cgi->td ({-align => 'left'},  $controls{$item}));
    }
    my $table = $cgi->table ({-align => 'center'}, @rows);
    my $hide = $display ? '' : 'style = "display: none"';
    return qq (<div id="New_textarea_div" $hide>$table</div>);
}

# Single select drop-down menu
sub _new_select_div {
    my $self = shift;
    my %args = @_;
    my ($cgi, $i18n, $field, $display, $display_order, $field_count)
             = @args{qw /cgi i18n field display display_order field_count/};
    my %defaults;
    if ($field) {
        $defaults{name}     = $field->name;
        $defaults{default}  = $field->default;
        $defaults{required} = $field->required;
        $defaults{display}  = $field->display;
        $defaults{label}    = $field->label;
        $defaults{values}   = join "\n", $field->input_values;
        if (ref $defaults{default}) {
            $defaults{default} = join ',', @{$defaults{default}};
        }
    }
    $defaults{order} = $display_order;

    my @display_order = qw /name values default required label display order/;
    my $order_index = ($field_count * 2) + 1;
    my %tab_index = map {$_ => $order_index++} @display_order;

    # Get Name, Required, Label, Order
    my %common_fields = _common_form_fields (name        => 'select',
                                             defaults    => \%defaults,
                                             field_count => $field_count,
                                             tab_index   => \%tab_index,
                                             cgi         => $cgi);
    my $default  = $cgi->textfield (-name      => 'selectDefault',
                                    -default   => $defaults{default},
                                    -tabindex  => $tab_index{default},
                                    -size      => 20,
                                    -maxlength => 60);
    my $values   = $cgi->textarea (-name => 'selectInputValues',
                                   -default => $defaults{values},
                                   -tabindex  => $tab_index{values},
                                   -rows => 6,
                                   -cols => 40,
                                   -wrap => 'SOFT');

    my %controls = (name     => $common_fields{name},
                    default  => $default,
                    required => $common_fields{required},
                    display  => $common_fields{display},
                    label    => $common_fields{label},
                    order    => $common_fields{order},
                    values   => $values);

    my @rows;
    foreach my $item (@display_order) {
        push @rows, $cgi->Tr ($cgi->td ({-align => 'right'},
                                        $self->{form_labels}->{$item}),
                              $cgi->td ({-align => 'left'},  $controls{$item}));
    }
    my $table = $cgi->table ({-align => 'center'}, @rows);
    my $hide  = $display ? '' : 'style = "display: none"';
    return qq (<div id="New_select_div" $hide>$table</div>);
}

# Multi select drop-down menu
sub _new_multiselect_div {
    my $self = shift;
    my %args = @_;
    my ($cgi, $i18n, $field, $display, $display_order, $field_count)
             = @args{qw /cgi i18n field display display_order field_count/};
    my %defaults;
    if ($field) {
        $defaults{name}     = $field->name;
        $defaults{default}  = $field->is_multi_valued
                                  ? join "\n", @{$field->default}
                                  : $field->default;
        $defaults{required} = $field->required;
        $defaults{display}  = $field->display;
        $defaults{label}    = $field->label;
        $defaults{values}   = join "\n", $field->input_values;
        $defaults{rows}     = $field->rows;
    }
    $defaults{order} = $display_order;

    my @display_order = qw /name values multidefault required label rows
                            display order/;
    my $order_index = ($field_count * 2) + 1;
    my %tab_index = map {$_ => $order_index++} @display_order;

    # Get Name, Required, Label, Order
    my %common_fields = _common_form_fields (name        => 'multiselect',
                                             defaults    => \%defaults,
                                             field_count => $field_count,
                                             tab_index   => \%tab_index,
                                             cgi         => $cgi);
    my $default  = $cgi->textarea (-name    => 'multiselectDefault',
                                   -default => $defaults{default},
                                   -tabindex  => $tab_index{multidefault},
                                   -rows    => 4,
                                   -cols    => 40,
                                   -wrap    => 'SOFT');
    my $values   = $cgi->textarea (-name => 'multiselectInputValues',
                                   -default => $defaults{values},
                                   -tabindex  => $tab_index{values},
                                   -rows => 6,
                                   -cols => 40,
                                   -wrap => 'SOFT');
    my $rows     = $cgi->textfield (-name      => 'multiselectRows',
                                    -default   => $defaults{rows} || '5',
                                    -tabindex => $tab_index{rows},
                                    -size      => 3,
                                    -maxlength => 4);

    my %controls = (name     => $common_fields{name},
                    multidefault  => $default,
                    required => $common_fields{required},
                    display  => $common_fields{display},
                    label    => $common_fields{label},
                    order    => $common_fields{order},
                    rows     => $rows,
                    values   => $values);

    my @rows;
    foreach my $item (@display_order) {
        push @rows, $cgi->Tr ($cgi->td ({-align => 'right'},
                                        $self->{form_labels}->{$item}),
                              $cgi->td ({-align => 'left'},  $controls{$item}));
    }
    my $table = $cgi->table ({-align => 'center'}, @rows);
    my $hide  = $display ? '' : 'style = "display: none"';
    return qq (<div id="New_multiselect_div" $hide>$table</div>);
}

sub _new_checkbox_div {
    my $self = shift;
    my %args = @_;
    my ($cgi, $i18n, $field, $display, $display_order, $field_count)
             = @args{qw /cgi i18n field display display_order field_count/};
    my %defaults;
    if ($field) {
        $defaults{name}     = $field->name;
        $defaults{default}  = $field->default;
        $defaults{required} = $field->required;
        $defaults{display}  = $field->display;
        $defaults{label}    = $field->label;
    }
    $defaults{order} = $display_order;

    my @display_order = qw /name default label display order/;
    my $order_index = ($field_count * 2) + 1;
    my %tab_index = map {$_ => $order_index++} @display_order;

    # Get Name, Required, Label, Order (don't use "required" actually)
    my %common_fields = _common_form_fields (name        => 'checkbox',
                                             defaults    => \%defaults,
                                             field_count => $field_count,
                                             tab_index   => \%tab_index,
                                             cgi         => $cgi);

    my $default  = $cgi->checkbox (-name      => 'checkboxDefault',
                                   -checked   => $defaults{default},
                                   -tabindex  => $tab_index{default},
                                   -label     => '');
    my %controls = (name     => $common_fields{name},
                    default  => $default,
                    label    => $common_fields{label},
                    display  => $common_fields{display},
                    order    => $common_fields{order});

    my @rows;
    foreach my $item (@display_order) {
        push @rows, $cgi->Tr ($cgi->td ({-align => 'right'},
                                        $self->{form_labels}->{$item}),
                              $cgi->td ({-align => 'left'},  $controls{$item}));
    }
    my $table = $cgi->table ({-align => 'center'}, @rows);
    my $hide  = $display ? '' : 'style = "display: none"';
    return qq (<div id="New_checkbox_div" $hide>$table</div>);
}


sub display_modify_stuff {
    my ($self, $field_id, $message) = @_;
    my $i18n = $self->I18N;
    my $cgi = CGI->new;
    my $calName = $self->calendarName;
    my $fields_lr = $self->prefs->get_custom_fields (system => undef);
    my $field_count = @$fields_lr;
    my ($field) = grep {$_->id eq $field_id} @$fields_lr;
    my $only_message;
    if (!$field or !ref $field) {
        $message = "Can't find field for id $field_id. $field";
        $only_message = 1;
    }

    my $position = 1;
    my @order = split ',', ($self->prefs->CustomFieldOrder || '');
    foreach my $existing_id (@order) {
        last if ($existing_id  eq $field_id);
        $position++;
    }

    print GetHTML->startHTML (title  => $i18n->get ('Custom Fields') . ': ' .
                                        ($calName ||
                                             $i18n->get ('System Defaults'))
                                        . $i18n->get ('Modify'),
                              op     => $self);
    print GetHTML->SectionHeader ($i18n->get ('Modify Custom Field'));

    if ($message) {
        print '<center>';
        print qq (<p class="ErrorHighlight">$message</p>);
        print '</center>';
    }
    if ($only_message) {
        return;
    }

    print $cgi->startform;
    print '<center><div style="border-width: 1px; border-style: solid; '
          . 'text-align: center; padding: 5px; margin: 5px;">';
    print $i18n->get ('Field Type') . ': ';
    print $self->_field_setting_divs (CGI   => $cgi,
                                      I18N  => $i18n,
                                      field => $field,
                                      field_count => $field_count,
                                      position    => $position);
    print '</div></center>';
    print $cgi->submit (-name => 'SaveModify', -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-value => $i18n->get ('Cancel'),
                        -onClick => 'window.close()');

    print $cgi->hidden (-name => 'FieldID'     , -value => $field->id);
    print $cgi->hidden (-name => 'Op',           -value => __PACKAGE__);
    print $cgi->hidden (-name => 'CalendarName', -value => $calName)
      if $calName;
    print $cgi->endform;
    print $cgi->end_html;
}

# Create DIVs of form controls for all types of custom fields.
# All but one div is set to "display: none" so they don't show; made
# visible when the pulldown selector set to that field type.
sub _field_setting_divs {
    my $self = shift;
    my %args = @_;
    my $cgi   = $args{CGI};
    my $i18n  = $args{I18N};
    my $field = $args{field};
    my $default_type = $args{default_type};
    my $field_count  = $args{field_count};
    my $position     = $args{position} || ($field_count + 1);

    my @type_names = qw /textfield textarea select multiselect checkbox/;
    my %type_names = (textfield   => 'Text - Single Line',
                      textarea    => 'Text - Multiple Line',
                      select      => 'Popup Menu - Choose One',
                      multiselect => 'Popup Menu - Choose Many',
                      checkbox    => 'Checkbox');

    # If we've got a field, we're editing; set defaults appropriately
    my %defaults;
    $defaults{field_type} = $field ? $field->input_type : $default_type;

    # First, JS for hiding/showing divs
    my $html =<<END_JS;
<script type="text/javascript">
<!--
  var displayed_div;
  function display_div (field_type) {
      if (displayed_div != undefined) {
          displayed_div.style.display = "none";
      }
      el = document.getElementById ('New_' + field_type + '_div');
      el.style.display = "";
      displayed_div = el;
  }
//-->
</script>
END_JS

    # Next, the pulldown to allow selecting a type
    $html .= $cgi->popup_menu (-name     => 'FieldTypeSelector',
                               -default  => $defaults{field_type},
                               -values   => \@type_names,
                               -labels   => \%type_names,
                               -tabindex => ($field_count * 2) + 1,
                               -onChange =>
               'display_div(this.options[this.selectedIndex].value)');

    $html .= '<hr width="50%"/>';

    my %display_it = ($defaults{field_type} => 1);

    my %div_subs = (textfield   => \&_new_textfield_div,
                    textarea    => \&_new_textarea_div,
                    select      => \&_new_select_div,
                    multiselect => \&_new_multiselect_div,
                    checkbox    => \&_new_checkbox_div);

    # Finally, the divs for each type
    foreach my $type (@type_names) {
        $html .= $div_subs{$type}->($self,
                                    cgi           => $cgi,
                                    i18n          => $i18n,
                                    field         => $field,
                                    field_count   => $field_count,
                                    display_order => $position,
                                    display       => $display_it{$type});
    }

    my $default_id = "New_$defaults{field_type}_div";
    $html .=<<END_SET_DIV;
<script type="text/javascript">
<!--
  var displayed_div = document.getElementById ('$default_id');
//-->
</script>
END_SET_DIV

    return $html;
}


sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
