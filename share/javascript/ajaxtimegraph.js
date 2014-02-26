/* 
 * Opsview AjaxTimeGraphs javascript library for graphing data against time
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

// Ajax Time Graphs (extends Ajax Graphs)
// JS Graphs for data against time
// Requires: excanvas, prototype, serialization, jquery, jquery.flot, jquery.noConflict, ajaxglobals, ajaxgraph
// Author: Tristan Aubrey-Jones 16/10/2009

var AjaxTimeGraphs = function() {

  // Graph extends AjaxGraphs.Graph
  var Graph = Class.create(AjaxGraphs.Graph, {
    initialize: function($super, container, dataAdapter, options, state) {
      // default options
      var now = new Date().getTime() + options.timezoneOffset + 0*60*1000; // 0 mins in future
      var day = (24*60*60*1000);
      var lastYr = now-(day*365);
      var lastWeek = now-(day*3);
      var defaultOptions = {
        state: {
          xaxis: { min: -(day*1), max: 0 } // default to snap to now
        },
        flot: {
          main: {
            xaxis: { min: lastWeek, max: now, mode: 'time' } // previous day
          },
          overview: {
            xaxis: { min: lastYr, max: now, mode: 'time', ticks: 12 }, // previous year
            selection: { mode: "x" }
          }
        },
        // zoom buttons
        zooms: [
          {label: "1h", width: 60*60*1000},
          {label: "1d", width: 24*60*60*1000},
          {label: "1w", width: 7*24*60*60*1000},
          {label: "1M", width: 30*24*60*60*1000},
          {label: "4M", width: 4*30*24*60*60*1000},
          {label: "1y", width: 365*24*60*60*1000}
        ],
        // extend base controls
        classes: {
        },
        labels: {
          snapToNowOn: "Snap to now on",
          snapToNowOff: "Snap to now off"
        },
        flags: {
          snapToNow: true // show snap to now option?
        }
      };
      options = $J.extend(true, defaultOptions, options);

      // set max x margin      
      this.maxXMargin = 5*60*1000; // 5mins

      // call super constructor
      $super(container, dataAdapter, options, state);

      // periodic updates
      var me = this;
      var onRefresh = function (cb) {
        // if graph viewing live data
        var now = me.getNow();
        me.setRanges({}, false, true); // snap to now if on. Stop autoloading
        var r = me.getRanges();
        var maxx = r.xaxis.to;
        if (maxx > now) {
          // refresh data
          me.requestData(me.state.series);
          me.requestOverviewData(me.state.series);
        }
        // callback
        if (cb !== undefined) cb();
      };
      if (typeof refreshTimer == 'object') {
        // page level timer
        refreshTimer.addListener(onRefresh);
      } else {
        // manual timer
        var delay = 5*60*1000;
        var f = function() {
          onRefresh();
          setTimeout(f, delay);
        };
        setTimeout(f, delay);
      }

      // adds snap to now button to toolbar
      this.initSnapToNowButton();
    },

    // creates snap to now button and adds it to the graph
    initSnapToNowButton: function() {
      if (this.options.flags.snapToNow) {
        // create elements
        var div = $AG.createElement('span', { className:'toolbar-btn' });
        this.divs.snapToNowBtn = div;
        var on = $AG.createElement('span', {}, this.options.labels.snapToNowOn);      
        var off = $AG.createElement('span', {}, this.options.labels.snapToNowOff);

        // show correct one
        if (this.getSnapToNow()) { on.show(); off.hide(); }
        else { on.hide(); off.show(); }

        // on click events
        var me = this;
        Event.observe(on, 'click', function() {
          // turn off
          me.setSnapToNow(false);
        });
        Event.observe(off, 'click', function() {
          // turn on
          me.setSnapToNow(true);
        });
      
        // add to graph
        div.appendChild(on);
        div.appendChild(off);
        this.divs.rescaleYAxis.insert({ after: div });
        this.divs.snapToNowOn = on;
        this.divs.snapToNowOff = off;
      }
      
    },

    getNow: function() {
      return (new Date()).getTime() + this.options.timezoneOffset;
    },

    // returns true if snap to now is currently on, or false otherwise
    getSnapToNow: function() {
      var x = this.state.xaxis;
      return (x.max == 0);
    },

    // sets whether set to now is on or not
    setSnapToNow: function(value, nr) {
      // get if on
      var on = this.getSnapToNow();
      if (on != value) {
        // get duration
        var r = this.getRanges();
        var dx = r.xaxis.to - r.xaxis.from;
        var x = this.state.xaxis;
        // get icons
        var onb = this.divs.snapToNowOn;
        var offb = this.divs.snapToNowOff;
        // switch
        if (value) {
          // turn on
          // max=0, min=-duration
          x.max = 0;
          x.min = -dx;
          onb.show(); offb.hide();
          this.setRanges({});
        } else {
          // turn off
          // max=time, min=time
          x.min = r.xaxis.from;
          x.max = r.xaxis.to;
          onb.hide(); offb.show();
          if (typeof nr == 'object') this.setRanges(nr);
        }
      }
    },

    // override to translate relative values
    // into absolute when using "snap to now"
    getRanges: function($super) {
      var x = this.state.xaxis;
      var r = $super();
      // if snap to now is on
      if (r.xaxis.to == 0) {
        // convert from relative to absolute
        r.xaxis.to = this.getNow() + this.maxXMargin;
        r.xaxis.from = r.xaxis.from + r.xaxis.to;
      }
      return r;
    },

    // override to translate relative values
    // into absolute when using "snap to now"
    setRanges: function($super, r, zooming, dontRequestData) {
      // see if snap to now is on
      var x = this.state.xaxis;
      var on = (x.max == 0);
      
      // if on snap max x to now
      // (also x always needs to be defined when on)
      if (on) {
        // if changing zoom level, or just snapping to now
        if (zooming || r.xaxis === undefined) {
          // snap to now
          if (r.xaxis === undefined) {
            r.xaxis = { from: x.min, to: x.max };
          }
          var to = this.getNow() + this.maxXMargin;
          r = $J.extend(true, r, {
            xaxis: { from: to - (r.xaxis.to - r.xaxis.from), 
                   to: to }
          });
        } else {
          // turn snap to now off
          this.setSnapToNow(false, r);
          return;
        }
      }

      // set as usual
      $super(r, dontRequestData);

      // convert absolute pos to relative
      if (on && x.max != 0) {
        x.min = x.min - x.max;
        x.max = 0;
      }
    }

  });

  return {
    Graph: Graph
  };

}();
