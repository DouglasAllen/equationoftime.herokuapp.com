# Copyright 2005-2006, Fred Steinberg, Brown Bear Software

package Template;

# Simple template processor

use strict;

my $template_dir = Defines->baseDirectory . '/data/Templates';

sub new {
    my $class = shift;
    my %self = (name             => undef,
                cal_name         => undef,
                convert_newlines => undef,   # if true and no HTML, s/\n/<br>/g;
                @_);
    die "Must specify template name\n" unless $self{name};

    my $obj = bless \%self, $class;

    my $template_file = $obj->get_filespec;
    if (!-e $template_file) {
        $obj->{error} = 'not found';
        return $obj;
    }
    if (open (TMPL, '<', $template_file)) {
        # Grab all the lines as one string
        $obj->{template} = do {local $/; <TMPL>};
        close TMPL;
    }
    else {
        $obj->{error} = $!;
    }

    # If template has no HTML tags and we're told to, change newlines to <br>
    if ($obj->{convert_newlines} and $obj->{template}
        and $obj->{template} !~ /<[^>]*>/) {         # good enough check
        $obj->{template} =~ s{\n}{<br/>}g;
    }

    return $obj;
}

sub ok {
    return !defined shift->{error}
}
sub error {
    return shift->{error};
}

# Return full path to template file
sub get_filespec {
    my $self = shift;
    return sprintf ("%s/%s.%s",
                    $template_dir, $self->{cal_name}, $self->{name});
}
# Convenience; return full path to directory, and filename
sub get_dir_and_file {
    my $filespec = shift->get_filespec;
    $filespec =~ m{^(.*)/(.*)};
    my ($dir, $file) = ($1, $2);
}

# Pash hashref of {from => to} and expand in the template text
# Return expanded text
sub expand {
    my ($self, $substitutions) = @_;
    return unless $substitutions;
    die "No template exists" unless $self->{template};
    $self->{expanded} = $self->{template};
    while (my ($from, $to) = each %$substitutions) {
        $from = quotemeta ($from);
        $to ||= '';
        $self->{expanded} =~ s/$from/$to/sgi;
    }
    return $self->{expanded};
}

# Set or get (raw) template text
sub text {
    my $self = shift;
    $self->{template} = shift if (@_);
    return $self->{template};
}

# Get (previously) filled in template
sub expansion {
    return shift->{expanded};
}

# Replace (or create) template file on disk.
# If text is empty, delete the file.
sub save_to_disk {
    my $self = shift;
    my $template_file = $self->get_filespec;

    delete $self->{error};

    my $new_text = $self->text;

    # If Template directory doesn't exist, create it
    if (!-d $template_dir) {
        if (!mkdir $template_dir) {
            $self->{error} = "Couldn't create dir $template_dir: $!";
            return;
        }
    }

    # If no text exists, just delete the file (if it exists)
    if (!$new_text and -f $template_file) {
        unlink $template_file or $self->{error} = $!;
        return;
    }

    # Replace entire file w/new contents
    if (open (TMPL, '>', $template_file)) {
        print TMPL $new_text;
        close TMPL;
    }
    else {
        $self->{error} = $!;
    }
}

1;
