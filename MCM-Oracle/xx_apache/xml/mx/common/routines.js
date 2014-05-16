//#################################################
//#                                               #
//# File: routines.js                             #
//# Author: Mario Truyens (NEOlabs)               #
//# Date: 31/12/02                                #
//# Version: 1.0                                  #
//#                                               #
//#################################################


function AddNewOption(component, name, description) {
	var string = prompt("Specify new " + description + ":", "");
	if (! string) return false;
	var option = new Option(string, string, true, true);
	var options = component.elements[name].options;
	options[options.length] = option;
	return true;
}

function GetId(string) {
	var pattern = /_id=(\d+)/;
	var result = string.match(pattern);
	if (result != null) {
		return result[1];
	}
}

function IsChecked(member, id) {
	var options = self.opener.document.forms[0].elements[member].options;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];
		if (GetId(option.value) == id) {
			return option.selected;
		}
	}
	return false;
}

function AlterCheckbox(component, member, id) {
	var options = self.opener.document.forms[0].elements[member].options;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (GetId(option.value) == id) {
			option.selected = component.checked;
			return true;
		}
	}
}

function GetCrosstableField(member, id, field) {
	var pattern = new RegExp("&" + field + "=([^&]*)");
	var options = self.opener.document.forms[0].elements[member].options;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (GetId(option.value) == id) {
			var result =  option.value.match(pattern);
			if (result != null) {
				return result[1];
			}
		}
	}
}

function GetCrosstableFields(member, id) {
	var results = new Array();
	var options = self.opener.document.forms[0].elements[member].options;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (GetId(option.value) == id) {
			for (var j = 2; j < arguments.length; j++) {
				var pattern = new RegExp("&" + arguments[j] + "=([^&]*)");
				var result =  option.value.match(pattern);
				if (result != null) {
					results.push(result[1]);
				} else {
					results.push("");
				}
			}
			break;
		}
	}
	return results;
}

function AlterCrosstableField(component, member, id, field) {
	var pattern = new RegExp("&" + field + "=[^&]*");
	var options = self.opener.document.forms[0].elements[member].options;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (GetId(option.value) == id) {
			option.value = option.value.replace(pattern, "&" + field + "=" + component.value);
			return true;
		}
	}
}

function AlterCrosstableField2(component, member, id, field) {
	var pattern = new RegExp("&" + field + "=[^&]*");
	var options = self.opener.document.forms[0].elements[member].options;
	var value = component.options[component.selectedIndex].value;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (GetId(option.value) == id) {
			option.value = option.value.replace(pattern, "&" + field + "=" + value);
			return true;
		}
	}
}

function AlterCrosstableField3(component, member, id, field) {
	var pattern = new RegExp("&" + field + "=[^&]*");
	var options = self.opener.document.forms[0].elements[member].options;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (GetId(option.value) == id) {
			if (component.checked) {
				option.value = option.value.replace(pattern, "&" + field + "=checked");
			} else {
				option.value = option.value.replace(pattern, "&" + field + "=");
			}
			return true;
		}
	}
}

function GetSelectList(component, name) {
	var options = component.form.elements[name].options;
        var list = new Array;
	for (var i = 0; i < options.length; i++) {
	 	var option = options[i];	
		if (option.selected) {
			var id = GetId(option.value);
			list.push(id);
		}
	}
	return list.join(",");
}

function GetCurrentListValues(component) {
	var list = new Array;
	for (var i = 0; i < component.length; i++) {
		if (component.options[i].selected == true) {
			list[i] = 1;
		} else { 
			list[i] = 0;
		}
	}
	return list;
}

function FillListValues(component, oldlist) {
	var intNewPos = component.selectedIndex;
	if (oldlist[intNewPos] == 1) {
		component.options[intNewPos].selected = false;
	} else {
		component.options[intNewPos].selected = true;
	}
	for (var i = 0; i < oldlist.length; i++) {
		if (i == intNewPos) {
			continue;
		}
		if (oldlist[i] == 1) {
			component.options[i].selected = true;
		} else if (oldlist[i] == 0) {
			component.options[i].selected = false;
		}
	}
}
