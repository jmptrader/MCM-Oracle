function popupWindow(url, target, width, height, scroll, position) {
  if ( position == "random" ) {
    LeftPosition = (screen.width)  ? Math.floor(Math.random() * (screen.width-width))       : 100;
    TopPosition  = (screen.height) ? Math.floor(Math.random() * ((screen.height-height)-75)) : 100;
  }
  else if ( position == "center" ) {
    LeftPosition = (screen.width)  ? (screen.width-width)/2  : 100;
    TopPosition  = (screen.height) ? (screen.height-height)/2 : 100;
  }
  else if ( ( position != "center" && position != "random" ) || position == null ) {
    LeftPosition = 0;
    TopPosition  = 20;
  }

  settings='width=' + width + ',height=' + height + ',top=' + TopPosition + ',left=' + LeftPosition + ',scrollbars=' + scroll + ',location=no,directories=no,status=no,menubar=no,toolbar=no,resizable=yes';

  win=window.open(url, target, settings);
}
