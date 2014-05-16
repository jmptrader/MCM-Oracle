function toggleAllCheckboxes(id) {
    var box = document.getElementById(id);
    var setting;
    if (box.checked == true) {
      setting = true;
    }
    else {
      setting = false;
    }
    var cur_id = id + '1'
    var count = 1;
    while ( box = document.getElementById(cur_id) ) {
      box.checked = setting;
      count++;
      cur_id = id + count;
    }
}

function getCheckboxValues(id1, id2) {
    var values = [];
    var cur_id = id1 + 1;
    var box;
    var count = 1;
    while ( box = document.getElementById(cur_id) ) {
      if ( box.checked ) {
        values.push(box.value);
      }
      count++;
      cur_id = id1 + count;
    }
    var list = document.getElementById(id2);
    list.value = values.join(',');
}
