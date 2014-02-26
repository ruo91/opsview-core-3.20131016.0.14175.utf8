/* 
 * Opsview graphs javascript library for graphing RRD data
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

// Opsview Graphs
// JS Graphs for Opsview RRD data
// Requires: excanvas, prototype, serialization, jquery, jquery.flot, jquery.noConflict, ajaxglobals, ajaxgraph, ajaxtimegraph
// Author: Tristan Aubrey-Jones 09/09/2009

var OpsviewGraphs = function() {

  // Get Max&Min y values of a data set
  function getDataRanges(d) {
    if (typeof d == 'object' && d.length > 0) {
      var minX = Number.POSITIVE_INFINITY, maxX = Number.NEGATIVE_INFINITY,
          minY = Number.POSITIVE_INFINITY, maxY = Number.NEGATIVE_INFINITY;
      var r = AjaxGraphs.foreachPoint(d, function(p) {
            if (p[0] != null) {
              if (p[0] > maxX) maxX = p[0];
              if (p[0] < minX) minX = p[0];
            }
            if (p[1] != null) {
              if (p[1] > maxY) maxY = p[1];
              if (p[1] < minY) minY = p[1];
            }
      });
      return [minX, maxX, minY, maxY];
    } else {
      return null;
    } 
  };

  // Gets data from JSON endpoint
  var DataAdapter = Class.create(AjaxGraphs.DataAdapter, {
    initialize: function($super, url) {
      $super();
      $AG.assert(typeof url == 'string', "OpsviewGraphs.DataAdapter requires a url string");
      this.url = url;
    },
    query: function(query, callback) {
      // format parameters
      var params = {
        start: Math.round(query.ranges.xaxis.from / 1000),
        end: Math.round(query.ranges.xaxis.to / 1000),
        hsm: query.series
      };
      // start XHR request
      var req = new Ajax.Request(this.url, {
        method: 'get',
        parameters: params,
        requestHeaders: {Accept: 'application/json'},
        onSuccess: function(transport) {
          var json = transport.responseJSON;
          if (typeof json == 'undefined') {
            json = eval("(" + transport.responseText + ")");
            if (typeof json == 'undefined') {
              alert("Graph data request failed to parse json: " + transport.responseText);
              throw ("Graph failed to parse JSON.");
            }
          }

          if (json != null) {
            // convert unix timestamps to javascript timestamps
            AjaxGraphs.foreachPoint(json.ResultSet.lines, function(p) {
              p[0] = p[0] * 1000;
            }); 

            // callback
            callback(true, query, json.ResultSet);  
          } else {
            // error
            callback(false, query, transport.statusText);
          }
        }, 
        onFailure: function(transport) {
          callback(false, query, transport.statusText);
        },
        onException: function(req, err) {
          if (typeof err == 'object' && typeof err.message == 'string') err = err.message;
          callback(false, query, err);
        }
      });
    } 
  });

  // Add series control
  var AddSeriesControl = Class.create(AjaxGlobals.Control, {
    // constructor
    initialize: function($super, graph) {
      // save ref to graph
      this.graph = graph;

      // init elements
      this.element = $AG.createElement('div', {}, 
        "<span class='graph-heading'>"+graph.options.labels.addSeriesTitle+":</span>");

      // create inputs
      function createInput(label, className, size, idx) {
        var ip = $AG.createElement('input', { 
          type: "text",
          value: label,
          title: label,
          className: className,
          size: size,
          id: 'graph-add' + className + $AG.uuid()
        });
        if (typeof ip.autocomplete !== undefined) ip.autocomplete = "off";
        // when starting edit
        Event.observe(ip, 'focus', function(ev) {
          if (ip.value == ip.title) ip.value = "";
        });
        // when finishing edit
        var textChanged = function() {
          // strip lead/trail whitespace
          ip.value = ip.value.strip();

          // validate...
          // TODO: 

          // if empty string revert to label
          if (ip.value.length == 0) {
            ip.value = label;
          }
        };
        Event.observe(ip, 'blur', textChanged);
        Event.observe(ip, 'change', textChanged);
      /* Event.observe(ip, 'keyup', function(ev) {
          if (ev.keyCode == 13) textChanged();
        });*/
        return ip;
      };
      var host = createInput(graph.options.labels.addHost, 'hostbox', 15, 0); 
      this.host = host;
      var service = createInput(graph.options.labels.addService, 'servicebox', 10, 1);
      this.service = service;
      var metric = createInput(graph.options.labels.addMetric, 'metricbox', 5, 2); 
      this.metric = metric;    

      // create add button
      var op = graph.options;
      var addBtn = $AG.createElement('input', {
        type: 'button',
        value: graph.options.labels.addSeriesButton
      });
      var loadingIcon = $AG.createElement('img', {
        className: "graph-btn",
        src: op.urls.loadingIcon,
        alt: op.labels.loading,
        title: op.labels.loading
      }); loadingIcon.hide();
      var invalidIcon = $AG.createElement('img', {
        className: "graph-btn",
        src: op.urls.invalidIcon,
        alt: op.labels.invalid
      }); invalidIcon.hide();
      var connectionErrorIcon = $AG.createElement('img', {
        className: "graph-btn",
        src: op.urls.connectionErrorIcon,
        alt: op.labels.connectionError
      }); connectionErrorIcon.hide();

      // onAddbutton click
      var onAdd = function(ev) {

        // populate blanks with default
        var s = graph.getSeries();
        if (s.length > 0) {
          var hsm = s[s.length-1].split(/::/);
          if (hsm.length >= 3) {
            if (host.value.length == 0 || host.value == host.title) host.value = hsm[0];
            if (service.value.length == 0 || service.value == service.title) service.value = hsm[1];
            if (metric.value.length == 0 || metric.value == metric.title) metric.value = hsm[2];
          }
        } 

        // display busy icon
        loadingIcon.show();

        // validate  
        new Ajax.Request(graph.options.urls.seriesAutocompleter, {
          method: 'get',
          parameters: {
            host: host.value,
            service: service.value,
            metric: metric.value,
            output: 'json',
            type: 'host'
          },
          onSuccess: function(xhr) {
            var json = xhr.responseJSON;
            
            // make series string  
            var s = host.value.strip() + "::" + service.value.strip() + "::" + metric.value.strip();

            // hide busy & failure icons
            loadingIcon.hide(); connectionErrorIcon.hide();

            // if valid
            if (json.ResultSet.count > 0) {
              // hide invalid, and failure icons
              invalidIcon.hide();

              // add to graph
              try { graph.addSeries(s);
              var exp;
              } catch (ex) { exp = ex; invalidIcon.show(); invalidIcon.title = ex; }

              // addSeries used to request data, but now do it on demand
              graph.requestAllData();

              // blank text boxes
              host.value = host.title;
              service.value = service.title;
              metric.value = metric.title;

              // if raised an exception, bubble it
              if (typeof exp != 'undefined') throw exp;
            } else {
              // invalid icon
              invalidIcon.show();
              invalidIcon.title = graph.options.labels.invalidSeries + ": " + s;
            }
          },
          onFailure: function(xhr) {
            // hide busy icon
            loadingIcon.hide();

            // show failure icon
            connectionErrorIcon.title = graph.options.labels.connectionError + ": " + xhr.statusText;
            connectionErrorIcon.show();
          },
          onException: function(req, err) {
            // hide busy icon
            loadingIcon.hide();
            // show failure icon
            connectionErrorIcon.title = graph.options.labels.connectionError + ": " + err;
            connectionErrorIcon.show();
          }
        });
      };
      Event.observe(addBtn, 'click', onAdd);
      var addOnEnter =  function(ev) {
        // add it
        if (ev.keyCode == 13) onAdd(ev);
      };
      Event.observe(host, 'keyup', addOnEnter);
      Event.observe(service, 'keyup', addOnEnter);
      Event.observe(metric, 'keyup', addOnEnter);

      // add to div
      this.element.appendChild(host);
      this.element.appendChild(service);
      this.element.appendChild(metric);
      this.element.appendChild($AG.createElement('br'));
      this.element.appendChild(addBtn);
      this.element.appendChild(loadingIcon);
      this.element.appendChild(invalidIcon);
      this.element.appendChild(connectionErrorIcon);

      // create autocompleters
      if (typeof Ajax.Autocompleter !== undefined) {

        // creates an autocompleter
        var me = this;
        function createAutocompleter(url, input, type, others) {
          // create div for choices
          var e = $AG.createElement('div', { 
            className: 'autocomplete', 
            id: input.id + "_autocompleter" });     
          me.element.appendChild(e);

          // create ajax control 
          var a = new Ajax.Autocompleter(input, e, url, {
             paramName: type,
             minChars: -1,  /* So that empty values will trigger an autocomplete list - 0 doesn't work */
             indicator: loadingIcon,
             onFailure: function(xhr) { loadingIcon.hide(); connectionErrorIcon.show(); },
             callback: function(ip, qs) {
               var p = qs.split(/=/);
               qs = p[0] + '=%25' + p[1] + '%25';
               qs += '&type=' + escape(type);
               for (t in others) { 
                 if (others[t].value.length > 0 && others[t].value != others[t].title)
                   qs += '&' + escape(t) + '=' + escape(others[t].value);
               }
               return qs;
             }
          });
          return e;
        }

        // create autocompleter for each input
        var url = graph.options.urls.seriesAutocompleter;
        createAutocompleter(url, host, 'host', { service: service, metric: metric });
        createAutocompleter(url, service, 'service', { host: host, metric: metric });
        createAutocompleter(url, metric, 'metric', { service: service, host: host });
      }
    },

    // returns element to add to DOM
    getElement: function() {
      return this.element;
    },

    // set focus to host box
    focus: function() {
      //var e = this.host;
      //setTimeout(function () { if (e.visible() && !e.disabled) { e.focus(); } }, 1000);
    }
  });

  var SeriesItemControl = Class.create(AjaxGraphs.SeriesItemControl, {
    // constructor
    initialize: function($super, graph, series) {
      // dont show thresholds in series
      if (/.*::.*::.*::(critical|warning)$/.test(series)) {
        this.element = null;
        return;
      }

      // super cons
      $super(graph, series);

      // strings
      var crit = "::critical",
          warn = "::warning";

      // are we currently showing thresholds for this series?
      var on = graph.state.series.indexOf(series + crit)>=0 ||
                 graph.state.series.indexOf(series + warn)>=0;

      // add thresholds checkbox
      var thresholdsOn = $AG.createElement('span', {}, 
        graph.options.labels.hideThresholds);
      var thresholdsOff = $AG.createElement('span', {}, 
        graph.options.labels.showThresholds);
      if (on) { thresholdsOn.show(); thresholdsOff.hide(); }
      else { thresholdsOn.hide(); thresholdsOff.show(); }

      // event handlers
      Event.observe(thresholdsOff, 'click', function() {
        // hide off, show on
        thresholdsOff.hide(); thresholdsOn.show();
        // add series
        var opts = graph.getSeriesOptions(series);
        var customNameW = null, customNameC = null;
        if (opts.customName != null) {
          customNameW = opts.customName + warn;
          customNameC = opts.customName + crit;
        }
        graph.addSeries(series + warn, true, 
          {visible: opts.visible, customName: customNameW} );
        graph.addSeries(series + crit, true, 
          {visible: opts.visible, customName: customNameC} );
      });
      Event.observe(thresholdsOn, 'click', function() {
        // hide on, show off
        thresholdsOn.hide(); thresholdsOff.show();
        // remove series
        graph.removeSeries(series + warn);
        graph.removeSeries(series + crit);
      });
      if (graph.options.flags.seriesRemoveButtons) {
        Event.observe(this.removeButton, 'click', function() {
          // remove series
          graph.removeSeries(series + warn);
          graph.removeSeries(series + crit);
        });
      }
      this.element.appendChild(thresholdsOn);
      this.element.appendChild(thresholdsOff);

      // handle custom name changes
      if (graph.options.flags.changeSeriesNames) {
        var input = this.input;
        Event.observe(input, 'blur', function() {
          // update custom name for threshold series
          graph.setSeriesOptions(series + warn, { customName: input.value + warn });
          graph.setSeriesOptions(series + crit, { customName: input.value + crit });
        }); 
        Event.observe(this.revertButton, 'click', function() {
          // update custom name for threshold series
          graph.setSeriesOptions(series + warn, { customName: series + warn });
          graph.setSeriesOptions(series + crit, { customName: series + crit });
        }); 
      }
    }
  });



  // Graph extends AjaxTimeGraphs.Graph
  var Graph = Class.create(AjaxTimeGraphs.Graph, {
    initialize: function($super, container, dataAdapter, options, state) {
      // default options
      var defaultOptions = {
        state: {
          yaxis: { min: 0, max: 1 }
        },
        flot: {
          main: {
            yaxis: { min: 0, max: 1 }
          },
          overview: {
            yaxis: { min: 0, max: 1 }
          }
        },
        classes: {
          // extend base controls
          addSeriesControl: AddSeriesControl, // overrides as h,s,m triple
          seriesItemControl: SeriesItemControl // adds thresholds checkboxes
        },
        labels: {
          addSeriesButton: "Add",
          addHost: "Host",
          addService: "Service",
          addMetric: "Metric",
          loading: "Loading...",
          invalid: "Invalid",
          invalidSeries: "Host, service, metric combination does not exist",
          showThresholds: "[Show thresholds]",
          hideThresholds: "[Hide thresholds]"
        },
        urls: {
          seriesAutocompleter: "http://..../search/performancemetric/",
          loadingIcon: "busy.png",
          invalidIcon: "invalid.png"
        },
        // y SI units
	// Need to have the 1-1000 range in there to select correctly, but we give it a blank name so not displayed in selection
        units: {
          yaxis: [
            { name: 'Raw', f: null },
            { name: 'Micro', min: 0.000001, max: 0.001, f: function(n,a) { return (n*1000000).toPrecision(3)+'u'; } },
            { name: 'Milli', min: 0.001, max: 1, f: function(n,a) { return (n*1000).toPrecision(3)+'m'; } },
            { name: '', min: 1, max: 1000, f: function(n,a) { return (n).toPrecision(3); } },
            { name: 'Kilo', min: 1000, max: 1000000, f: function(n,a) { return (n/1000).toPrecision(3)+'k'; } },
            { name: 'Mega', min: 1000000, max: 1000000000, f: function(n,a) { return (n/1000000).toPrecision(3)+'M'; } },
            { name: 'Giga', min: 1000000000, max: 1000000000000, f: function(n,a) { return (n/1000000000).toPrecision(3)+'G'; } },
            { name: 'Tera', min: 1000000000000, max: Number.POSITIVE_INFINITY, f: function(n,a) { return (n/1000000000000).toPrecision(3)+'T'; } }
          ]
        },
        unitsPerUOM: {
          "bytes": [
            { name: 'Raw', f: null },
            { name: 'Bytes', min: 1, max: 1000, f: function(n,a) { return (n).toPrecision(3)+'B'; } },
            { name: 'Kilobytes', min: 1000, max: 1000*1000, f: function(n,a) { return (n/1000).toPrecision(3)+'KB'; } },
            { name: 'Megabytes', min: 1000*1000, max: 1000*1000*1000, f: function(n,a) { return (n/(1000*1000)).toPrecision(3)+'MB'; } },
            { name: 'Gigabytes', min: 1000*1000*1000, max: 1000*1000*1000*1000, f: function(n,a) { return (n/(1000*1000*1000)).toPrecision(3)+'GB'; } },
            { name: 'Terabytes', min: 1000*1000*1000*1000, max: Number.POSITIVE_INFINITY, f: function(n,a) { return (n/(1000*1000*1000*1000)).toPrecision(3)+'TB'; } }
          ],
          "percent": [
             { name: 'Raw', f: null }, 
          ]
        }
      };
      options = $J.extend(true, defaultOptions, options);

      // call super constructor
      $super(container, dataAdapter, options, state);
    },

    /* This gets some min/max ranges for calculating the y-axis based on the overview */
    drawOverview: function($super) {
      var r = getDataRanges(this.data.overview);
      if (Object.isArray(r)) {
        var y = this.options.flot.overview.yaxis;
        /* If all data points are null (possible when just starting a new performance plot), we use the min/max values of the raw data instead */
        if(r[2] <= r[3]) {
            y.min = r[2];
            y.max = r[3];
        } else {
            r = getDataRanges(this.data.raw);
            if (Object.isArray(r)) {
                y.min = r[2];
                y.max = r[3];
            }
        }
        /* Test for reasonable values returned */
        if(y.min <= y.max) {
             // dontRequestData true because this occurs in response to data
             // it shouldnt trigger the request of more data
            this.setRanges( { yaxis: { from: y.min, to: y.max } }, false, true );
            this.drawGraph();
        }
      }

      // updates y-label with unit of measurement
      if (/\{\{uom\}\}/.test(this.state.yaxis.label)) {
        // find most common unit of measurement
        var uoms = {};
        var numUOM = 0, defUOM = null;
        for (var i=0,l=this.data.raw.length;i<l;i++) {
          var u = this.data.raw[i].uom;
          if (typeof u == 'string') {
            if (uoms[u] === undefined) uoms[u] = 1;
            else uoms[u]++;
            if (uoms[u] > numUOM) {
              numUOM = uoms[u];
              defUOM = u;
            }
          }
        }

        // insert most common unit of measurement
        if (defUOM != null) {
          this.setYLabel(this.state.yaxis.label.replace(/\{\{uom\}\}/g, defUOM));
        }
      }

      // draw graph
      $super();
    },

    // overriden because requesting an overlap returns
    // incorrect max/min/current values for the series tooltip
    getDataRanges: function() {
      return this.getRanges();
    }

  });

  // Public
  return {
    DataAdapter: DataAdapter,
    Graph: Graph,
    SeriesItemControl: SeriesItemControl,
    AddSeriesControl: AddSeriesControl
  };

}();
