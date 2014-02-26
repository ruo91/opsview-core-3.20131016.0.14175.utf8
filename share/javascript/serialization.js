/* 
 * Opsview javascript serialization library
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

// Serialization
// --------------------
// Serializes javascript objects into very small
// strings using type infomation.
// -----------------------------
// Author: Tristan Aubrey-Jones for Opsview Limited. 04/09/2009
// -----------------------------------

// Deprecated - nolonger required, but useful code for future...
// String replacer (precompiles regexp list)
// -----------------------
// call var f=create(arr) with list of pairs of regexp and string replacements
// then use f(str) to apply all replacements to a string
// e.g. 
//  var escapeBrackets = StringSubstituter.create(['(', '%28'], [')','%29']]);
//  var s = escapeBrackets("hello world (boo)"); // s == "hello world %28boo%29"
/*var StringSubstituter = function () {
  // constructor
  // - arr - 2D array list of replacements in form [["str1a", "str1b"], ["str2a", "str2b"]]
  function create(arr) {
    // precompile regular expressions
    var rearr = new Array(arr.length);
    for (var i=0,l=arr.length;i<l;i++)
      rearr[i] = new RegExp(arr[i][0],'g');
    // instance method
    return function(str) {
      for (var i=0,l=rearr.length;i<l;i++) 
        str = str.replace(rearr[i],arr[i][1]);
      return str;
    };
  };
  // escape regular expression special characters
  var lst = ['(',')','[',']','?','.','-','$','^'];
  for (var i=0,l=lst.length;i<l;i++) lst[i]=['\\'+lst[i],'\\'+lst[i]];
  var escapeRegexp = create(lst);
  // public 
  return {
    create: create,
    escapeRegexp: escapeRegexp
  };
}();
*/

// Reads a string, a chunk at a time
var StringReader = Class.create({
  // constructor
  initialize: function(str) {
    if (typeof str == 'undefined') alert("StringReader error: str is undefined");
    this.str = str;
    this.pos = 0;
  },

  // peek char
  peekChar: function() {
    return this.str.charAt(this.pos);
  },

  // read char
  readChar: function() {
    var c=this.str.charAt(this.pos);
    this.pos++;
    return c;
  },

  // read for (reads n chars and returns them)
  readFor: function(n) {
    var s=this.str.substr(this.pos,n);
    this.pos+=n;
    return s;
  },

  // read hex number (l is num of digits)
  readHexNum: function(l) {
    var s = this.readFor(l);
    return parseInt(s,16);
  },

  // is end of string - true when no more chars left
  isEOF: function() {
    return this.pos >= this.str.length;
  }

  /* Deprecated - nolonger required but useful code for later
  // read until one of the strings is found
  readUntil: function(arr) {
    if (typeof arr == 'string') arr = [arr];
    // find pos of first occurence, of one of the strings
    var e=this.str.length;
    for (var i=0,l=arr.length;i<l;i++) {
      var e2=this.str.indexOf(arr[i], this.pos);
      if (e2 >=this.pos && e2 < e) e = e2;
    }
    // return string
    var s = this.str.substr(this.pos,e-this.pos);
    this.pos = e;
    return s;
  }
  */

});

// Serialization
// ----------------------
// Serializes and deserializes values to a from a string using type metadata
// Allows serialized objects to be much smaller than JSON etc because information
// about the values type and structure is known.
// 
// Format of <typeinfo>:
//   "boolean" - boolean value - serializes to 0/1
//   "number" - numeric value - serializes to decimal string
//   "integer" - integer values - stored as hex (with length)
//   "byte" - 0-255 integer, stored as 2 hex chars
//   "string" - string value - serializes to ( string ) where internal brackets are urlencoded
//   "shortstring" - up to 255 chars
//   "date" - a date value - serializes to a hexadecimal timestamp value
//   { exponential: 5 } - a floating point value to be stored an exp form e.g. 1.00000e+0
//   { sigfigs: 5 } - a floating point value to be stored with the number of significant figures e.g. 10.000
//   { array: <typeinfo> } - an array with elements of type <typeinfo> - serializes to space 
//                           delimited list (el1 el2...)
//   { hash: <typeinfo> } - a hash with values of type <typeinfo> - serializes to space 
//                          delimited list of parts ((key1) v1 (key2) v2...)
//   { tuple: [<typeinfo1>, <typeinfo2>...] } - a fixed size array with set types for each element
//   { enumerated: [value1, value2, value3] } - an enum where the index is stored rather than the value.
//   [[field1, <typeinfo>], [field2, <typeinfo>]] - an object - serializes to a space 
//                          delimited list in same order of fields (v1 v2 v3..)
// in array & hash the attribute "lengthsize: 1" is optional and sets the number of bytes to use to
// store the length of the array/hash so 1, means 1B, which means up to 255 elements.
var Serialization = function() {
 
  // private functions
  function error(txt) {
      alert("Serialization error: " + txt);
  };
  function assert(cond, txt) {
    if (!cond) {
      error("assertion failed: " + txt);
    }
  };

  // returns length of string as a hex 
  // number padded to l digits long
  function hex(n, l) {
    var s = n.toString(16); 
    while (s.length<l) s='0'+s;
    return s;
  };
  function slen(str, l) { return hex(str.length,l); };

  // serialize object using typeinfo structure
  function _serialize(val, typeinfo) {
    if (typeof val == 'undefined') {
      // undef
      return 'u';
    } else if (val == null) {
      // null
      return 'n';
    } else if (Object.isArray(typeinfo)) {
      // an object (typeinfo is an array of fields)
      var arr=[];
      for (var i=0,l=typeinfo.length;i<l;i++)
        arr.push(_serialize(val[typeinfo[i][0]], typeinfo[i][1]));
      return 'o' + arr.join('');
    } else if (typeof typeinfo == 'object') {
      var arr=[];
      if (typeinfo.enumerated) {
        // enum values - store index of value
        for (var i=0,l=typeinfo.enumerated.length;i<l;i++) {
          if (val == typeinfo.enumerated[i]) 
            return hex(i,(l<16) ? 1 : (l<256 ? 2:3));
        } 
        error("Value not in enum: " + Object.toJSON(val) + " not in " + Object.toJSON(typeinfo.enumerated));
      } else if (typeinfo.tuple) {
        // fixed length (dont need to store length)
        // tuple (sequence of finite length, typeinfo.tuple is array of types)
        assert(val.length==typeinfo.tuple.length,"Tuple length incorrect: " + Object.toJSON(val) + Object.toJSON(typeinfo.tuple));
        for (var i=0,l=typeinfo.tuple.length;i<l;i++) 
          arr.push(_serialize(val[i],typeinfo.tuple[i]));
        return 'o' + arr.join('');
      } else if (typeinfo.exponential) {
        // float stored as an exponential value
        var p = typeinfo.exponential;
        var s=val.toExponential(p); return slen(s,p<=8?1:2)+s;
      } else if (typeinfo.sigfigs) {
        // float stored to a given number of sigfigs
        var p = typeinfo.sigfigs;
        var s=val.toPrecision(p); 
        if (s.length>p+2) {
          // if too long try as exp, just in case that fits
          var e=val.toExponential(p-1);
          if (e.length<=p+2) s=e;
          // have to truncate it so it fits in the expected length
          else s=s.substr(0,p+2);
        }
        return slen(s,p<=13?1:2)+s;
      } else {
        // variable length
        var len =0;
        if (typeinfo.array) {
          // an array (typeinfo.array is the element type)
          len=val.length;
          for (var i=0;i<len;i++)
            arr.push(_serialize(val[i], typeinfo.array));
        } else if (typeinfo.hash) {
           // a hash (typeinfo.hash is the value type)
           for (var k in val) {
            arr.push(_serialize(k,"string"), _serialize(val[k], typeinfo.hash));
            len++;
          }
        }
        var ll = 4;
        if (typeinfo.lengthsize) ll = typeinfo.lengthsize*2;
        return hex(len,ll)+arr.join('');
      }
    } else {
      // a scalar value
      switch (typeinfo) {
        case "boolean": return (val ? '1' : '0'); // 1 or 0
        case "number": var s=''+val; return slen(s,2)+s; // decimal floating point
        case "integer": var s=val.toString(16); return slen(s,1)+s; // hex integer
        case "byte": return hex(val,2); // hex integer 0-255
        case "string": return slen(val,4)+val; // string
        case "shortstring": return slen(val,2)+val; // string up to 255 chars
        case "date": var s=val.getTime().toString(16); return slen(s,1)+s; // hex timestamp
      }
    }
    alert("Serialization error: Invalid typeinfo '" + Object.toJSON(typeinfo) + "'");
  };

  // deserialize object (setting fields) from string
  function _deserialize(reader, typeinfo, obj) {
    // check for end of string
    if (reader.isEOF()) {
      if (typeof obj != 'undefined') return obj; // try to return current/default value
      else return null; // otherwise return null
    }
    // peek first char to check for undefined or null
    var fc = reader.peekChar();
    if (Object.isArray(typeinfo) && typeinfo.length == 0) {
      // empty object
      return (typeof obj == 'undefined') ? {} : obj;
    } else if (fc == 'u') {
      // undefined
      reader.readChar(); // consume char
      return;
    } else if (fc == 'n') {
      // null
      reader.readChar(); // consume char
      return null;
    } else if (typeof typeinfo == 'string') {
      // a scalar value
      if (typeinfo == "boolean") {
        // a boolean
        return (reader.readChar() == '1');
      } else if (typeinfo == "string") {
        // a string
        return reader.readFor(reader.readHexNum(4));
      } else if (typeinfo == "shortstring") {
        // short string up to 255 chars
        return reader.readFor(reader.readHexNum(2));
      } else {
        // read until space or closing bracket
        if (typeinfo == "date") {
          // a date
          var s = reader.readFor(reader.readHexNum(1));
          return new Date(parseInt(s,16));
        } else if (typeinfo == "number") {
          // a number
          var s = reader.readFor(reader.readHexNum(2));
          return parseFloat(s);
        } else if (typeinfo == "integer") {
          // an integer
          var s = reader.readFor(reader.readHexNum(1));
          return parseInt(s,16);
        } else if (typeinfo == "byte") {
          // a 1B integer (0-255)
          return reader.readHexNum(2);
        }
      }
    } else if (Object.isArray(typeinfo)) {
      // an object
      if (fc == 'o') reader.readChar(); // a placeholder to differentiate between null object, and null member
      if (typeof obj == 'undefined') obj = {};
      for (var i=0,l=typeinfo.length;i<l;i++) {
        var k = typeinfo[i][0]; var c;
        if (typeof obj[k] != 'undefined') c = obj[k];
        var v = _deserialize(reader, typeinfo[i][1], c); // deserialize field
        obj[k] = v; // assign field to obj
      }
      return obj;
    } else if (typeof typeinfo == 'object') {
      if (typeinfo.enumerated) {
        // an enum value
        var l=typeinfo.enumerated.length;
        var i=reader.readHexNum((l<16)?1 : (l<256 ? 2 : 3));
        assert(i<l, "Enum value " + i + " out of bounds of enum array: " + Object.toJSON(typeinfo.enumerated));
        return typeinfo.enumerated[i];
      } else if (typeinfo.tuple) {
        // tuple - fixed length
        if (fc == 'o') reader.readChar(); // allows differentiation between null tuple, and null tuple element
        var arr=[];
        for (var i=0,l=typeinfo.tuple.length;i<l;i++)
          arr[i] = _deserialize(reader,typeinfo.tuple[i]);
        return arr;
      } else if (typeinfo.exponential) {
        // a floating point number stored as an exponential
        var p = typeinfo.exponential;
        var l=reader.readHexNum(p<=8?1:2);
        return parseFloat(reader.readFor(l));
      } else if (typeinfo.sigfigs) {
        // a floating point number stored to a given number of decimal places
        var p = typeinfo.sigfigs;
        var s = reader.readFor(reader.readHexNum(p<=13?1:2));
        return parseFloat(s);
      } else {
        // variable length
        var ll=4;
        if (typeinfo.lengthsize) ll=typeinfo.lengthsize*2;
        var len=reader.readHexNum(ll);
        if (typeinfo.array) {
          // an array
          var arr=[];
          for (var i=0; i<len; i++) arr[i] = _deserialize(reader, typeinfo.array);
          return arr;
        } else if (typeinfo.hash) {
          // a hash
          var hsh={};
          for (var i=0; i<len; i++) {
            var k=_deserialize(reader,'string');
            var v=_deserialize(reader,typeinfo.hash);
            hsh[k] = v;
          }
          return hsh;
        }
      }
    }
  };

  // init module

  // public interface
  function deserialize(str, typeinfo, obj) {
    var reader = new StringReader(str);
    return _deserialize(reader, typeinfo, obj);
  };

  return {
    serialize: _serialize,
    deserialize: deserialize
  };

}();

// Serializable (abstract)
// -------------------
// Base class for serializable objects
// override getTypeInfo to return an array 
// of 2 element arrays in the form
// [ ['field1', <field1type>], ['field2', <field2type>]... ]
// Serialize returns string.
// Deserialize takes a string and inits 'this' with the values.
// -----------------------------
var Serializable = Class.create({
  // constructor
  initialize: function() {
  },

  // abstract: get typeinfo
  getTypeInfo: function() {
    return []; // empty object
  },

  // serialize object
  serialize: function() {
    return Serialization.serialize(this, this.getTypeInfo());    
  },

  // deserialize object
  deserialize: function(str) {
    Serialization.deserialize(str, this.getTypeInfo(), this);
  }

});

/* Example:

<textarea id='serializationTextBox' cols="100" rows="20"></textarea>
<script type="text/javascript">
var serTextBox = $('serializationTextBox');
var obj = {
  // fields
  d: new Date(),
  s: "hello world (boo)",
  b: true,
  n: -1.234,
  i: 235,
  a: [1,2,3,4,5,6,7,8],
  h: {
    boo: true, foo: false, bar: true
  },
  o: {
    d: new Date(),
    s1: "hello",
    s2: "world"
  },
  e: {},
  j: null
};
// type meta data
var typeinfo = [
    ['d', 'date'], // date
    ['s', 'string'], // string
    ['b', 'boolean'], // boolean
    ['n', 'number'], // float
    ['i', 'integer'], // integer
    ['a', { array: 'number' } ], // array of floats
    ['h', { hash: 'boolean' } ], // hash of booleans
    ['o', [ ['d', 'date'], ['s1', 'string'], ['s2', 'string']] ], // object
    ['e', []], // empty object
    ['j', 'string'], // string (is null)
    ['u', 'string'] // string (undefined)
];

var data = Serialization.serialize(obj, typeinfo);
var obj2 = Serialization.deserialize(data, typeinfo);
serTextBox.value = "JSON\n" + Object.toJSON(obj) + "\n\nSerialized\n" + data + "\n\nDeserialized\n" + Object.toJSON(obj2) +
  "\n\nLengths: " + Object.toJSON(obj).length + " (json); " + data.length + " (serialized)";

</script>

*/
