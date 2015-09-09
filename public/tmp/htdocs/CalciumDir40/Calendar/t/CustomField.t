#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 50;

use lib '../../../../CalciumDir311';
use lib '../..';
use Calendar::CustomField;

# Constructor, accessors
my $obj = CustomField->new;
ok ($obj, 'simple new()');

$obj = CustomField->new (id         => 33,
                         name       => 'test',
                         input_type => 'textfield',
                         default    => 'hello',
                         required   => 1,
                         label      => 'Hello Label: ');
ok ($obj->name    eq 'test',  'name accessor');
ok ($obj->id      == 33,      'id accessor');
ok ($obj->default eq 'hello', 'default accessor');

my $serialized = $obj->serialize;
my $new_obj = CustomField->unserialize (split $;, $serialized);
ok ($new_obj->isa ('CustomField'), 'unserialize');
ok ($new_obj->name    eq 'test',   'unser. name accessor');
ok ($new_obj->id      == 33,       'unser. id accessor');
ok ($new_obj->default eq 'hello',  'unser. default accessor');
