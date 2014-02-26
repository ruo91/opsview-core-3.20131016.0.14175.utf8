/* 
 * Opsview AjaxGlobals javascript library
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

// AjaxGlobals
// Global methods & classes
// Author: Tristan Aubrey-Jones, Opsview Limited, 08/09/2009

var AjaxGlobals = function() {
  // generates a unique id
  var idCounter = 0;
  function uuid(pre, post) {
    if (typeof pre != 'string') pre = 'uuid';
    if (typeof post != 'string') post = '';
    var id = pre + idCounter + post;
    idCounter++;
    return id;
  };

  // creates an element and assigns attrs
  function createElement(tag, attrs, inner) {
    var e = document.createElement(tag);
    for (var k in attrs) {
      e[k] = attrs[k];
    }
    if (typeof inner == 'string') e.innerHTML = inner;
    return $(e);
  };

  // gets the computed css (actual current value) of an element
  function getComputedStyle(oElm, strCssRule) {
    var strValue = "";
	if(document.defaultView && document.defaultView.getComputedStyle){
		strValue = document.defaultView.getComputedStyle(oElm, "").getPropertyValue(strCssRule);
	}
	else if(oElm.currentStyle){
		strCssRule = strCssRule.replace(/\-(\w)/g, function (strMatch, p1){
			return p1.toUpperCase();
		});
		strValue = oElm.currentStyle[strCssRule];
	}
	return strValue;
  };

  // convert to json string
  function toJSON(o) {
    if (Object.toJSON) {
      return Object.toJSON(o);
    } else {
      error("Object.toJSON not defined, include prototype.");
    }
  };

  // show error
  function error(msg) {
    throw (msg);
  };

  // assert
  function assert(cond, txt, obj) {
    if (!cond) error("Assertion failed: " + txt + toJSON(obj));
  };

  // if a string, parseInt
  function int(s) { 
    if (typeof s == 'string') return parseInt(s); 
    else return s; 
  };

  // base class for all controls
  var Control = Class.create({
    // constructor
    initialize: function() {
    },

    // abstract
    // get dom element
    getElement: function() {
      error("Control.getElement not implemented, abstract class.");
    }
  });

  // makes a number positive
  function magnitude(n) { return n<0 ? -n : n; };
  
  // pads an integer with leading 0's to the desired length 
  function padInteger(n, digits) { 
    var s=''+n; while(s.length<digits) s='0'+s; return s; 
  };

  // Finds the index of an array element
  Array.prototype.indexOf = function(o) {
    for (var i=0,l=this.length;i<l;i++) {
      if (this[i] == o) return i;
    }
    return -1;
  };

  // Adds an element to an array
  Array.prototype.add = function(o) {
    return this.push(o);
  };

  // Removes the given object from the array
  Array.prototype.remove = function(o) {
    var i = this.indexOf(o);
    if (i >= 0) { this.splice(i,1); return o; }
    else return null;
  };

  // executes the function foreach element in array
  Array.prototype.foreach = function(f, args) {
    var i=0,l=this.length;
    if (typeof f == 'function') {
      if (args !== undefined && args.length > 0) {
        for (; i < l && f.apply(this[i], args) !== false; i++) {}
      } else { 
        for (; i < l && f.call(this[i], i, this[i]) !== false; i++) {}
      }
    } else if (typeof f == 'string') {
      if (args !== undefined && args.length > 0) {
        for (; i < l; i++) {
          if (typeof this[i][f] == 'function' && 
              this[i][f].apply(this[i], args) === false) break;
        }
      } else { 
        for (; i < l; i++) {
          if (typeof this[i][f] == 'function' && 
              this[i][f].call(this[i], i, this[i]) === false) break;
        }
      }
    }
  };

  // creates a foreach function for the given array
  function foreachFunction(arr, f) {
    if (typeof f == 'function') {
      return function() {
        var i=0,l=arr.length;
        if (arguments.length > 0) {
          for (; i < l && f.apply(arr[i], arguments) !== false; i++) {} }
        else {
          for (; i < l && f.call(arr[i]) !== false; i++) {} }
      };
    } else if (typeof f == 'string') {
      return function() {
        var i=0,l=arr.length;
        if (arguments.length > 0) {
          for (; i < l && arr[i][f].apply(arr[i], arguments) !== false; i++) {} }
        else {
          for (; i < l && arr[i][f].call(arr[i]) !== false; i++) {} }
      };
    }
  };

  // Converts JS Date to 2009-07-22 03:42:29
  Date.prototype.toDateTimeString = function() {
      var d = this, p = padInteger;
      return d.getFullYear() + '-' +
             p(d.getMonth()+1,2) + '-' +
             p(d.getDate(),2) + ' ' +
             p(d.getHours(),2) + ':' +
             p(d.getMinutes(),2) + ':' +
             p(d.getSeconds(),2);
  };
  Date.prototype.toUTCDateTimeString = function() {
      var d = this, p = padInteger;
      return d.getUTCFullYear() + '-' +
             p(d.getUTCMonth()+1,2) + '-' +
             p(d.getUTCDate(),2) + ' ' +
             p(d.getUTCHours(),2) + ':' +
             p(d.getUTCMinutes(),2) + ':' +
             p(d.getUTCSeconds(),2);
  };

  // Converts 2009-07-22 03:42:29 to a Date
  var stringToDate = function(s) {
      var a = this.dateRegexp.exec(s);
      if (!Object.isArray(a) || a.length < 5) return null;
      function num(s) { return parseInt(s, 10); }
      if (a.length < 6) a.push(0); // if no secs, add 0s
      var d = new Date(num(a[1]), num(a[2])-1, num(a[3]), num(a[4]), num(a[5]), num(a[6]) );
      return d;
  };

  // Blind up/down effects
  var effect = (typeof Effect2 == 'object') ? Effect2 :
               (typeof Effect == 'object') ? Effect : false;
  function blindUp(el) {
    if (effect) effect.BlindUp(el);
    else el.hide();
  };
  function blindDown(el) {
    if (effect) effect.BlindDown(el);
    else el.hide();
  };
  function blindToggle(el) {
    if (!el.visible()) blindDown(el);
    else blindUp(el);
  };
  function blind(el, vis) {
    if (vis) blindDown(el); else blindUp(el);
  };

  // Public
  return {
    uuid: uuid, // makes a unique id
    createElement: createElement,
    getComputedStyle: getComputedStyle,
    int: int,
    error: error,
    assert: assert,
    Control: Control,
    Math: {
      mag: magnitude,
      padInt: padInteger
    },
    Effect: {
      Blind: blind,
      BlindUp: blindUp,
      BlindDown: blindDown,
      BlindToggle: blindToggle
    },
    foreachFunction: foreachFunction
  };
}();
var $AG = AjaxGlobals;

