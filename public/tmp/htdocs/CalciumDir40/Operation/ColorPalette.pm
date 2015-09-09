# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Display Color Palette
package ColorPalette;
use strict;
use CGI (':standard');

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my $i18n = $self->I18N;
    my @colors = qw (antiquewhite aqua aquamarine azure
                     beige bisque black blanchedalmond blue blueviolet
                     brown burlywood cadetblue chartreuse chocolate coral
                     cornflowerblue cornsilk crimson cyan darkblue darkcyan
                     darkgoldenrod darkgray darkgreen darkkhaki darkmagenta
                     darkolivegreen darkorange darkorchid darkred
                     darksalmon darkseagreen darkslateblue darkslategray
                     darkturquoise darkviolet deeppink deepskyblue dimgray
                     dodgerblue firebrick floralwhite forestgreen fuchsia
                     gainsboro ghostwhite gold goldenrod gray green
                     greenyellow honeydew hotpink indianred indigo ivory
                     khaki lavender lavenderblush lawngreen lemonchiffon
                     lightblue lightcoral lightcyan lightgoldenrodyellow
                     lightgreen lightgrey lightpink lightsalmon
                     lightseagreen lightskyblue lightslategray
                     lightsteelblue lightyellow lime limegreen linen
                     magenta maroon mediumaquamarine mediumblue
                     mediumorchid mediumpurple mediumseagreen
                     mediumslateblue mediumspringgreen mediumturquoise
                     mediumvioletred midnightblue mintcream mistyrose
                     moccasin navajowhite navy oldlace olive olivedrab
                     orange orangered orchid palegoldenrod palegreen
                     paleturquoise palevioletred papayawhip peachpuff peru
                     pink plum powderblue purple red rosybrown royalblue
                     saddlebrown salmon sandybrown seagreen seashell sienna
                     silver skyblue slateblue slategray snow springgreen
                     steelblue tan teal thistle tomato turquoise violet
                     wheat white whitesmoke yellow yellowgreen);

    my $cgi = new CGI;

    my $html = GetHTML->startHTML (title  => $i18n->get ('Color Palette'),
                                   op     => $self);

    my $instructions = $i18n->get ('ColorPalette_HelpString');
    if ($instructions eq 'ColorPalette_HelpString') {
        ($instructions =<<"        FNORD") =~ s/^ +//gm;
            <p>You can specify colors using either a <b>color name</b>, or
            a <b>numeric value</b> which specifies the intensity of the
            Red, Green, and Blue pixels. Valid names with the colors they
            represent are shown below. (You can click your mouse and drag
            over a color name to highlight it if it is unreadable.) An
            explanation of how to specify <b>any</b> color using a numeric
            value is at the bottom of the page. </p>
        FNORD
    }
    $html .= $instructions;

    my $numCols = 4;
    my @rows;
    while (@colors) {
        my @tds;
        foreach (1..$numCols) {
            my $color = shift @colors;
            last unless defined $color;
            push @tds, $cgi->td ({-bgcolor => $color}, $color);
        }
        push @rows, $cgi->Tr (@tds);
    }
    $html .= $cgi->table ({-width => '100%',
                           -cols  => $numCols},
                          @rows);

    $instructions = $i18n->get ('ColorPalette_MoreHelpString');
    if ($instructions eq 'ColorPalette_MoreHelpString') {
        ($instructions =<<"        FNORD") =~ s/^ +//gm;
            <p>Any color can be specified by using a numeric value which
            represents the relative amounts of red, green, and blue. These
            values are specified as a six digit hexadecimal number,
            preceded by the '#' character. The first two digits of the
            number specify the Red value, the next two specify Green, and
            the final two are for Blue.</p> Some examples:<br>
        FNORD
    }

    $html .= $instructions;

    $html .= <<FNORD;
        &nbsp;<code>#0000ff</code> - <font color=#0000ff>blue</font><br>
        &nbsp;<code>#ff00ff</code> - <font color=#ff00ff>purple</font><br>
        &nbsp;<code>#777777</code> - <font color=#777777>medium gray</font><br>
        &nbsp;<code>#cc9903</code> - <font color=#cc9903>yellowish</font><br>
FNORD

    $html .= $cgi->startform;
    $html .= '<hr>';
    $html .= $cgi->button ({-value   => $i18n->get ('Close'),
                         -onClick => 'window.close()'});
    $html .= $cgi->endform;

    $html .= $cgi->end_html;
    print $html;
}

1;
