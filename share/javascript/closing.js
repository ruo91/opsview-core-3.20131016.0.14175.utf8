/* 
 * Opsview javascript library for closable elements
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

// Closing
// JavaScript closable divs framework
// Requires: prototype
// Author: Tristan Aubrey-Jones, Opsview Limited 15/10/2009

// Closing namespace
var Closing = function() {

  // config
  var config = {
    innerHTML: "[Close]",
    toolTip: "Close",
    className: "close-btn",
    width: null,
    height: null,
    bgImage: null
  };

  // Element with close button in top right
  var ClosableElement = Class.create({
    initialize: function(el, onclose, onclosed) {
      // create close button
      var btn = $(document.createElement('div'));
      btn.update(config.innerHTML);
      btn.style.margin = "3px";
      btn.className = config.className;
      btn.style.position = "absolute";
      btn.style.top = "0px";
      btn.style.right = "0px";
      btn.style.cursor = "pointer";
      if (config.toolTip != null) btn.title = config.toolTip;
      if (config.bgImage != null)
        btn.style.backgroundImage = "url('" + config.bgImage + "')";
      if (config.width != null) btn.style.width = config.width;
      if (config.height != null) btn.style.height = config.height;
      
      // on click - close
      Event.observe(btn, 'click', function() {
        var cancel = false;
        if (typeof onclose == 'function') {
          cancel = onclose(el);
        }
        if (cancel == undefined || !cancel) el.parentNode.removeChild(el);
        if (typeof onclosed == 'function') {
          onclosed(el);
        }
      });

      // add to page
      el.appendChild(btn);
    }
  });

  return {
    ClosableElement: ClosableElement,
    config: config
  };

}();

var ClosableElement = Closing.ClosableElement;
