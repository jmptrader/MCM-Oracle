function move(fbox, tbox) {
     var arrFbox = new Array();
     var arrTbox = new Array();
     var arrLookup = new Array();
     var i;
     for(i=0; i<tbox.options.length; i++) {
         arrLookup[tbox.options[i].text] = tbox.options[i].value;
         arrTbox[i] = tbox.options[i].text;
     }
     var fLength = 0;
     var tLength = arrTbox.length
     for(i=0; i<fbox.options.length; i++) {
         arrLookup[fbox.options[i].text] = fbox.options[i].value;
         if(fbox.options[i].selected && fbox.options[i].value != "") {
              arrTbox[tLength] = fbox.options[i].text;
              tLength++;
         } else {
              arrFbox[fLength] = fbox.options[i].text;
              fLength++;
         }
     }
     arrFbox.sort();
     arrTbox.sort();
     fbox.length = 0;
     tbox.length = 0;
     for(i=0; i<arrFbox.length; i++) {
         var option = new Option();
         option.value = arrLookup[arrFbox[i]];
         option.text = arrFbox[i];
         fbox[i] = option;
     }
     for(i=0; i<arrTbox.length; i++) {
         var option = new Option();
         option.value = arrLookup[arrTbox[i]];
         option.text = arrTbox[i];
         tbox[i] = option;
     }
}

function selectAll(box) {
     for(var i=0; i<box.length; i++) {
         box[i].selected = true;
     }
}
