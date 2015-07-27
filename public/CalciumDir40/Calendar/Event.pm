# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Event

# An Event has a string to display, and a link for either a URL or
# Javascript popup. It can also, optionally, have a start time, end time,
# and/or RepeatInfo object for repeating. And then there are other things, too.

# Methods include:
#  new
#  getTimeString
#  isRepeating
#  getHTML
#  applies
#  equals
#  excludeThisInstance
#  addToDateHash
#  getIncludedOverrides ($incInfo) - check for included color, border overrides
#  getCategoryOverrides ($prefs,)  - check for included color, border overrides
#  private - return true if event is not to be included in other cals
#  privatePopup - return true if popup text is not to be included in other cals

# The Get/Set methods are handled by AUTOLOAD.

package Event;
use strict;
use Calendar::EventSorter;
use vars qw ($AUTOLOAD %validField);

use overload ('=='       => 'equals',
              'fallback' => 'true');

# If mod_perling, This had better be a constant hash.
# Date and TZoffset and Prefs are not stored!
#  And neither is display_privacy_string! (Or hide_details)
BEGIN {
    foreach (qw(text link popup export repeatInfo startTime endTime id owner
                drawBorder bgColor fgColor includedFrom category isTentative
                mailTo mailCC mailBCC mailText timePeriod
                Date TZoffset Prefs display_privacy_string hide_details
                reminderTimes reminderTo subscriptions)) {
        $validField{$_}++;
    }
}

# Pass hash pairs
sub new {
    my $class = shift;
    my %args = ('text'       => '',
                'link'       => '',
                'popup'      => '',
                'export'     => 'Public',
#                repeatInfo => ,    Notice that
#                startTime  => ,            these keys (and others)
#                endTime    => ,                 are optional
                @_);
    my $self = {};
    bless $self, $class;

    my ($key, $value);
    while (($key, $value) = (each %args)) {
        $self->{$key} = $value if $value;
    }

    # some are special; false is ok, undef is not. silly.
    foreach (qw/startTime endTime/) {
        $self->{$_} = $args{$_} if (defined ($args{$_}) and $args{$_} ne '');
    }

    # If a Time Period defined, don't store start/end times
    if ($args{timePeriod}) {
        delete $self->{startTime};
        delete $self->{endTime};
    }

    # if categories a ref to a list, make it a scalar
    if (ref $self->{category}) {
        $self->{category} = join "\035", @{$self->{category}};
    }

    $self;
}

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;           # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY 

    # Make sure it's a valid field, eh wot?
    die "Bad Field Name to Event! '$name'\n" unless $validField{$name};

    $self->{$name} = shift if (@_);
    $self->{$name};
}

# Shallow copy; has references to same thingys (e.g. repeatInfo)
sub copy {
    my $self = shift;
    my $copy = Event->new (%$self);
    if ($copy->timePeriod) {
        # need to copy separately, new() doesn't get them, and they might
        # have been adjusted for TZ offset. ack.
        $copy->startTime ($self->startTime);
        $copy->endTime   ($self->endTime);
    }
    return $copy;
#    return Event->new (%$self);
}

# Return passed in text, possibly with HTML possibly escaped and things
# that look something like URLs converted to href links. Newlines are
# converted to <br>, unless simplistic check for HTML tags succeeds.
sub _escapeThis {
    my ($text, $escaped, $doHREFs, $linkColor) = @_;
    return '' unless $text;
    my $noBR = ($text =~ /<[^>]*>/); # not very good, but good enough
    if ($escaped) {
        $text =~ s/</&lt;/g;
        $text =~ s/>/&gt;/g;
        $text =~ s/&/&amp;/g;
        $text =~ s/"/&quot;/g;
    }
    # If there's not href or img in there already, put in href and mailto: tags
    if ($doHREFs and $text !~ /<\s*(a|img|form)(\s+|>)/i) {
        # inherit colors
        # my $style = qq (style="color: inherit;");
        # except 'inherit' doesn't work on IE, so we have to do this
        my $style = $linkColor ? qq (style="color: $linkColor") : '';

        $text =~ s {([-\w.]+@[-\w]+\.[-\w.]+)}
                   {<a href="mailto:$1" $style>$1</a>}g;

        my $target = '';
        $target = ' target="_blank"' if ($doHREFs =~ /newwindow/i);
        local $^W = undef;
        # look for 'http' first, then for 'www' if no 'http' found
        $text =~ s {http(s)?://(\S+)}
                   {<a href="http$1://$2"$target $style>$2</a>}g
          or $text =~ s {(www\.[\w-]+\.[\w-]+\S+)}
                        {<a href="http://$1"$target $style>$1</a>}g
    }

    $text =~ s/\n/<br>/g unless $noBR;
    $text;
}

# args are flags for ($escapeIt, $doHREFs, $fgColor)
sub escapedText {
    my $self = shift;
    _escapeThis ($self->text, @_);
}
sub escapedPopup {
    my $self = shift;
    _escapeThis ($self->popup, @_);
}

# See if event text matches passed in regex (use quotemeta for exact match).
# 2nd param is where to look; one of ['text', 'popup', 'both']
sub matchesText {
    my ($self, $regex, $where) = @_;
    return undef unless defined $regex;
    $where ||= 'both';
    if ($where =~ /text|both/i) {
        return 1 if (defined $self->text and $self->text =~ /$regex/);
    }
    if ($where =~ /popup|both/i) {
        return 1 if (defined $self->popup and $self->popup =~ /$regex/);
        return 1 if (defined $self->link  and $self->link  =~ /$regex/);
        # Check custom fields, if any
        my $fields_hr = $self->get_custom_fields;
        foreach my $value (values %$fields_hr) {
            return 1 if ($value =~ /$regex/);
        }
    }
    return undef;
}

# See if event is in any of the categories (typically for filtering)
# Pass one category, or ref to list of them.
sub inCategory {
    my ($self, $cats) = @_;
    $cats = [$cats] unless ref $cats;
    my %myCats = map {$_ => 1} $self->getCategoryList;
    return undef unless (keys %myCats);
    foreach my $cat (@$cats) {
        return 1 if ($myCats{$cat});
    }
    return undef;
}

# Return only first category in category list; undef if no primary
sub primaryCategory {
    my $self = shift;
    my ($primaryCat, @moreCats) = $self->getCategoryList;
    return $primaryCat;
}

# Return categories as list. Make sure Primary category always first.
sub getCategoryList {
    my $self = shift;
    my $cats = $self->{category} || return ();
    my @cats = split "\035", $cats;
    return @cats;
}
sub setCategoryList {
    my ($self, @cats) = @_;
    $self->{category} = join "\035", @cats;
    return @cats;
}
# Return comma separated string of categories, or undef if none
sub getCategoryScalar {
    my $self = shift;
    my $cats = $self->{category} || return undef;
    $cats =~ s/\035/,/g;
    return $cats;
}

sub hasTime {
    my $self = shift;
    return 1 if ($self->timePeriod or defined $self->startTime);
#    return 1 if ($self->timePeriod or $self->startTime);
}
# Set or return startTime, which might be defined in a time period
sub startTime {
    my $self = shift;
    $self->{startTime} = shift if (@_);
    return $self->{startTime} if exists ($self->{startTime});
    return undef unless ($self->timePeriod and $self->Prefs);
    $self->_getTimesFromPeriod;
    return $self->{startTime};
}
sub endTime {
    my $self = shift;
    $self->{endTime} = shift if (@_);
    return $self->{endTime} if exists ($self->{endTime});
    return undef unless ($self->timePeriod and $self->Prefs);
    $self->_getTimesFromPeriod;
    return $self->{endTime};
}
sub _getTimesFromPeriod {
    my $self = shift;
    my ($name, $start, $end, $display) =
                          $self->Prefs->getTimePeriod ($self->timePeriod);
    ($self->{startTime}, $self->{endTime}) = ($start, $end);
}

# If object method, pass 'start', 'end', or 'both', and prefs object
#  - If event has no times, returns undef
#  - If event has Time Period, get times for that
#  - If event has start but no end and you ask for both, returns just start
# If class method, just pass a time (as int) and militaryTimeP
sub getTimeString {
    my $caller = shift;
    my (@times, $milTimeP);
    if (ref ($caller)) {
        my ($which, $prefs) = @_;
        $milTimeP = $prefs? $prefs->MilitaryTime : 0;
        my ($start, $end);
        $start = $caller->startTime;
        $end   = $caller->endTime;
        push @times, $start if ($which =~ /start|both/ and defined $start);
        push @times, $end   if ($which =~ /end|both/   and defined $end);
    } else {
        push @times, shift;
        $milTimeP = shift;
    }
    my ($theString, $secondTime);
    foreach my $time (@times) {
        next if (!defined $time or $time eq '');   # shouldn't happen, but...
        $theString .= ' - ' if ($secondTime++);
        my ($hour, $minute) = (int ($time / 60), $time % 60);
        if ($milTimeP) {
            $theString .= sprintf '%d:%.2d', $hour, $minute;
        } else {
            my $string;
            if ($hour <= 12) {
                # midnight = 0;
                $string = sprintf '%d:%.2d', ($hour ? $hour : 12), $minute;
            } else {
                $string = sprintf '%d:%.2d', $hour - 12, $minute;
            }
            $string .= ($hour > 11) ? 'pm' : 'am';
            $theString .= $string;
        }
    }
    $theString;
}

# Return what date we fall on, adjusted for timezone
# Pass date, offset in hours (as stored in prefs)
sub getDisplayDate {
    my ($self, $date, $offset) = @_;
    my $start = $self->startTime;
    return $date unless (defined $start and $offset);
    $start += $offset * 60;

    if ($start < 0) {
        my $numDays = int ($start/-1440) + 1;     # 1440 = 24* 60
        return $date - $numDays;
    } elsif ($start >= 1440) {
        my $numDays = int ($start/1440);
        return $date + $numDays;
    }
    return $date;

#     return $date - 1 if $start < 0;
#     return $date + 1 if $start >= 24*60;
#     return $date;
}
# Return (startTime, endTime) adjusted by offset.
sub getDisplayTime {
    my ($self, $offset) = @_;
    my ($start, $end) = ($self->startTime, $self->endTime);
    return ($start, $end) unless $offset;
    foreach ($start, $end) {
        next unless defined;
        $_ += $offset * 60;
        $_ %= 1440;
#         if ($_ < 0) {
#             $_ += 24*60;
#         } elsif ($_ >= 24*60) {
#             $_ -= 24*60;
#         }
    }
    return ($start, $end);
}
# Change times, store date
# Return -1 if date decremented, 1 if incremented, 0 if unchanged
sub adjustForTimezone {
    my ($self, $date, $offsetHours) = @_;
    my ($start, $end) = ($self->startTime, $self->endTime);
    my $offset = $offsetHours * 60;
    my $ret = 0;
    return $self->TZoffset if (defined $self->TZoffset);

    if (defined $start) {
        $start += $offset;
        if ($start < 0) {
            $date -= int ($start/-1440) + 1;
            $start %= 1440;
            $ret = -1;
        } elsif ($start >= 24*60) {
            $date += int ($start/1440);
            $start %= 1440;
            $ret = 1;
        }

        $self->startTime ($start);

        if (defined $end) {
            $end += $offset;
            $self->endTime ($end % 1440);
        }
    }

    $self->Date ($date);       # not stored on disk
    $self->TZoffset ($ret);
    return $ret;
}


sub isRepeating {
    my $self = shift;
    return defined $self->{'repeatInfo'};
}

# Return ('', $linkText) if it's a link, ($popupText, '') if not.
sub textToPopupOrLink {
    my ($ref, $text) = @_;
    return ('', '') unless $text;
    if ($text =~ /^((https?|mailto|ftp|file):)|^www\.[^ .]+\.[^ .]/s) {
        return ('', ($1 ? $text : "http://$text"));
    } else {
        return ($text, '');
    }
}

# The popup code is an HTTP link to display the popup
sub getHTML {
    my ($self, $args) = @_;

    die "Unexpected args to Event::getHTML\n" unless (ref $args eq 'HASH');

    my ($op, $calName, $date, $prefs, $i18n, $textFG,
        $eventFace, $eventSize, $timeFace, $timeSize, $textID, $hideTimes);

    $op        = $args->{op};
    $calName   = $args->{calName};
    $date      = $args->{date};
    $prefs     = $args->{prefs};
    $i18n      = $args->{i18n};
    $textFG    = $args->{textFG};
    $eventFace = $args->{eventFace};
    $eventSize = $args->{eventSize};
    $timeFace  = $args->{timeFace};
    $timeSize  = $args->{timeSize};
    $textID    = $args->{textID};
    $hideTimes = $args->{hideTimes};
    my $class  = $args->{class};

    my $htmlText;

    # if displaying tentative event, add a tentative tag
    if ($self->isTentative) {
        $htmlText .= "<span class='EventTag Tentative'>" .
                           $i18n->get ('Pending Approval') . "</span><br>";
    }

    # includedFrom could be wrong if db is cached
    if ($self->includedFrom and $self->includedFrom eq $calName) {
        $self->includedFrom (undef);
    }

    if ($self->includedFrom and $textID) {
        $htmlText .= qq (<span class="IncludeTag">$textID</span><br>);
    }

    # workaround for workaround in BlockView (planner view...)
    my $source = $self->includedFrom || '';
    $source =~ s/\s*$//;

    my @catList = $self->getCategoryList;
    if (@catList) {
        my @names;
        foreach my $catName (@catList) {
            my $cat = $prefs->category ($catName) ||
                      MasterDB->new->getPreferences->category ($catName);
            if ($cat and my $cat_text = $cat->showName) {
                push @names, $cat_text;
            }
        }
        if (@names) {
            my $tags = join '<br>', @names;
            $htmlText .= qq (<span class="EventTag Category">$tags</span><br>);
        }
    }

    # if wanted, display extra tags
    if (my $extraTags = $prefs->EventTags) {
        $htmlText .= '<span class="EventTag Owner">' . $self->owner .
                     '</span><br>'
            if ($self->owner and $extraTags =~ /owner/);
        if ($extraTags =~ /export/) {
            my $tag = $self->displayString ($i18n) || $i18n->get ('Public');
            $htmlText .= qq (<span class="EventTag Export">$tag</span><br>);
        }
    }

    my @timeStrings;
    unless ($hideTimes) {
        if (my $period = $self->timePeriod) {
            my $p = $prefs;
            my $orig;
            if ($self->includedFrom) { # gads...this is rather ugly
                $orig = $prefs;
                $p = Preferences->new ($source);
                $self->Prefs ($p);
                delete $self->{startTime};
                delete $self->{endTime};
            }
            my ($name, $start, $end, $display) = $p->getTimePeriod ($period);

            $display ||= '';   # in case period doesn't exist
            if ($display eq 'period' or $display eq 'both') {
                push @timeStrings, $name;
            }
            if ($display eq 'times' or $display eq 'both') {
                push @timeStrings, $self->getTimeString ('both', $prefs);
            }
            $self->Prefs ($orig) if $orig;
        } elsif (defined $self->startTime) {
            push @timeStrings, $self->getTimeString ('both', $prefs);
        }
    }

    my @sizes = ('.6em','.6em','.75em', '1em', '1.2em', '1.5em', '2em', '3em');
    foreach ($timeSize, $eventSize) {
        next unless defined;
        $_ = $sizes[$_]
                if ($_ ne 'smaller' and $_ ne 'larger');
    }
    if (@timeStrings) {
        my @styles;
        push @styles, "font-family: $timeFace" if $timeFace;
        push @styles, "font-size: $timeSize"   if defined $timeSize;
        my $style = '';
        if (@styles) {
            $style = 'style="' . join (';', @styles) . '"';
        }
        $htmlText .= qq (<span class="TimeLabel" $style>);
        $htmlText .= join ': ', @timeStrings;
        $htmlText .= '</span><br>';
    }

    my $eventStyles = '';
    if ($eventFace or $eventSize or $textFG) {
        my @styles;
        push @styles, "font-family: $eventFace" if $eventFace;
        push @styles, "font-size: $eventSize"   if defined $eventSize;
        push @styles, "color: $textFG"          if defined $textFG;
        $eventStyles = join ';', @styles;
    }
    my $style = '';
    if ($eventStyles) {
        $style = qq (style="$eventStyles");
    }

    # Get/process event text, or link, or URL, or perhaps special
    #  string (e.g. 'Out of Office')
    # Of course, this fn should not be called for private events that
    # shouldn't display at all!
    EVENT_TEXT: {
        # Private, but with Special String (e.g. 'Out of Office')
        if ($self->display_privacy_string and !$self->privatePopup) {
            $htmlText .= qq (<span class="PrivacyLabel" $style>) .
                         ($self->displayString ($i18n) || '') . '</span>';
            last EVENT_TEXT;
        }

        # escape HTML if we need to, converting \n to <br>, and maybe
        # detect email address and http links
        my $escapeIt = $prefs->EventHTML =~ /none/;
        my $eventText;

        # Display URL for a link, unless the "privacy string" flag is
        #   set, in which case it's "private popup" - we just show the
        #   plain text, no link. Note that url for link could be anything.
        if ($self->{link} and !$self->display_privacy_string) {
            $eventText = $self->escapedText ($escapeIt);
            $style = qq (style="$eventStyles");
            $htmlText .= qq (<a href="$self->{link}" $style>) .
                         qq ($eventText</a>);
            last EVENT_TEXT;
        }

        my $custom_fields_hr = $self->get_custom_fields || {};
        my $has_custom_data;
        my @custom_texts;
        foreach my $vals (values %$custom_fields_hr) {
            if (defined $vals) {
                $has_custom_data++;
                last;
            }
        }
        if ($has_custom_data) {
            my $custom_prefs = $prefs;
            if ($source and $source !~ /^ADDIN /) {
                $custom_prefs = Preferences->new ($source);
            }
            @custom_texts = _custom_summary_text ($op, $custom_prefs,
                                                  $custom_fields_hr);
        }

        # For popup/detail text - unless the "privacy string" is set,
        #   in which case we'll just display the event text/summary
        #   below, no link.
        if (($self->{popup} or $has_custom_data)
            and !$self->display_privacy_string
            and !$self->hide_details) {
            $eventText = $self->escapedText ($escapeIt);

            # Add any custom fields we want displayed w/text
            if (@custom_texts) {
                @custom_texts = map {_escapeThis ($_, $escapeIt)} @custom_texts;
                if (defined $eventText and $eventText ne '') {
                    unshift @custom_texts, $eventText;
                }
                $eventText = join '<br/>', @custom_texts;
            }

            my $id = $self->id;

            my $width  = $prefs->PopupWidth  || 250;
            my $height = $prefs->PopupHeight || 350;

            my $jsParams = "'$calName', '$date', '$id', '$source', " .
                           "'$width', '$height'";
            $style = qq (style="$eventStyles");
            my $jsStuff = qq{<a href="JavaScript:PopupWindow ($jsParams)" } .
                          qq{$style>} .
                          qq {$eventText</a>};
            $jsStuff =~ s/(["'\\])/\\$1/g;     # '"])
            $jsStuff =~ s/\n//g;
            $htmlText .= qq (<div class="EventLink">);
            $htmlText .= qq {<script>document.write ("$jsStuff");</script>};
            my $url = '';
            if ($op) {
                $url = $op->makeURL ({Op     => 'PopupWindow',
                                      ID     => $id,
                                      Date   => $date,
                                      Source => $source,
                                      DoneURL =>
                                          $op->makeURL ({Op => $op->opName})});
            }
            $htmlText .= qq {<noscript><a href="$url">$eventText</a>} .
                            '</noscript>';
            $htmlText .= '</div>';
            last EVENT_TEXT;
        }

        # OK, if we got to here, it's either a simple plain text, or
        #   semi-private, i.e. we display the text, but not as a link to
        #   popup details or a URL
        $eventText = $self->escapedText ($escapeIt, 'doHREFs', $textFG);
        if (@custom_texts) {
            @custom_texts = map {_escapeThis ($_, $escapeIt, 'doHREFs',
                                              $textFG)} @custom_texts;
            if (defined $eventText and $eventText != '') {
                unshift @custom_texts, $eventText;
            }
            $eventText = join '<br/>', @custom_texts;
        }
        $htmlText .= qq (<div $style>$eventText</div>);
    }

    if (my $primaryCat = $self->primaryCategory) {
        $primaryCat =~ s/\W//g;
        $htmlText = qq (<div class="$primaryCat">$htmlText</div>);
    }

    my $ondbl = '';
    if ($op->userPermitted ('Edit')) {
        if ($source and $source =~ /^ADDIN (.*)/) {
            my $addIn = $1;
            $ondbl = "editEvent (-1, '$addIn')";
        } else {
            $ondbl = sprintf ("editEvent (%d, '%s', '%s')", $self->id,
                              ($source || $calName), $date);
        }
        $ondbl = qq (ondblclick="$ondbl");
    }

    $style = defined $textFG ? qq (style="color: $textFG") : '';
    $class = $class ? "CalEvent $class" : 'CalEvent';
    return qq (<div class="$class" $ondbl $style>) .
          "$htmlText</div>";
}

# Return (fg, bg) colors based on event settings, inclusion, category
#   return included colors if included (and override set)
#   else, return event specific colors (if set)
#   else, return category colors (if set)
#   else, return colors from prefs
sub colors {
    my ($self, $calName, $prefs, $noDefault) = @_;

    my ($fgColor, $bgColor, $border, $textID);

    # included calendar colors specified?
    if ($self->includedFrom || '' ne $calName) {
        my ($fg, $bg, $bdr, $id) =
            $self->getIncludedOverrides ($prefs->Includes);
        $fgColor = $fg unless defined $fgColor;
        $bgColor = $bg unless defined $bgColor;
    }
    return ($fgColor, $bgColor) if (defined $fgColor and defined $bgColor);

    # event have it's own colors specified?
    $fgColor = $self->fgColor unless defined $fgColor;
    $bgColor = $self->bgColor unless defined $bgColor;
    return ($fgColor, $bgColor) if (defined $fgColor and defined $bgColor);

    # category colors specified?
    if (defined $self->primaryCategory) {
        my @prefList = ($prefs, MasterDB->new->getPreferences);
        # use category colors from included calendar if we're included
        if (my $inc_from = $self->includedFrom) {
            if ($inc_from !~ /^ADDIN/ and $inc_from ne $calName) {
                    my $incPrefs = Preferences->new ($self->includedFrom);
                    unshift @prefList, $incPrefs if $incPrefs;
                }
        }
        my ($fg, $bg, $bdr) = $self->getCategoryOverrides (@prefList);
        $fgColor = $fg unless defined $fgColor;
        $bgColor = $bg unless defined $bgColor;
    }
    return ($fgColor, $bgColor) if (defined $fgColor and defined $bgColor);

    return ($fgColor, $bgColor) if $noDefault;

    $fgColor = $prefs->color ('EventFG') if (!defined $fgColor);
    $bgColor = $prefs->color ('EventBG') if (!defined $bgColor);

    return ($fgColor, $bgColor);
}

sub applies {
    my $self = shift;
    my ($date) = @_;

    # return true right away if it's not a repeating event
    return 1 unless $self->isRepeating();

    # otherwise, ask the RepeatInfo object
    return $self->{'repeatInfo'}->applies ($date);
}

sub equals {
    my ($e1, $e2, $backwards) = @_;
    return ($e1->{'id'} == $e2->{'id'});
}

# Use this to keep track of which instances of a repeating event we deleted
sub excludeThisInstance {
    my $self = shift;
    my ($date) = @_;
    # Simply pass it along to the RepeatInfo object, unless there isn't
    # one. 
    if ($self->isRepeating()) {
        $self->{'repeatInfo'}->excludeThisInstance ($date);
    }
}

# Set or Return ref to list of excluded date objs; return undef if not a
#   repeating event
sub exclusionList {
    my $self = shift;
    my $listRef = shift;
    # Simply pass it along to the RepeatInfo object, unless there isn't
    # one. 
    if ($self->isRepeating()) {
        return $self->{'repeatInfo'}->exclusionList ($listRef);
    }
    return;
}

# Pass through to EventSorter
sub sort {
    my ($class, $eventListRef, $sortPref) = @_;
    my $sorter = EventSorter->new (split (',', ($sortPref || ())));
    my $sortedListref = $sorter->sortEvents ($eventListRef);
    return @$sortedListref;
}

# Find all applicable dates for this event, add to the hash passed in.
# Notice that if there is no repeat info, we don't need to do anything.
sub addToDateHash {
    my $self = shift;
    my ($hash, $fromDate, $toDate, $prefs) = @_;

    return unless $self->isRepeating();

    $self->repeatInfo()->addToDateHash ($hash, $fromDate, $toDate,
                                        $self, $prefs);
}

sub getIncludedOverrides
{
    my $self = shift;
    my ($incInfo) = @_;
    my $incCal = $self->includedFrom();
    my ($fgColor, $bgColor, $border, $text);
    if ($incCal &&
        $incInfo->{$incCal}->{'Included'}) {
        $text = $incInfo->{$incCal}->{Text} || '';
        if ($incInfo->{$incCal}->{'Override'}) {
            $fgColor = $incInfo->{$incCal}->{'FG'};
            $bgColor = $incInfo->{$incCal}->{'BG'};
            $border  = $incInfo->{$incCal}->{'Border'} ? 1 : 0;
        }
    }
    ($fgColor, $bgColor, $border, $text);
}

sub getCategoryOverrides
{
    my $self = shift;
    my (@prefs) = @_;
    my $catName = $self->primaryCategory;
    return undef unless $catName;
    foreach my $prefs (@prefs) {
        my $cat = $prefs->category ($catName);
        if ($cat) {
            my $border = 1 if $cat->border;
            return ($cat->fg, $cat->bg, $border);
        }
    }
    undef;
}

sub public {
    my $self = shift;
    return (!defined $self->export or
            $self->export =~ /Public/i or
            $self->export eq '');
}

sub private {
    my $self = shift;
    return ($self->export and $self->export =~ /Private/i);
}

sub privatePopup {
    my $self = shift;
    return ($self->export and $self->export =~ /NoPopup/i);
}

sub displayString {
    my $self = shift;
    my $i18n = shift;
    return $i18n->get ('Private')       if ($self->private);
    return $i18n->get ('Private Popup') if ($self->privatePopup);
    return '' unless $self->export;
    return $i18n->get ('Unavailable')   if ($self->export =~ /Unavailable/i);
    return $i18n->get ('Out of Office') if ($self->export =~ /OutOfOffice/i);
    return '';
}

# -- Subscriptions
# 'subscriptions' looks like: "calname:a@b.com,c@d.com;otherCal:f@g.com"
# Need to specify which calendar we're interested in

sub isSubscribed {
    my ($self, $address, $calName) = @_;
    my $addrs = $self->getSubscribers ($calName); # comma joined list
    return ($addrs =~ /\b$address\b/i);
}

sub addSubscriber {
    my ($self, $address, $calName) = @_;
    my @calStrings = split /;/, ($self->subscriptions || '');
    my $foundIt;
    foreach (@calStrings) {
        next unless /^$calName:(.*)/;
        $foundIt = 1;
        $_ .= ',' if $1;
        $_ .= $address;
        last;
    }
    if (!$foundIt) {
        push @calStrings, "$calName:$address";
    }
    $self->subscriptions (join ';', @calStrings);
}

# Return comma joined list of addresses for specified calendar.
sub getSubscribers {
    my ($self, $calName) = @_;
    my @calStrings = split /;/, ($self->subscriptions || '');
    foreach (@calStrings) {
        next unless /^$calName:/;
        s/$calName://;
        return $_;
    }
    return '';
}

# Set/get VALUE of custom field; pass CustomField obj, or field ID
# We keep lists as scalars for efficiency - i.e. don't convert on
#   every serialize/unserialize, only when used.
sub customField {
    my $self        = shift;
    my $field_or_id = shift;
    my $id = ref $field_or_id ? $field_or_id->id : $field_or_id;
    return unless $id;          # undef, 0 are invalid; must be >= 1

    # If setting, set - convert array to scalar
    if (@_) {
        my $val = shift;
        my $orig = $val;
        if (ref $val) {
            $val = join "\035", @$val;
        }
        $self->{customFields}->{$id} = $val;
        return $orig;
    }

    # A get - return val; if has special separators, return a listref
    my $val = $self->{customFields}->{$id};
    if ($val && index ($val, "\035") >= 0) {
        my @vals = split "\035", $val;
        return \@vals;
    }
    else {
        return $val;     # scalar
    }
}

# Return all custom fields formatted for specified view; might use template
# Return undef if no custom fields.
sub custom_fields_display {
    my $self = shift;
    my %args = (format   => 'html',         # or text (ignored if template used)
                prefs    => undef,          # use if not included
                escape   => undef,          # escape HTML tags or not?
                template => undef,
                @_
               ); 
    my $prefs = $args{prefs};
    if (my $source = $self->includedFrom) {
        if ($source =~ /^ADDIN (.*)/) {
            $source = $1;
        }
        $prefs = Preferences->new ($source);
    }

    my $field_order = $prefs->CustomFieldOrder;
    if (!$field_order) {
        return undef;           # no custom fields!
    }

    my $format = ($args{format} and lc ($args{format}) eq 'text') ? 'text'
                                                                  : 'html';

    my $used_template;
    my $template_failed;
    my $fields_lr = $prefs->get_custom_fields (system => 1);

    my $custom_div;

    # If template passed in, check it out
    my $template = $args{template};

    if ($template and $template->ok) {
        my %substitutions;
        foreach my $field (@$fields_lr) {
            my $from = '$' . $field->name;
            my $to   = $self->custom_field_for_display ($field,
                                                        $args{escape},
                                                        'newWindow');
            $substitutions{$from} = $to;
        }
        $custom_div = $template->expand (\%substitutions);
        $used_template++;
    }
    elsif ($template and $template->error ne 'not found') {
        $template_failed = $template->error;
    }

    # If no template, just spit fields out
    if (!$used_template) {
        my @rows;
        my @field_order = split ',', $field_order;
        my %fields_by_id = map {$_->id => $_} @$fields_lr;
        foreach my $field_id (@field_order) {
            my $field = $fields_by_id{$field_id};
            next unless $field;
            my $value = $self->custom_field_for_display ($field_id,
                                                         $args{escape},
                                                         'newWindow');
            my $label = $field->label  || '&nbsp;';
            if ($format eq 'html') {
                push @rows, qq (<tr><td><b>$label</b><td>$value</td></tr>);
            }
            else {
                push @rows, sprintf ("%-15s: %s", $label, $value);
            }
        }
        if ($template_failed) {
            my $message = sprintf ('Found "%s" template file, '
                                   . "but couldn't open it: ", $template->name);
            $message .= "'$template_failed'";
            if ($format eq 'html') {
                push @rows, qq (<tr><td colspan="2"><b><i>Note:</i></b>)
                          . qq ( <i>$message</i>);
            }
            else {
                push @rows, "Note: $message";
            }
        }
        if (@rows) {
            if ($format eq 'html') {
                $custom_div = qq (<table>@rows</table>);
            }
            else {
                $custom_div = join "\n", @rows;
            }
        }
    }
    if ($format eq 'html') {
        return qq (<div id="CustomFields" class="CustomFields">)
          . qq ($custom_div</div>);
    }
    else {
        return $custom_div;
    }
}

# Return text, escaped for display
sub custom_field_for_display {
    my ($self, $field_or_id, @params) = @_;
    my $val = $self->customField ($field_or_id);
    $val = join (', ', @$val) if (ref $val);  # multivalued fields
    return _escapeThis ($val, @params);
}

# Return hashref of {id => value} pairs. Listref values NOT split!
sub get_custom_fields {
    my $self = shift;
    return $self->{customFields};
}
# Pass hashref of {id => value} pairs; replace entire custom field set for obj
sub set_custom_fields {
    my ($self, $hashref) = @_;
    return $self->{customFields} = $hashref;
}

# Return list of strings to display w/event summary, in order to display them
sub _custom_summary_text {
    my ($op, $prefs, $custom_fields_hr) = @_;

    # For efficiency, store some stuff in op's stash, instead of
    #   re-getting for every event displayed in this operation
    if ($op and !$op->{__stash}) {
        $op->{__stash} = {};
    }
    my $stash = $op ? $op->{__stash} : {};
    if (!$stash->{custom_fields_lr}) {
        # Get display order for custom fields
        my $field_order = $prefs->CustomFieldOrder;
        my @field_order = split ',', $field_order;
        my $fields_lr = $prefs->get_custom_fields (system => 1);
        my %fields    = map {$_->id, $_} @$fields_lr;
        $stash->{custom_fields_lr} = [map {$fields{$_}} @field_order];
    }
    my @custom_texts;
    foreach my $field (@{$stash->{custom_fields_lr}}) {
        next unless $field->display;
        my $value = $custom_fields_hr->{$field->id};
        if (defined $value) {
            push @custom_texts, $custom_fields_hr->{$field->id};
        }
    }
    return @custom_texts;
}

{
    # these are the fields that can get stored
    my %map = (a => 'text',
               b => 'link',
               c => 'popup',
               d => 'export',
               e => 'startTime',
               f => 'endTime',
               g => 'id',
               h => 'owner',
               i => 'drawBorder',
               j => 'bgColor',
               k => 'fgColor',
               l => 'mailTo',
               m => 'mailCC',
               n => 'mailBCC',
               o => 'mailText',
               p => 'reminderTimes',
               q => 'reminderTo',
               r => 'category',
               s => 'isTentative',
               t => 'subscriptions',
               u => 'timePeriod',

               A => 'startDate',
               B => 'endDate',
               C => 'period',
               D => 'frequency',
               E => 'monthWeek',
               F => 'monthMonth',
               G => 'exclusions',
               H => 'skipWeekends',

               X => 'customFields',     # not actually used; see below
              );

    # Return a list of ascii elements representing an event. Escape newlines.
    sub serialize {
        my $self = shift;
        my @list;

        if ($self->timePeriod) {
            delete $self->{startTime};
            delete $self->{endTime};
        }

        foreach ('a'..'u') {
            my $val = $self->{$map{$_}};
            push @list, ($_, $val) if (defined $val);
        }

        if ($self->isRepeating) {
            foreach ('A'..'F','H') {
                my $val = $self->{'repeatInfo'}->{$map{$_}};
                push @list, ($_, $val) if (defined $val);
            }
            my $val = $self->{'repeatInfo'}->{$map{G}};
            push @list, ('G', $val) if (defined $val and $val->[0]);
        }

        # Add custom fields to the list - if there are any. Like "X1", "X2"
        if ($self->{customFields}) {
            while (my ($custom_id, $val) =  each %{$self->{customFields}}) {
                next if (!defined $val or $val eq '');
                next if ($custom_id !~ /^\d+$/);
                push @list, ("X$custom_id", $val);
            }
        }

        for (my $i=1; $i<@list; $i+=2) {
            if (ref ($list[$i]) eq 'Date') {
                $list[$i] = "$list[$i]";
              # some fields could be lists (period, monthWeek, exclusions)
              # store them separated by whitespace
            } elsif (ref ($list[$i]) eq 'ARRAY') {
                $list[$i] = join ' ', @{$list[$i]};
            } else {
                $list[$i] =~ s/\n/\\n/g;
                $list[$i] =~ s/\r//g; # otherwise it writes carriage returns
            }
        }
        @list;
    }

    sub unserialize {
        my $classname = shift;
        my (%values) = @_;

        my $self = {};
        bless $self, $classname;

        my $val;
        foreach ('a'..'u') {
            next unless defined ($val = $values{$_});
            ($self->{$map{$_}} = $val) =~ s/\\n/\n/g;
        }

        if ($values{'A'}) {     # startDate
            require Calendar::RepeatInfo;
            $self->{repeatInfo} = RepeatInfo->new (@values{'A'..'F','H'});
            if ($values{'G'}) {
                require Calendar::Date;
                my @exclusions = split /\s+/, $values{'G'};
                @exclusions = map {Date->new($_)} @exclusions;
                $self->{repeatInfo}->{'exclusions'} = \@exclusions;
            }
        }

        foreach my $key (keys %values) {
            next unless $key =~ /^X(.*)/;
            my $custom_id = $1;
            next unless defined ($val = $values{$key});
            ($self->{customFields}->{$custom_id} = $val) =~ s/\\n/\n/g;
        }

        $self;
    }
}

1;
