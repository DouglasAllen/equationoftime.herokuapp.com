# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Admin for specifying which Add-Ins to use, and their colors, etc.
package AdminAddIns;
use strict;

use CGI (qw (:standard *table));
use Calendar::GetHTML;
use Calendar::Javascript;
use Operation::MultiCal;

use vars ('@ISA');
@ISA = ('Operation::MultiCal');

sub perform {
    my $self = shift;

    my ($save, $add_new, $delete, $cancel) =
              $self->getParams (qw (Save AddNew Delete Cancel));

    if ($cancel) {
        my $op = $self->isSystemOp ? 'SysAdminPage' : 'AdminPage';
        print $self->redir ($self->makeURL ({Op => $op}));
        return;
    }

    my $i18n    = $self->I18N;
    my $calName = $self->calendarName;

    my ($calendars, $prefs) = $self->getCalsAndPrefs;

    my $override = 1;
    my $message  = $self->adminChecks;

    if (!$message and !$self->isMultiCal) {

        # New One Added
        if ($add_new) {
            if (!$self->_handle_new) {
                $message = $self->{_new_addin_error};
            }
        }

        # One or more Deleted
        if ($delete) {
            if (!$self->_handle_delete) {
                $message = $self->{_delete_addin_error};
            } else {
                $message = $self->{_delete_message};
            }
        }

        # Refresh Button Pushed
        foreach my $param (keys %{$self->{params}}) {
            next unless ($param =~ /^RefreshNow-(.*)/);
            my $name = $1;
            my $addin = AddIn->new ($name, $self->db);
            if (my $url = $addin->sourceLocation) {
                $addin->last_loaded_date (time);
                $url = AddIn->normalize_URL ($url);
                my $contents = $self->_retrieve_file ($url);
                if (!defined $contents) {
                    $addin->last_load_status (0);
                    $message = $self->{_retrieve_addin_error};
                }
                else {
                    my $err = $addin->replaceSourceFile ($contents);
                    if ($err) {
                        $addin->last_load_status (0);
                        if ($err eq 'bad file type') {
                            $err = 'Unrecognized Add-In file format';
                        }
                        $message .= "$name: $err<br>";
                    } else {
                        $addin->last_load_status (1);
                        $message = $i18n->get ('Add-In was refreshed');
                    }
                }
            }
        }
    }

    # Existing ones modified
    if (!$message and $save) {
        $override = 1;
        $self->{audit_formsaved}++;

        # First, handle settings that are stored w/each AddIn: Source & Refresh
        # Only for retrieved ones, not uploaded
        if (!$self->isMultiCal) {
            foreach my $param (keys %{$self->{params}}) {
                next unless ($param =~ /^Source-(.*)/);
                my $name = $1;

                my $addin = AddIn->new ($name, $self->db);

                # if no source, just ignore changes
                next if (!$addin->sourceLocation);

                my $source  = $self->{params}->{"Source-$name"}  || '';
                my $refresh = $self->{params}->{"Refresh-$name"} || '';

                if ($addin->sourceLocation || '' ne $source) {
                    $addin->sourceLocation ($source);
                }
                if ($addin->refresh_interval || '' ne $refresh) {
                    $addin->refresh_interval ($refresh);
                }
            }
        }

        my %newInc;
        my @addInNames;

        # Next, handle display params which are stored w/calendar
        # Do FG/BG first, since they are there even if unset
        foreach my $param (keys %{$self->{params}}) {
            next unless ($param =~ /^ADDIN-FG-(.*)/);
            my $name = $1;
            push @addInNames, $name;
            my $dbName = "ADDIN $name";

            my ($fg, $bg, $text) = ($self->{params}->{"ADDIN-FG-$name"},
                                    $self->{params}->{"ADDIN-BG-$name"},
                                    $self->{params}->{"ADDIN-Text-$name"});
            ($newInc{$dbName}{BG} = $bg) =~ s/^\s+//;
             $newInc{$dbName}{BG}        =~ s/\s+$//;
            ($newInc{$dbName}{FG} = $fg) =~ s/^\s+//;
             $newInc{$dbName}{FG}        =~ s/^\s+$//;
            ($newInc{$dbName}{Text} = $text) =~ s/^\s+//;
             $newInc{$dbName}{Text}          =~ s/^\s+$//;
        }

        # Now do the checkboxes
        foreach my $name (@addInNames) {
            my $dbName = "ADDIN $name";
            my $included = $self->{params}->{"ADDIN-Included-$name"};
            my $border   = $self->{params}->{"ADDIN-Border-$name"};
            $newInc{$dbName}{Included} = ($included and
                                          ($included eq 'on')) ? 1 : 0;
            $newInc{$dbName}{Border}   = ($border and
                                          ($border eq 'on'))   ? 1 : 0;
            $newInc{$dbName}{Override} = 1;
        }

        # Remove ignored ones, build confirmation message
        if ($self->isMultiCal) {
            my %map = map {$_ => ["ADDIN $_"]} @addInNames;
            my @modified = $self->removeIgnoredPrefs (map   => \%map,
                                                      prefs => \%newInc);
            $message = $self->getModifyMessage (cals   => $calendars,
                                                mods   => \@modified,
                                                labels => {});
        }

        # Set prefs for each specified calendar
        foreach my $calName (@$calendars) {
            my $thePrefs = Preferences->new ($self->dbByName ($calName));
            my $origInfo = $thePrefs->Includes;

            # remove included AddIns that don't exist anymore
            foreach (keys %$origInfo) {
                next unless /^ADDIN (.*)/;
                delete $origInfo->{$calName} unless (grep /$1/, @addInNames);
            }

            foreach (keys %newInc) {
                $self->{audit_orig}->{$calName}{$_} = $origInfo->{$_};
                $origInfo->{$_} = $newInc{$_};
                # don't bother storing info for ones we don't include
#                delete $origInfo->{$_} unless $newInc{$_}{Included};
            }
            $self->dbByName ($calName)->setPreferences ({Includes=>$origInfo});
        }

        $prefs = Preferences->new ($self->dbByName ($calendars->[0])); # re-get
    }

    my $cgi = new CGI;

    print GetHTML->startHTML (title  => $i18n->get ('Add-Ins'),
                              op     => $self,
                              onLoad =>
                      'sourceChanged (document.getElementById ("MethodField"))'
                             );
    print '<center>';
    if ($self->isSystemOp) {
        print GetHTML->SysAdminHeader ($i18n, 'Add-Ins', 1);
    } else {
        print GetHTML->AdminHeader (I18N    => $i18n,
                                    cal     => $calName || '',
                                    goob    => $self->goobLabel    || '',
                                    group   => $self->groupName    || '',
                                    section => 'Add-Ins');
    }

    print '<br>';
    print "<h3>$message</h3>" if $message;
    print '</center>';

    print $cgi->start_multipart_form;


    # If group, allow selecting any calendar we have Admin permission for
    my %onChange = ();
    if ($self->isMultiCal) {
        my ($calSelector, $message) = $self->calendarSelector;
        print $message if $message;
        print $calSelector if $calSelector;
    }

#     my $helpString = $i18n->get ('AdminAddIns_HelpString');
#     if ($helpString eq 'AdminAddIns_HelpString') {
#         my $sysString = $self->isSystemOp ? ' by default for new calendars'
#                                           : '';
#         ($helpString =<<"        FNORD") =~ s/^ +//gm;
#             Select which Add-Ins you would like to include$sysString. You can
#             specify the colors to use for each event from an Add-In, and
#             whether or not to draw a border. If you leave a color blank, the
#             default color for the calendar will be used.<br>
#         FNORD
#     }
#     print $helpString;

    my $help_string = $i18n->get ('AdminAddIns_HelpString1');
    if ($help_string eq 'AdminAddIns_HelpString1') {
        $help_string = qq {Add-Ins are collections of events you can
                           include from external sources. Two formats
                           are available - iCalendar files - e.g. from
                           Apple's iCal program or Google's calendar;
                           or they can be in a Calcium-defined Add-In
                           format. You can retrieve or 'subscribe' to
                           Add-In files over the Internet, or you can
                           upload them from your desktop.};
    }
    print $help_string;

    if ($self->isSystemOp) {
        my $help_string = $i18n->get ('AdminAddIns_HelpString2');
        if ($help_string eq 'AdminAddIns_HelpString2') {
            $help_string = qq /System Add-Ins will be available for
                               any calendar to use./;
        }
        print qq {<p>$help_string</p>};
    }

    my %addInsDB;

    my $masterDB = MasterDB->new;
    foreach (AddIn->getAddInFilenames ($masterDB)) {
        $addInsDB{$_} = $masterDB;
    }
    if ($calName) {
        foreach (AddIn->getAddInFilenames ($self->db)) {
            $addInsDB{$_} = $self->db;
        }
    }
    # all add-in files; cal specific ones overwrite system ones w/same name
    my @allAddIns  = sort {lc($a) cmp lc($b)} keys %addInsDB;
    my $includes   = $prefs->Includes;

    my @refresh_values = (0, 15, 60, 60*24, 60*24*7);
    my %refresh_labels = (0       => $i18n->get ('never'),
                          15      => sprintf ($i18n->get ('every %d mins'), 15),
                          60      => $i18n->get ('every hour'),
                          60*24   => $i18n->get ('every day'),
                          60*24*7 => $i18n->get ('every week'));

    my ($thisRow, $thatRow) = ('thisRow', 'thatRow');

    my @tableRows;
    foreach my $name (@allAddIns) {

        my $db = AddIn->new ($name, $addInsDB{$name});
        my $dbName = "ADDIN $name";
        my $is_system = ($addInsDB{$name} == $masterDB);

        my ($includeCB, $fgField, $bgField, $textField, $borderCB, $border,
            $fgColor, $bgColor, $incP, $text);
        if (defined $includes->{"$dbName"}) {
            $incP     = $includes->{$dbName}{'Included'};
            $border   = $includes->{$dbName}{'Border'};
            $fgColor  = $includes->{$dbName}{'FG'}   || '';
            $bgColor  = $includes->{$dbName}{'BG'}   || '';
            $text     = $includes->{$dbName}{'Text'} || '';
        } else {
            $incP = $border = $fgColor = $bgColor = $text = '';
        }

        my $onChange;
        $onChange = $self->getOnChange ($name)
            if ($self->isMultiCal);


        $includeCB  = checkbox (-name    => "ADDIN-Included-$name",
                                -checked => $incP,
                                -override => $override,
                                -onChange => $onChange,
                                -label   => " $name");
        $borderCB   = checkbox (-name    => "ADDIN-Border-$name",
                                -checked => $border,
                                -override => $override,
                                -onChange => $onChange,
                                -label   => '');
        $fgField = textfield (-name      => "ADDIN-FG-$name",
                              -default   => $fgColor,
                              -override  => $override,
                              -onChange  => $onChange,
                              -size      => 8,
                              -maxlength => 20);
        $bgField = textfield (-name      => "ADDIN-BG-$name",
                              -default   => $bgColor,
                              -override  => $override,
                              -onChange  => $onChange,
                              -size      => 8,
                              -maxlength => 20);
        $textField = textfield (-name      => "ADDIN-Text-$name",
                                -default   => $text,
                                -override  => $override,
                                -onChange  => $onChange,
                                -size      => 10,
                                -maxlength => 2000);

        my $status    = $db->last_load_status ? 'ok' : 'FAILED';
        my $status_c  = $db->last_load_status ? '' : 'class="ErrorHighlight"';
        my $last_load = int ($db->last_loaded_date); # don't want text
        my $onclick;
        if ($last_load and $last_load > 0) {
            $last_load = localtime $last_load;
            $onclick = sprintf ("alert('%s: %s on %s')",
                                $db->name,
                                ($db->last_load_status ? $i18n->get ('Loaded')
                                                       : $i18n->get ('Tried')),
                                $last_load);
        } else {
            $last_load = $i18n->get ('never loaded');
            $onclick = sprintf ("alert('%s: %s')", $db->name, $last_load);
        }


        $status = qq (<span $status_c onClick="$onclick" title="$last_load">$status</span>);

        my $source_url = ' - ' . $i18n->get ('uploaded') . ' - ';
        my $refresh    = ' - ';
        if ($is_system and !$self->isSystemOp) {
            $source_url = ' - ' . $i18n->get ('inherited') . ' - ';
            $refresh    = ' - ';
        }
        elsif ($db->sourceLocation) {
            $source_url = textfield (-name      => "Source-$name",
                                     -default   => $db->sourceLocation,
                                     -override  => $override,
                                     -size      => 20,
                                     -maxlength => 1024);
            $refresh = popup_menu (-name      => "Refresh-$name",
                                   -default   => $db->refresh_interval,
                                   -override  => $override,
                                   -onChange  => $onChange,
                                   -values    => \@refresh_values,
                                   -labels    => \%refresh_labels);
            $refresh .= submit (-style => 'margin-top: 2px;font-size: x-small;',
                                -name  => "RefreshNow-$name",
                                -value => $i18n->get ('Refresh Now'));
        }

        ($thisRow, $thatRow) = ($thatRow, $thisRow);

        push @tableRows, Tr ({-class => $thisRow},
                             $self->groupToggle (name  => $name),
                             td ($includeCB),
                             td ({-bgcolor => $bgColor},
                                 qq (<span style="color: $fgColor;">) .
                                 $db->description . '</span>'),
                             td ({-align => 'center'}, $status),
                             td ({-align => 'center'}, $source_url),
                             td ({-align => 'center'}, $refresh),
                             td ({align => 'center'},
                                 [$fgField, $bgField, $borderCB, $textField]));
    }

    if (@tableRows) {

        print q {
             <script language="JavaScript">
             <!--
             function SetAll (setThem) {
                 theform=document.forms[0];
                 for (i=0; i<theform.elements.length; i++) {
                     if (theform.elements[i].type =='checkbox' &&
                         theform.elements[i].name.match ('ADDIN-Included-')) {
                         theform.elements[i].checked = setThem;
                     }
                 }
             }
             //-->
             </script>
            };

        my $groupSetAll = '';
        my $togHead = '';
        if ($self->isMultiCal) {
            my ($js, $setAllRow) = $self->setAllJavascript;
            print $js;
            $groupSetAll = $cgi->td ({-align => 'center'}, $setAllRow)
                if $setAllRow;
            $togHead = th ('&nbsp;');
        }

        my %header_align = (Refresh => 'center');

        my @headers = map {$i18n->get ($_)}
                       ('Include?', 'Description', 'Status', 'Source Address',
                        'Refresh',
                        'FG Color', 'BG Color', 'Border', 'Display Label',
                        );

        print table ({class       => 'alternatingTable',
                      align       => 'center',
                      border      => 0,
                      cellspacing => 1,
                      cellpadding => 2},
                     $togHead,
                     th ({-class => 'caption'}, \@headers),
                     @tableRows,
                     Tr ({-style => 'font-size: smaller;'},
                         $groupSetAll,
                         $cgi->td ({-colspan => 2,
                                    -class   => 'SetAllLinks'},
                                   $cgi->a ({-href =>
                                             "javascript:SetAll(true)"},
                                            'Select All') .
                                   '&nbsp;&nbsp;' .
                                   $cgi->a ({-href =>
                                             "javascript:SetAll(false)"},
                                            'Clear All'))));
        print submit (-name => 'Save',   -value => $i18n->get ('Save Changes'));
    } else {
        my $message = $self->isSystemOp || $self->isMultiCal
                               ? $i18n->get ('There are no System Add-Ins yet.')
                               : $i18n->get ('There are no Add-Ins for this '
                                             . 'calendar yet.');
        print '<p>', $cgi->center ($cgi->b ($message)), '</p>';
    }


    print '<hr width="50%"><br/>';

    print <<END_SCRIPT;
<script language="Javascript">
<!--
    function sourceChanged (pd) {
        if (pd.selectedIndex == 1) {
            document.getElementById ('SourceURLField').style.display = "none";
            document.getElementById ('UploadField').style.display = "";
            document.getElementById ('RefreshField').style.display = "none";
            document.getElementById ('NoRefresh').style.display = "";
        } else {
            document.getElementById ('SourceURLField').style.display = "";
            document.getElementById ('UploadField').style.display = "none";
            document.getElementById ('RefreshField').style.display = "";
            document.getElementById ('NoRefresh').style.display = "none";
        }
    }
-->
</script>
END_SCRIPT

    print Javascript->ColorPalette ($self);

    if (!$self->isMultiCal) {
        my @headers = map {$i18n->get ($_)}
                        ('Name', 'Method', 'Source Address', 'Auto-Refresh',
                         'FG Color', 'BG Color', 'Border', 'Display Label');

        print GetHTML->SectionHeader ($i18n->get ('Create New Add-In') . '<br>'
                                    . $i18n->get ('Retrieve from URL, '
                                                 .' or upload from desktop'));
        print table ({class       => 'alternatingTable',
                      align       => 'center',
                      border      => 0,
                      cellspacing => 1,
                      cellpadding => 2},
#                 caption ($i18n->get ('Add New Add-In - Retrieve from URL, or '
#                                      . 'upload from desktop')),
                     th ({-align => 'left', -class => 'caption'}, \@headers),
                     Tr (td (textfield (-name => 'NEW-Name',
                                        -size => 10,
                                        -maxlength => 64)),
                         td (popup_menu (-name     => 'NEW-Method',
                                         -id       => 'MethodField',
                                         -values   => [qw /retrieve upload/],
                                         -onChange => 'sourceChanged (this)',
                                         -labels   => {upload =>
                                                       $i18n->get ('Upload'),
                                                       retrieve =>
                                                     $i18n->get ('From URL')})),
                         td (textfield (-name      => 'NEW-SourceURL',
                                        -id        => 'SourceURLField',
                                        -size      => 30,
                                        -maxlength => 1024) .
                             filefield (-name      => 'NEW-UploadFile',
                                        -id        => 'UploadField',
                                        -style     => 'display: none;',
                                        -size      => 30,
                                        -maxlength => 128)),
                         td ({-align => 'center'},
                             popup_menu (-name      => 'NEW-Refresh',
                                         -id        => 'RefreshField',
                                         -values    => \@refresh_values,
                                         -labels    => \%refresh_labels) .
                             span ({-id    => 'NoRefresh',
                                    -style => 'display: none;'}, ' - ')),
                         td (textfield (-name      => 'NEW-FG',
                                        -size      => 8,
                                        -maxlength => 20)),
                         td (textfield (-name      => 'NEW-BG',
                                        -size      => 8,
                                        -maxlength => 20)),
                         td (checkbox (-name    => 'NEW-Border',
                                       -label   => '')),
                         td (textfield (-name      => 'NEW-Text',
                                        -size      => 10,
                                        -maxlength => 2000))),
                     Tr (td ({-colspan => 4},
                             submit (-name => 'AddNew',
                                     value => $i18n->get ('Add New File'))),
                         td ({-colspan => 2},
                             a ({-href   => "Javascript:ColorWindow()",
                                 -class  => 'InlineHelp'},
                                $i18n->get ('See Available Colors')))));

        print '<br/><br/>';

        # If any per-calendar addins exist, display delete stuff
        my @my_addins = sort {lc ($a) cmp lc ($b)}
                             AddIn->getAddInFilenames ($self->db);
        if (@my_addins) {
            print GetHTML->SectionHeader
                                      ($i18n->get ('Delete Existing Add-Ins'));
            print '<div style="text-align: center;">';
            print scrolling_list (-name     => 'DeleteThese',
                                  -values   => \@my_addins,
                                  -size     => @my_addins > 5 ? 10 : 5,
                                  -multiple => 'true');
            print '<br/>';
            print submit (-name  => 'Delete',
                          -value =>
                                $i18n->get ('Delete Selected Add-In files'));
            print '</div>';
        }
        print '<br/><hr>';
    }

    print submit (-name => 'Cancel', -value => $i18n->get ('Done'));

    print $self->hiddenParams;

    print endform;
    print $self->helpNotes;

    my @help_strings;

    if (!eval {require LWP::Simple;}) {
        push @help_strings, '<span class="WarningHighlight">Warning:</span> '
                          . 'Retrieving files over the Internet will not '
                          . 'be possible,'
                          . ' as the necessary Perl library module (LWP) is '
                          . ' not installed.';
    }
    push @help_strings,   'Click or hover on the "Status" field to see '
                        . 'the time and date the Add-In was last loaded';
    push @help_strings,   'The "Display Label" will be shown with each event '
                        . 'from the Add-In. You can use HTML tags here.';
    push @help_strings,   'Refreshing an Add-In will remove any existing user '
                        . 'email subscriptions for <i>individual events</i> '
                        . 'from that Add-In file.';
    push @help_strings,   'You can find some example Add-In files'
                        . ' <a href="http://www.brownbearsw.com/AddIns"'
                        . ' target="_blank">here</a>.';
    print '<br><div class="AdminNotes">';
    print span ({-class => 'AdminNotesHeader'}, $i18n->get ('Notes') . ':');
    print ul (li ([@help_strings]));
    print '</div>';

    print end_html;
}

sub _handle_new {
    my $self = shift;
    my $i18n = $self->I18N;

    my ($name, $method) = $self->getParams (qw /NEW-Name NEW-Method/);

    # Make sure we don't have this name already, and that it's valid
    if (my $error = _checkName ($name, $self->I18N, $self->db)) {
        $self->{_new_addin_error} = $error;
        return undef;
    }

    # File Upload
    if ($method eq 'upload') {
        my $upload_file = $self->getParams ('NEW-UploadFile');
        if (!defined $upload_file or $upload_file eq '') {
            $self->{_new_addin_error} =
                  $i18n->get ("Error: You didn't specify a file to load!");
            return undef;
        }

        my $fh;
        my $cgi = CGI->new;

        if ($CGI::VERSION < 2.47) {
            $fh = $cgi->param ('NEW-UploadFile');
            $fh = undef unless (ref $fh and fileno ($fh));
        } else {
            $fh = $cgi->upload ('NEW-UploadFile');
        }
        if (!$fh) {
            $self->{_new_addin_error} = $i18n->get ('Error') . $cgi->cgi_error;
            return undef;
        }

        my @lines = <$fh>;

        my $error = $self->_processNewFile ($name, \@lines);
        if ($error) {
            $self->{_new_addin_error} = $error;
            return undef;
        }
    }

    # Retrieve From URL
    if ($method eq 'retrieve') {
        my $url = $self->getParams ('NEW-SourceURL');

        $url = AddIn->normalize_URL ($url);

        if (!defined $url or $url eq '') {
            $self->{_new_addin_error} =
                              $i18n->get ("Error: You didn't specify a URL!");
            return undef;
        }

        my $contents = $self->_retrieve_file ($url);

        if (!defined $contents) {
            $self->{_new_addin_error} = $self->{_retrieve_addin_error};
            return undef;
        }

        my $error = $self->_processNewFile ($name, $contents, $url);
        if ($error) {
            $self->{_new_addin_error} = $error;
            return undef;
        }
    }

    # Take care of display settings
    return 1;
}

sub _handle_delete {
    my $self = shift;
    my $i18n = $self->I18N;
    my $db   = $self->db;

    my @delete = CGI->new->param ('DeleteThese');
    my $ok = 0;
    foreach (@delete) {
        if (AddIn->deleteFiles ($db, $_)) {
            $ok++;
        } else {
            warn "Delete $_ failed\n";
        }
    }
    # Remove from include lists
    $db->removeAddIns (@delete);
    $self->{_delete_message} =
                      "$ok " . ($ok == 1 ? $i18n->get ('Add-In was deleted')
                                       : $i18n->get ('Add-Ins were deleted'));
    return undef;
}


sub _checkName {
    my ($name, $i18n, $db) = @_;

    # Make sure the name has only simple chars.
    if (!defined $name or $name eq '') {
      return $i18n->get ("Error: You must specify a name for the new Add-In.");
    }
    if ($name =~ /\W/) {
        return $i18n->get ('Error: only letters, digits, and the ' .
                           'underscore are allowed in Add-In names.');
    }

    # And make sure it doesn't already exist
    my @addIns = AddIn->getAddInFilenames ($db);
    my $found = grep /^$name$/, @addIns;
    if ($found) {
        return  $i18n->get ("Error: couldn't write new Add-In file.")
                . " '$name' " . $i18n->get ('already exists.');
    }

    return;
}

# Return undef if ok, message on error
sub _processNewFile {
    my ($self, $name, $lines, $url) = @_;
    my $message;

    my $db   = $self->db;
    my $i18n = $self->I18N;

    if ($message = AddIn->writeNewFile ($db, $name, $lines)) {
        $message = $i18n->get ("Error: couldn't write new Add-In file.")
            . " $message";
        return  $message;
    }

    # Count events
    my $addIn = AddIn->new ($name, $db);
    $addIn->openDatabase ('read'); # just to compile the source
    $addIn->closeDatabase;
    my ($reg, $rep, $type) = ($addIn->getCounts, $addIn->getType);
    if ($type eq 'unknown') {
        AddIn->deleteFiles ($db, $name);
        $message = 'Unrecognized Add-In file format; not saved.';
        my $lines = $addIn->getBadLines;
        $message .= '<br>First few lines: <br>';
        $message .= "<xmp>@$lines[0..2]</xmp>";
        return $message;
    }

    my $refresh = $self->getParams ('NEW-Refresh');
    $refresh = 0 if ($refresh and $refresh < 0 or $refresh > 60*24*7);

    # Save some stuff about this AddIn, if we got one.
    $addIn->last_load_status (1);
    $addIn->last_loaded_date (time);         # seconds since epoch
    $addIn->sourceLocation   ($url);         # undef if uploaded
    $addIn->refresh_interval ($url ? $refresh : undef);     # undef if uploaded

    $message = $i18n->get ('Created Add-In File') . ": $name";
    $message .= "<br>Regular: $reg, Repeat: $rep, Type: $type";

    # Save display stuff, and turn on AddIn in this calendar (not for sys)
    my ($bg, $fg, $border, $text) = $self->getParams ('NEW-BG', 'NEW-FG',
                                                      'NEW-Border', 'NEW-Text');
    my %settings = (Included => 1,
                    BG       => $bg,
                    FG       => $fg,
                    Border   => $border,
                    Text     => $text);
    if (!$self->calendarName) {
        delete $settings{Included};
    }
    my $incInfo = $db->getPreferences ('Includes');
    $incInfo->{"ADDIN $name"} = \%settings;
    $db->setPreferences ({Includes => $incInfo});

    return $message;
}

# Return contents of retrieved file; undef on errors.
sub _retrieve_file {
    my ($self, $url) = @_;

    # make sure we've got LWP
    eval {require LWP::Simple;};
    if ($@) {
        my $i18n = $self->I18N;
        my $message =
              $i18n->get ("Sorry, can't retrieve the file; the necessary "
                          . " Perl module 'LWP::Simple' does "
                          . 'not seem to be installed.');
        $message .= '<br/>'
                        . $i18n->get ('You can try downloading the file from '
                                    . 'this link, and then uploading it:')
                        . qq (<br/><a href="$url">$url</a><br/>);
        $self->{_retrieve_addin_error} = $message;
        return undef;
    }

    # Get the file
    my $contents = LWP::Simple::get ($url);
    if (!defined $contents) {
        my $i18n = $self->I18N;
        $self->{_retrieve_addin_error} = $i18n->get ('Error') . ': '
                                       . $i18n->get ("Couldn't retrieve ")
                                       . $url;
        return undef;
    }
    return $contents;
}


sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    $css .= Operation->cssString ('.SetAllLinks a',
                                  {color       => 'black',
                                   'font-size' => 'smaller'});
    return $css;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->basicAuditString ($short);

    my $cal = $self->currentCal;

    my $orig = $self->{audit_orig}->{$cal};
    my $new  = Preferences->new ($cal)->Includes;

    my $info;
    foreach my $cal (sort keys %$orig) {
        my $diffs;
        foreach (sort keys %{$orig->{$cal}}) {
            next if ($_ eq 'Categories');
            my $old = $orig->{$cal}->{$_} || "''";
            my $gnu = $new->{$cal}->{$_}  || "''";
            next if ($old eq $gnu);
            $diffs .= " ($_: $old -> $gnu)";
        }
        $cal =~ /ADDIN (.*)/;
        if ($diffs) {
            $info .= "\n" unless $short;
            $info .= " [$1 -$diffs]";
        }
    }
    return unless $info;     # don't report if nothing changed
    return $line . $info;
}

1;
