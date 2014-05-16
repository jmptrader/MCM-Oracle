$.fn.dataTableExt.oApi.fnReloadAjax = function ( oSettings, sNewSource, fnCallback, bStandingRedraw )
{
    if ( typeof sNewSource != 'undefined' && sNewSource != null )
    {
        oSettings.sAjaxSource = sNewSource;
    }
    this.oApi._fnProcessingDisplay( oSettings, true );
    var that = this;
    var iStart = oSettings._iDisplayStart;
    var aData = [];
 
    this.oApi._fnServerParams( oSettings, aData );
     
    oSettings.fnServerData( oSettings.sAjaxSource, aData, function(json) {
        /* Clear the old information from the table */
        that.oApi._fnClearTable( oSettings );
         
        /* Got the data - add it to the table */
        var aData =  (oSettings.sAjaxDataProp !== "") ?
            that.oApi._fnGetObjectDataFn( oSettings.sAjaxDataProp )( json ) : json;
         
        for ( var i=0 ; i<aData.length ; i++ )
        {
            that.oApi._fnAddData( oSettings, aData[i] );
        }
         
        oSettings.aiDisplay = oSettings.aiDisplayMaster.slice();
        that.fnDraw();
         
        if ( typeof bStandingRedraw != 'undefined' && bStandingRedraw === true )
        {
            oSettings._iDisplayStart = iStart;
            that.fnDraw( false );
        }
         
        that.oApi._fnProcessingDisplay( oSettings, false );
         
        /* Callback user function - for event handlers etc */
        if ( typeof fnCallback == 'function' && fnCallback != null )
        {
            fnCallback( oSettings );
        }
    }, oSettings );
}

$.fn.dataTableExt.oApi.fnStandingRedraw = function(oSettings) {
    if(oSettings.oFeatures.bServerSide === false){
        var before = oSettings._iDisplayStart;
 
        oSettings.oApi._fnReDraw(oSettings);
 
        // iDisplayStart has been reset to zero - so lets change it back
        oSettings._iDisplayStart = before;
        oSettings.oApi._fnCalculateEnd(oSettings);
    }
  
    // draw the 'current' page
    oSettings.oApi._fnDraw(oSettings);
};

$.fn.dataTableExt.oSort['formatted-num-asc'] = function(a,b) {
    if ( a == "" ) {
        return 1;
    }
    if ( b == "" ) {
        return -1;
    }

    /* Remove any formatting */
    var x = a.match(/\d/) ? a.replace( /[^\d\-\.]/g, "" ) : 0;
    var y = b.match(/\d/) ? b.replace( /[^\d\-\.]/g, "" ) : 0;
      
    /* Parse and return */
    return parseFloat(x) - parseFloat(y);
};
  
$.fn.dataTableExt.oSort['formatted-num-desc'] = function(a,b) {
    if ( a == "" ) {
        return 1;
    }
    if ( b == "" ) {
        return -1;
    }

    var x = a.match(/\d/) ? a.replace( /[^\d\-\.]/g, "" ) : 0;
    var y = b.match(/\d/) ? b.replace( /[^\d\-\.]/g, "" ) : 0;
      
    return parseFloat(y) - parseFloat(x);
};

$.fn.dataTableExt.oSort['num-html-asc']  = function(a,b) {
    var x = a.replace( /<.*?>/g, "" );
    var y = b.replace( /<.*?>/g, "" );
    x = parseFloat( x );
    y = parseFloat( y );
    return ((x < y) ? -1 : ((x > y) ?  1 : 0));
};
 
$.fn.dataTableExt.oSort['num-html-desc'] = function(a,b) {
    var x = a.replace( /<.*?>/g, "" );
    var y = b.replace( /<.*?>/g, "" );
    x = parseFloat( x );
    y = parseFloat( y );
    return ((x < y) ?  1 : ((x > y) ? -1 : 0));
};

$.fn.dataTableExt.oSort['alt-string-asc'] = function(a,b) {
    var x = a.match(/alt="(.*?)"/)[1].toLowerCase();
    var y = b.match(/alt="(.*?)"/)[1].toLowerCase();
    return ((x < y) ? -1 : ((x > y) ? 1 : 0));
};

$.fn.dataTableExt.oSort['alt-string-desc'] = function(a,b) {
    var x = a.match(/alt="(.*?)"/)[1].toLowerCase();
    var y = b.match(/alt="(.*?)"/)[1].toLowerCase();
    return ((x < y) ? 1 : ((x > y) ? -1 : 0));
};

function heatMapColor( field, value, maxvalue ) {
    /* starting color  */
    var xr = 255; var xg = 255; var xb = 204;
    /* ending color  */
    var yr = 255; var yg = 0; var yb = 0;

    if ( value == '' ) {
        var color = 'rgb('+xr+','+xg+','+xb+')';
        $(field).css( 'background-color', color );
        return;
    }

    /* number of levels */
    var nlevels = 100;

    value = value.replace(/,/g, '');
    var number = parseFloat( value );

    maxvalue = maxvalue.replace(/,/g, '');
    var maxnumber = parseFloat( maxvalue );

    if ( number > maxnumber ) {
        number = maxnumber;
    }

    var pos = parseInt( (Math.round( (number/maxnumber)*100 )).toFixed(0) );
    
    red   = parseInt( (xr + (( pos * (yr - xr)) / nlevels)).toFixed(0) );
    green = parseInt( (xg + (( pos * (yg - xg)) / nlevels)).toFixed(0) );
    blue  = parseInt( (xb + (( pos * (yb - xb)) / nlevels)).toFixed(0) );

    var color = 'rgb('+red+','+green+','+blue+')';

    $(field).css( 'background-color', color );
}

function heatMapColor2( field, pos ) {
    if ( pos < 0 || pos == 0  ) {
        return;
    }

    if ( pos == 'FAIL' ) {
        $(field).css( 'background-color', '#5970B2' );
        $(field).css( 'color', '#FFFFFF' );
        $(field).css( 'text-align', 'center' );
        return;
    };

    /* starting color  */
    var xr = 255; var xg = 255; var xb = 204;
    /* ending color  */
    var yr = 255; var yg = 0; var yb = 0;

    /* number of levels */
    var nlevels = 100;
    
    red   = parseInt( (xr + (( pos * (yr - xr)) / nlevels)).toFixed(0) );
    green = parseInt( (xg + (( pos * (yg - xg)) / nlevels)).toFixed(0) );
    blue  = parseInt( (xb + (( pos * (yb - xb)) / nlevels)).toFixed(0) );

    var color = 'rgb('+red+','+green+','+blue+')';

    $(field).css( 'background-color', color );
}

function installHover() {
    $('#result tbody tr').live( 'mouseenter',
        function() {
            $(this).contents('td').css({'border': '1px solid black', 'border-left': '1px solid transparent', 'border-right': '1px solid transparent'});
            $(this).contents('td:first').css('border-left', '1px solid black');
            $(this).contents('td:last').css('border-right', '1px solid black');
        }
    ).live( 'mouseleave',
        function() {
            $(this).contents('td').css('border', '1px solid transparent');
        }
    );
}

function detectBrowser() {
var browserName  = navigator.appName;
  if (browserName=="Microsoft Internet Explorer") {
	var oldloc = document.URL;
	var newloc = oldloc.substring(0, oldloc.length-6) + ".html";
	window.location.replace(newloc);
  }
}
