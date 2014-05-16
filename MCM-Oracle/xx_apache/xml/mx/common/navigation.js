var timeout	= 500;
var closetimer	= 0;
var ddmenuitem	= 0;

// open hidden layer
function mopen(id)
{	
	// cancel close timer
	mcancelclosetime();

	// close old layer
	if(ddmenuitem) ddmenuitem.style.visibility = 'hidden';

	// get new layer and show it
	ddmenuitem = document.getElementById(id);
	ddmenuitem.style.visibility = 'visible';

}
// close showed layer
function mclose()
{
	if(ddmenuitem) ddmenuitem.style.visibility = 'hidden';
}

// go close timer
function mclosetime()
{
	closetimer = window.setTimeout(mclose, timeout);
}

// cancel close timer
function mcancelclosetime()
{
	if(closetimer)
	{
		window.clearTimeout(closetimer);
		closetimer = null;
	}
}

function mnavigate( url, args, nav_args ) {
        $('#tiptip_holder').css( 'display', 'none' );
        $('#result_processing2').css( 'visibility', 'visible' );
        var params = $.extend( {}, nav_args, args, { body_only: 1 } );
        $.post(url, params, function(data){ $('#body_content').html( data ); $('#result_processing2').css( 'visibility', 'hidden' ); });
        return false;
}

function mgoback( url, nav_args ) {
        $('#tiptip_holder').css( 'display', 'none' );
        $('#result_processing2').css( 'visibility', 'visible' );
        var params = $.extend( {}, nav_args, { body_only: 1 } );
        $.post(url, params, function(data){ $('#body_content').html( data ); $('#result_processing2').css( 'visibility', 'hidden' ); });
        return false;
}

function msubmit( form, url, args ) {
        $('#tiptip_holder').css( 'display', 'none' );
        $('#result_processing2').css( 'visibility', 'visible' );
        var inputs = $(form).serializeArray();
        var params = inputs.concat( [ { name: 'body_only', value: 1 } ], args );
        $.post(url, params, function(data){ $('#body_content').html( data ); $('#result_processing2').css( 'visibility', 'hidden' ); });
        return false;
}

// close layer when click-out
document.onclick = mclose; 

