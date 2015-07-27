# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# MatchForm - Common stuff for Search/Filter popups

package MatchForm;
use strict;
use CGI (':standard');
use Calendar::GetHTML;
use Calendar::Date;

sub getHTML {
    my $className = shift;
    my ($theOp, $message, $cgi, $isPopup) = @_;

    my $i18n    = $theOp->I18N;
    my $calName = $theOp->calendarName;

    my ($title, $prompt, $button, $useDates);
    if ($theOp->opName =~ /search/i) {
        $title  = $i18n->get ('Calendar') . ' ' . $i18n->get ('Search');
        $prompt = $i18n->get ('Search for this text:');
        $button = $i18n->get ('Search');
        $useDates++;
    } else {
        $title  = $i18n->get ('Calendar') . ' '
                  . $i18n->get ('Event Text Filter');
        $prompt = $i18n->get ('Only show events which match this text:');
        $button = $i18n->get ('Filter');
    }

    my $html;
    $html  = '<center>';
    $html .= GetHTML->PageHeader    ($title);
    $html .= GetHTML->SectionHeader ($calName);
    $html .= '</center>';

    $html .= "<p>$message</p>" if $message;

    $html .= $cgi->startform (-name => 'MatchForm');
    $html .= "<big><b>$prompt</big></b><br>";
    $html .= $cgi->textfield (-name => 'MatchText',
                              -size => 30);
    $html .= "<br>in " . $cgi->popup_menu (-name    => 'LookHere',
                                           -default => 'EventText',
                                           -Values  => ['EventText',
                                                        'PopupText', 'Both'],
                                           -labels  => {
                                 'EventText' => $i18n->get ('Event Text Only'),
                                 'PopupText' => $i18n->get ('Popup Text Only'),
                                 'Both'      => $i18n->get ('Either')});
    $html .= "<br>" . $cgi->checkbox (-name  => 'CaseSensitive',
                                      -label => ' ' .
                                                $i18n->get ('Case Sensitive'));
    $html .= "<br>" . $cgi->checkbox (-name  => 'UseRegex',
                                      -label => ' ' .
                                                $i18n->get ('Use Regex'));

    my $helpString = $i18n->get ('MiscHTML_HelpString');
    if ($helpString eq 'MiscHTML_HelpString') {
        ($helpString =<<'        FNORD') =~ s/^ +//gm;
            Selecting \'Use Regex\' means that the entered text will be 
            interpreted\nas a Regular Expression. The expression should be in\n
            standard Perl regex syntax.\n\n
            Some examples:\n
            \t\tmatch \'lunch\', followed by \'Martha\', with anything in 
            between: lunch.*Martha\n
            \t\tmatch \'Bill\' or \'Will\':    [BW]ill\n
            \t\tmatch \'fish\' or \'Cow\' :    fish|Cow\n
            \t\tmatch \'The\', but only at the start of the string: ^The\n
        FNORD
    }

    $html .= $cgi->a ({class => 'InlineHelp',
                       href => "JavaScript:alert (\'$helpString\')"},
                      $i18n->get ('What does this mean?'));
#                       '<small>' . $i18n->get ('What does this mean?') .
#                       '</small>');
    $html .= '<br>';

    my @categories = sort {lc ($a) cmp lc ($b)}
                       keys %{$theOp->prefs->getCategories (1)};
    if (@categories) {
        print qq {<script language="JavaScript">
                  <!--
                    function SetAllOptions (value) {
                       theList=document.MatchForm.FilterCategories;
                       for (i=0; i<theList.length; i++) {
                           theList.options[i].selected=value;
                       }
                    }
                  //-->
                  </script>};
        $html .= "<hr width='60%'>";
        $html .= '<center>' if $isPopup;
        $html .= '<big><b>' . $i18n->get ('In These Categories:') .
                 '</b></big><br>';
        $html .= scrolling_list (-name     =>'FilterCategories',
                                 -values   => \@categories,
                                 -size     => 5,
                                 -multiple => 'true');
        $html .= '<div style="font-size: smaller;">';
        $html .= $i18n->get ('control-click to choose multiple items');
        my $setAll   = $i18n->get ('Select All');
        my $unsetAll = $i18n->get ('Unselect All');
        $html .= '<br>';
        $html .= $cgi->a ({-href => "javascript:SetAllOptions(true)"},
                          $setAll);
        $html .= '&nbsp;&nbsp;';
        $html .= $cgi->a ({-href => "javascript:SetAllOptions(false)"},
                          $unsetAll);
        $html .= '</div>';
        $html .= '</center>' if $isPopup;
    }


    if ($useDates) {
        my $startDate = Date->new;
        $startDate->addYears (-15);
        my $fromDate = Date->new->firstOfMonth;
        $fromDate->month (1);
        my $toDate = Date->new ($fromDate->year, 12, 31);
        $html .= "<hr width='60%'>";
        $html .= $cgi->table ($cgi->Tr ($cgi->td ([$i18n->get ('From:'),
                                   GetHTML->datePopup ($i18n,
                                                       {name     => 'From',
                                                        start    => $startDate,
                                                        default  => $fromDate,
                                                        numYears => 30,
                                                        noSelector => 1,
                                                        excludeDay => 1})])),
                              $cgi->Tr ($cgi->td ([$i18n->get ('Through:'),
                                   GetHTML->datePopup ($i18n,
                                                       {name     => 'To',
                                                        start    => $startDate,
                                                        default  => $toDate,
                                                        numYears => 30,
                                                        noSelector => 1,
                                                        excludeDay => 1})])));
    }

    $html .=  '<hr>';
    $html .= $cgi->submit (-name    => 'DoIt',
                           -value   => $button);
    $html .= '&nbsp;';
    $html .= $cgi->submit (-name  => 'Cancel',
                           -value => $i18n->get ('Done'));
    $html .= $cgi->hidden (-name  => 'Op',
                           -value => $theOp->opName);
    $html .= $cgi->hidden ({-name  => 'CalendarName',
                            -value => $calName});
    # clear previous settings
    $theOp->clearParams (qw /TextFilter FilterIn FilterCategories IgnoreCase
                             UseRegex/);
    $html .= $theOp->hiddenDisplaySpecs;
    $html .= $cgi->endform;
    $html;
}

sub checkRegex {
    my $className = shift;
    my ($regex, $i18n) = @_;
    my $ok = eval { '' =~ /$regex/; 1 } || 0;
    return undef if $ok;
    return '<font color="red">' .
           $i18n->get ('Sorry, that is an invalid regular expression.') .
           '</font>';
}

1;
