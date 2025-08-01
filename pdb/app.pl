# GIMP - The GNU Image Manipulation Program
# Copyright (C) 1998-2003 Manish Singh <yosh@gimp.org>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

package Gimp::CodeGen::app;

$destdir  = "$main::destdir/app/pdb";
$builddir = "$main::builddir/app/pdb";

*arg_types = \%Gimp::CodeGen::pdb::arg_types;
*arg_parse = \&Gimp::CodeGen::pdb::arg_parse;

*enums = \%Gimp::CodeGen::enums::enums;

*write_file = \&Gimp::CodeGen::util::write_file;
*FILE_EXT   = \$Gimp::CodeGen::util::FILE_EXT;

use Text::Wrap qw(wrap);

sub quotewrap {
    my ($str, $indent, $subsequent_indent) = @_;
    my $leading = ' ' x $indent . '"';
    my $subsequent_leading = ' ' x $subsequent_indent . '"';
    $Text::Wrap::columns = 1000;
    $Text::Wrap::unexpand = 0;
    $str = wrap($leading, $subsequent_leading, $str);
    $str =~ s/^\s*//s;
    $str =~ s/(.)\n(.)/$1\\n"\n$2/g;
    $str =~ s/(.)$/$1"/s;
    $str;
}

sub format_code_frag {
    my ($code, $indent) = @_;

    chomp $code;
    $code =~ s/\t/' ' x 8/eg;

    if (!$indent && $code =~ /^\s*{\s*\n.*\n\s*}\s*$/s) {
	$code =~ s/^\s*{\s*\n//s;
	$code =~ s/\n\s*}\s*$//s;
    }
    else {
	$code =~ s/^/' ' x ($indent ? 4 : 2)/meg;
    }
    $code .= "\n";

    $code =~ s/^\s+$//mg;

    $code;
}

sub declare_args {
    my $proc = shift;
    my $out = shift;
    my $outargs = shift;

    local $result = "";

    foreach (@_) {
	my @args = @{$proc->{$_}} if (defined $proc->{$_});

	foreach (@args) {
	    my ($type, $name) = &arg_parse($_->{type});
	    my $arg = $arg_types{$type};

	    if ($arg->{array} && !exists $_->{array}) {
		warn "Array without number of elements param in $proc->{name}";
	    }

	    unless (exists $_->{no_declare} || exists $_->{dead}) {
		if ($outargs) {
                    if (exists $arg->{app_type}) {
                        $result .= "  $arg->{app_type}$_->{name} = $arg->{init_value}";
                    }
                    else {
                        $result .= "  $arg->{type}$_->{name} = $arg->{init_value}";
                    }
		}
		else {
                    if (exists $arg->{app_const_type}) {
                        $result .= "  $arg->{app_const_type}$_->{name}";
                    }
                    else {
                        $result .= "  $arg->{const_type}$_->{name}";
                    }
		}
		$result .= ";\n";

		if (exists $arg->{headers}) {
		    foreach (@{$arg->{headers}}) {
			$out->{headers}->{$_}++;
		    }
		}
	    }
	}
    }

    $result;
}

sub marshal_inargs {
    my ($proc, $argc) = @_;

    my $result = "";
    my %decls;

    my @inargs = @{$proc->{inargs}} if (defined $proc->{inargs});

    foreach (@inargs) {
	my($pdbtype, @typeinfo) = &arg_parse($_->{type});
	my $arg = $arg_types{$pdbtype};
	my $var = $_->{name};
	my $value;

	$value = "gimp_value_array_index (args, $argc)";
        if (exists $_->{nopdb}) {
            $argc--;
        }
        elsif (!exists $_->{dead}) {
	    my $var_len;

	    if (exists $_->{array}) {
		my $arrayarg = $_->{array};

		if (exists $arrayarg->{name}) {
		    $var_len = $arrayarg->{name};
		}
		else {
		    $var_len = 'num_' . $_->{name};
		}
	    }
	    $result .= eval qq/"  $arg->{get_value_func};\n"/;
	}

	$argc++;

	if (!exists $_->{no_validate}) {
	    $success = 1;
	}
    }

    $result = "\n" . $result . "\n" if $result;
    $result;
}

sub marshal_outargs {
    my $proc = shift;
    my $result;
    my $argc = 0;
    my @outargs = @{$proc->{outargs}} if (defined $proc->{outargs});

    if ($success) {
	$result = <<CODE;
  return_vals = gimp_procedure_get_return_values (procedure, success,
                                                  error ? *error : NULL);
CODE
    } else {
	$result = <<CODE;
  return_vals = gimp_procedure_get_return_values (procedure, TRUE, NULL);
CODE
    }

    if (scalar @outargs) {
	my $outargs = "";

	foreach (@{$proc->{outargs}}) {
	    my ($pdbtype) = &arg_parse($_->{type});
	    my $arg = $arg_types{$pdbtype};
	    my $var = $_->{name};
	    my $var_len;
	    my $value;

	    $argc++;

            if (exists $_->{nopdb}) {
                $argc--;
            }
            else {
                $value = "gimp_value_array_index (return_vals, $argc)";

                if (exists $_->{array}) {
                    my $arrayarg = $_->{array};

                    if (exists $arrayarg->{name}) {
                        $var_len = $arrayarg->{name};
                    }
                    else {
                        $var_len = 'num_' . $_->{name};
                    }
                }

                $outargs .= eval qq/"  $arg->{take_value_func};\n"/;
            }
	}

	$outargs =~ s/^/' ' x 2/meg if $success;
	$outargs =~ s/^/' ' x 2/meg if $success && $argc > 1;

	$result .= "\n" if $success || $argc > 1;
	$result .= ' ' x 2 . "if (success)\n" if $success;
	$result .= ' ' x 4 . "{\n" if $success && $argc > 1;
	$result .= $outargs;
	$result .= ' ' x 4 . "}\n" if $success && $argc > 1;
        $result .= "\n" . ' ' x 2 . "return return_vals;\n";
    }
    else {
	if ($success) {
	    $result =~ s/return_vals =/return/;
	    $result =~ s/       error/error/;
	}
	else {
	    $result =~ s/  return_vals =/\n  return/;
	    $result =~ s/       error/error/;
	}
    }

    $result;
}

sub generate_pspec {
    my $arg = shift;
    my ($pdbtype, @typeinfo) = &arg_parse($arg->{type});
    my $name = $arg->{canonical_name};
    my $nick = $arg->{canonical_name};
    my $blurb = exists $arg->{desc} ? $arg->{desc} : "";
    my $min;
    my $max;
    my $default;
    my $flags = 'GIMP_PARAM_READWRITE';
    my $pspec = "";
    my $postproc = "";

    $nick =~ s/-/ /g;

    if (exists $arg->{no_validate}) {
	$flags .= ' | GIMP_PARAM_NO_VALIDATE';
    }

    if ($pdbtype eq 'image') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_image ("$name",
                       "$nick",
                       "$blurb",
                       $none_ok,
                       $flags)
CODE
    }
    elsif ($pdbtype eq 'resource') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$default = exists $arg->{default} ? $arg->{default} : NULL;
	$pspec = <<CODE;
gimp_param_spec_resource ("$name",
                          "$nick",
                          "$blurb",
                          GIMP_TYPE_RESOURCE,
                          $none_ok,
                          $default,
                          FALSE,
                          $flags)
CODE
    }
    elsif ($pdbtype eq 'brush') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$default = exists $arg->{default} ? $arg->{default} : NULL;
	$default_to_context = exists $arg->{default_to_context} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_brush ("$name",
                       "$nick",
                       "$blurb",
                       $none_ok,
                       $default,
                       $default_to_context,
                       $flags)
CODE
    }
    elsif ($pdbtype eq 'font') {
  $none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
  $default = exists $arg->{default} ? $arg->{default} : NULL;
  $default_to_context = exists $arg->{default_to_context} ? 'TRUE' : 'FALSE';
  $pspec = <<CODE;
gimp_param_spec_font ("$name",
                      "$nick",
                      "$blurb",
                      $none_ok,
                      $default,
                      $default_to_context,
                      $flags)
CODE
    }
    elsif ($pdbtype eq 'gradient') {
  $none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
  $default = exists $arg->{default} ? $arg->{default} : NULL;
  $default_to_context = exists $arg->{default_to_context} ? 'TRUE' : 'FALSE';
  $pspec = <<CODE;
gimp_param_spec_gradient ("$name",
                          "$nick",
                          "$blurb",
                          $none_ok,
                          $default,
                          $default_to_context,
                          $flags)
CODE
    }
    elsif ($pdbtype eq 'palette') {
  $none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
  $default = exists $arg->{default} ? $arg->{default} : NULL;
  $default_to_context = exists $arg->{default_to_context} ? 'TRUE' : 'FALSE';
  $pspec = <<CODE;
gimp_param_spec_palette ("$name",
                         "$nick",
                         "$blurb",
                         $none_ok,
                         $default,
                         $default_to_context,
                         $flags)
CODE
    }
    elsif ($pdbtype eq 'pattern') {
  $none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
  $default = exists $arg->{default} ? $arg->{default} : NULL;
  $default_to_context = exists $arg->{default_to_context} ? 'TRUE' : 'FALSE';
  $pspec = <<CODE;
gimp_param_spec_pattern ("$name",
                         "$nick",
                         "$blurb",
                         $none_ok,
                         $default,
                         $default_to_context,
                         $flags)
CODE
    }
    elsif ($pdbtype eq 'item') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_item ("$name",
                      "$nick",
                      "$blurb",
                      $none_ok,
                      $flags)
CODE
    }
    elsif ($pdbtype eq 'drawable') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_drawable ("$name",
                          "$nick",
                          "$blurb",
                          $none_ok,
                          $flags)
CODE
    }
    elsif ($pdbtype eq 'group_layer') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_group_layer ("$name",
                             "$nick",
                             "$blurb",
                             $none_ok,
                             $flags)
CODE
    }
    elsif ($pdbtype eq 'text_layer') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_text_layer ("$name",
                            "$nick",
                            "$blurb",
                            $none_ok,
                            $flags)
CODE
    }
    elsif ($pdbtype eq 'layer') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_layer ("$name",
                       "$nick",
                       "$blurb",
                       $none_ok,
                       $flags)
CODE
    }
    elsif ($pdbtype eq 'channel') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_channel ("$name",
                         "$nick",
                         "$blurb",
                         $none_ok,
                         $flags)
CODE
    }
    elsif ($pdbtype eq 'layer_mask') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_layer_mask ("$name",
                            "$nick",
                            "$blurb",
                            $none_ok,
                            $flags)
CODE
    }
    elsif ($pdbtype eq 'selection') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_selection ("$name",
                           "$nick",
                           "$blurb",
                           $none_ok,
                           $flags)
CODE
    }
    elsif ($pdbtype eq 'path') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_path ("$name",
                      "$nick",
                      "$blurb",
                      $none_ok,
                      $flags)
CODE
    }
    elsif ($pdbtype eq 'filter') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_drawable_filter ("$name",
                                 "$nick",
                                 "$blurb",
                                 $none_ok,
                                 $flags)
CODE
    }
    elsif ($pdbtype eq 'display') {
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$pspec = <<CODE;
gimp_param_spec_display ("$name",
                         "$nick",
                         "$blurb",
                         $none_ok,
                         $flags)
CODE
    }
    elsif ($pdbtype eq 'file') {
	$pspec = <<CODE;
g_param_spec_object ("$name",
                     "$nick",
                     "$blurb",
                     G_TYPE_FILE,
                     $flags)
CODE
    }
    elsif ($pdbtype eq 'tattoo') {
	$pspec = <<CODE;
g_param_spec_uint ("$name",
                   "$nick",
                   "$blurb",
                   1, G_MAXUINT32, 1,
                   $flags)
CODE
    }
    elsif ($pdbtype eq 'guide') {
        $min = exists $arg->{none_ok} ? 0 : 1,
	$pspec = <<CODE;
g_param_spec_uint ("$name",
                   "$nick",
                   "$blurb",
                   $min, G_MAXUINT32, $min,
                   $flags)
CODE
    }
    elsif ($pdbtype eq 'sample_point') {
        $min = exists $arg->{none_ok} ? 0 : 1,
	$pspec = <<CODE;
g_param_spec_uint ("$name",
                   "$nick",
                   "$blurb",
                   $min, G_MAXUINT32, $min,
                   $flags)
CODE
    }
    elsif ($pdbtype eq 'export_options') {
	$pspec = <<CODE;
gimp_param_spec_export_options ("$name",
                                "$nick",
                                "$blurb",
                                $flags)
CODE
    }
    elsif ($pdbtype eq 'double') {
	$min = defined $typeinfo[0] ? $typeinfo[0] : -G_MAXDOUBLE;
	$max = defined $typeinfo[2] ? $typeinfo[2] : G_MAXDOUBLE;
	$default = exists $arg->{default} ? $arg->{default} : defined $typeinfo[0] ? $typeinfo[0] : 0.0;
	$pspec = <<CODE;
g_param_spec_double ("$name",
                     "$nick",
                     "$blurb",
                     $min, $max, $default,
                     $flags)
CODE
    }
    elsif ($pdbtype eq 'size') {
	if (defined $typeinfo[0]) {
	    $min = ($typeinfo[1] eq '<') ? ($typeinfo[0] + 1) : $typeinfo[0];
	}
	else {
	    $min = G_MINSIZE;
	}
	if (defined $typeinfo[2]) {
	    $max = ($typeinfo[3] eq '<') ? ($typeinfo[2] - 1) : $typeinfo[2];
	}
	else {
	    $max = G_MAXSIZE;
	}
	$default = exists $arg->{default} ? $arg->{default} : defined $typeinfo[0] ? $typeinfo[0] : 0;
	$pspec = <<CODE;
g_param_spec_size ("$name",
                   "$nick",
                   "$blurb",
                   $min, $max, $default,
                   $flags)
CODE
    }
    elsif ($pdbtype eq 'int32') {
	if (defined $typeinfo[0]) {
	    $min = ($typeinfo[1] eq '<') ? ($typeinfo[0] + 1) : $typeinfo[0];
	}
	else {
	    $min = G_MININT32;
	}
	if (defined $typeinfo[2]) {
	    $max = ($typeinfo[3] eq '<') ? ($typeinfo[2] - 1) : $typeinfo[2];
	}
	else {
	    $max = G_MAXINT32;
	}
	$default = exists $arg->{default} ? $arg->{default} : defined $typeinfo[0] ? $typeinfo[0] : 0;
	$pspec = <<CODE;
g_param_spec_int ("$name",
                  "$nick",
                  "$blurb",
                  $min, $max, $default,
                  $flags)
CODE
    }
    elsif ($pdbtype eq 'int16') {
	if (defined $typeinfo[0]) {
	    $min = ($typeinfo[1] eq '<') ? ($typeinfo[0] + 1) : $typeinfo[0];
	}
	else {
	    $min = G_MININT16;
	}
	if (defined $typeinfo[2]) {
	    $max = ($typeinfo[3] eq '<') ? ($typeinfo[2] - 1) : $typeinfo[2];
	}
	else {
	    $max = G_MAXINT16;
	}
	$default = exists $arg->{default} ? $arg->{default} : defined $typeinfo[0] ? $typeinfo[0] : 0;
	$pspec = <<CODE;
g_param_spec_int ("$name",
                  "$nick",
                  "$blurb",
                  $min, $max, $default,
                  $flags)
CODE
    }
    elsif ($pdbtype eq 'boolean') {
	$default = exists $arg->{default} ? $arg->{default} : FALSE;
	$pspec = <<CODE;
g_param_spec_boolean ("$name",
                      "$nick",
                      "$blurb",
                      $default,
                      $flags)
CODE
    }
    elsif ($pdbtype eq 'string') {
	$allow_non_utf8 = exists $arg->{allow_non_utf8} ? 'TRUE' : 'FALSE';
	$none_ok = exists $arg->{none_ok} ? 'TRUE' : 'FALSE';
	$non_empty = exists $arg->{non_empty} ? 'TRUE' : 'FALSE';
	$default = exists $arg->{default} ? $arg->{default} : NULL;
	$pspec = <<CODE;
gimp_param_spec_string ("$name",
                        "$nick",
                        "$blurb",
                        $allow_non_utf8, $none_ok, $non_empty,
                        $default,
                        $flags)
CODE
    }
    elsif ($pdbtype eq 'enum') {
	$enum_type = $typeinfo[0];
	$enum_type =~ s/([a-z])([A-Z])/$1_$2/g;
	$enum_type =~ s/([A-Z]+)([A-Z])/$1_$2/g;
	$enum_type =~ tr/[a-z]/[A-Z]/;
	$enum_type =~ s/^GIMP/GIMP_TYPE/;
	$enum_type =~ s/^GEGL/GEGL_TYPE/;
	$default = exists $arg->{default} ? $arg->{default} : $enums{$typeinfo[0]}->{symbols}[0];

	my ($foo, $bar, @remove) = &arg_parse($arg->{type});

	foreach (@remove) {
	    $postproc .= 'gimp_param_spec_enum_exclude_value (GIMP_PARAM_SPEC_ENUM ($pspec),';
	    $postproc .= "\n                                    $_);\n";
	}

	if ($postproc eq '') {
	    $pspec = <<CODE;
g_param_spec_enum ("$name",
                   "$nick",
                   "$blurb",
                   $enum_type,
                   $default,
                   $flags)
CODE
	}
	else {
	    $pspec = <<CODE;
gimp_param_spec_enum ("$name",
                      "$nick",
                      "$blurb",
                      $enum_type,
                      $default,
                      $flags)
CODE
        }
    }
    elsif ($pdbtype eq 'unit') {
	$allow_pixel = exists $arg->{allow_pixel} ? TRUE : FALSE;
	$allow_percent = exists $arg->{allow_percent} ? TRUE : FALSE;
	$default = exists $arg->{default} ? $arg->{default} : 'gimp_unit_inch ()';
	$pspec = <<CODE;
gimp_param_spec_unit ("$name",
                      "$nick",
                      "$blurb",
                      $allow_pixel,
                      $allow_percent,
                      $default,
                      $flags)
CODE
    }
    elsif ($pdbtype eq 'geglcolor') {
	$has_alpha = exists $arg->{has_alpha} ? TRUE : FALSE;
	$default = exists $arg->{default} ? $arg->{default} : NULL;
	$pspec = <<CODE;
gimp_param_spec_color ("$name",
                       "$nick",
                       "$blurb",
                       $has_alpha,
                       $default,
                       $flags)
CODE
    }
    elsif ($pdbtype eq 'format') {
	$pspec = <<CODE;
g_param_spec_boxed ("$name",
                    "$nick",
                    "$blurb",
                    GIMP_TYPE_BABL_FORMAT,
                    $flags)
CODE
    }
    elsif ($pdbtype eq 'parasite') {
	$pspec = <<CODE;
gimp_param_spec_parasite ("$name",
                          "$nick",
                          "$blurb",
                          $flags)
CODE
    }
    elsif ($pdbtype eq 'param') {
	$pspec = <<CODE;
g_param_spec_param ("$name",
                    "$nick",
                    "$blurb",
                    G_TYPE_PARAM,
                    $flags)
CODE
    }
    elsif ($pdbtype eq 'int32array') {
	$pspec = <<CODE;
gimp_param_spec_int32_array ("$name",
                             "$nick",
                             "$blurb",
                             $flags)
CODE
    }
    elsif ($pdbtype eq 'doublearray') {
	$pspec = <<CODE;
gimp_param_spec_double_array ("$name",
                              "$nick",
                              "$blurb",
                              $flags)
CODE
    }
    elsif ($pdbtype eq 'bytes') {
	$pspec = <<CODE;
g_param_spec_boxed ("$name",
                    "$nick",
                    "$blurb",
                    G_TYPE_BYTES,
                    $flags)
CODE
    }
    elsif ($pdbtype eq 'strv') {
	$pspec = <<CODE;
g_param_spec_boxed ("$name",
                    "$nick",
                    "$blurb",
                    G_TYPE_STRV,
                    $flags)
CODE
    }
    elsif ($pdbtype eq 'colorarray') {
	$pspec = <<CODE;
g_param_spec_boxed ("$name",
                    "$nick",
                    "$blurb",
                    GIMP_TYPE_COLOR_ARRAY,
                    $flags)
CODE
    }
    elsif ($pdbtype eq 'imagearray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_IMAGE,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'itemarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_ITEM,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'drawablearray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_DRAWABLE,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'layerarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_LAYER,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'channelarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_CHANNEL,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'patharray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_PATH,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'filterarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_DRAWABLE_FILTER,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'resourcearray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_RESOURCE,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'brusharray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_BRUSH,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'fontarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_FONT,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'gradientarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_GRADIENT,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'palettearray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_PALETTE,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'patternarray') {
	$pspec = <<CODE;
gimp_param_spec_core_object_array ("$name",
                                   "$nick",
                                   "$blurb",
                                   GIMP_TYPE_PATTERN,
                                   $flags)
CODE
    }
    elsif ($pdbtype eq 'valuearray') {
	$pspec = <<CODE;
gimp_param_spec_value_array ("$name",
                             "$nick",
                             "$blurb",
                             NULL,
                             $flags)
CODE
    }
    else {
	warn "Unsupported PDB type: $arg->{name} ($arg->{type})";
	exit -1;
    }

    $pspec =~ s/\s$//;

    return ($pspec, $postproc);
}

sub canonicalize {
    $_ = shift; s/_/-/g; return $_;
}

sub generate {
    my @procs = @{(shift)};
    my %out;
    my $total = 0.0;
    my $argc;

    foreach $name (@procs) {
	my $proc = $main::pdb{$name};
	my $out = \%{$out{$proc->{group}}};

	my @inargs = @{$proc->{inargs}} if (defined $proc->{inargs});
	my @outargs = @{$proc->{outargs}} if (defined $proc->{outargs});

	my $blurb = $proc->{blurb};
	my $help = $proc->{help};

	my $procedure_name;
	my $procedure_is_private;

	local $success = 0;

	if ($proc->{deprecated}) {
            if ($proc->{deprecated} eq 'NONE') {
		if (!$blurb) {
		    $blurb = "Deprecated: There is no replacement for this procedure.";
		}
		if ($help) {
		    $help .= "\n\n";
		}
		$help .= "Deprecated: There is no replacement for this procedure.";
	    }
	    else {
		if (!$blurb) {
		    $blurb = "Deprecated: Use '$proc->{deprecated}' instead.";
		}
		if ($help) {
		    $help .= "\n\n";
		}
		$help .= "Deprecated: Use '$proc->{deprecated}' instead.";
	    }
	}

	$help =~ s/gimp(\w+)\(\s*\)/"'gimp".canonicalize($1)."'"/ge;

	if ($proc->{group} eq "plug_in_compat") {
	    $procedure_name = "$proc->{canonical_name}";
	} else {
	    $procedure_name = "gimp-$proc->{canonical_name}";
	}

	$out->{pcount}++; $total++;

        if ($proc->{lib_private}) {
            $procedure_is_private = "TRUE";
        } else {
            $procedure_is_private = "FALSE";
        }

	$out->{register} .= <<CODE;

  /*
   * gimp-$proc->{canonical_name}
   */
  procedure = gimp_procedure_new (${name}_invoker, $procedure_is_private);
  gimp_object_set_static_name (GIMP_OBJECT (procedure),
                               "$procedure_name");
  gimp_procedure_set_static_help (procedure,
                                  @{[ &quotewrap($blurb, 2, 34) ]},
                                  @{[ &quotewrap($help,  2, 34) ]},
                                  NULL);
  gimp_procedure_set_static_attribution (procedure,
                                         "$proc->{author}",
                                         "$proc->{copyright}",
                                         "$proc->{date}");
CODE

        if ($proc->{deprecated}) {
	    $out->{register} .= <<CODE;
  gimp_procedure_set_deprecated (procedure,
                                 "\"$proc->{deprecated}\"");
CODE
	}

	$argc = 0;

        foreach $arg (@inargs) {
	    my ($pspec, $postproc) = &generate_pspec($arg);

            if (exists $arg->{nopdb}) {
                $argc--;
            }
            else {
                $pspec =~ s/^/' ' x length("  gimp_procedure_add_argument (")/meg;

                $out->{register} .= <<CODE;
  gimp_procedure_add_argument (procedure,
${pspec});
CODE

                if ($postproc ne '') {
                    $pspec = "procedure->args[$argc]";
                    $postproc =~ s/^/'  '/meg;
                    $out->{register} .= eval qq/"$postproc"/;
                }
            }

	    $argc++;
	}

	$argc = 0;

	foreach $arg (@outargs) {
	    my ($pspec, $postproc) = &generate_pspec($arg);
	    my $argc = 0;

            if (exists $arg->{nopdb}) {
                $argc--;
            }
            else {
                $pspec =~ s/^/' ' x length("  gimp_procedure_add_return_value (")/meg;

                $out->{register} .= <<CODE;
  gimp_procedure_add_return_value (procedure,
${pspec});
CODE

                if ($postproc ne '') {
                    $pspec = "procedure->values[$argc]";
                    $postproc =~ s/^/'  '/meg;
                    $out->{register} .= eval qq/"$postproc"/;
                }
            }

	    $argc++;
	}

	$out->{register} .= <<CODE;
  gimp_pdb_register_procedure (pdb, procedure);
  g_object_unref (procedure);
CODE

	if (exists $proc->{invoke}->{headers}) {
	    foreach $header (@{$proc->{invoke}->{headers}}) {
		$out->{headers}->{$header}++;
	    }
	}

	$out->{code} .= "\nstatic GimpValueArray *\n";
	$out->{code} .= "${name}_invoker (GimpProcedure         *procedure,\n";
	$out->{code} .=  ' ' x length($name) . "          Gimp                  *gimp,\n";
	$out->{code} .=  ' ' x length($name) . "          GimpContext           *context,\n";
	$out->{code} .=  ' ' x length($name) . "          GimpProgress          *progress,\n";
	$out->{code} .=  ' ' x length($name) . "          const GimpValueArray  *args,\n";
	$out->{code} .=  ' ' x length($name) . "          GError               **error)\n{\n";

	my $code = "";

	if (exists $proc->{invoke}->{no_marshalling}) {
	    $code .= &format_code_frag($proc->{invoke}->{code}, 0) . "}\n";
	}
	else {
	    my $invoker = "";

	    $invoker .= ' ' x 2 . "GimpValueArray *return_vals;\n" if scalar @outargs;
	    $invoker .= &declare_args($proc, $out, 0, qw(inargs));
	    $invoker .= &declare_args($proc, $out, 1, qw(outargs));

	    $invoker .= &marshal_inargs($proc, 0);
	    $invoker .= "\n" if $invoker && $invoker !~ /\n\n/s;

	    my $frag = "";

	    if (exists $proc->{invoke}->{code}) {
		$frag = &format_code_frag($proc->{invoke}->{code}, $success);
		$frag = ' ' x 2 . "if (success)\n" . $frag if $success;
		$success = ($frag =~ /success =/) unless $success;
	    }

	    chomp $invoker if !$frag;
	    $code .= $invoker . $frag;
	    $code .= "\n" if $frag =~ /\n\n/s || $invoker;
	    $code .= &marshal_outargs($proc) . "}\n";
	}

	if ($success) {
	    $out->{code} .= ' ' x 2 . "gboolean success";
	    unless ($proc->{invoke}->{success} eq 'NONE') {
		$out->{code} .= " = $proc->{invoke}->{success}";
	    }
	    $out->{code} .= ";\n";
	}

        $out->{code} .= $code;
    }

    my $gpl = <<'GPL';
/* GIMP - The GNU Image Manipulation Program
 * Copyright (C) 1995-2003 Spencer Kimball and Peter Mattis
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/* NOTE: This file is auto-generated by pdbgen.pl. */

GPL

    my $group_procs = "";
    my $longest = 0;
    my $once = 0;
    my $pcount = 0.0;

    foreach $group (@main::groups) {
	my $out = $out{$group};

	foreach (@{$main::grp{$group}->{headers}}) { $out->{headers}->{$_}++ }

	$out->{headers}->{"\"core/gimpparamspecs.h\""}++;

	my @headers = sort {
	    my ($x, $y) = ($a, $b);
	    foreach ($x, $y) {
		if (/^</) {
		    s/^</!/;
		}
		elsif (!/libgimp/) {
		    s/^/~/;
		}
	    }
	    $x cmp $y;
	} keys %{$out->{headers}};

	my $headers = "";
	my $lib = 0;
	my $seen = 0;
	my $sys = 0;
	my $base = 0;
	my $error = 0;
	my $utils = 0;
	my $context = 0;
	my $intl = 0;

	foreach (@headers) {
	    $seen++ if /^</;

	    if ($sys == 0 && !/^</) {
		$sys = 1;
		$headers .= "\n" if $seen;
		$headers .= "#include <gegl.h>\n\n";
		$headers .= "#include <gdk-pixbuf/gdk-pixbuf.h>\n\n";
	    }

	    $seen = 0 if !/^</;

	    if (/libgimp/) {
		$lib = 1;
	    }
	    else {
		$headers .= "\n" if $lib;
		$lib = 0;

		if ($sys == 1 && $base == 0) {
		    $base = 1;
		    $headers .= "#include \"libgimpbase/gimpbase.h\"\n\n";
		    $headers .= "#include \"pdb-types.h\"\n\n";
		}
	    }

	    if (/gimp-intl/) {
		$intl = 1;
	    }
	    elsif (/gimppdb-utils/) {
		$utils = 1;
	    }
	    elsif (/gimppdberror/) {
		$error = 1;
	    }
	    elsif (/gimppdbcontext/) {
		$context = 1;
	    }
	    else {
		$headers .= "#include $_\n";
	    }
	}

	$headers .= "\n";
	$headers .= "#include \"gimppdb.h\"\n";
	$headers .= "#include \"gimppdberror.h\"\n" if $error;
	$headers .= "#include \"gimppdb-utils.h\"\n" if $utils;
	$headers .= "#include \"gimppdbcontext.h\"\n" if $context;
	$headers .= "#include \"gimpprocedure.h\"\n";
	$headers .= "#include \"internal-procs.h\"\n";

	$headers .= "\n#include \"gimp-intl.h\"\n" if $intl;

	my $extra = {};
	if (exists $main::grp{$group}->{extra}->{app}) {
	    $extra = $main::grp{$group}->{extra}->{app}
	}

	my $cfile = "$builddir/".canonicalize(${group})."-cmds.c$FILE_EXT";
	open CFILE, "> $cfile" or die "Can't open $cfile: $!\n";
	print CFILE $gpl;
	print CFILE qq/#include "config.h"\n\n/;
	print CFILE qq/#include "stamp-pdbgen.h"\n\n/;
	print CFILE $headers, "\n";
	print CFILE $extra->{decls}, "\n" if exists $extra->{decls};
	print CFILE "\n", $extra->{code} if exists $extra->{code};
	print CFILE $out->{code};
	print CFILE "\nvoid\nregister_${group}_procs (GimpPDB *pdb)\n";
	print CFILE "{\n  GimpProcedure *procedure;\n$out->{register}}\n";
	close CFILE;
	&write_file($cfile, $destdir);

	my $decl = "register_${group}_procs";
	push @group_decls, $decl;
	$longest = length $decl if $longest < length $decl;

	$group_procs .=  ' ' x 2 . "register_${group}_procs (pdb);\n";
	$pcount += $out->{pcount};
    }

    if (! $ENV{PDBGEN_GROUPS}) {
	my $internal = "$builddir/internal-procs.h$FILE_EXT";
	open IFILE, "> $internal" or die "Can't open $internal: $!\n";
	print IFILE $gpl;
	print IFILE <<HEADER;
#pragma once


HEADER

        print IFILE "void   internal_procs_init" . ' ' x ($longest - length "internal_procs_init") . " (GimpPDB *pdb);\n\n";

	print IFILE "/* Forward declarations for registering PDB procs */\n\n";
	foreach (@group_decls) {
	    print IFILE "void   $_" . ' ' x ($longest - length $_) . " (GimpPDB *pdb);\n";
	}
	close IFILE;
	&write_file($internal, $destdir);

	$internal = "$builddir/internal-procs.c$FILE_EXT";
	open IFILE, "> $internal" or die "Can't open $internal: $!\n";
	print IFILE $gpl;
	print IFILE qq@#include "config.h"\n\n@;
	print IFILE qq/#include "stamp-pdbgen.h"\n\n/;
	print IFILE qq@#include <glib-object.h>\n\n@;
	print IFILE qq@#include "pdb-types.h"\n\n@;
	print IFILE qq@#include "gimppdb.h"\n\n@;
	print IFILE qq@#include "internal-procs.h"\n\n@;
	chop $group_procs;
	print IFILE "\n/* $total procedures registered total */\n\n";
	print IFILE <<BODY;
void
internal_procs_init (GimpPDB *pdb)
{
  g_return_if_fail (GIMP_IS_PDB (pdb));

$group_procs
}
BODY
	close IFILE;
	&write_file($internal, $destdir);
    }
}

1;
