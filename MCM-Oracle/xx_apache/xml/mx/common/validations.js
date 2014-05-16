//#################################################
//#                                               #
//# File: validations.js                          #
//# Author: Mario Truyens (NEOlabs)               #
//# Date: 31/12/02                                #
//# Version: 1.0                                  #
//#                                               #
//#################################################
function schrikkelyear(year) {
	if ((year % 4) == 0) {
		if ((year % 100) == 0) {
			result = ((year % 400) == 0);
          	} else {
            		result = true;
          	}
	} else {
		result = false;
	}
	return result;
}

function TrimZeroes(numstring) {
	while (numstring.charAt(0) == "0") numstring = numstring.substring(1);
	if (numstring == "") numstring = "0";
	return numstring;
}

function CheckIntegerField(field, fieldname, min, max, mandatory) {    
	if ((mandatory == 1) && ((field.value == null) || (field.value == ""))) { 
		alert(fieldname + " is not filled in");
		return false;
	}
	sNo = TrimZeroes(field.value);
	lNo = parseInt(sNo);
	sNewNo = lNo + "";
	if ((field.value != "") && (sNewNo != sNo || lNo > max || lNo < min)) {
		alert(fieldname + " is not a number, is too big or is too small");
		field.value = "";
		return false;
	} else {
		return true;
	}
}

function CheckStringField(field, fieldname, max, mandatory) {
	if ((mandatory == 1) && ((field.value == null) || (field.value == ""))) { 
		alert(fieldname + " is not filled in");
		return false;
	}
	if (field.value.length > max) {
		alert(fieldname + " contains too many characters (max. " + max + ")");
		field.value = field.value.substr(0, max);
		return false;
	} else {
		return true;
	}
}

function CheckDateField(field) {
	dfields = field.value.split('/');
	if (!dfields[0]) dfields[0] = "";
	if (!dfields[1]) dfields[1] = "";
	if (!dfields[2]) dfields[2] = "";
	datefield = dfields[0] + "/" + dfields[1] + "/" + dfields[2];
        if ((dfields[0] == "") || (dfields[1] == "") || (dfields[2] == "")) {
		if ((dfields[0]) || (dfields[1]) || (dfields[2])) {
			alert(datefield + " is not a valid date");
			field.value = "";
			return false
		} else {
			return true;
		}
	} else {
		if (((dfields[2] > 9999) || (dfields[2] < 1900)) || ((dfields[1] > 12) || (dfields[1] < 1)) || ((dfields[0] > 31) || (dfields[0] < 1))) {
			alert(datefield + " not a valid date.");
			return false;
		}
		monthval = parseInt(TrimZeroes(dfields[1]));
		dayval = parseInt(TrimZeroes(dfields[0]));
		yearval = parseInt(TrimZeroes(dfields[2]));
		if ((monthval == 4) || (monthval == 6) || (monthval == 9) || (monthval == 11)) {
			maxday = 30;
		} else if(monthval == 2) {
			if (schrikkelyear(yearval)) maxday = 29;
			else                        maxday = 28;
		} else {
			maxday = 31;
		}
		if(dayval > maxday) {
			alert(datefield + " is not a valid date");
			field = "";
			return false
		} else {
			return true;
		}
	}
}

function CheckMandatoryField(field, fieldname) {
	if (field.value == "") {
		alert(fieldname + " is mandatory !");
		return false;
	} else {
	return true;
	}
}

function CheckExclusiveMandatoryFields(field1, field1name, field2, field2name) {
	if ((field1.value == "") && (field2.value == "")) {
		alert(field1name + " or " + field2name + " is mandatory !");
		return false;
	} else {
		return true;
	}
}

function CheckMandatoryRadio(field, fieldname) {
	checked = false;
	for (i = 0 ;i < field.length ; i++) {
		checked |= field[i].checked;
	}
	if (!checked) {
		alert(fieldname + " is mandatory !");
		return false;
	} else {
		return true;
	}
}

function CheckMandatorySelect(field, fieldname) {
	checked = false;
	for (i = 0; i < field.length; i++) {
		if(!field[i].value == '') checked |= field[i].selected;
	}
	if (!checked) {
		alert(fieldname + " is mandatory !");
		return false;
	} else {
		return true;
	}
}
