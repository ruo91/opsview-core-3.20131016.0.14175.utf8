/*

Copyright (C) 2003-2013 Opsview Limited. All rights reserved

This file is part of Opsview

Opsview is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

Opsview is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Opsview; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

*/

function toggle_menu(menu_name) {
	if (document.getElementById) {
		var abra = document.getElementById(menu_name).style;
		// TODO: Effects do not work well on IE6. Maybe change so 
		// that just appear in and out
		if (abra.display != "none") {
			save_prefs("", menu_name);
			new Effect.BlindUp(menu_name);
		} else {
			save_prefs(menu_name, "");
			new Effect.BlindDown(menu_name);
		}
		return false;
	} else {
		return true;
	}
}
function save_prefs(add_menu, remove_menu) {
	var divs = document.getElementsByTagName("DIV");
	var numberOfDivs = divs.length;
	var openSectionArray = new Array();
	var i;
	for (i = 0; i < numberOfDivs; i++) {
		var div = divs[i];
		var id_name = div.id;

		// Get name of section
		// display set to none at end of effect
		if (id_name.search(/^section-/) != -1 && id_name != remove_menu && (id_name == add_menu || div.style.display != "none")) {
			var section = id_name.replace(/^section-/, "");
			openSectionArray.push(section);
		}
	}
	// Set cookie
	var nowDate = new Date();
	nowDate.setFullYear(nowDate.getFullYear() + 1);
	var cookieExpires = nowDate.toGMTString();
	document.cookie = "navigator_sections=" + escape(openSectionArray.join(".")) + "; path=/; expires=" + cookieExpires;
}
