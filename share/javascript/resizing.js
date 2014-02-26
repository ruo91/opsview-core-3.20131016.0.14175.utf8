/* 
 * Opsview javascript library for resizable elements
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

// Resizing
// JavaScript resizing library
// Requires: prototype
// Author: Tristan Aubrey-Jones, Opsview Limited 6/10/2009

// Monitors elements raising the
// resize event when their size changes
var ResizeEvent = function() {
  // pause in ms between checks
  var delay = 500;

  // is ie? (if so dont need timer as have resize event)
  var ie = Prototype.Browser.IE;

  // elements being monitored
  var elements = [];

  // methods
  function addElement(e) {
    // in IE can use onresize
    if (ie) {
      Event.observe(e, 'resize', function(ev) { 
        Event.fire(e, 'dom:resized', {} ); 
      });
    } else {
      // otherwise must monitor using timer
      elements.push([e, e.clientWidth, e.clientHeight]);
    }
  };
 
  function removeElement(e) {
    // if not ie
    if (!ie) {
      // add to monitored list
      var lst = [];
      for(var i=0,l=elements.length;i<l;i++) {
        if (elements[i] != e) { 
          lst.push(elements[i]);
        }
      }
      elements = lst;
    }
  };

  function fire(e) {
    // fire event
    Event.fire(e, 'dom:resized', {});
    if (!ie) {
      // update stored width & height
      for (var i=0,l=elements.length;i<l;i++) {
        var ce = elements[i];
        if (ce[0] == e) {
          ce[1] = e.clientWidth;
          ce[2] = e.clientHeight;
          break;
        }
      }
    }
  };

  // timer (not needed in IE)
  if (!ie) {
    var checkSizes = function() {
     // check to see if sizes have changed
      for (var i=0,l=elements.length;i<l;i++) {
        var e = elements[i];
        var cw = e[0].clientWidth, ch = e[0].clientHeight;
        if (cw != e[1] || ch != e[2]) {
          // fire resize event
          Event.fire(e[0], 'dom:resized', {});
          e[1] = cw; e[2] = ch; 
       }
      }
      setTimeout(checkSizes, delay);
    };
    setTimeout(checkSizes, delay);
  }

  // public
  return {
    addElement: addElement,
    removeElement: removeElement,
    fire: fire,
    DEFAULT_DELAY: delay,
    setDelay: function(d) { delay = d; },
    getDelay: function() { return delay; }
  };

}();

// Resizing namespace
var Resizing = function() {

  // config
  var config = {
    toolTip: "Resize",
    innerHTML: "/",
    className: "resize-bevel",
    bgImage: null,
    width: null,
    height: null
  };

  // removes an element from an array
  function removeObjFunc(arr) {
    return function (f) {
      for (var i=0,l=arr.length;i<l;i++) {
        if (arr[i] == f) { arr.splice(i,1); break; }
      }
    };
  };
  function notifyListeners(arr, ev) {
    for (var i=0,l=arr.length;i<l;i++) 
      if (typeof arr[i] == 'function') arr[i](ev);
  };

  // Listen to mouse movement
  var mousePos = { x: 0, y: 0 };
  var listeners = [];
  function addMoveListener(f) { listeners.push(f); };
  var removeMoveListener = removeObjFunc(listeners);
  Event.observe(document, 'mousemove', function(ev) {
    // update mouse position
    if(ev.pageX || ev.pageY) {
      mousePos = {x:ev.pageX, y:ev.pageY}; 
    } else {
      mousePos = { 
        x:ev.clientX + document.body.scrollLeft - document.body.clientLeft, 
        y:ev.clientY + document.body.scrollTop  - document.body.clientTop 
      };
    }

    // notify listeners
    notifyListeners(listeners, mousePos);
  }); 

  // listen to mouse up
  var upListeners = [];
  function addUpListener(f) { upListeners.push(f); }
  var removeUpListener = removeObjFunc(upListeners);
  Event.observe(document, 'mouseup', function(ev) {
    notifyListeners(upListeners, mousePos);
  });

  // ResizableElement
  // An element that can be resized by the user
  var ResizableElement = Class.create({
    initialize: function(el, minW, minH, maxW, maxH) {
      // the resizable element
      this.element = $(el);

      // min/max sizes
      this.minW = (typeof minW == 'number') ? minW : null; 
      this.minH = (typeof minH == 'number') ? minH : null; 
      this.maxW = (typeof maxW == 'number') ? maxW : null; 
      this.maxH = (typeof maxH == 'number') ? maxH : null; 
      function clip(v, min, max) {
        if (min != null && v < min) return min;
        if (max != null && v > max) return max;
        return v;
      };

      // create resizing tab
      var t = document.createElement('div'); this.tab = t;
      t.innerHTML = config.innerHTML;
      t.className = config.className;
      t.title = config.toolTip;
      if (config.bgImage != null)
        t.style.backgroundImage = "url('" + config.bgImage + "')";
      if (config.width != null) t.style.width = config.width;
      if (config.height != null) t.style.height = config.height;
      t.style.position = "absolute";
      t.style.cursor = "se-resize";
      t.style.bottom = "0px";
      t.style.right = "0px";
      this.element.appendChild(t);

      // status
      this.startPos = null;
      this.startSize = null;
      this.cursor = document.body.style.cursor;

      // event handlers
      var me = this;
      var mouseMove = function(pos) {
        if (me.startPos != null && me.startSize != null) {
          // calc diff
          var dx = pos.x - me.startPos.x,
              dy = pos.y - me.startPos.y; 

          // resize element
          var w = clip(me.startSize.w + dx, minW, maxW),
              h = clip(me.startSize.h + dy, minH, maxH);
          var s = me.element.style;
          s.width = w + "px";
          s.height = h + "px";

          // deselect any text selected while dragging
          if (window.getSelection) window.getSelection().removeAllRanges();
          else if (document.selection) document.selection.empty();
        }
      };

      // stop resizing
      var mouseUp = function(pos) {
        // stop listening
        removeUpListener(mouseUp);
        removeMoveListener(mouseMove);
        // blank pos
        me.startPos = null;
        // revert cursor
        document.body.style.cursor = me.cursor;
        // fire event
        ResizeEvent.fire(me.element);
        // slow down resize checks
        ResizeEvent.setDelay(ResizeEvent.DEFAULT_DELAY);
      };

      // start resizing
      Event.observe(this.tab, 'mousedown', function(ev) {
        // save start pos & size
        me.startPos = mousePos;
        var s = me.element.style;
        me.startSize = { w: parseInt(s.width), h: parseInt(s.height) };
        // change cursor
        document.body.style.cursor = "se-resize";
        // listen for move & end
        addMoveListener(mouseMove);
        addUpListener(mouseUp);
        // increase resize checks
        ResizeEvent.setDelay(50);
        return false;
      });
    }
  });

  // Public
  return {
    config: config,
    ResizableElement: ResizableElement,
    addMouseMoveListener: addMoveListener,
    removeMouseMoveListener: removeMoveListener,
    getMousePosition: function() { return mousePos; }
  };

}();

var ResizableElement = Resizing.ResizableElement;

