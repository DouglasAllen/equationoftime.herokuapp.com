# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# GetHTML

package GetHTML;
use strict;

use CGI (':standard');
use Calendar::Date;
use Calendar::I18N;
use Calendar::Preferences;
use Calendar::MasterDB;

sub startHTML {
    my $class = shift;
    my %args = (meta   => {},
                op     => undef,     # to get styles
                @_);

#     return header
#         if (($ENV{SERVER_PROTOCOL} || '') eq 'INCLUDED');

    my %metaHeaders =
        (description => 'Calcium Web Calendar - Brown Bear Software ' .
                        'http://www.brownbearsw.com',
         keywords    => 'web calendar, calendar, calendar server, ' .
                        'Brown Bear Software',
         generator   => 'Calcium Web Calendar - Brown Bear Software ' .
                        'http://www.brownbearsw.com',
         %{$args{meta}});

    my $op = $args{op} || Operation->new;;
    my %styles = (-src  => $op->cssFile,
                  -code => $op->cssDefaults);

    my $master_prefs = Preferences->new (MasterDB->new);
    if (my $inline = $master_prefs->CSS_inline) {
        $styles{-code} .= "\n$inline\n";
    }
    if (my $inline = $op->prefs->CSS_inline) {
        $styles{-code} .= "\n$inline";
    }

    # If included via SSI, just return http header and styles
    if (($ENV{SERVER_PROTOCOL} || '') eq 'INCLUDED') {
        my $html = header;
        if ($styles{-src}) {
            $html .= qq
              {<link rel="stylesheet" type="text/css" href="$styles{-src}" />};
            $html .= "\n";
        }
        if ($styles{-code}) {
          $html .=<<END_CSS;
<style type="text/css">
<!--/* <![CDATA[ */
$styles{-code}
/* ]]> */-->
</style>
END_CSS
      }
        return $html;
    }

    my %headerArgs = (-cookie  => $args{cookie},    # scalar or arrayref
                      -Refresh => $args{Refresh});
    delete $headerArgs{-cookie}  unless $args{cookie};
    delete $headerArgs{-Refresh} unless $args{Refresh};
    my $html = header (%headerArgs);

    my $title = $args{title} || 'web calendar';
    my %startArgs = (-title => ($master_prefs->InstName || 'Calcium')
                               . " - $title",
                     -meta  => \%metaHeaders,
                     -head  => $args{head_elements},
                     -style => \%styles,
                     -declare_xml => 1,                # IE needs this
#                    -dtd   =>
#                         '!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" ' .
#                                     '"http://www.w3.org/TR/html4/strict.dtd',
                    );
    my $cssClass = $args{class} || $op->opName;
    $startArgs{-class}    = $cssClass if $cssClass;
    $startArgs{-onLoad}   = $args{onLoad}   if $args{onLoad};
    $startArgs{-onUnload} = $args{onUnload} if $args{onUnload};
    $html .= start_html (%startArgs);
    return $html;
}


# Produce a popup to select a date.
# Pass hash pairs with 'name', 'default', 'start' keys.
# The name of each popup_menu will be the 'name' passed in prepended to
#  'YearPopup', 'MonthPopup', & 'DayPopup'.
# 'default' is a date ref; defaults to today
# 'start' is to specify the earliest year in the popup; defaults to this year
# 'numYears' is how many years to include in the year popup
# 'excludeDay' is whether or not to supress the date popup
# 'onChange' is JavaScript code to call on selecting anything
sub datePopup {
    my $className = shift;
    my ($i18n, $params) = @_;
    my $today = Date->new();
    my %args = (name       => '',
                default    => $today,
                start      => $today,
                tab_index  => undef,
                numYears   => 5,
                excludeDay => undef,
                onChange   => '',
                noSelector => undef,
                op         => undef,
                %$params);

    my $tab_index = $args{tab_index};

    my $html;
    my ($monthPopup, $dayPopup, $yearPopup);
    $monthPopup =
            popup_menu ('-name'    => $args{name} . 'MonthPopup',
                        '-default' => $args{default}->month(),
                        -tabindex  => $tab_index,
                        '-values'  => [1..12],
                        '-labels'  => {map {$_,
                                            $i18n->get (Date->monthName ($_))}
                                           (1..12)},
                        '-onChange' => $args{onChange});

    if (defined $tab_index) {
        $tab_index++;
    }

    $dayPopup = '';
    $dayPopup =
            popup_menu ('-name'     => $args{name} . 'DayPopup',
                        '-default'  => $args{default}->day(),
                        '-values'   => [1..31],
                        -tabindex   => $tab_index,
                        '-onChange' => $args{onChange})
            unless $args{excludeDay};

    if (defined $tab_index) {
        $tab_index++;
    }

    $yearPopup =
            popup_menu ('-name'    => $args{name} . 'YearPopup',
                        '-default' => $args{default}->year(),
                        '-values'  => [$args{start}->year() ..
                                       $args{start}->year() + $args{numYears}],
                        -tabindex   => $tab_index,
                        '-onChange' => $args{onChange});

    if ($i18n->getLanguage ne 'English') {
        $html = "$dayPopup$monthPopup,$yearPopup";
    } else {
        $html = "$monthPopup$dayPopup,$yearPopup";
    }

    require Calendar::Javascript;
    my $url;
    if ($args{op}) {
        $url = $args{op}->makeURL ({Date => $args{default},
                                    Op   => 'PopupCal',
                                    Name => $args{name},
                                    PlainURL => 1});
    } else {
        $url = url() . "?Op=PopupCal&Name=$args{name}&Date=$args{default}";
    }
    unless ($args{noSelector}) {
        my $name = $args{name} . 'dateSelection';
        $html .= Javascript->MakePopupFunction ($url, $name, 300, 200);
        $html .= '<small>' . a ({-href =>"JavaScript:${name}Popup()"},
                                $i18n->get ('Date Selector')) . '</small>';
    }

    return $html;
}



sub AdminHeader {
    my ($className, %args) = @_;
    my $calName = $args{cal};
    my $group   = $args{group};
    my $section = $args{section};
    my $i18n    = $args{i18n}  || I18N->new (Preferences->new
                                              (MasterDB->new)->Language);
    my $html;
    my @rows;

    my $targetLabel = 'for Calendar: ';
    my $target      = $calName;

    if ($args{goob}) {
        $targetLabel = $args{goob}; # e.g. "Calendars not in any group"
        $target = '&nbsp;';
    }
    elsif ($group) {
        $targetLabel = 'for Calendar Group: ';
        $target      = $group;
    }

    push @rows, Tr (td ({align => 'center'},
                        ($i18n->get ('Calendar Administration'))));
    push @rows, Tr (td ({align => 'center'},
                        '<small><small>' .
                        $i18n->get ($targetLabel) . '</small></small>' .
                        qq (<span class="AdminHeaderCalName">$target</span>)))
        if $target;
    push @rows, Tr (td ($className->SectionHeader ($i18n->get ($section))))
        if $section;


    $html = table ({-class   => 'AdminHeader',
                    -cellpadding => 0, -cellspacing => 0,
                    -width   => '100%',},
                   \@rows);
    $html;
}

sub PageHeader {
    my ($className, $text) = @_;
    return unless $text;
    return qq(<div class="PageHeader">$text</div>);
}

sub HideShow_Javascript {
    my $class = shift;
    return <<END_HIDE_SHOW_JS;
<script language="JavaScript" type="text/javascript">
function hide_or_show (element_id, hide_text, show_text) {
  var el = document.getElementById (element_id);
  var the_label = document.getElementById (element_id + '_hide_show_label');
  if (el.style.display == "none") {
      el.style.display = "";
      the_label.innerHTML = hide_text;
      setCookie ("CalciumEditForm" + element_id, "show");
  }
  else {
      el.style.display = "none";
      the_label.innerHTML = show_text;
      setCookie ("CalciumEditForm" + element_id, "hide");
  }
  return false;
}
</script>
END_HIDE_SHOW_JS
}

# Header for a section. Optionally, pass args hash for hide/show js:
#  div_id:     name of surrounding id; element to hide/show
#  hide_label: label for "hide" link (defaults to 'Hide')
#  show_label: label for "show" link (defaults to 'Show')
# If Hide/Show is used, make sure you include the Javascript for it, via
#  GetHTML->HideShow_Javascript() !
sub SectionHeader {
    my ($className, $section_text, $args) = @_;
    return unless $section_text;
    if (!$args or !$args->{div_id}) {
        return qq(<div class="SectionHeader">$section_text</div>);
    }
    # Otherwise, we do want the hide/show stuff
    my $hide_label = $args->{hide_label} || 'Hide';
    my $show_label = $args->{show_label} || 'Show';
    my $x = <<END_JS;
    <span style="margin-left: 10px; font-size: small;">
         [<span id="$args->{div_id}_hide_show_label"
                style="text-decoration: underline"
                onclick="javascript:hide_or_show ('$args->{div_id}', '$hide_label', '$show_label');"><u>$hide_label/$show_label</u></span>]
      </span>
END_JS
    return qq(<div class="SectionHeader">$section_text $x</div>);
}

sub SysAdminHeader {
    my ($class, $i18n, $pageTitle, $notDefaults) = @_;
    my $html;
    my $header = (Preferences->new (MasterDB->new)->InstName || 'Calcium') . ' '
                 . $i18n->get ('System Administration');
    $header .= '<br>' . $i18n->get ('Defaults for New Calendars')
        unless $notDefaults;

    $html = $class->PageHeader ($header);
    $html .= $class->SectionHeader ($i18n->get ($pageTitle));
    $html .= h3 ($i18n->get ('Note: these are defaults you can use when '  .
                             'creating <em>new</em> calendars. They will ' .
                             'not affect any calendars which already exist.'))
        unless $notDefaults;
    $html;
}

sub AdminCSS {
    my ($class, $op) = @_;
    my $css;

    $css .= $op->cssString ('.linkMenu .link',        {bg => '#dddddd'});
#   $css .= $op->cssString ('.linkMenu .description', {bg => '#eeeeee'});
    $css .= $op->cssString ('a:hover',                {fg => 'black'});
    $css .= $op->cssString ('.linkMenu .linkRow',     {bg     => '#eeeeee',
                                                       cursor => 'pointer'});
    $css .= $op->cssString ('.linkMenu .linkRow:hover', {bg => '#dddddd'});
#   $css .= $op->cssString ('.linkMenu tr',
#                           {'forIE' => qq {expression(this.onmouseover=new Function("this.style.background='#d8d9cc';"),this.onmouseout=new Function("this.style.background='#feffee';"))}});

    $css .= $op->cssString ('.MenuLabel',  {'font-weight' => 'bold'});
#                                              'text-align'  => 'right'});
    $css .= $op->cssString ('.alternatingTable .thisRow', {bg => '#cccccc'});
    $css .= $op->cssString ('.alternatingTable .thatRow', {bg => '#eeeeee'});
    $css .= $op->cssString ('.alternatingTable .caption', {bg => '#bbbbbb'});
    $css .= $op->cssString ('.headerRow', {bg => '#aaaaaa'});
    $css .= $op->cssString ('.AdminHeader', {bg => '#cccccc',
                                               'font-size'   => 'xx-large',
                                               'font-weight' => 'bold'});
    $css .= $op->cssString ('.AdminHeaderCalName', {color => 'blue'});
    $css .= $op->cssString ('.AdminNotes', {'margin' => '0px 5%'});
    $css .= $op->cssString ('.AdminNotes li', {'margin-bottom' => '5px'});
    $css .= $op->cssString ('.AdminNotesHeader', {'font-weight' => 'bold'});
    $css .= $op->cssString ('.HelpLink', {'fg' => 'darkred',
                                            'font-size'   => 'larger',
                                            'font-weight' => 'bold'});
    $css .= $op->cssString ('.AdminTableHeader', {bg => '#ccccff',
                                                  'font-size' => 'larger'});
    $css .= $op->cssString ('.AdminTableColumnHeader', {bg => '#999999'});

    # e.g. security admin pages, sys user admin page
    $css .= $op->cssString ('.PagingControls', {'font-size' => 'smaller'});
    return $css;
}

sub categorySelector {
    my $class = shift;
    my %args = (name       => 'GetHTML_CategorySelector',
                op         => undef,
                categories => undef,
                multSelect => 'true',
                I18n       => undef,
                formName   => undef,
                @_);
    my $i18n = $args{I18N};
    if ($args{op}) {
        $i18n = $args{op}->I18N;
    }
    $i18n = I18N->new (Preferences->new (MasterDB->new)->Language)
        unless $i18n;

    my @cats = $args{categories} ? @{$args{categories}}
                                 : keys %{$args{op}->prefs->getCategories (1)};

    @cats = sort {lc $a cmp lc $b} @cats;
    my $formID = $args{formName} || 'forms[0]';
    my $html = qq {<script language="JavaScript">
                   <!--
                    function SetAllOptions (value) {
                       theList=document.$formID.$args{name};
                       for (i=0; i<theList.length; i++) {
                           theList.options[i].selected=value;
                       }
                    }
                  //-->
                  </script>};
    $html .= scrolling_list (-name     => $args{name},
                             -values   => \@cats,
                             -size     => 5,
                             -multiple => $args{multSelect});
    my $setAll   = $i18n->get ('Select All');
    my $unsetAll = $i18n->get ('Unselect All');
    $html .= '<br><small><small>';
    $html .= a ({-href => "javascript:SetAllOptions(true)"}, $setAll);
    $html .= '&nbsp;&nbsp;&nbsp;&nbsp;';
    $html .= a ({-href => "javascript:SetAllOptions(false)"}, $unsetAll);
    $html .= '</small></small>';
    if (!@cats) {
        $html .= '<br><small>(' . $i18n->get ('No categories defined.') .
                 ')</small>';
    }

    $html;
}

sub onLoad_for_link_menu {
    return <<END_JS;
<script type="text/javascript"><!--
function stopIt (the_event) {
  the_event.stopPropagation();
}
function page_load () {
  var links = document.links;
  if (links[0] && links[0].addEventListener) {
    for (var i=0; i<links.length; i++) {
      links[i].addEventListener ("click", stopIt, true);
    }
  }
}
// --></script>
END_JS
}

sub linkMenu {
    my $className = shift;
    my %args = (links       => {},
                linkText    => {},
                description => {},
                order       => [],
                @_);

    # Allow JS users to click anywhere on the row, not just the underlined link
    my %on_click;
    foreach my $row_name (@{$args{order}}) {
        if (my $url = $args{links}->{$row_name}) {
            my $js = qq {location.href="$args{links}->{$row_name}"};
            $on_click{$row_name} = $js;
        }
    }

    return table ({-width       => '100%',
                   -class       => 'linkMenu',
                   -cellspacing => 1},
                  map {
                      /SPACE/ ? Tr ({-class => 'space'}, td ('&nbsp;'))
                              : Tr ({-class => 'linkRow'},
                                    td ({-class => 'link',
                                         -onClick => $on_click{$_}}, 
                                        ($args{links}->{$_}
                                         ? a ({-href => $args{links}->{$_}},
                                              $args{linkText}->{$_})
                                         : $args{linkText}->{$_})),
                                    td ({-class => 'description',
                                         -onClick => $on_click{$_}},
                                        $args{description}->{$_}))
                          } @{$args{order}});
}

sub errorPage {
    my $className = shift;
    my $i18n = shift;
    my %args = (header    => '',
                message   => '',
                isWarning => 0,
                backCount => -1,
                moreStuff => undef,
                button    => undef,
                onClick   => undef,
                @_);

    my $master_prefs = Preferences->new (MasterDB->new);
    $i18n = I18N->new ($master_prefs->Language)
        unless $i18n;

    if ($args{backCount}) {
        $args{button}  ||= $i18n->get ('Go Back');
        $args{onClick} ||= "history.go($args{backCount})"
    }

    my $title = ($args{isWarning} ? 'Calendar Warning' : 'Calendar Error');
    my $cgi = CGI->new;
    print GetHTML->startHTML (-title => $i18n->get ($title));
    print $className->PageHeader (($master_prefs->InstName || 'Calcium ') . ' '
                                  . ($args{isWarning}
                                           ? $i18n->get ('Warning')
                                           : '<span class="ErrorHighlight">'
                                             . $i18n->get ('Error')
                                             . '</span>'));
    print $className->SectionHeader ($args{header});
    print "<blockquote><p>$args{message}</blockquote></p>";

    print "<blockquote><p>$args{moreStuff}</p><blockquote>"
        if ($args{moreStuff});

    if ($args{button}) {
        print '<table width="95%", align="center"><tr><td>';
        print $cgi->startform (-onSubmit => 'return false;');
        print submit (-name    => 'Back',
                      -value   => $args{button},
                      -onClick => $args{onClick});
        print $cgi->endform;
        print '</td></tr></table>';
    }
    print $cgi->end_html;
}

sub reloadOpener {
    my ($className, $closeMe) = @_;
    $closeMe = $closeMe ? 'window.close();' : '';
    print $className->startHTML;
    print "<script><!--\n";
    print "window.opener.location.reload();$closeMe";
    print "\n//--></script>";
    print '</body></html>';
}


1;
