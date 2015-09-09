# Copyright 2005-2006, Fred Steinberg, Brown Bear Software

use strict;

package CategoryChooser;

use Calendar::Javascript;

sub new {
    my $class = shift;
    my %args = (prefs       => undef,
                num_columns => undef,
                @_);
    my $self = \%args;
    return bless $self, $class;
}

sub getHTML {
    my $self = shift;
    return '' unless $self->{prefs};

    # Get all categories
    my $categories_hr = $self->{prefs}->getCategories ('masterToo');

    # Build <spans> for each one
    my @items;
    my @colors;                 # if using table below
    foreach my $name (sort {lc $a cmp lc $b} keys %$categories_hr) {
        my $cat = $categories_hr->{$name};
        my $safe_name = $name;
        $safe_name =~ s/\W//g;
        my $onclick = qq /toggleEventInCat ('c_$safe_name')/;
        my $style   = sprintf 'color: %s; background-color: %s; padding: 1px',
                                $cat->fg || 'white',
                                $cat->bg || 'black';
        my $item =   qq {<span style="$style" onclick="$onclick">}
                   . qq {<input id="c_${safe_name}_cbox" type="checkbox"}
                   . qq { checked="checked"/>$name</span>};
        push @items, $item;
        push @colors, [$cat->bg || 'black', $cat->fg || 'white'];
    }

    # Stick it in a table, if we've been passed a # of columns to use
    my $table;
    if (my $num_cols = $self->{num_columns}) {
        require CGI;
        my $num_rows = @items / $num_cols;
        if ($num_rows != int ($num_rows)) {
            $num_rows = int ($num_rows) + 1;
        }
        my @rows;
        my $row = 0;
        my $col = 0;
        my @cells;
        foreach my $item (@items) {
            $cells[$row][$col] = $item;
            $col++;
            if ($col == $num_cols) {
                $col = 0;
                $row++;
            }
        }
        for my $idx (scalar @items..$num_rows * $num_cols - 1) {
            push @items, '&nbsp;';
        }
        my @trs;
        for my $row_num (0..$num_rows-1) {
            my @tds;
            for my $col_num (0..$num_cols-1) {
                my $num = $col_num * $num_rows + $row_num;
                push @tds, CGI->td ({-color   => $colors[$num]->[1],
                                     -bgcolor => $colors[$num]->[0]},
                                    $items[$num]);
            }
            push @trs, CGI->Tr ({-align => 'left'}, @tds);
        }
        $table = CGI->table ({-cols => $num_cols,
                              -align => 'center'}, @trs);
    }
    else {
        $table = join ' ', @items;
    }

    my $html = $self->javascript;
    $html .= $table;
}

# Filter OUT by category; if an event has any categories that are off - it's off
sub javascript {
    my $set_cookie = Javascript->setCookie;
    my $get_cookie = Javascript->getCookie;
    return <<END_JAVASCRIPT;
$set_cookie
$get_cookie
<script type="text/javascript"><!--
var catDispStatus = new Object;
var catDispCSSIndex = new Object;

function initCatChooser () {
  var cookie_string = getCookie ("CalciumCatChooser");
  if (cookie_string) {
    var off_cats = cookie_string.split (';');
    for (var i=0; i<off_cats.length; i++) {
      if (off_cats[i]) {
        toggleEventInCat (off_cats[i]);
}}}}

function toggleEventInCat (name) {
  var cbox = document.getElementById (name + "_cbox");
  if (catDispStatus[name] == "none") {
    catDispStatus[name] = "";
    if (cbox) {cbox.checked = true;}
  } else {
    catDispStatus[name] = "none";
    if (cbox) {cbox.checked = false;}
  }

  var cookie_string = "";
  for (var catName in catDispStatus) {
    if (catDispStatus[catName] == "none") {
      cookie_string = cookie_string + catName + ';';
    }
  }
  setCookie ("CalciumCatChooser", cookie_string);

  var sheet = document.styleSheets[0];
  var index_to_del = catDispCSSIndex[name];
  if (index_to_del) {
    if (sheet.deleteRule) {
      sheet.deleteRule (index_to_del);
    }
    else if (sheet.removeRule) {
      sheet.removeRule (index_to_del);
    }
    delete catDispCSSIndex[name];
    // must decrement indices which were greater. Oy.
    for (var catName in catDispCSSIndex) {
      if (catDispCSSIndex[catName] > index_to_del) {
        catDispCSSIndex[catName] = catDispCSSIndex[catName] - 1;
      }
    }
  }
  var rules = sheet.rules ? sheet.rules : sheet.cssRules;
  var last_index = rules.length;
  var how = catDispStatus[name];
  if (how == "none") {
    var new_selector = "." + name;
    var new_style    = "{display: none;}";
    if (sheet.insertRule) {
      sheet.insertRule (new_selector + " " + new_style, last_index);
    } else if (sheet.addRule) {
      sheet.addRule (new_selector, new_style);
    }
    catDispCSSIndex[name] = last_index;
  }
}

var orig_onload = window.onload;
window.onload = function () {if (orig_onload) { orig_onload();} initCatChooser();}

//--></script>
END_JAVASCRIPT
}


1;
