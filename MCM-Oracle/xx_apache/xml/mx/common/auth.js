function checkRights( fnCallback ) {
  var rights = [];
  $('*[right]').each( function(i) {
    rights[i] = $(this).attr('right');
  } );
  rights = $.unique( rights );

  var rights_enc = rights.join(',');

  var d = new Date();
  var request = $.ajax({
    type: 'POST',
    url: '/mx-auth/right_check.html',
    cache: false,
    data: { _: d.getTime(), names: rights_enc },
    dataType: 'json',
    error: function( jqXHR, textStatus, errorThrown ) {
      alert( textStatus + ': ' + errorThrown );
    }
  });

  request.done( function( data ) {
    var rights = Object.keys( data );

    for ( var i = 0; i < rights.length; i++ ) {
      var right = rights[i];

      if ( data[right] == 1 ) {
        $('*[right="' + right + '"]').prop('disabled', false);
      }
      else {
        $('*[right="' + right + '"]').attr('disabled', 'disabled');
        $('a[right="' + right + '"]').removeAttr('onclick');
        $('a[right="' + right + '"]').click( function(event) { return false; } );
      }
    }

    $("#contextmenu a[disabled='disabled']").each( function() {
      $("#contextmenu").disableContextMenuItems($(this).attr("href"));
    } );

    typeof fnCallback === 'function' && fnCallback();
  });
}
