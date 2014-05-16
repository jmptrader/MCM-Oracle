package Mx::Mason::HTML;

use strict;
use warnings;

use URI::Escape;

my $alert_style = ' style="background-color: #FF9900;"';

#------#
sub td {
#------#
    my ( $class, %args ) = @_;


    my $output = '';

    my $column     = $args{column};
    my $result     = $args{result};
    my $nav_args   = $args{nav_args} || '';

    return unless $column->{visible};

    my $type     = $column->{type};
    my $index    = $column->{index};

    my $value = $result->[$index];

    unless ( defined $value ) {
        return '<td>&nbsp;</td>';
    }

    my $title;
    if ( my $tip = $column->{tip} ) {
        my @tips = ( ref( $tip ) eq 'ARRAY' ) ? @{$tip} : ( $tip );

        foreach my $name ( @tips ) {
            my $label = $HTML::Mason::Commands::columns{$name}->{label};
            my $index = $HTML::Mason::Commands::columns{$name}->{index};
            my $value = $result->[$index];

            $title .= "$label: $value<br>";
        }
    }

    #
    # string
    #
    if ( $type eq 'string' ) {
        $output = '<td>' . $value . '</td>';
    }
    #
    # timestamp
    #
    elsif (  $type eq 'timestamp' ) {
        return '<td>&nbsp;</td>' unless $value;
        $output = '<td>' . Mx::Util->convert_time( $value ) . '</td>';
    }
    #
    # count
    #
    elsif ( $type eq 'count' ) {
        my $style = '';
        if ( my $threshold = $column->{threshold} ) {
            $style = ( $value >= $threshold ) ? $alert_style : '';
        }
        
        $output = '<td align="right"' . $style . '>' . Mx::Util->separate_thousands( $value ) . '</td>';
    }
    #
    # bytes
    #
    elsif ( $type eq 'bytes' ) {
        $output = '<td align="right">' . Mx::Util->convert_bytes( $value ) . '</td>';
    }
    #
    # kbytes
    #
    elsif ( $type eq 'kbytes' ) {
        $output = '<td align="right">' . Mx::Util->convert_bytes( $value * 1024 ) . '</td>';
    }
    #
    # seconds
    #
    elsif ( $type eq 'seconds' ) {
        $output = '<td>' . scalar( Mx::Util->convert_seconds( $value ) ) . '</td>';
    }
    #
    # exitcode
    #
    elsif ( $type eq 'exitcode' ) {
        if ( $value == 0 ) {
            $output = '<td>0</td>';
        }
        else {
            $output = '<td' . $alert_style . '>' . $value . '</td>';
        }
    }
    #
    # id
    #
    elsif ( $type eq 'id' ) {
        if ( $value ) {
            my $ajax_url = $column->{ajax_url};
            my $url = $column->{url};
            $url =~ s/__id__/$value/g;
            my $args = $column->{args};
            $args =~ s/__id__/$value/g;
            if ( $args ) {
                $args .= ',' . $nav_args;
            }
            else {
                $args = $nav_args;
            }

            if ( $ajax_url ) {
                $output  = '<td><a class="';
                $output .= ( $title ) ? 'tiptip' : 'select';
                $output .= '" href="#" onclick="$(\'#dummytrigger\').attr(\'object_id\',';
                $output .= $value;
                $output .= ');$(\'#dummytrigger\').attr(\'url\',\'';
                $output .= $ajax_url;
                $output .= '\');$(\'#modalWindow\').jqmShow();"';
                if ( $title ) {
                    $output .= ' title="' . $title . '"';
                }
                $output .= '>';
                $output .= $value;
                $output .= '</a></td>';
            }
            elsif ( $url ) {
                $output  = '<td><a class="';
                $output .= ( $title ) ? 'tiptip' : 'select';
                $output .= '" href="#" onclick="mnavigate(\'';
                $output .= $url;
                $output .= '\', {';
                $output .= $args;
                $output .= '})"';
                if ( $title ) {
                    $output .= ' title="' . $title . '"';
                }
                $output .= '>';
                $output .= $value;
                $output .= '</a></td>';
            }
        }
        else {
            $output = '<td>&nbsp;</td>';
        }
    }
    #
    # win_user
    #
    elsif ( $type eq 'win_user' ) {
        if ( my $full_name = $HTML::Mason::Commands::full_names{ $value } ) {
            my $args = "name:'" . $value . "'," . $nav_args;
            $output = '<td><a class="tiptip" href="#" onclick="mnavigate(\'/mx-auth/user_details.html\', {' . $args . '})" title="' . $value . '">' . $full_name . '</a></td>'; 
        }
        else {
            $output = '<td>' . $value . '</td>';
        } 
    }
    #
    # hostname
    #
    elsif ( $type eq 'hostname' ) {
        if ( substr( $value, 0, 1 ) ne 's' && ( my $username = $HTML::Mason::Commands::client_map{ $value } ) ) {
            $output = '<td><a class="tiptip" href="#" title="' . $username .'">' . $value . '</a></td>';
        }
        else {
            $output = '<td>' . $value . '</td>';
        } 
    }
    #
    # boolean
    #
    elsif ( $type eq 'boolean' ) {
        if ( $value =~ /^y(es)?$/i ) {
            my $style = ( $column->{alert_on_true} ) ? $alert_style : '';
            $output = '<td' . $style . '>YES</td>';
        }
        else {
            my $style = ( $column->{alert_on_false} ) ? $alert_style : '';
            $output = '<td' . $style . '>NO</td>';
        }
    }
    #
    # table
    #
    elsif ( $type eq 'table' ) {
        my $url  = 'display_table.html';
        my $args = "table:'$value'";
        $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $value . '</a></td>';
    }
    #
    # report
    #
    elsif ( $type eq 'report' ) {
        my $url  = 'display_report.html';
        my $args = "path:'$value'";
        $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $value . '</a></td>';
    }
    #
    # xml_file
    #
    elsif ( $type eq 'xml_file' ) {
        my $url  = 'display_xml.html';
        my $args = "path:'$value'";
        $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $value . '</a></td>';
    }
    #
    # array
    #
    elsif ( $type eq 'array' ) {
        $output = '<td>';
        $output .= join ',', @{$value};
        $output .= '</td>';
    }
    #
    # link
    #
    elsif ( $type eq 'link' ) {
        if ( $value ) {
            my $url = $column->{url};
            $url =~ s/__value__/uri_escape( $value )/ge;

            my $url_label = $column->{url_label};
            $url_label =~ s/__value__/$value/g;

            $output = '<td><a class="select" href="' . $url . '">' . $url_label . '</a></td>';
        }
        else {
            $output = '<td>&nbsp;</td>';
        }
    }

    return $output;
}

#--------------#
sub td_details {
#--------------#
    my ( $class, %args ) = @_;


    my $output = '';

    my $column   = $args{column};
    my $result   = $args{result};
    my $nav_args = $args{nav_args} || '';

    my $type   = $column->{type};
    my $index  = $column->{index};

    my $value = $result->[--$index];

    unless ( defined $value ) {
        return '<td>&nbsp;</td>';
    }

    #
    # string
    #
    if ( $type eq 'string' ) {
        $output = '<td>' . $value . '</td>';
    }
    #
    # timestamp
    #
    elsif (  $type eq 'timestamp' ) {
        return '<td>&nbsp;</td>' unless $value;
        $output = '<td>' . Mx::Util->convert_time( $value ) . '</td>';
    }
    #
    # count
    #
    elsif ( $type eq 'count' ) {
        $output = '<td>' . Mx::Util->separate_thousands( $value ) . '</td>';
    }
    #
    # bytes
    #
    elsif ( $type eq 'bytes' ) {
        $output = '<td>' . Mx::Util->convert_bytes( $value ) . '</td>';
    }
    #
    # kbytes
    #
    elsif ( $type eq 'kbytes' ) {
        $output = '<td>' . Mx::Util->convert_bytes( $value * 1024 ) . '</td>';
    }
    #
    # seconds
    #
    elsif ( $type eq 'seconds' ) {
        $output = '<td>' . scalar( Mx::Util->convert_seconds( $value ) ) . '</td>';
    }
    #
    # exitcode
    #
    elsif ( $type eq 'exitcode' ) {
        $output = '<td>' . $value . '</td>';
    }
    #
    # id
    #
    elsif ( $type eq 'id' ) {
        if ( $value ) {
            my $url = $column->{url};
            $url =~ s/__id__/$value/g;
            my $args = $column->{args};
            $args =~ s/__id__/$value/g;
            if ( $args ) {
                $args .= ',' . $nav_args;
            }
            else {
                $args = $nav_args;
            }

            $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '})">' . $value . '</a></td>'; 
        }
        else {
            $output = '<td>&nbsp;</td>';
        }
    }
    #
    # win_user
    #
    elsif ( $type eq 'win_user' ) {
        if ( my $full_name = $HTML::Mason::Commands::full_names{ $value } ) {
            my $args = "name:'" . $value . "'," . $nav_args;
            $output = '<td><a class="tiptip" href="#" onclick="mnavigate(\'/mx-auth/user_details.html\', {' . $args . '})" title="' . $value . '">' . $full_name . '</a></td>'; 
        }
        else {
            $output = '<td>' . $value . '</td>';
        } 
    }
    #
    # hostname
    #
    elsif ( $type eq 'hostname' ) {
        if ( substr( $value, 0, 1 ) ne 's' && ( my $username = $HTML::Mason::Commands::client_map{ $value } ) ) {
            $output = '<td><a class="tiptip" href="#" title="' . $username .'">' . $value . '</a></td>';
        }
        else {
            $output = '<td>' . $value . '</td>';
        } 
    }
    #
    # boolean
    #
    elsif ( $type eq 'boolean' ) {
        if ( $value =~ /^y(es)?$/i ) {
            my $style = ( $column->{alert_on_true} ) ? $alert_style : '';
            $output = '<td' . $style . '>YES</td>';
        }
        else {
            my $style = ( $column->{alert_on_false} ) ? $alert_style : '';
            $output = '<td' . $style . '>NO</td>';
        }
    }
    #
    # table
    #
    elsif ( $type eq 'table' ) {
        my $url  = 'display_table.html';
        my $args = "table:'$value'";
        $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $value . '</a></td>';
    }
    #
    # report
    #
    elsif ( $type eq 'report' ) {
        my $url  = 'display_report.html';
        my $args = "path:'$value'";
        $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $value . '</a></td>';
    }
    #
    # xml_file
    #
    elsif ( $type eq 'xml_file' ) {
        my $url  = 'display_xml.html';
        my $args = "path:'$value'";
        $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $value . '</a></td>';
    }
    #
    # array
    #
    elsif ( $type eq 'array' ) {
        $output = '<td>';
        $output .= join '<br>', @{$value};
        $output .= '</td>';
    }
    #
    # link
    #
    elsif ( $type eq 'link' ) {
        if ( $value ) {
            my $url  = $column->{url};
            my $args = $column->{args};
            $args =~ s/__value__/$value/g;

            my $url_label = $column->{url_label};
            $url_label =~ s/__value__/$value/g;

            $output = '<td><a class="select" href="#" onclick="mnavigate(\'' . $url . '\', {' . $args . '},{' . $nav_args . '})">' . $url_label . '</a></td>';
        }
        else {
            $output = '<td>&nbsp;</td>';
        }
    }

    return $output;
}

#------#
sub th {
#------#
    my ( $class, %args ) = @_;


    my $output = '';

    my $object  = $args{object};
    my $column  = $args{column};
    my $url     = $args{url};
    my $filter  = $args{filter};
    my $sort    = $args{sort};
    my $reverse = $args{reverse};

    return unless $column->{visible};

    my $name  = $column->{name};
    my $label = $column->{label};

    $output  = "\n" . '<form id="form_th_' . $name . '" onsubmit="return msubmit(this,\'' . $url . '\')">' . "\n";
    $output .= '<input type=hidden name="object" value="' . $object . '">' . "\n";
    $output .= '<input type=hidden name="sort" value="' . $name . '">' . "\n";
    $output .= '<input type=hidden name="reverse" value="1">' . "\n";

    foreach my $entry ( @{$filter} ) {
        my ( $key, $value ) = split /=/, $entry;
        $output .= '<input type=hidden name="' . $key . '" value="' . $value . '">' . "\n";
    }

    if ( $sort eq $name ) {
        $output .= '<th><a href="#" onclick="$(\'#form_th_' . $name . '\').trigger(\'onsubmit\')" style="color: #FFCC33;">' .  $label . '</a></th>';
    }
    else {
        $output .= '<th><a href="#" onclick="$(\'#form_th_' . $name . '\').trigger(\'onsubmit\')" style="color: #FFFFFF;">' .  $label . '</a></th>';
    }

    $output .= '</form>' . "\n";

    return $output;
}

#-------------#
sub tr_search {
#-------------#
    my ( $class, %args ) = @_;


    my $output = '';

    my $column     = $args{column};
    my $table_name = $args{table_name};
    my $db_audit   = $args{db_audit};

    return unless $column->{stype};

    my $name        = $column->{name};
    my $description = $column->{desc};
    my $type        = $column->{type};
    my $stype       = $column->{stype};
    my $slength     = $column->{slength};


    $output = '<tr><td class="description" style="color: #FFFFFF;">' . $description . '&nbsp;</td>' . "\n";

    if ( $stype eq 'free' ) {
        $output .= '<td><input class="selectize_rw" placeholder="Input ' . $description . '" type="text" name="' . $name . '" size=' . $slength . ' maxlength=' . $slength . '></td></tr>' . "\n";
    }
    elsif ( $stype eq 'list' ) {
        my @values = $db_audit->get_distinct_values( column => $name, table => $table_name );
        return unless @values;

        $output .= '<td><select multiple class="selectize_ro" placeholder="Choose ' . $description . '" name="' . $name . '">' . "\n";
        $output .= '<option></option>' . "\n";


        if ( $type eq 'win_user' ) {
            foreach my $value ( sort @values ) {
                if ( my $full_name = $HTML::Mason::Commands::full_names{ $value } ) {
                    $output .= '<option value="' . $value . '">' . $value . ' (' . $full_name . ')</option>' . "\n";
                }
                else {
                    $output .= '<option>' . $value . '</option>' . "\n";
                }
            }
        }
        else {
            foreach my $value ( sort @values ) {
                $output .= '<option>' . $value . '</option>' . "\n";
            }
        }

        $output .= '</select></td></tr>' . "\n";
    }

    return $output;
}

1;
