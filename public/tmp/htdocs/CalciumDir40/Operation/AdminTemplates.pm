# Copyright 2005-2006, Fred Steinberg, Brown Bear Software

package AdminTemplates;
use strict;
use CGI;

use Calendar::GetHTML;
use Calendar::Template;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($save, $cancel, $template_type) =
            $self->getParams (qw (Save Cancel WhichTemplate));

    my $calName = $self->calendarName;

    if ($cancel or !defined $calName) {
        my $op = defined $calName ? 'AdminPage' : 'SysAdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $i18n    = $self->I18N;
    my $cgi     = new CGI;
    my $message;
    my $print_template_dir;

    my @template_names = qw /EditForm List Popup Mail RSS/;
    my %display_names = (EditForm => $i18n->get ('Edit Form'),
                         List     => $i18n->get ('List View Details Column'),
                         Popup    => $i18n->get ('Event Popup'),
                         Mail     => $i18n->get ('Mail Messages'),
                         RSS      => $i18n->get ('RSS feed'),
                        );

    # Make sure it's valid; also untaints, needed for saving
    $template_type ||= '';
    ($template_type) = grep {$_ eq $template_type} @template_names;

    if ($save and $template_type) {
        $self->{audit_formsaved}++;

        my $template_text = $self->getParams ("Template-$template_type") || '';
        $template_text =~ s/^\s+//;
        $template_text =~ s/\s+$//;

        # Untaint cal name, it too becomes part of the template filename
        $calName =~ /(\w+)/; $calName = $1;

        my $template = Template->new (name     => $template_type,
                                      cal_name => $calName);
        $template->text ($template_text);
        $template->save_to_disk;
        if ($template->ok) {
            my $action = $template_text ? 'Saved' : 'Removed';
            $message = sprintf ($i18n->get ("$action template '%s'"),
                                $template_type);
        }
        else {
            my $error = $template->error;
            my ($dir, $file) = $template->get_dir_and_file;
            $message = $i18n->get ('Could not save template file')
                       . " '$file': $error";
            $message = "<p>$message</p>";
            $print_template_dir = $dir;
        }
    }

    print GetHTML->startHTML (title => $i18n->get ('Templates'),
                              op    => $self);
    if (defined $calName) {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $self->calendarName || '',
                                    section => 'Output Templates');
    } else {
        print GetHTML->SysAdminHeader ($i18n, 'Output Templates', 1);
    }

    my $current_template = $template_type || $template_names[0];

    # JS for hiding/showing the textareas based on pulldown selection
    print <<END_JS;
<script type="text/javascript">
<!--
  var current_name = "$current_template";
  function display_div (template_name) {
      displayed_div = document.getElementById ('Textarea_' + current_name);
      if (displayed_div != undefined) {
          displayed_div.style.display = "none";
      }
      var el = document.getElementById ('Textarea_' + template_name);
      el.style.display = "";
      current_name = template_name;
  }
//-->
</script>
END_JS

    my $select_which = $cgi->popup_menu (-name     => 'WhichTemplate',
                                         -default  => $current_template,
                                         -values   => \@template_names,
                                         -labels   => \%display_names,
                                         -onChange => 
               'display_div(this.options[this.selectedIndex].value)');

    my %textarea_divs;
    my %errors;

    foreach my $name (@template_names) {
        my $template = Template->new (name     => $name,
                                      cal_name => $calName);
        if ($template->ok or $template->{error} eq 'not found') {
            $textarea_divs{$name} =
                          $cgi->textarea (-name => "Template-$name",
                                          -default  => $template->text,
                                          -rows     => 10,
                                          -cols     => 60,
                                          -wrap     => 'SOFT');
        }
        elsif ($template->error ne 'not found') {
            $errors{$name} = $template->error;
            my ($dir, $file) = $template->get_dir_and_file;
            $message .= '<p>';
            $message .= $i18n->get ("Couldn't read template file ") . "'$file'";
            $message .= ": $errors{$name}</p>";
            $print_template_dir = $dir;
        }
    }

    if ($message) {
        print "<center><h3>$message";
        if ($print_template_dir) {
            print $i18n->get ('Check directory') . " '$print_template_dir'";
        }
        print "</h3></center>";
    }
    print '<br/>';

    print $cgi->startform;
    print '<center>';
    my $select_prompt = $i18n->get ("Choose a Template") . ':';
    print "<div>$select_prompt $select_which</div>";
    print '<br/>';
    foreach my $name (@template_names) {
        my $style;
        if ($current_template eq $name) {
            $style = '';
        } else {
            $style = 'style="display: none"';
        }
        my $div_id = "Textarea_$name";
        print qq (<div id="$div_id" $style>$textarea_divs{$name}</div>);
    }
    print '</center>';

    print '<center>';
    print '<br/>';
    print '<hr/>';
    print $cgi->submit (-name  => 'Save',   -value => $i18n->get ('Save'));
    print '&nbsp;';
    print $cgi->submit (-name  => 'Cancel', -value => $i18n->get ('Done'));
    print $cgi->hidden (-name  => 'Op', -value => __PACKAGE__);
    print $cgi->hidden (-name  => 'CalendarName', -value => $calName)
      if $calName;
    print '</center>';

    print $cgi->endform;

    my @help_strings;
    my %help;

    $help{general} =<<HELP_STRING;
        Templates can be used to customize the display of
        events. They're available for: the event edit form; event
        popup windows; the event 'details' column in the List View;
        mail messages; and RSS feeds. They're typically used to format
        the display of custom fields that are defined for the
        calendar, but you can include anything you like in them.
HELP_STRING

    $help{linebreaks} =<<HELP_STRING;
        You can use HTML formatting in Templates. If you do use any HTML tags,
        newlines in your template will <i>not</i> automatically be converted
        to HTML line breaks - so you may need to use &lt;br&gt;,
        &lt;div&gt; or other line breaking tags.
HELP_STRING

    $help{substitutions} =<<'HELP_STRING';
        Custom fields that you've defined can be included in your
        templates by referring to them with a '$' before the field
        name. For example, a custom field named <b>phone</b> would be
        referenced as <b>$phone</b>.
HELP_STRING

    $help{customvarvalue} =<<HELP_STRING;
        For the Edit Form template, using a custom field will display
        its input control, e.g. a text entry field, drop-down menu, or
        whatever is defined for that Custom Field. For other
        templates, like the Event Popup, just the value of the field
        will be displayed.
HELP_STRING

    $help{location} =<<HELP_STRING;
        Templates are stored as plain ASCII files in the
        "data/Templates" directory of your Calcium installation. If
        you like, you can edit those files directly.
HELP_STRING

    foreach my $name (qw /general substitutions customvarvalue
                          linebreaks location/) {
        my $string_name = "AdminTemplates_HelpString_$name";
        my $string = $i18n->get ($string_name);
        if ($string eq $string_name) {
            $string = $help{$name};
        }
        push @help_strings, $string;
    }

    print '<br/><div class="AdminNotes">';
    print $cgi->span ({-class => 'AdminNotesHeader'},
                      $i18n->get ('Notes') . ':');
    print $cgi->ul ($cgi->li (\@help_strings));
    print '</div>';

    print $cgi->end_html;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
