# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Import Events from ASCII file, in Calcium-[US/Euro], iCal, Outlook format.
# Imports into existing calendar (i.e. won't create a new one)

package AdminImport;
use strict;
use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

use Calendar::EventImporter;

sub perform {
    my $self = shift;

    my ($doIt, $cancel, $importFile, $importType, $loadOrCheck,
        $deleteFirst, $dupeHandling, $isPopup, $userPage) =
                $self->getParams (qw (Import Cancel TheImportFile ImportType
                                      LoadOrCheck DeleteBefore
                                      Duplicates IsPopup FromUserPage));

    my $calName = $self->calendarName;
    my $i18n    = $self->I18N;
    my $cgi  = new CGI;
    my ($message, $badName);


    # if we've been cancel-ed, go back
    if ($cancel) {
        my $op = $calName ? ($isPopup || $userPage ? 'AdminPageUser'
                                                   : 'AdminPage')
                          : 'SysAdminPage';
        print $self->redir ($self->makeURL({Op => $op}));
        return;
    }

    my %typeLabels = (ical           => 'iCal (Brown Bear Software)',
                      vcalendar      => 'iCalendar - e.g. from Apple iCal',
                      calcium30_usa  => 'Calcium - USA Format',
                      calcium30_euro => 'Calcium - European Format',
                      msoutlook_usa  => 'MS Outlook - USA Format',
                      msoutlook_euro => 'MS Outlook - European Format');

    my $canDelete = $self->permission->permitted ($self->getUsername, 'Edit');

    my $import;

    if (!$calName) {
        $message = $i18n->get ('Must import into an existing calendar!');
    } elsif ($doIt) {{
        $message = $i18n->get ("Error: You didn't specify a file to load!"),
                   last unless $importFile;
        $import = EventImporter->new ($importFile, $importType);
        my ($reg, $rep, $bad) = $import->parseEvents ($self->getUsername);
        if (!ref ($bad)) {
            $message = "$typeLabels{$importType} file $importFile<br>" .
                       $i18n->get ('Bad field separator') . ': ' .
                       ($bad || '') . "<br><font color=black size=-1>" .
                       $i18n->get ('Check the file type and/or the first ' .
                                   'line of the input file.') . '</font>';
            $self->{audit_error} = "bad field separator: " . ($bad || '');
        }
        unless (@{$import->lines}) {
            $message = "$importFile: " .
                         $i18n->get ("file is empty, or it doesn't exist.");
            $self->{audit_error} = "file empty or not found";
        }
        $self->{audit_formsaved}++;
        $self->{audit_filename} = $importFile;
        $self->{audit_importer} = $import;
    }}

    # And display (or re-display) the form
    print GetHTML->startHTML (title  => $i18n->get ('Import Events'),
                              op     => $self);
    print GetHTML->AdminHeader (I18N    => $i18n,
                                cal     => $calName,
                                section => 'Import Events');
    print '<br>';

    print "<center><font color='red' size=+1>$message</font></center><hr>"
        if $message;

    # If we uploaded parsed the file, maybe load them, print results
    if ($import and !$message) {
        my $regularCount = @{$import->regularEvents}/2;
        my $repeatCount  = @{$import->repeatingEvents};
        my $loadedCount  = $regularCount + $repeatCount;

        my $regularEventsToImport   = $import->regularEvents;
        my $repeatingEventsToImport = $import->repeatingEvents;

        # if Outlook or vCalendar, set border if default for new events is 'on'
        if ($importType =~ /outlook|vcalendar/ and
            $self->prefs->DefaultBorder) {
            foreach (@$regularEventsToImport, @$repeatingEventsToImport) {
                next unless ref ($_) and $_->isa ('Event');
                $_->drawBorder (1);
            }
        }

        my ($regDupeText, $repDupeText) = ('', '');

        my $deleteAll = ($canDelete and $deleteFirst =~ /delete/i);

        # Check for dupes, maybe
        if (!$deleteAll and lc ($dupeHandling) eq 'check') {
            my $newRegList = $regularEventsToImport;
            my $newRepList = $repeatingEventsToImport;
            my $regHash = $self->db->getAllRegularEvents;
            my $repList = $self->db->getAllRepeatingEvents;
            my @keeperRegList;
            while (@$newRegList) {
                my $newEvent = shift @$newRegList;
                my $newDate  = shift @$newRegList;
                my $dontKeep;
                if (my $evList = $regHash->{$newDate}) {
                    foreach (@$evList) {
                        if ($newEvent->text eq $_->text) {
                            $dontKeep = 1;
                            last;
                        }
                    }
                }
                push @keeperRegList, ($newEvent, $newDate)
                    unless $dontKeep;
            }
            my %repHash;
            foreach (@$repList) {
                $repHash{$_->repeatInfo->startDate} ||= [];
                push @{$repHash{$_->repeatInfo->startDate}}, $_;
            }
            my @keeperRepList;
            foreach my $newEvent (@$newRepList) {
                my $dontKeep;
                if (my $evList = $repHash{$newEvent->repeatInfo->startDate}) {
                    foreach (@$evList) {
                        if ($newEvent->text eq $_->text and
                            $newEvent->repeatInfo->endDate ==
                                                   $_->repeatInfo->endDate) {
                            $dontKeep = 1;
                            last;
                        }
                    }
                }
                push (@keeperRepList, $newEvent) unless $dontKeep;
            }
            my $dupeReg = $regularCount - (@keeperRegList/2);
            my $dupeRep = $repeatCount - @keeperRepList;

            $loadedCount -= ($dupeReg + $dupeRep);

            $regDupeText = "; $dupeReg ". $i18n->get ($dupeReg == 1
                                                           ? 'duplicate'
                                                           : 'duplicates');
            $repDupeText = "; $dupeRep ". $i18n->get ($dupeRep == 1
                                                           ? 'duplicate'
                                                           : 'duplicates');

            $regularEventsToImport   = \@keeperRegList;
            $repeatingEventsToImport = \@keeperRepList;
        }

        my ($head, $action);
        if ($loadOrCheck eq 'load') {
            $head = "$loadedCount " . $i18n->get ('events loaded');
            $action = $i18n->get ('Loaded');
            $self->db->deleteAllEvents if ($deleteAll);

            # Mark all events Tentative...if we need to
            if (!$canDelete and Preferences->new ($calName)->TentativeSubmit) {
                foreach (@$repeatingEventsToImport) { 
                    $_->isTentative (1);
                }
                # list of reg. events is (event, date, event, date)
                for (my $i=0; $i<@$regularEventsToImport; $i+=2) {
                    $regularEventsToImport->[$i]->isTentative (1);
                }
            }

            $self->db->insertEvents ($regularEventsToImport);
            $self->db->insertEvents ($repeatingEventsToImport);
        } else {
            $head = $i18n->get ('Just Checking Input File - No Events Loaded');
            $action = $i18n->get ('Found');
        }
        my $numBad = @{$import->badLines}+0;
        print $cgi->center (b ($head));
        print $cgi->center ($i18n->get ("File Type") . ': ' .
                            $typeLabels{$importType});
        print '<br><center>';
        print table (th ({-align => 'center'},
                         $i18n->get ('Results for file') .
                                     ": <b>$importFile</b>"),
                     Tr (td ("$action $regularCount " .
                             $i18n->get ('regular events') . $regDupeText)),
                     Tr (td ("$action $repeatCount " .
                             $i18n->get ('repeating events') . $repDupeText)),
                     Tr (td ($numBad ? '' : 'No errors were found')));
        print '</center>';

        $self->{audit_loaded}   = ($loadOrCheck =~ /load/i);
        $self->{audit_deleted}  = ($canDelete and $deleteFirst =~ /delete/i);
        $self->{audit_regcount} = $regularCount;
        $self->{audit_repcount} = $repeatCount;
        $self->{audit_errcount} = $numBad;

        if ($numBad) {
            print '<b>';
            print $i18n->get ('Number of bad lines') . ": $numBad</b> ";
            if ($numBad == @{$import->lines} - $import->ignoredCount) {
                print font ({-color => 'red'},
                            i ($i18n->get ('Did you choose the correct ' .
                                           'file format?')));
            }
            my $numLines = $numBad < 11 ? ($numBad-1) : 9; # 10 lines max
            print '<xmp>';
            map {print "$_ " . $import->errors->{$_} . ": " .
                                    $import->lines->[$_] . "\n"}
                @{$import->badLines}[0..$numLines];
            print '</xmp>';
        }

        print '<hr>';
    }

    my $Format_Help = $i18n->get ('AdminImport_FormatHelp');
    if ($Format_Help eq 'AdminImport_FormatHelp') {
        ($Format_Help =<<'        ENDHELP') =~ s/^ +//gm;
         This option specifies the type of data in the input file, 
         and how dates and times are represented.\n\n
         'European' expects dates as DD/MM/YYYY (e.g. 31/01/2000), 
         times in 24-hour format, and Monday as the first day of the week.\n\n
         'USA' expects dates as MM/DD/YYYY (e.g. 01/31/2000), 
         times in 12-hour format with 'am' or 'pm', and Sunday as the 
         first day of the week.\n\n
         'iCalendar' is for '.ics' files and others, such as those used 
          by Apple Computer's 'iCal' program, or exported from Microsoft 
          Outlook\n\n
         'iCal' is for datafiles exported from Brown Bear Software's iCal 
         program.
        ENDHELP
    }
    $Format_Help =~ s/'/\\'/g; #'

    # Save full path to print out, so they can copy/paste. Since file
    # import fields have security issues, can't set defaults, even
    # w/Javascript
    print <<ENDSCRIPT;
<script language="Javascript">
<!--
    function saveFileSpec () {
        var fspec = window.document.forms[0].elements["TheImportFile"].value;
        window.document.forms[0].elements["FullFileSpec"].value = fspec;
    }
-->
</script>
ENDSCRIPT

    print $cgi->start_multipart_form (-onSubmit=> 'Javascript:saveFileSpec()');

    my (%text, %control);
    $text{file} = $i18n->get ('Enter the full path to the ASCII '   .
                              'import file on your local machine, ' .
                              'or press the "Browse" button to '    .
                              'find it:');
    $control{file} =  $cgi->filefield (-name      => 'TheImportFile',
                                       -size      => 40,
                                       -maxlength => 120);
    my ($lastFile) = $self->getParams ('FullFileSpec');
    if ($lastFile) {
        $control{file} .= '<br><small><b>' . $i18n->get ('Previous file:') .
                          "</b> $lastFile</small>";
    }

    $text{format} = $i18n->get('Specify the format of the import file:');
    $control{format} = $cgi->popup_menu (-name => 'ImportType',
                                         -values  => [ 'calcium30_usa',
                                                       'calcium30_euro',
                                                       'msoutlook_usa',
                                                       'msoutlook_euro',
                                                       'vcalendar',
                                                       'ical'],
                                         -labels  => \%typeLabels);
    $control{format} .= '&nbsp; ' .
                      $cgi->a ({href => "JavaScript:alert (\'$Format_Help\')"},
                               '<small>' .
                               $i18n->get ('What does this mean?') .
                               '</small>');

    $text{loadp} = $i18n->get ('Specify whether to Load the events, ' .
                               'or just check for errors:');
    $control{loadp} = $cgi->popup_menu (-name => 'LoadOrCheck',
                                        -default => 'check',
                                        -values  => [ 'load', 'check' ],
                                        -labels  => { load =>
                                                   $i18n->get ('Load Events'),
                                                      check =>
                                        $i18n->get ('Just Check Input File')});

    $text{dupes} = $i18n->get ('Check for duplicate events?');
    $control{dupes} = $cgi->popup_menu (-name => 'Duplicates',
                                        -default => 'ignore',
                                        -values  => [ 'ignore', 'check'],
                                        -labels  => {ignore =>
                  $i18n->get ("Import everything; don't check for duplicates"),
                                                     check =>
                  $i18n->get ('Don\'t import if already in calendar')});

    $text{delete} = $i18n->get ('Delete <b>all</b> existing events ' .
                                'before loading?');
    $control{delete} = $cgi->popup_menu (-name    => 'DeleteBefore',
                                         -default => 0,
                                         -values  => [ 'keep', 'delete'],
                                         -labels  => { keep =>
                                                          $i18n->get ('No'),
                                                       delete =>
                                                          $i18n->get ('Yes')});

    if ($isPopup) {
        my @items = qw /file format loadp dupes/;
        push @items, 'delete' if $canDelete;
        foreach (@items) {
            print $cgi->p ($text{$_} . '<br>' . $control{$_});
        }
    } else {
        my $delRow = $canDelete ? Tr (td ($text{delete}),
                                      td ($control{delete}))
                                : '';
        print table (Tr (td ($text{file}),
                         td ($control{file})),
                     Tr (td ($text{format}),
                         td ($control{format})),
                     Tr (td ($text{loadp}),
                         td ($control{loadp})),
                     Tr (td ($text{dupes}),
                         td ($control{dupes})),
                     $delRow);
    }

# if ($importFile) {
# print <<ENDSCRIPT;
# <script>window.document.forms[0].elements["TheImportFile"].value="$importFile";</script>
# ENDSCRIPT
# }

    print '<hr>';
    print submit (-name  => 'Import',
                  -value => $i18n->get ('Import Events'));
    print '&nbsp;';
    print submit (-name  => 'Cancel',
                  -value => $i18n->get ('Done'));
    print '&nbsp;';
    print hidden (-name => 'Op',           -value => 'ImportData');
    print hidden (-name => 'CalendarName', -value => $calName);
    print hidden (-name => 'FullFileSpec', -value => '');
    print hidden (-name => 'FromUserPage', -value => $userPage) if $userPage;
    print $self->hiddenDisplaySpecs;
    print reset  (-value => 'Reset');

    print $cgi->endform;
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $line = $self->SUPER::auditString ($short);

    $line .= " '$self->{audit_filename}'";
    return $line . " $self->{audit_error}" if ($self->{audit_error});

    $line .= ' (Just Checking)' unless $self->{audit_loaded};

    my $reg = $self->{audit_regcount};
    my $rep = $self->{audit_repcount};
    my $err = $self->{audit_errcount};

    if ($reg) {
        my $foo = 'event' . ($reg > 1 ? 's' : '');
        $line .= " [$reg single $foo]";
    }
    if ($rep) {
        my $foo = 'event' . ($rep > 1 ? 's' : '');
        $line .= " [$rep repeating $foo]";
    }
    if ($err) {
        my $foo = 'line' . ($err > 1 ? 's' : '');
        $line .= " [$err bad $foo]";
    }
#     $line .= " [$reg single $event]"    if $reg;
#     $line .= " [$rep repeating events]" if $rep;
#     $line .= " [$err bad lines]"        if $err;

    $line .= ' Deleted all existing' if ($self->{audit_loaded} and
                                         $self->{audit_deleted});
    $line;
}

sub cssDefaults {
    my $self = shift;
    my $css = $self->SUPER::cssDefaults;
    $css .= GetHTML->AdminCSS ($self);
    return $css;
}

1;
