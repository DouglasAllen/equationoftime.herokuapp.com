# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package Javascript;
use strict;
use CGI;

my $_scriptStart = "\n<script type=\"text/javascript\"><!-- \n";
my $_scriptEnd   = "\n// --></script>\n";
# my $_winFocus    = "\nif (navigator.appName.search (/^microsoft/i) == -1) {" .
#                    "\n    win.focus()" .
#                    "\n}";
my $_winFocus = "win.focus()";


sub SetLocation {
    my $code .= <<END_SCRIPT;
    <script type="text/javascript">
    <!--
        function SetLocation (window, url) {
            window.location=url;
        }
       // -->
    </script>
END_SCRIPT

    $code;
}

# Popup Window to display Event Details
sub PopupWindow {
    my $class = shift;
    my $op = shift;
    my $url = $op->makeURL ({Op           => 'PopupWindow',
                             Date         => undef,
                             CalendarName => undef});

    my $code = << "    END_OF_JAVASCRIPT";     # since end tag is indented
        $_scriptStart
        function PopupWindow (calName, date, id, source, width, height) {
            if (width < 100) {
               width = Math.round (screen.width * width / 100);
            }
            if (height < 100) {
               height = Math.round (screen.height * height / 100);
            }
            win = window.open ("$url" +
                               "&CalendarName=" + calName +
                               "&Date=" + escape (date) +
                               "&ID=" + id +
                               "&Source=" + source,
                               "PopupWindow" + calName + id,
                               "scrollbars,resizable," +
                               "width=" + width + "," +
                               "height=" + height)
            $_winFocus
       }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}

# Popup to select which included cals to display.
sub EventFilter {
    my $class = shift;
    my $op = shift;
    my $url = $op->makeURL ({Op => 'EventFilter',
                             IncludeOnly => $op->getParams ('IncludeOnly')});

    my $code = << "    END_OF_JAVASCRIPT";
        $_scriptStart
        function EventFilter () {
            win = window.open ("$url", "EventFilter",
                               "scrollbars,resizable,width=300,height=300")
            $_winFocus
        }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}


# Popup to display all existing calendars and allow selecting one.
sub SelectCalendar {
    my $class = shift;
    my $op = shift;
    my $language = $op->I18N->getLanguage;
    my $url = $op->makeURL ({Op           => 'SelectCalendar',
                             IsPopup      => 1,
                             Language     => $language});
    my $code;

    $code = << "    END_OF_JAVASCRIPT";     # since end tag is indented
        $_scriptStart
        function SelectCalendar (width, height) {
            if (width < 100) {
               width = Math.round (screen.width * width / 100);
            }
            if (height < 100) {
               height = Math.round (screen.height * height / 100);
            }
            win = window.open ("$url", "SelectWindow",
                               "scrollbars,resizable," +
                               "width=" + width + "," +
                               "height=" + height)
            $_winFocus
        }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}

# Popup to display Search Form
sub SearchCalendar {
    my $class = shift;
    my $op = shift;
    my $language = $op->I18N->getLanguage;
    my $url = $op->makeURL ({Op           => 'SearchForm',
                             IsPopup      => 1,
                             Language     => $language});
    my $code;

    $code = << "    END_OF_JAVASCRIPT";     # since end tag is indented
        $_scriptStart
        function SearchCalendar () {
            win = window.open ("$url", "SearchWindow",
                               "scrollbars,resizable,width=350,height=550")
            $_winFocus
        }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}

# Popup to display Text Filter Form
sub TextFilter {
    my $class = shift;
    my $op = shift;
    my $language = $op->I18N->getLanguage;
    my $url = $op->makeURL ({Op           => 'TextFilter',
                             Language     => $language});
    my $code;

    $code = << "    END_OF_JAVASCRIPT";     # since end tag is indented
        $_scriptStart
        function TextFilter () {
            win = window.open ("$url", "TextFilterWindow",
                               "scrollbars,resizable,width=350,height=500")
            $_winFocus
        }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}


# Popup Color Palette
sub ColorPalette {
    my $class = shift;
    my $op = shift;
    my $url = $op->makeURL ({Op => 'ColorPalette'});
    my $code;
    $code = << "    END_OF_JAVASCRIPT";
        $_scriptStart
        function ColorWindow () {
            win = window.open ("$url", "Colors",
                               "scrollbars,resizable,width=600,height=550")
            $_winFocus
        }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}

# Fn to display URL in Popup window
sub MakePopupFunction {
    my ($class, $url, $title, $width, $height) = @_;
    my $code;

    if ($url =~ /\?/) {
        $url .= '&IsPopup=1';
    } else {
        $url .= '?IsPopup=1';
    }

    $code = << "    END_OF_JAVASCRIPT";     # since end tag is indented
        $_scriptStart
        var ${title}PopupWindow;
        function ${title}Popup () {
           var width  = $width;
           var height = $height;
           if (width < 100) {
              width = Math.round (screen.width * width / 100);
           }
           if (height < 100) {
              height = Math.round (screen.height * height / 100);
           }
            ${title}PopupWindow = window.open ("$url", "$title",
                           "scrollbars,resizable,width=" + width +
                           ",height=" + height);
            ${title}PopupWindow.focus();
        }
        $_scriptEnd
    END_OF_JAVASCRIPT

    $code;
}

sub EditEvent {
    my ($class, $operation) = @_;
    # Javascript code for editing and adding events
    my $editURL = "?Op=EditEvent&PopupWin=1&CalendarName=";

    my $width  = $operation->prefs->EventModPopupWidth  || 50;
    my $height = $operation->prefs->EventModPopupHeight || 50;

    my $code = << "    END_OF_JAVASCRIPT";
        $_scriptStart
        editWidth = $width;
        editHeight = $height;
        if (editWidth < 100) {
           editWidth = Math.round (screen.width * editWidth / 100);
        }
        if (editHeight < 100) {
           editHeight = Math.round (screen.height * editHeight / 100);
        }
        function editEvent (id, calName, theDate) {
            if (id < 0) {
                alert ('This is an event from the ' + calName + ' Add-In.' +
                       '\\nYou cannot edit it.');
            } else {
                win = window.open ("$editURL" + calName + "&EventID=" + id +
                                   "&Date=" + theDate,
                                   "EditWindow" + calName + id,
                                   "scrollbars,resizable," +
                                     "width="  + editWidth + "," +
                                     "height=" + editHeight);
                win.focus();
            }
        }
        $_scriptEnd
    END_OF_JAVASCRIPT
    $code;
}

# For Adding event in popup window
sub AddEvent {
    my ($class) = @_;
    my $addURL  = "?Op=AddEvent&PopupWin=1&CalendarName=";
    my $code = << "    END_OF_JAVASCRIPT";
        $_scriptStart
        function addEvent (calName, date, start, end) {
            if (isNaN(start)) {
                start = -1;
            }
            win = window.open ("$addURL" + calName
                                + "&Date=" + date
                                + "&StartTime=" + start
                                + "&EndTime=" + end,
                               "AddWindow" + calName,
                               "scrollbars,resizable,"
                                + "width="  + editWidth + ","
                                + "height=" + editHeight);
            win.focus();
        }
        $_scriptEnd
    END_OF_JAVASCRIPT
    return $code;
}

sub setCookie {
    my $code = << "    END_OF_JAVASCRIPT";
        $_scriptStart
        function setCookie (name, value, expires, path, domain) {
            document.cookie = name + "=" + escape(value) +
                ((expires) ? "; expires=" + expires.toGMTString() : "") +
                ((path)    ? "; path="    + path : "") +
                ((domain)  ? "; domain="  + domain : "");
        }
        $_scriptEnd
    END_OF_JAVASCRIPT
    return $code;
}

sub getCookie {
    my $code = << "    END_OF_JAVASCRIPT";
        $_scriptStart
        function getCookie (name) {
            var prefix = name + "=";
            var begin = document.cookie.indexOf("; " + prefix);
            if (begin == -1) {
               begin = document.cookie.indexOf(prefix);
               if (begin != 0)
                   return null;
            }
            else {
                 begin += 2;
            }
            var end = document.cookie.indexOf(";", begin);
            if (end == -1) {
                end = document.cookie.length;
            }
            return unescape (document.cookie.substring(begin + prefix.length,
                                                       end));
        }
        $_scriptEnd
    END_OF_JAVASCRIPT
    return $code;
}


1;
