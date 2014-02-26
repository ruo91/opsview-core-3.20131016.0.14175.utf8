/*
 * Opsview forms helper scripts
 *
 * Copyright (C) 2003-2013 Opsview Limited. All rights reserved
 *   This file is part of Opsview
 *
 *   Opsview is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 *   Opsview is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with Opsview; if not, write to the Free Software
 *   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
/*--------------------------------------------------------------------------*/

var ajaxUpdaterFailures = function() { alert(Opsview.Messages.noPermission) };

function dimAll(thisForm, itemName, checked) {
    jQuery(':input', thisForm).each(function(){
        if (this.name == itemName ) {
            this.disabled = checked == 1 ? true : false;
        }
    });
}

function hideIfAllUnchecked(thisForm, boxName, hideName, reversed) {
	var i;
	var hide = true;
    var checked = true;
    if (reversed) {
        checked = false;
    }
    jQuery(':input', thisForm).each(function(){
        if (this.name.match(boxName)) {
            if (this.checked == checked) {
                hide = false;
            }
        }
    });
	if (hide == true) {
		document.getElementById(hideName).style.display="none";
	} else {
		document.getElementById(hideName).style.display="";
	}
}

function convert_lowercase_no_spaces(string, formElement) {
	if (string && ! formElement.value) {
		string = string.replace(/ /g, "");
		string = string.toLowerCase();
		formElement.value = string;
	}
}

function populate_if_text(string, formElement) {
	if (string && ! formElement.value && string.search(/^[\w\.-]+$/)!=-1) {
		formElement.value = string;
	}
}

function isEmpty(aTextField) {
	var str = aTextField.value.replace(/\s/g, "");
	if (str.length == 0) {
		return true;
	} else {
		return false;
	}
}

// This is called only on submission
function onsubmit_form(event) {

    // Don't continue if event already stopped
    if(event.stopped)
        return false;

	/* Any hidden form elements are deleted here and not passed to the server */
	/* However, form elements hidden from a div are fine */
    var thisForm = this;
    jQuery(':input', thisForm).each(function(){
        if (this && this.style && this.style.display == "none" ) {
            this.parentNode.removeChild(this); // This seems like a cack handed way to say "delete me"
        }
    });
}

/* This gets called as part of the validation */
/* TODO: All validations here should be using the validation techniques instead */
function validate_form(validate_result, thisForm) {
	if (! validate_result) {
		return false;
	}

    var options = [ 'parents', 'hosttemplates', 'dependencies' ];
    jQuery.each(options, function(i, options_element) {
        var list = jQuery(':input[name='+ options_element +']', thisForm).get(0);
        if (list && list.length) {
            if (list.options[0].value != "temp") {
                for (i=0; i<list.length; i++) {
                    list.options[i].selected = true;
                }
            } else {
                list.options[0].selected = false;	// just in case is selected
            }
        }
    });
	return true;
}

function chooseboxSelected( choosebox ) {
    if (choosebox.length) {
        if (choosebox.options[0].value != "temp") {
            for (i=0; i<choosebox.length; i++) {
                choosebox.options[i].selected=true;
            }
        } else {
            choosebox.options[0].selected=false; // just in case temp message is selected
        }
    }
}

function setAllOptionsSelected(list) {
	if(list.length) {
		if (list.options[0].value != "temp") {
			for (i=0; i<list.length; i++) {
				list.options[i].selected = true;
			}
		} else {
			list.options[0].selected = false;
		}
	}
}
function removeSelectedFromList(list) {
	/* Must delete backwards */
	for (i=list.options.length-1; i>=0; i--) {
		if (list.options[i].selected) {
			list.options[i] = null;
			return true;
		}
	}
	return false;
}


var strUserAgent = navigator.userAgent.toLowerCase();
var isIE = strUserAgent.indexOf("msie") > -1;
var invalidChars = /[\[\]`~!$%^&*|'"<>?,\:()=]/;
var invalidCharsAllowParenthesis = /[\[\]`~!$%^&*|'"<>?,\:=]/;
var invalidCharsWithSlash = /[\[\]\/`~!$%^&*|'"<>?,\:()=]/;		/* Disallow / for monitoringserver names */
var lessInvalidChars = /[\[\]`~!$%^&*|'"<>?,()=]:/;
var invalidCharsWithSpace = /[\[\]`~!$%^&*|'"<>?,\:()= ]/;	/* For usernames */
var invalidTimeperiodChars = /[\[\]`~!$%^&*|'"<>?()=a-zA-Z ]/;     /* timeperiods */
var invalidCharsIP = /[\[\]`~!$%^&*|'"<>?,()= ]/;
var integer_percent = /[\[\]\/£,.@+:;\\{}_#`~!$^&*|'"<>?()=a-zA-Z ]/; /* whole numbers with a percent sign */
var integer_percent_colon_space_ampersand_bar = /[\[\]\/£,@+;\\{}_#`~!$^*'"<>?()=]/;
var integer = /[\[\]\/£,.@+:;\\{}_#`~!$%^&*|'"<>?()=a-zA-Z ]/; /* whole numbers only */

function blockInvalidKeys(objEvent, chars) {
	var iKeyCode, strKey;
	if (chars == 2) {
		chars = lessInvalidChars;
	} else if (chars == 3) {
		chars = invalidCharsWithSpace;
	} else if (chars == 4) {
		chars = invalidCharsWithSlash;
	} else if (chars == 5) {
		chars = invalidTimeperiodChars;
	} else if (chars == 6) {
		chars = integer_percent;
	} else if (chars == 7) {
		chars = integer;
	} else if (chars == 8) {
		chars = invalidCharsIP;
	} else if (chars == 9) {
		chars = invalidCharsAllowParenthesis;
	} else if (chars == 10) {
		chars = integer_percent_colon_space_ampersand_bar;
	} else {
		chars = invalidChars;
	}
	if (isIE) {
		iKeyCode = objEvent.keyCode;
	} else {
		iKeyCode = objEvent.which;
	}
	strKey = String.fromCharCode(iKeyCode);

	if (chars.test(strKey)) {
		//alert("Invalid character\nKeyCode = " + iKeyCode + "\nCharacter = '"+strKey+"'");
		var text;
		if (strKey == " ") {
			text = "[space]";
		} else if (strKey == "	") {
			text = "[tab]";
		} else {
			text = strKey;
		}
		alert( Opsview.Messages.invalidCharacter + " " + text );
		return false;
	}
}

function blockForKeywords(objEvent) {
	var iKeyCode, strKey;
	//chars = /[a-z0-9_,]/;
	chars = /[\[\]`~!$%^&*|'"<>?\.\:()= ]/;	/* Same as invalidCharsWithSpace, but with comma removed and dot added */
	if (isIE) {
		iKeyCode = objEvent.keyCode;
	} else {
		iKeyCode = objEvent.which;
	}
	strKey = String.fromCharCode(iKeyCode);

	if (chars.test(strKey)) {
		var text;
		if (strKey == " ") {
			alert( Opsview.Messages.useCommaSeparateKeywords );
		} else {
			text = strKey;
			alert( Opsview.Messages.invalidCharacter + " " +text );
		}
		return false;
	}
}

function blockEnter(objEvent) {
	var key;
	if (isIE) {
		key = objEvent.keyCode;
	} else {
		key = objEvent.which;
	}
	if (key == "13") {
		return false;
	}
}

/* Need to go through twice, setting the relevant ones first, then ignoring if already set.
   Required for divs that are common between two different options.
   Also disables all input/select/textarea tags within the divs */
function showIfCheckedRadioGroup(thisForm, boxName, options) {
	var radios = Form.getInputs(thisForm, "radio", boxName);
	var seen = {};
	radios.each( function(button) {
		if (button.checked == true) {
			var div_names = options[button.value];
			if (! div_names) { return };
			div_names.each(
				function(t) {
					$(t).style.display="";
					seen[t] = 1;
					$A($(t).getElementsByTagName('*')).each(
						function(element) { if (['input', 'select', 'textarea'].include(element.tagName.toLowerCase())) { element.disabled=''; } }
					);
				}
			);
		} });
	radios.each( function (button) {
		if (button.checked == false) {
			var div_names = options[button.value];
			if (! div_names) { return };
			div_names.each(
				function(t) {
					if (! seen[t]) {
						$(t).style.display="none";
						$A($(t).getElementsByTagName('*')).each(
							function(element) { if (['input', 'select', 'textarea'].include(element.tagName.toLowerCase())) { element.disabled=true; } }
						);
					}
				}
			);
		} });
}

/* Used for copying between two different select boxes */
/* Routine from http://www.quirksmode.org/js/transfer.html */
function copyToList(fromList, toList, forceRemove) {
	if (toList.options.length > 0 && toList.options[0].value == "temp") {
		toList.options.length = 0;
	}
	for (i=0; i<fromList.options.length; i++) {
		var current = fromList.options[i];
		if (current.selected) {
			if (current.value == "temp") {
				alert( Opsview.Messages.cannotMoveOption );
				return;
			}
			alreadyInToList=0;
			for (j=0; j<toList.options.length; j++) {
				if (toList.options[j].value == current.value) {
					alreadyInToList=1;
					current.selected = false;
				}
			}
			if (alreadyInToList == 0) {
				toList.options[toList.length] = new Option(current.text, current.value);
				fromList.options[i] = null;
				i--;
			} else if (forceRemove) {
				fromList.options[i] = null;
				i--;
			}
		}
	}
}
/* Adds a given name into toList */
function addToList(thisValue, toList) {
	if (thisValue == "") { return }
	if (toList.options.length > 0 && toList.options[0].value == "temp") {
		toList.options.length = 0;
	}
	alreadyInToList=0;
	for (j=0; j<toList.options.length; j++) {
		if (toList.options[j].value == thisValue) {
			alreadyInToList=1;
		}
	}
	if (alreadyInToList == 0) {
		toList.options[toList.length] = new Option(thisValue, thisValue);
	}
}
function selectAll(list) {
	for (i=0; i<list.length; i++) {
		list.options[i].selected = true;
	}
}

/* Moves all selected items up one space */
/* Inspired from http://www.javascripttoolbox.com/lib/selectbox/source.php */
function moveOptionUp(selectbox) {
	for (i=0; i<selectbox.options.length; i++) {
		if (selectbox.options[i].selected) {
			if (i>0 && !selectbox.options[i-1].selected) {
				swapOptions(selectbox, i, i-1);
			}
		}
	}
}
function moveOptionDown(obj) {
	for (i=obj.options.length-1; i>=0; i--) {
		if (obj.options[i].selected) {
			if (i != (obj.options.length-1) && ! obj.options[i+1].selected) {
				swapOptions(obj, i, i+1);
			}
		}
	}
	return true;
}
function swapOptions(obj, i, j) {
	var o = obj.options;
	var i_selected = o[i].selected;
	var j_selected = o[j].selected;
	var temp = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
	var temp2 = new Option(o[j].text, o[j].value, o[j].defaultSelected, o[j].selected);
	o[i] = temp2;
	o[j] = temp;
	o[i].selected = j_selected;
	o[j].selected = i_selected;
	return true;
}

function firstSelectedOption(obj, obj2) {
	for (i=0; i<obj.options.length; i++) {
		var opt = obj.options[i];
		if (opt.selected) { return opt; }
	}
	if (! obj2) { return false; }
	for (i=0; i<obj2.options.length; i++) {
		var opt = obj2.options[i];
		if (opt.selected) { return opt; }
	}
	return false;
}

function setOptionsFor(id, list) {
	select = $(id);
	select.options.length = 0;
	var nodes = $A(list);
	nodes.each( function(n, i) {
		select.options[i] = new Option(n.name, n.value);
		} );
}

function copyTextToList(textinput, list) {
	if (! textinput.value) return false;
	alreadyInList=0;
	for (j=0; j<list.options.length; j++) {
		if (list.options[j].value == textinput.value) {
			alreadyInList = 1;
		}
	}
	if (alreadyInList == 0) {
		list.options[list.length] = new Option(textinput.value, textinput.value);
	}
}

/* Used for updating contents of a choosebox, for example if filtering */
function updateChooseboxList(base_url, choosebox_id, filter_elements_class) {
    if (! choosebox_id || ! filter_elements_class)
        return;
    var indicator = choosebox_id + "_indicator";
    var choosebox_full = choosebox_id + "_full";
    var elements = $$("." + filter_elements_class);
    var result = $A([]);
    /* We pick everything in the selected choosebox with this */
    elements.each( function(e) {
        if(e.tagName == "INPUT") {
            result.push(e.name+"="+(e.checked?1:0));
        } else if(e.tagName == "SELECT") {
            for (i=0; i<e.length; i++) {
                result.push(e.id+"="+e.options[i].value);
            }
        }
    });
    var params = result.join("&");
    Element.show(indicator);
    new Ajax.Request(
        base_url+'/ajax_'+choosebox_id+'?'+params,
        { method:"get",
            onSuccess: function(t) {
                var json=t.responseText.evalJSON(true);
                setOptionsFor(choosebox_full, json.ResultSet.Results);
                Element.hide(indicator);
            }
        } );
}

function check_unique_field(url, element, old_value) {
	if (old_value == "" || old_value.toLowerCase() != element.value.toLowerCase()) {
	  var indicator = $(element.name + "_indicator");
	  if (indicator) Element.show(indicator);
	  var reply = new Ajax.Request( url, {
                        method:'post',
			postBody:element.name+'='+element.value,
	   		asynchronous: false
			} );
	  if (indicator) Element.hide(indicator);
	  if (reply.transport.responseText.evalJSON().ResultSet == 0)
	  	return false;
	  else
		return true;
	} else {
		return true;
	}
}

/* Checks that field entered is a valid duration. Will also display normalised value if different from entered */
function normalise_duration(url, element) {
    var indicator = $(element.name + "_indicator");
    if (indicator) Element.show(indicator);
    var reply = new Ajax.Request( url, {
                        method:'post',
			postBody:'q='+element.value,
	   		asynchronous: false
			} );
	if (indicator) Element.hide(indicator);
	if (reply.transport.status != 200) return false;
    var response = reply.transport.responseText.evalJSON().ResultSet;
    if (! response) return false;
    var info = $(element.name + "_info");
    if (response.error) {
        if (info) info.innerHTML = "";
        return false;
    }
    if (info) {
        if (response.normalised_duration != element.value) {
            info.innerHTML = "= "+ response.normalised_duration;
        } else {
            info.innerHTML = "";
        }
    }
    return true;
}

function check_datetime_field(url, element, old_value) {
	if (old_value == "" || old_value != element.value) {
	  var indicator = $(element.name + "_indicator");
	  if (indicator) Element.show(indicator);
	  var reply = new Ajax.Request( url, {
                        method:'post',
			postBody:element.name+'='+element.value,
	   		asynchronous: false
			} );
	  if (indicator) Element.hide(indicator);
	  if (reply.transport.responseText.evalJSON().ResultSet == 0)
	  	return false;
	  else
		return true;
	} else {
		return true;
	}
}

function toggle_section(name) {
	var el = $(name);
	if (el) {
		if (el.style.display != "none") {
			new Effect.BlindUp(name);
		} else {
			new Effect.BlindDown(name);
		}
	}
	return false;
}

/* Assumes there's an item with id action_name_info and action_name_indicator, and an action at /admin/ajax/action_name */
/* Expects an url to the location of the action */
function run_ajax_action_url(url,action_name, element) {
	if (! element.value) { alert( Opsview.Messages.missingInformation ); return false; }
	if (element.hasClassName("validation-failed")) { alert( Opsview.Messages.fixValidationErrors); return false }
	Element.show(action_name+'_indicator');
	new Ajax.Updater({success:action_name+'_info'}, url+"/"+action_name, { method:"post", parameters:Form.Element.serialize(element), onComplete:function() { Element.hide(action_name+"_indicator")}, onFailure:ajaxUpdaterFailures } );
}


/* This changes the state of the div and then enables/disables all elements within the div */
function toggle_div_form(div) {
	if (Element.visible(div)) {
		Element.hide(div);
		disable = 1;
	} else {
		Element.show(div);
		disable = 0;
	}
	$A($(div).getElementsByTagName('*')).find(function(element) {
		if (['input', 'select', 'textarea'].include(element.tagName.toLowerCase())) {
			element.disabled = disable;
		};
	});
}

// fixing weird effect behaviour
var Effect2 = function () {

  // stores Effect.Base objects (effectively mutexes)
  var states = {};

  // only perform effect if there is no other running
  function doEffect(f) {
    return function (e,options) {
      e = $(e);
      // if already running an effect
      if (typeof states[e.id] != "undefined" && states[e.id].state == "running") {
        return; // cancel new effect
      }
      // if not start
      states[e.id] = f(e,options);
      return states[e.id];
    };
  };

  function toggleEffect(fShow, fHide) {
    return function(e) {
      e = $(e);
      if (e.visible()) return fHide(e);
      else return fShow(e);
    };
  };

  return {
    BlindDown: doEffect(Effect.BlindDown),
    BlindUp: doEffect(Effect.BlindUp),
    BlindToggle: toggleEffect(doEffect(Effect.BlindUp), doEffect(Effect.BlindDown))
  };

}();

/* This hides and shows a help box which is populated from an ajax page when it is shown for
   the first time.
   linkid - id of the div that contains the link text
   boxid - id of the div to show and hide
   ontext - link text for when the box is visible
   offtext - link text for when the box is hidden
   contenturl - optional: url of the content to populate the box with
   contentchanges - optional: when true repeats the ajax call for each show
*/
var toggleHelpBox_populated = new Array();
function toggleHelpBox(linkid, boxid, ontext, offtext, contenturl, contentchanges, cb) {
    var o = document.getElementById(linkid);
    if (Element.visible(boxid)) {
      // hide it
      if (typeof globalValidator == "undefined" || globalValidator.validate(boxid)) {
        new Effect.Fade(boxid); // use Fade instead of BlindUp due to jerky effect on IE7
      	if (o) o.innerHTML = offtext;
      }
    } else {
      // show it
      if (contenturl && (contentchanges || !toggleHelpBox_populated[boxid])) {
         // This doesn't appear to display in Safari 5.0.3
         var indicator = $(linkid + "_indicator");
         if (indicator) {
           Element.show(indicator);
         }
         // download with ajax
         new Ajax.Updater({success:boxid}, contenturl, {
            asynchronous:false,
            method:'get',
            onComplete:function(t){
             if (indicator) Element.hide(indicator)
            },
            onFailure:ajaxUpdaterFailures}
         );
         toggleHelpBox_populated[boxid] = true;
      }
      new Effect.Appear(boxid);
      if (o) o.innerHTML = ontext;
      // if callback
      if (cb) cb(boxid);
    }
    return false;
}

/* Pops an alert if there are duplicated host attributes */
function check_host_attributes_duplication() {
  var items = $A([]);
  var last_name;
  var names
  var duplicates = $A([]);
  Form.getElements($('hostattributes_list')).each( function(e) {
    if (e.name.match(/^hostattributes\[\d+\]\[name\]$/)) {
      last_name = e.value.toUpperCase();
    } else if (e.name.match(/^hostattributes\[\d+\]\[value\]$/)) {
      var value = e.value.toLowerCase();
      primary_key = last_name + "::" + value;
      if (items.include(primary_key)) {
        var error = " " + last_name + " "+value;
        duplicates.push(error);
      } else {
        items.push(primary_key);
      }
    }
  } );
  if (duplicates.length) {
    alert((Opsview.Messages.duplicates)+":\n"+duplicates.join("\n"));
    return false;
  } else {
    return true;
  }
}

function queryhost(args) {
  var url=args.url;
  var extra="";
  if(args.extra_params)
    extra="&"+args.extra_params;
  extra=extra+"&.auth_cookie="+jQuery.cookie('auth_tkt');
  if($('tidy_ifdescr_level'))
    extra=extra+"&tidy_ifdescr_level="+$F('tidy_ifdescr_level');
  if($('snmp_max_msg_size'))
    extra=extra+"&snmp_max_msg_size="+$F('snmp_max_msg_size');
  if(!args.useHost) {
    if(args.hostid)
      extra=extra+"&hostid="+args.hostid;
    if($('monitored_by'))
      extra=extra+"&msid="+$('monitored_by').value;
    var list = Form.getInputs($('main_form'), 'radio', 'snmp_version');
    list.push($('ip'), $('snmp_community'), $('snmpv3_username'), $('snmpv3_authpassword'), $('snmpv3_authprotocol'), $('snmpv3_privprotocol'), $('snmpv3_privpassword'), $('snmp_port') );
    var params = Form.serializeElements(list);
  }
  Element.show("query_host_indicator");
  new Ajax.Updater({success:'snmp_info'}, url, { method:"post", parameters:params+extra, onFailure:ajaxUpdaterFailures, onComplete:function(){Element.hide("query_host_indicator")} } );
}


/**
* taken from http://xavisys.com/using-prototype-javascript-to-get-the-value-of-a-radio-group/
*
* Returns the value of the selected radio button in the radio group, null if
* none are selected, and false if the button group doesn't exist
*
* @param {radio Object} or {radio id} el
* OR
* @param {form Object} or {form id} el
* @param {radio group name} radioGroup
*/
function $RF(el, radioGroup) {
    if($(el).type && $(el).type.toLowerCase() == 'radio') {
        var radioGroup = $(el).name;
        var el = $(el).form;
    } else if ($(el).tagName.toLowerCase() != 'form') {
        return false;
    }

    var checked = $(el).getInputs('radio', radioGroup).find(
        function(re) {return re.checked;}
    );
    return (checked) ? $F(checked) : null;
}

jQuery171(document).ready( function() {
    jQuery171('form').each( function() {
        jQuery171(this).append(
            '<input type="hidden" name=".auth_cookie" value="' + jQuery171.cookie('auth_tkt') + '" />'
        );
    } )
} )
