/*
 * Opsview Ajax Graph javascript graphing library
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

// Ajax Sparklines
// JavaScript sparklines framework
// Requires: prototype, ajaxglobals, excanvas, jquery, jquery.sparkline, jquery.noConflict
// Author: Tristan Aubrey-Jones, Opsview Limited 12/03/2010

// AjaxSparkline namespace
var AjaxSparkline = function() {

  // make any string usable as a hashtable key
  function hashStr(str) {
    return escape(str).replace(/[^a-zA-z0-9]/g, "_");
  };

  // convert / strip html tags to plain text
  function htmlToPlain(str) {
    return str.replace(/<[Bb][rR][^>]*>/g, ' \n').replace(/<[^>]+>/g, "");
  };

  // DataAdapter gets data from json webservice
  var DataAdapter = Class.create({
    // constructor
    initialize: function() {
    },

    // abstract
    // query data source for data
    // params: callback - function(success, query, data) { }
    //         keyword - series selector
    //         startTime - begin time
    //         endTime - end time
    query: function(keyword, startTime, endTime, callback) {
       $AG.error("DataAdapter.query not implemented, abstract method.");
    },

    // abstract
    // called by query or directly to process response data and call callback
    handleResponse: function(keyword, startTime, endTime, response, callback) {
       $AG.error("DataAdapter.handleResponse not implemented, abstract method.");
    }

  });


  // JSONDataAdapter base
  var JSONDataAdapter = Class.create(DataAdapter, {
    // constructor
    // params: endpoint - url of the json service endpoint
    initialize: function(url) {
      this.url = url;
    },

    // query data source for data
    // params: keyword - series selector
    //         startTime - timestamp in ms
    //         endTime - timestamp in ms
    //         callback - function(success, [
    query: function(keyword, startTime, endTime, callback) {
      // format parameters
      // TODO change so uses hsm selector rather than a specific hsm
      var params = {
        start: Math.round(startTime / 1000),
        end: Math.round(endTime / 1000),
        keyword: keyword
      };

      // start XHR request
      var me = this;
      var req = new Ajax.Request(this.url, {
        method: 'get',
        parameters: params,
        requestHeaders: {Accept: 'application/json'},
        onSuccess: function(transport) {
          var json = transport.responseJSON;
          if (typeof json == 'undefined') {
            json = eval("(" + transport.responseText + ")");
            if (typeof json == 'undefined') {
              alert("Sparkline data request failed to parse json: " + transport.responseText);
              throw ("Sparkline failed to parse JSON.");
            }
          }
          if (json != null) {
            // handle data
            me.handleResponse(keyword, startTime, endTime, json, callback, transport);
          } else {
            // error
            callback(false, keyword, transport.statusText, transport);
          }
        },
        onFailure: function(transport) {
          callback(false, keyword, transport.statusText, transport);
        },
        onException: function(req, err) {
          if (typeof err == 'object' && typeof err.message == 'string') err = err.message;
          callback(false, keyword, err, req);
        }
      });
    },

    // process successful response, and invoke callback
    handleResponse: function(keyword, startTime, endTime, response, callback, transport) {
      // turn array of coordinates, to array of y-points
      var lines = response.ResultSet.lines;
      for (var i=0; i<lines.length; i++) {
        var data = lines[i].data, points = [];
        for (var x=0; x<data.length; x++) {
          points.push(data[x][1]);
        }
        lines[i].ypoints = points;
      }
      // invoke callback 
      callback(true, keyword, lines, transport); 
    }

  });

  // Group of sparklines
  var Group = Class.create({
    // constructor
    // params: adapter - data adapter
    //         keyword - series selector
    //         duration - duration to display in milliseconds
    initialize: function(adapter, keyword, duration, default_options, lang) {
      // save parameters
      this.adapter = adapter;
      this.keyword = keyword;
      this.duration = duration;
      this.default_options = default_options;

      // initialize collection of sparklines
      this.spans = {};
      this.savedLines = {};
      this.descriptions = {};    
      this.options = {};
      this.valueSpans = [];
      this.errorNumber = 1;

      // data adapter callback
      var me = this;
      this.callback = function(success, keyword, lines) {
        if (success) {
          // save data in hash
          var lineHash = {};

          // update sparkline spans with data
          for (var i=0; i<lines.length; i++) {
            var seriesName = hashStr(lines[i].label);
            lineHash[seriesName] = lines[i];
            var ypoints = lines[i].ypoints;
            if (typeof me.spans[seriesName] != 'undefined') {
              // if there is a span for this sparkline
              // save ypoints for future redraws
              me.savedLines[seriesName] = ypoints;

              // get options
              var opts = {};
              $J.extend(true, opts, me.default_options, 
                (typeof me.options[seriesName] == 'object') ? me.options[seriesName] : {});

              // draw sparkline
              var spn = me.spans[seriesName];
              if (typeof spn == 'string') spn = '#' + spn;
              spn = $J(spn);
              spn.sparkline(ypoints, opts);
              if (typeof lines[i].description == 'string') {
                var d = htmlToPlain(lines[i].description);
                me.descriptions[seriesName] = d;
                if (typeof spn[0] != 'undefined') // If span is hidden (table filter), then this is undefined
                  spn[0].title = d;
              }
            } else {
              // TODO add refresh page here so if there are new metrics they will be found
            } 
          }

          // update value spans with data
          for (var i=0; i<me.valueSpans.length; i++) {
            // get data
            var spn = $J(me.valueSpans[i]);
            if (typeof spn == 'string') spn = '#' + spn;
            spn = $J(spn);
            var seriesName = hashStr(spn.l);
            if (typeof lineHash[seriesName] == 'object') {
              var ln = lineHash[seriesName];
              spn.s.update(spn.f(ln));
            }
          }
          me.errorNumber=1;
        } else {
          // error message
          if (lines=="Unauthorized") {
            $J(".history_title_info").each(function(){ $(this).show(); $(this).innerHTML="("+lang.historyUnauthorised+")" });
          } else {
            // Only alert on 2nd error. This is because changing pages will kill an ajax request which may propagate a message unnecessarily
            if(me.errorNumber>=2)
              alert("sparkline error: " + lines);
            me.errorNumber++;
          }
        }
      };
    },

    // add a sparkline to the group
    add: function(label, span, sloptions) {
      // make hash key from label
      var h = hashStr(label);
      
      // if already exists return
      if (typeof this.spans[h] != 'undefined') return;

      // add to hash tables
      this.spans[h] = span;
      if (typeof sloptions == 'object')
        this.options[h] = sloptions;
      return h;
    },

    // remove a sparkline from the group
    remove: function(label) {
      var h = hashStr(label);
      if (typeof this.spans[h] != 'undefined')
        delete this.spans[h];
      if (typeof this.options[h] != 'undefined')
        delete this.options[h];
    },

    // add a span that contains a value synchronized to a given sparkline
    addValueSpan: function(span, label, filterFunction) {
      this.valueSpans.add({s: span, l: label, f: filterFunction});
    },

    // remove a span with a value synchronized to a given sparkline
    removeValueSpan: function(span) {
      for (var i = 0; i < this.valueSpans.length; i++) {
        if (this.valueSpans[i].s == span) {
          this.valueSpans.splice(i,1);
          return;
        }
      }
    },
 
    // refresh the sparklines with newest data
    refresh: function(response) {
      // make time range
      var now = (new Date()).getTime();
      var st = now - this.duration, et = now;

      // if data provided
      var r = typeof response;
      if (r == 'object')
        this.adapter.handleResponse(this.keyword, st, et, response, this.callback);
      // perform query
      else {
        if (r == 'function') {
          // start async refresh with callback
          var cb = response;
          var me = this;
          var f = function(a, b, c, t) {
            me.callback(a, b, c);
            cb(t, a ? undefined : c);
          };
          this.adapter.query(this.keyword, st, et, f);
        } else {
          // start refresh
          this.adapter.query(this.keyword, st, et, this.callback);
        }
      }
    },

    // redraw sparklines from saved data
    // (only redraws spans that have some data to draw)
    redraw: function() {
      for (var seriesName in this.savedLines) {
        var ypoints = this.savedLines[seriesName];
        var opts = {};
        $J.extend(true, opts, this.default_options, 
                (typeof this.options[seriesName] == 'object') ? this.options[seriesName] : {});

        var spn = this.spans[seriesName];
        if (typeof spn == 'string') spn = '#' + spn;
        spn = $J(spn);
        if (typeof spn[0] != 'undefined') {
          spn.sparkline(ypoints, opts);
          if (typeof this.descriptions[seriesName] == 'string')
                spn[0].title = this.descriptions[seriesName];
        }
      }
    }

  });


  return {
    Group: Group,
    DataAdapter: DataAdapter,
    JSONDataAdapter: JSONDataAdapter,
    hashString: hashStr
  };

}();

