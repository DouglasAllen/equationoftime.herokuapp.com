# Copyright 2003-2006, Fred Steinberg, Brown Bear Software
package AdminPager;
use strict;

sub new {
    my $class = shift;
    my %self  = (op               => undef,
                 contents         => [],
                 PageNumName      => 'PageNum',
                 DisplayCountName => 'DisplayCount',
                 itemName         => '', # for 'N of N <name>' label
                 @_);
    my ($pageNum, $dispCount) = $self{op}->getParams ($self{PageNumName},
                                                      $self{DisplayCountName});
    $self{pageNum}      = $pageNum   || 1;
    $self{displayCount} = $dispCount || 10;

    bless \%self, $class;
}

sub controls {
    my $self = shift;
    my %args = (pageNames   => {},
                @_);

    my $numPages = int (@{$self->{contents}} / $self->{displayCount});
    $numPages++ if (@{$self->{contents}} % $self->{displayCount});

    my $cgi  = CGI->new ('');
    my $i18n = $self->{op}->I18N;

    my $pageNumLabel = $i18n->get ('Go to Page') . ':';
    my $pageNumTD = $cgi->popup_menu (-name    => 'PageNum',
                                      -default => $self->{pageNum},
                                      -values  => [1..$numPages],
                                      -onChange => 'this.form.submit()');

    my $rowCountLabel = $i18n->get ('Rows per page') . ':';
    my @count = (5,10,15,20,25,50,75,100);
    my $rowCountTD  = $cgi->popup_menu (-name    => 'DisplayCount',
                                        -default => $self->{displayCount},
                                        -values  => \@count,
                                        -onChange => 'this.form.submit()');

    my $first = ($self->{pageNum} - 1) * $self->{displayCount} + 1;
    my $last = $first + $self->{displayCount} - 1;
    $last = @{$self->{contents}} + 0 if ($last > @{$self->{contents}});
    my $label;
    my $of = $i18n->get ('of');
    if ($first != $last) {
        $label = sprintf "#%d-%d of %d %s",
                         $first, $last, @{$self->{contents} || []} + 0,
                         $self->{itemName} || '';
    } else {
        $label = sprintf "#%d of %d %s",
                         $first, @{$self->{contents} || []} + 0,
                         $self->{itemName} || '';
    }

    my $html;
    $html .= $cgi->table ({-align       => 'center',
                           -xwidth       => '80%'},
                          $cgi->Tr ({-align => 'center',
                                     -class => 'PagingControls'},
                                    $cgi->td ("<nobr>$label</nobr>"),
                                    $cgi->td ('&nbsp;&nbsp;'),
                                    $cgi->td ("<nobr>$pageNumLabel</nobr>"),
                                    $cgi->td ($pageNumTD),
                                    $cgi->td ('&nbsp;&nbsp;'),
                                    $cgi->td ("<nobr>$rowCountLabel</nobr>"),
                                    $cgi->td ($rowCountTD)));
    $html .= '<noscript><center>' . $cgi->submit (-name => 'Go') .
             '</center></noscript>';
    return $html;
}

sub getDisplayList {
    my ($self) = @_;
    my $list = $self->{contents} || [];
    my $pageNum = $self->{pageNum} - 1;

    if ($pageNum * $self->{displayCount} > @$list) {
        $pageNum = int (@$list / $self->{displayCount});
        $self->{pageNum} = $pageNum + 1;
    }

    my $firstIndex = $pageNum * $self->{displayCount};
    my $end = $firstIndex + $self->{displayCount} - 1;

    my $maxIndex = @$list - 1;
    $end = $maxIndex if ($end > $maxIndex);

    return @$list[$firstIndex..$end];
}

1;
