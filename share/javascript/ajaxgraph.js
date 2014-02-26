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

// Ajax Graph
// JavaScript graphing framework
// Requires: prototype, ajaxglobals, excanvas, serialization, jquery, jquery.flot, jquery.noConflict, resizing
// Author: Tristan Aubrey-Jones, Opsview Limited 7/09/2009

// AjaxGraphs namespace
var AjaxGraphs = function() {

  // When true displays the debug console
  var debug = false;

  // calls a method for each point in a dataset
  function foreachPoint(d, func, fibre) {
    if (typeof func != 'function') throw ("func must be a function");
    if (typeof fibre == 'undefined') var fibre = null;
    // if has values
    if (typeof d == 'object' && d.length > 0) {
      // for each series
      for (var si = 0; si < d.length; si++) {
        // for each point
        var s = d[si].data;
        for (var i=0,l=s.length;i<l;i++) {
          var p = s[i]
          if (typeof p == 'object' && p != null && p.length >= 2)
            func(p, fibre);
        }
      }
    }
    return fibre;
  };

  // get max&min y values of points in a given x range
  function getYDataRange(d, xrange) {
    if (typeof d == 'object' && d.length > 0) {
      var minY = null, maxY = null;
      var r = foreachPoint(d, function(p) {
            if (p[1] != null && p[0] != null && p[0] > xrange.from && p[0] < xrange.to) {
              if (p[1] > maxY || maxY == null) maxY = p[1];
              if (p[1] < minY || minY == null) minY = p[1];
            }
      });
      return [minY, maxY];
    } else {
      return null;
    }
  };

  // DataAdapter gets data from json webservice
  var DataAdapter = Class.create({
    // constructor
    initialize: function() {
    },

    // abstract
    // query data source for data
    // params: callback - function(success, query, data) { }
    //         success - true when request worked, false otherwise.
    //         query - { series: ['series1', 'series2'],
    //                   ranges: {xaxis: {from: 0, to: 1}, yaxis: {from: 3, to: 4}} }
    query: function(success, query, callback) {
       //$AG.error("DataAdapter.query not implemented, abstract method.");
      callback(true, query, { lines: [] });
    }

  });

  // Graph type functions:
  // each function f(d) -> d
  // takes a dataset and returns a flot dataset
  var GraphTypes = Class.create({
    initialize: function() {
    },

    // forall objects in an array
    forall: function(ds, f) {
      if (typeof f != 'function') return ds;
      var d = [];
      for(var i=0,l=ds.length;i<l;i++) {
        if (typeof ds[i].color == 'undefined' || ds[i].color == null) ds[i].color = i;
        d.push(f(ds[i]));
      }
      return d;
    },

    // line graph
    lines: function(ds) {
      return this.forall(ds, function(d) {
        return {
          label: d.label,
          lines: { show: true },
          data: d.data,
          color: d.color
        };
      });
    },

    // line graph with points
    linesAndPoints: function(ds) {
      return this.forall(ds, function(d) {
        return {
          label: d.label,
          data: d.data,
          lines: { show: true },
          points: { show: true },
          color: d.color
        };
      });
    },

    // scatter graph
    points: function(ds) {
      return this.forall(ds, function(d) {
        return {
          label: d.label,
          data: d.data,
          points: { show: true },
          color: d.color
        };
      });
    },

    // bar chart
    bars: function(ds) {
      return this.forall(ds, function(d) {
        return {
          label: d.label,
          data: d.data,
          bars: { show: true },
          color: d.color
        };
      });
    },


    // stacked bar chart
    stacked: function(ds) {
      // result
      var r = [];

      // find first nonempty series
      var i = 0;
      while (i<ds.length && ds[i].data.length==0) {
        r.push( {
          label: ds[i].label,
          data: [],
          color: (typeof ds[i].color == 'string' ? ds[i].color : i)
        } );
        i++;
      }
      if (i >= ds.length) return r;

      // add first non empty series to plot
      r.push({
        label: ds[i].label,
        data: ds[i].data,
        lines: { show: true, fill: true },
        color: (typeof ds[i].color == 'string' ? ds[i].color : i)
      });

      // clone this series data for sum of plot
      var sum = [];
      for (var di=0,l=ds[i].data.length;di<l;di++) {
        var p = ds[i].data[di];
        var c = null;
        if (p != null) c = [ p[0], p[1] ];
        sum.push(c);
      }

      // foreach other series
      i++;
      for (var l=ds.length;i<l;i++) {
        var nd=[];
        var s = ds[i].data;
        // iterate through both sets, correlating on x
        var ai=0,al = sum.length;
        for (var bi=0,bl=s.length;bi<bl;bi++) {
          // skip through sum to correlate x
          while (ai<al && (s[bi] == null || sum[ai] == null || sum[ai][0] < s[bi][0])) ai++;
          if (ai>=al) break;
          // sum y values
          sum[ai][1] += s[bi][1];
          // add to new data
          nd.push([ s[bi][0], sum[ai][1] ]);
        }
        // add series to result
        r.push({
          label: ds[i].label,
          data: nd,
          lines: { show: true, fill: true },
          color: (typeof ds[i].color == 'string' ? ds[i].color : i)
        });
      }

      // reverse array
      r = r.reverse();

      // return result
      return r;
    }

  });

  // State of control, preserved across sessions
  var State = Class.create(Serializable, {
    // constructor
    initialize: function($super, serialized) {
      $super();

      // fields
      this.title = ""; // title (max 255 chars)
      this.xaxis = {
        min: null, // min x
        max: null,  // min y
        unit: null // idx of unit to use
      };
      this.yaxis = {
        min: null, // min y
        max: null, // max y
        label: "", // y label (max 255 chars)
        unit: null // idx of unit to use
      };
      this.series = []; // array of series names
      this.seriesOptions = []; // array of series options
      this.graphType = ''; // graph type
      this.size = { // size of graph in pixels
        w: null,
        h: null
      };
      this.validFlag = true; // used to validate deserializations
      this.autoScale = { // should this axis be autoscaled
        x: false,
        y: true
      };
      this.showLegend = true; /*graph.options.flags.showLegend*/ // show or hide legend

      // deserialize
      if (typeof serialized == 'string') {
        this.deserialize(serialized);
      }
      // defaults
      else if (typeof serialized == 'object') {
        $J.extend(true, this, serialized);
      }
    },

    // returns type info for serialization
    getTypeInfo: function($super) {
      var a=$super();
      a.push(['title', 'shortstring']);
      a.push(['xaxis', [
        ['min', { sigfigs: 13 } ],
        ['max', { sigfigs: 13 } ],
        ['unit', 'byte']
      ]]);
      a.push(['yaxis', [
        ['min', { sigfigs: 13 } ],
        ['max', { sigfigs: 13 } ],
        ['label', 'shortstring'],
        ['unit', 'byte']
      ]]);
      a.push(['series', { array: 'shortstring' }]);
      a.push(['seriesOptions', { array: [
        ['visible', 'boolean'],
        ['customName', 'shortstring']
      ]}]);
      a.push(['graphType', 'shortstring']);
      a.push(['size', [
        ['w', 'integer'],
        ['h', 'integer']
      ]]);
      a.push(['validFlag', 'boolean']);
      a.push(['autoScale', [
        ['x', 'boolean'],
        ['y', 'boolean']
      ]]);
      a.push(['showLegend', 'boolean']);
      return a;
    }
  });

  // default class for "add series" control
  var AddSeriesControl = Class.create(AjaxGlobals.Control, {
    // fields:
    // - this.element - <div>Add Series: <br /><input... /></div>
    // - this.input - <input type='text'.../>

    // constructor
    initialize: function($super, graph) {
      // init elements
      this.element = $AG.createElement('div', {}, "<span class='graph-heading'>" + graph.options.labels.addSeriesTitle + ":</span>");
      var ip = $AG.createElement('input', { type: "text" });
      this.input = ip;
      var textChanged = function() {
        if (ip.value.length > 0) {
          graph.addSeries(ip.value);
          ip.value = "";
        }
      };
      Event.observe(ip, 'blur', textChanged);
      Event.observe(ip, 'keyup', function(ev) {
        if (ev.keyCode == 13) textChanged();
      });
      this.element.appendChild(ip);
    },

    // returns element to add to DOM
    getElement: function() {
      return this.element;
    }
  });

  // control for each li item in the list
  var SeriesItemControl = Class.create(AjaxGlobals.Control, {
    // constructor:
    initialize: function($super, g, series) {
      // assign
      this.graph = g;
      this.series = series;

      // text element
      var name = g.getSeriesOptions(series).customName;
      if (name == null) name = series;
      this.element = $AG.createElement('li', { title: series });
      var span = $AG.createElement('span', { title: series }, name);
      this.element.appendChild(span);

      // input element (for editable series names)
      if (g.options.flags.changeSeriesNames) {
        var input = $AG.createElement('input', { title: series, value: name, size: series.length });
        this.input = input;
        input.hide();
        this.element.appendChild(input);
      }

      // remove button
      if (g.options.flags.removeSeriesButtons) {
        this.removeButton = $AG.createElement('span', { className: "graph-btn",  title: g.options.labels.removeSeriesTitle },
         g.options.labels.removeSeries);
        Event.observe(this.removeButton, 'click', g.removeSeriesFunction(series));
        this.element.appendChild(this.removeButton);
      }

      // series name changing
      if (g.options.flags.changeSeriesNames) {
        // revert button (changes back to fill series name)
        var revert = $AG.createElement('span', {className: 'graph-btn'}, g.options.labels.revertSeriesButton);
        this.revertButton = revert;
        if (name == series) revert.hide();
        this.element.appendChild(revert);

        // event handlers
        // series name change
        Event.observe(span, 'click', function() {
          span.hide(); input.show();
        });
        var change = function() {
          // hide text box, and update span
          span.innerHTML = input.value;
          input.hide(); span.show();
          // show hide revert button
          if (input.value != series) revert.show();
          else revert.hide();
          // change series options
          var v= (input.value == series) ? null : input.value;
          g.setSeriesOptions(series, { customName: v });
          g.drawGraph();
        };
        Event.observe(input, 'keypress', function(ev) {
          if (ev.keyCode == 13) change();
        });
        Event.observe(input, 'blur', function() {
          change();
        });
        // revert click
        Event.observe(revert, 'click', function() {
          input.value = series;
          change();
        });
      }
    },

    // returns element to add to DOM
    getElement: function() {
      return this.element;
    }

  });

  // tooltip control
  var pointTooltip = null;
  var legendTooltip = null;
  var TooltipControl = Class.create(AjaxGlobals.Control, {
    initialize: function($super, cssClass, remainMouseOver) {
      // super
      $super();

      // create element
      this.element = $AG.createElement('div', {
        className: (typeof cssClass == 'string') ? cssClass : 'tooltip'
      }, 'tooltip');
      this.element.style.position = "absolute";
      this.element.hide();
      this.jelement = $J(this.element);

      // if should stay visible when mouse is over it
      this.stayVisible = false;
      this.visible = false;
      if (typeof remainMouseOver == 'boolean' && remainMouseOver) {
        var me = this;
        Event.observe(this.element, 'mouseover', function() {
          me.stayVisible = true;
          if (!me.visible) me.show();
        });
        Event.observe(this.element, 'mouseout', function() {
          me.stayVisible = false;
          if (!me.visible) me.hide();
        });
      }

      // inject into document
      document.body.appendChild(this.element);
    },

    getElement: function() {
      return this.element;
    },

    // set color
    setColor: function(c) {
      this.element.style.backgroundColor = c;
    },

    // set location
    setLocation: function(x,y) {
      this.element.style.top = y + "px";
      this.element.style.left = x + "px";
    },

    // appear
    show: function() {
      this.visible = true;
      this.jelement.fadeIn(200);
    },

    // disappear
    hide: function() {
      this.visible = false;
      if (!this.stayVisible) {
        this.jelement.fadeOut(200);
      }
    }

  });

  // default class for "options control" in the drop down
  var OptionsControl = Class.create(AjaxGlobals.Control, {
    // fields:
    // - this.element - main div
    // - this.graphType - graph type drop down select box

    // constructor
    initialize: function($super, graph) {
      this.element = $AG.createElement('div', { className: "graph-options" },
        "<span class='graph-heading'>" + graph.options.labels.optionsTitle + ":</span>");

      // graph type drop down
      if (graph.options.flags.graphTypes) {
        var tdd = $AG.createElement('select', {
          id: $AG.uuid(),
          multiple: false,
         size: 1
        });
        this.graphType = tdd;
        for (var k in graph.options.labels.graphTypes) {
          if (typeof graph.options.graphTypes[k] == 'function') {
            tdd.appendChild($AG.createElement('option', {
              value: k,
              selected: (graph.getGraphType == k)
            }, graph.options.labels.graphTypes[k]));
          }
        }
        Event.observe(tdd, 'change', function(ev) {
          graph.setGraphType(Form.Element.getValue(tdd));
        });
        var tLbl = $AG.createElement('label', {
          'for': tdd.id
        }, graph.options.labels.graphType);
        this.element.appendChild(tLbl);
        this.element.appendChild(tdd);
        this.element.appendChild($AG.createElement('br'));
      }

      // units drop downs
      var me = this;
      function unitDD(insertionElement, label, list) {
        var dd = $AG.createElement('select', {
          id: $AG.uuid(),
          multiple: false,
          size: 1
        });
        dd.appendChild($AG.createElement('option', {
          value: '-1'
        }, graph.options.labels.autoUnits));
        for (var i=0,l=list.length;i<l;i++) {
	  if (list[i].name) {
          dd.appendChild($AG.createElement('option', {
            value: i
          }, list[i].name));
	  }
        }
        var lbl = $AG.createElement('label', {
          'for': dd.id
        }, label);
        insertionElement.appendChild(lbl);
        insertionElement.appendChild(dd);
        return dd;
      };
      if (graph.options.flags.xUnits && graph.options.units.xaxis.length > 0) {
        this.xunits = unitDD(this.element, graph.options.labels.xUnitsLabel, graph.options.units.xaxis);
        Event.observe(this.xunits, 'change', function(ev) {
          var i = Form.Element.getValue(me.xunits);
          graph.setUnits('x', i);
        });
        this.element.appendChild($AG.createElement('br'));
      }
      // Create placeholder for yunits drop down
      this.yunitsDropDown = $AG.createElement('span');
      this.element.appendChild(this.yunitsDropDown);
      // Function to cause refresh of list - needs to run after data received to work out what uom is
      this.yunitsDropDownRefresh = function() {
        if (graph.options.flags.yUnits) {
          // Delete last list before adding new one
          while( this.yunitsDropDown.hasChildNodes() ) {
            this.yunitsDropDown.removeChild( this.yunitsDropDown.firstChild );
          }
          this.yunits = unitDD(this.yunitsDropDown, graph.options.labels.yUnitsLabel, graph.getYUnitArrayByUOM());
          Event.observe(this.yunits, 'change', function(ev) {
            var i = Form.Element.getValue(me.yunits);
            graph.setUnits('y', i);
          });
          this.yunitsDropDown.appendChild($AG.createElement("br"));
        }
      }
      if (graph.options.flags.legendControl) {
        var cbLegendControl = $AG.createElement('input', {
          type: 'checkbox',
          id: 'showlegend' + $AG.uuid(),
          defaultChecked: graph.options.flags.showLegend && graph.state.showLegend
        });
        this.showLegend = cbLegendControl;
        var lblLegend = $AG.createElement('label',
          { 'for': cbLegendControl.id }, graph.options.labels.legendControl);
        Event.observe(cbLegendControl, 'change', function() {
          graph.state.showLegend = cbLegendControl.checked;
          graph.options.flot.main.legend.show=graph.state.showLegend;
          graph.drawGraph();
        });
        this.element.appendChild(lblLegend);
        this.element.appendChild(cbLegendControl);
        this.element.appendChild($AG.createElement('br'));
      }
    },

    // returns element to add to DOM
    getElement: function() {
      return this.element;
    }
  });

  // stores current graph count
  var graphCounter = 0;

  // helper methods

  // adds some data (replaces/appends) to a data array
  // adds nds to ds
  var addDataToData = function(ds, nds) {
    // for all series in data
    for (var i=0,l=nds.length;i<l;i++) {
      // if line already exists in data
      var line = nds[i];
      for (var t=0,tl=ds.length;t<tl;t++) {
        if (ds[t].label == line.label) {
          // replace it
          ds.splice(t,1,line);
          line = false;
          break;
        }
      }

      // otherwise append line to data set
      if (line) ds.push(line);
    }
  };

  // removes a series from a data array
  var removeSeriesFromData = function(ds, s) {
    for (var i=0,l=ds.length;i<l;i++) {
      if (ds[i].label == s) { ds.splice(i,1); break ;}
    }
  };

  // finds and returns a series from a dataset by name
  var findSeries = function(ds, sname) {
    for (var i=0,ln=ds.length;i<ln;i++) {
      var s = ds[i];
      if (s.label == sname) return s;
    }
    return null;
  };

  // adds a series to the HTML <li> list in graph options
  function addSeriesToHTMLList(series, g) {
    var item = new g.options.classes.seriesItemControl(g, series);
    if (item.getElement() != null) {
      g.divs.seriesList.appendChild(item.getElement());
    }
  };

  // global static variable
  var graphStackZIndex = 100;

  // Graph widget
  var Graph = Class.create(Serializable, {
    // constructor
    initialize: function($super, container, dataAdapter, options, state) {
      // default options
      var defaultOptions = {
        // flot config
        flot: {
          main: {
            xaxis: { min: 0, max: 1, labelHeight: Prototype.Browser.IE ? 25 : 15 },
            yaxis: { min: 0, max: 1, labelWidth: 25 },
            legend: { position: 'ne', backgroundColor: 'transparent' },
            selection: { mode: "x" },
            grid: {
              backgroundColor: '#ffffff',
              hoverable: true, clickable: true
            }
          },
          overview: {
            lines: { show: true, lineWidth: 1 },
            shadowSize: 0,
            xaxis: { min: 0, max: 1, labelHeight: 10 },
            yaxis: { ticks: [],  min: 0, max: 1.0 },
            legend: { show: false },
            grid: { backgroundColor: '#ffffff' }
          }
        },
        // zoom buttons
        zooms: [
          // in form { label: "<label for zoom>", width: <width of graph>, height: <height of graph>  }
          // e.g. { label: "10 wide", width: 10 }
          //      { label: "100 square", width: 100, height: 100 }
          //      { label: "PI high", height: 3.14 }
        ],
        // default state
        state: {
          xaxis: { min: 0, max: 1 },
          yaxis: { min: 0, max: 1, label: "Y" },
          title: "Graph",
          graphType: "lines"
        },
        // textual/html labels
        labels: {
          loadingIndicator: "Loading...",
          promptYLabelMessage: "Please enter a label for the y axis",
          menuDown: "(+) Graph options",
          menuUp: "(-) Graph options",
          closeDropDown: "[Close]",
          clickToEdit: "Click to edit",
          zoomTooltip: "Click to zoom",
          panLeft: "&lt&lt;",
          panRight: "&gt;&gt;",
          rescaleYAxis: "Autoscale Y Axis",
          rescaleYAxisButton: "[Autoaxis]",
          rescaleYAxisButtonOff: "[Autoaxis off]",
          removeSeries: "[Remove]",
          removeSeriesTitle: "Remove from graph",
          revertSeriesButton: "[Use fullname]",
          optionsTitle: "Options",
          graphType: "Graph type",
          graphTypes: {
            lines: "Line",
            points: "Scatter",
            linesAndPoints: "Line (with points)",
            bars: "Bar",
            stacked: "Stacked"
          },
          seriesTitle: "Series",
          addSeriesTitle: "Add Series",
          panLeft: "&lt;&lt;",
          panLeftTooltip: "Pan left",
          panRight: "&gt;&gt;",
          panRightTooltip: "Pan right",
          autoUnits: "Automatic",
          connectionError: "Connection error",
          linkButton: "Link",
          linkDropDownText1: "Paste link in email or IM",
          linkDropDownText2: "Paste HTML to embed in website",
          xUnitsLabel: "X Units",
          yUnitsLabel: "Y Units",
          legendControl: "Show legend",
          exportText: "Export",
          goLink: "Go"
        },
        // urls
        urls: {
          svgYLabel: "ajaxgraph-ylabel.svg",
          connectionErrorIcon: "connection-error.png",
          bookmarkLink: 'http://...?state={{state}}',
          embedTag: "<iframe src='{{state}}'></iframe>"
        },
        // pluggable classes
        classes: {
          addSeriesControl: AddSeriesControl,
          seriesItemControl: SeriesItemControl,
          optionsControl: OptionsControl
        },
        // graph type functions
        graphTypes: new GraphTypes(),
        // units
        units: {
          // list of all units
          xaxis: [
            // in form { name: '<Name of unit>',
            //                 f: function(num,axes) { <returning num as string with unit> }
            //                 [ min: <min value suitable for>, ] [ max: <max unit suitable for>, ]
            // e.g. { name: 'None', f: null },
            //      { name: 'Milliseconds', f: function(n,a) { return (n*1000).toFixed(3) + "ms"; },
            //        min: 0.00001, max: 1 },
            //      { name: 'Seconds', f: function(n,a) { return (n).toFixed(3) + "m"; },
            //        min: 1, max: 60 }
            //      { name: 'Minutes', f: function(n,a) { return (n/60).toFixed(3) + "mins"; },
            //        min: 60, max: 60*60 },
            //      { name: 'Hours', f: function(n,a) { return (n/60/60).toFixed(3) + "hours"; },
            //        min: 60*60, max: 60*60*24 }
          ],
          yaxis: [
            // same as x
            // e.g.
            // { name: 'Kilo', min: 100, f: function(n,a) { return sigFigs(n/1000,3)+'k'; } },
            // { name: 'Mega', min: 10000, f: function(n,a) { return sigFigs(n/1000000,3)+'M'; } },
            // { name: 'Giga', min: 10000000, f: function(n,a) { return sigFigs(n/1000000000,3)+'G'; } }
          ],
          // current units
          current: {
            xaxis: null,
            yaxis: null
          }
        },
        // flags for turning features on and off
        flags: {
          showTooltip: true, // display tooltip
          showLegend: true, // display legend on graph
          legendControl: true, // display legend on graph
          // titlebar
          titleBar: true, // display title bar
          titleEditable: true, // title is edittable
          // customize y axis
          yLabel: true, // display y axis label
          yLabelEditable: true, // y axis label is editable
          // customize x axis
          xLabel: true, // display x axis label
          xLabelEditable: true, // xaxis label is editable
          xOverview: true, // show overview bar along x axis
          // customize toolbar
          toolBar: true, // display toolbar
          xPanningButtons: true, // display x panning buttons
          rescaleAxisButton: true, // display rescale axis button
          zoomButtons: true, // display zoom buttons
          linkDropDown: true, // display link drop down
          // customize graph options drop down
          optionsDropDown: true, // display options drop down
          graphOptionsControl: true, // display graph options control
          graphTypes: true, // display different graph types
          xUnits: true, // display list of x units in options
          yUnits: true, // display list of different y units in options drop down
          addSeriesControl: true, // display box for adding a series
          seriesListControl: true, // display series list
          changeSeriesNames: true, // series names are editable
          removeSeriesButtons: true // series can be removed from the graph
        }
      };

      // init options
      this.options = (typeof options == 'object') ? $J.extend(true, defaultOptions, options)  : defaultOptions;
      this.options = $J.extend(true, this.options, {
        flot: { main: { legend: { show: this.options.flags.showLegend } } }
      });

      // fields
      this.adapter = dataAdapter; // data source
      this.state = (typeof state == 'object') ? state : ((typeof state == 'string') ? new State(state) : new State(this.options.state));
      this.divs = {
        main: $(container),
        graph: null,
        overview: null,
        title: null,
        toolbar: null,
        ylabel: null
      };
      this.graphs = {
        main: null,
        overview: null
      };
      this.data = {
        raw: [], // raw data (straight from json responses)
        graph: [], // data processed by current graphtype
        overview: [], // overview data
        ranges: this.getDataRanges() // ranges that raw/graph cover
      };


      // call super constructor (must be here as state needs to be defined to get typeinfo)
      $super();

      // init
      this.initElements(); // create elements
      this.initGraphs(); // populate with graphs
    },

    // returns type info for serialization
    getTypeInfo: function($super) {
      var a=$super();
      a.push(['state', State.prototype.getTypeInfo()]);
      return a;
    },

    // save state
    saveState: function() {

      this.state.validFlag = true;
      return escape(this.state.serialize());
    },

    // load state
    loadState: function(str) {
      // deserialize
      var s = this.state, d = this.divs;
      s.validFlag = false; // deserializing should set this to true
      s.deserialize(unescape(str));
      if (!s.validFlag) {
        this.setOptionsMenuVisibility(true);
        alert("Invalid graph bookmark. Could not restore graph from saved state:\n\n" + str + "\n\n" + Object.toJSON(s));
        throw "Invalid state string";
      }
      // update controls
      this.setTitle(s.title);
      this.setYLabel(s.yaxis.label);
      // set size
      if (s.size != null) {
        if (s.size.w != null) d.main.style.width = s.size.w + "px";
        if (s.size.h != null) d.main.style.height = s.size.h + "px";
      }
      // add series to list
      for (var i=0,l=s.series.length;i<l;i++) {
        addSeriesToHTMLList(s.series[i],this);
      }
      // set if legend is visible
      this.options.flot.main.legend.show=this.state.showLegend;
      this.divs.graphOptions.showLegend.checked=this.state.showLegend;
      // layout
      this.layout();
      // request data for all series
      this.data.ranges = this.getDataRanges();
      this.requestData(s.series);
      this.requestOverviewData(s.series);
    },

    // creates HTML elements
    initElements: function() {
      var me = this, divs = this.divs, flags = this.options.flags;
      // add style to root
      if (!divs.main.hasClassName('ajaxgraph')) {
        divs.main.addClassName('ajaxgraph');
      }

      // create containers
      divs.bg = $AG.createElement('div', {
        className: "background"
      });
      divs.graph = $AG.createElement('div', {
        className: "graph-placeholder"
      });
      if (flags.titleBar) {
        divs.title = $AG.createElement('div', {
          className: "graph-title",
          title: this.options.labels.clickToEdit
        }, this.state.title);
      }
      if (flags.toolBar) {
        divs.toolbar = $AG.createElement('div', {
          className: "graph-toolbar"
        });
      }
      if (flags.yLabel) {
        divs.ylabel = $AG.createElement('div', {
          className: "graph-y-label",
          title: flags.yLabelEditable ? this.options.labels.clickToEdit : ""
        });
        if (Prototype.Browser.IE) {
          divs.ylabel.style.writingMode = "tb-rl";
          divs.ylabel.style.filter = "flipv fliph";
        }
      }
      if (flags.xOverview) {
        divs.overview = $AG.createElement('div', {
          className: "graph-overview"
        });
      }

      // layout based on flags
      if (flags.toolBar) {
        if (!flags.titleBar) {
          // move toolbar to top
          divs.toolbar.style.top = "0px";
          divs.toolbar.style.borderTop = "none";
          // move graph up
          divs.graph.style.top = "30px";
          if (flags.yLabel) divs.ylabel.style.top = "30px";
        }
      } else {
        if (flags.titleBar) {
          divs.graph.style.top = "30px";
          if (flags.yLabel) divs.ylabel.style.top = "30px";
        } else {
          divs.graph.style.top = "0px";
          if (flags.yLabel) divs.ylabel.style.top = "0px";
        }
      }
      if (!flags.yLabel) {
        divs.graph.style.left = "0px";
        if (flags.xOverview) divs.overview.style.left = "20px";
      }

      // create editable title
      if (flags.titleBar && flags.titleEditable) {
        divs.titleEdit = $AG.createElement('input', {
          type: "text",
          className: "graph-title-textbox",
          value: this.state.title,
          title: this.options.labels.clickToEdit
        });
        divs.titleEdit.hide();
        Event.observe(divs.title, 'click', function () {
          divs.titleEdit.show();
        });
        var titleBlur = function() {
          divs.titleEdit.hide();
          me.setTitle(divs.titleEdit.value);
        };
        Event.observe(divs.titleEdit, 'blur', titleBlur);
        Event.observe(divs.titleEdit, 'keyup', function(ev) {
          if (ev.keyCode == 13) titleBlur();
        });
      }

      // create drop down options
      if (flags.toolBar && flags.optionsDropDown) {
        divs.dropDownButton = $AG.createElement('div',
          { className: "graph-dropdown-btn" },
          this.options.labels.menuDown);
        divs.toolbar.appendChild(divs.dropDownButton);
        divs.dropDown = $AG.createElement('div',
          { className: "graph-dropdown" });
        // close drop down
        divs.closeDropDown = $AG.createElement('div',
          { className: 'graph-dropdown-close' }, this.options.labels.closeDropDown);
        divs.dropDown.appendChild(divs.closeDropDown);
        // options control
        if (flags.graphOptionsControl) {
          var graphOptions = new this.options.classes.optionsControl(this);
          divs.graphOptions = graphOptions;
          $AG.assert(graphOptions.getElement, "AjaxGraph 'OptionsControl' class must define a getElement() method.");
          divs.dropDown.appendChild(graphOptions.getElement());
        }
        // series list
        if (flags.seriesListControl) {
          divs.seriesListHeading = $AG.createElement('span', {className: 'graph-heading'}, "<br/>" + me.options.labels.seriesTitle + ':');
          //divs.seriesListHeading = $AG.createElement('span', {className: 'graph-heading'}, 'Series:');
          divs.dropDown.appendChild(divs.seriesListHeading);
          divs.seriesList = $AG.createElement('ul', {className: 'series-list'});
          for (var i=0,l=this.state.series.length;i<l;i++) {
            var s = this.state.series[i];
            addSeriesToHTMLList(s, this);
          }
          divs.dropDown.appendChild(divs.seriesList);
        }
        // add series control
        if (flags.addSeriesControl) {
          var addSeries = new this.options.classes.addSeriesControl(this);
          $AG.assert(addSeries.getElement, "AjaxGraph 'AddSeriesControl' class must define a getElement() method.");
          divs.dropDown.appendChild(addSeries.getElement());
        }
        // drop down show/hide
        divs.dropDown.hide();
        var toggleDD = function() {
          var v = divs.dropDown.visible();
          // update button
          var t = v ? me.options.labels.menuDown : me.options.labels.menuUp;
          divs.dropDownButton.update(t);
          // blind up/down
          var e = false;
          $AG.Effect.BlindToggle(divs.dropDown);
          // give add series control focus
          if (flags.addSeriesControl && !v && typeof addSeries.focus == 'function') addSeries.focus();
        };
        Event.observe(divs.dropDownButton, 'click', toggleDD);
        Event.observe(divs.closeDropDown, 'click', toggleDD);
      }

      // create panning buttons
      if (flags.toolBar && flags.xPanningButtons) {
        var lbls = this.options.labels;
        divs.panBtns = {
          left: $AG.createElement('span', {title: lbls.panLeftTooltip, className: 'pan-btn'}, lbls.panLeft),
          right: $AG.createElement('span', {title: lbls.panRightTooltip, className: 'pan-btn'}, lbls.panRight)
        };
        var panning = false;
        var pan = function(xdir, ydir) {
          var r = me.getRanges();
          var dx = xdir * (r.xaxis.to - r.xaxis.from) / 5.0,
              dy = ydir * (r.yaxis.to - r.yaxis.from) / 5.0;
          panning = true;
          var f = function() {
            if (panning) {
              r.xaxis.from += dx;
              r.xaxis.to += dx;
              r.yaxis.from += dy;
              r.yaxis.to += dy;
              me.setRanges(r);
              setTimeout(f, 200);
            }
          };
          f();
        };
        Event.observe(divs.panBtns.left, 'mousedown', function() { pan(-1, 0); });
        Event.observe(document, 'mouseup', function() { panning = false; });
        Event.observe(divs.panBtns.right, 'mousedown', function() { pan(1, 0); });
        Event.observe(document, 'mouseup', function() { panning = false; });
        divs.toolbar.appendChild(divs.panBtns.left);
      }

      // create zoom buttons
      if (flags.toolBar && flags.zoomButtons) {
        divs.zoomBtns = $AG.createElement('span', { className: "graph-zoom-btns" });
        divs.toolbar.appendChild(divs.zoomBtns);
        function zoomClick(zoom,e) {
          return function () {
            me.setZoom(zoom);
            if (!e.hasClassName('selected')) e.addClassName('selected');
          };
        };
        for (var i=0,l=me.options.zooms.length;i<l;i++) {
          var z=me.options.zooms[i];
          var e=$AG.createElement('a', { title: this.options.labels.zoomTooltip }, z.label+' ');
          divs.zoomBtns.appendChild(e);
          Event.observe(e, 'click', zoomClick(z,e));
        }
      }

      // append right pan button after zooms
      if (flags.toolBar && flags.xPanningButtons) {
        divs.toolbar.appendChild(divs.panBtns.right);
      }

      // rescale y axis button
      if (flags.toolBar && flags.rescaleAxisButton) {
        divs.rescaleYAxis = $AG.createElement('span', {});
        var rson = $AG.createElement('span', {
          className: 'toolbar-btn',
          title: this.options.labels.rescaleYAxis
        }, this.options.labels.rescaleYAxisButton);
        divs.rescaleYAxis.appendChild(rson);
        var rsoff  = $AG.createElement('span', {
          className: 'toolbar-btn',
          title: this.options.labels.rescaleYAxis
        }, this.options.labels.rescaleYAxisButtonOff);
        rsoff.hide();
        divs.rescaleYAxis.appendChild(rsoff);
        var rsf = function() {
          // toggle on off
          var value = !me.state.autoScale.y;
          me.state.autoScale.y = value;
          if (value) { rson.show(); rsoff.hide(); }
          else { rson.hide(); rsoff.show(); }

          // if turning on - autoscale now
          if (value) {
            // get flot's max & min
            var y = me.graphs.main.getAxes().yaxis;
            var dy=y.datamax-y.datamin;
            me.setRanges( { yaxis: { from: /*(y.datamin > 0) ? 0.0 :*/ y.datamin - (dy/10),
                                     to: /*(y.datamax < 0) ? 0.0 :*/ y.datamax + (dy/10) } } );
          }
          // if turning off - use overview's scale
          else {
            var y = me.graphs.overview.getAxes().yaxis;
            var dy=(y.datamax-y.datamin)/10;
            me.setRanges( { yaxis: { from: y.datamin-dy, to: y.datamax+dy } } );
          }
        };
        Event.observe(rson, 'click', rsf);
        Event.observe(rsoff, 'click', rsf);

        divs.toolbar.appendChild(divs.rescaleYAxis);
      }

      // loading and error icons
      if (flags.toolBar) {
        divs.loading = $AG.createElement('span', {
          className: "graph-loading"
        }, this.options.labels.loadingIndicator);
        divs.loading.hide();
        divs.error = $AG.createElement('img', {
          className: "graph-loading",
          src: this.options.urls.connectionErrorIcon,
          alt: this.options.labels.connectionError
        });
        Event.observe(divs.error, 'click', function() {
          me.requestAllData();
        });
        divs.error.hide();
        divs.toolbar.appendChild(divs.error);
        divs.toolbar.appendChild(divs.loading);
      }

      // for ie, so drop down appears on top over next graph
      // use decreasing z-indexes for graphs
      divs.main.style.zIndex = --graphStackZIndex;

      // add to main div
      var msg = $AG.createElement('span', {}, 'Loading...');
      divs.main.parentNode.replaceChild(msg,divs.main);
      divs.main.appendChild(divs.bg);
      if (flags.yLabel) divs.main.appendChild(divs.ylabel);
      if (flags.titleBar) divs.main.appendChild(divs.title);
      if (flags.titleBar && flags.titleEditable) divs.main.appendChild(divs.titleEdit);
      if (flags.toolBar) divs.main.appendChild(divs.toolbar);
      divs.main.appendChild(divs.graph);
      if (flags.xOverview) divs.main.appendChild(divs.overview);
      if (flags.toolBar && flags.optionsDropDown) divs.main.appendChild(divs.dropDown);
      msg.parentNode.replaceChild(divs.main,msg);

      // register event handlers for ylabel
      var ylabelClick = function() {
        me.setYLabel(prompt(me.options.labels.promptYLabelMessage+":", me.getYLabel()));
      };
      if (flags.yLabelEditable)
        Event.observe(divs.ylabel, 'click', ylabelClick);

      // fallback to svg ylabel for non MSIE
      if (flags.yLabel && !Prototype.Browser.IE) {
        if (typeof window.svgmethods == 'undefined') window.svgmethods = [];
        divs.ylabelsvg = $AG.createElement('embed', {
          src: this.options.urls.svgYLabel,
          type: "image/svg+xml",
          frameborder: "no",
          width: "100%",
          height: "100%",
          title: this.options.labels.clickToEdit,
          onload: function () {
            // when svg loaded
            var svg = divs.ylabelsvg.getSVGDocument();
            var lbl = svg.getElementById('label');
            // set text
            if (typeof lbl != 'undefined') {
              divs.ylabelsvg_label = lbl;
              lbl.replaceChild(document.createTextNode(me.state.yaxis.label), lbl.childNodes[0]);
            }
            // register for clicks
            if (flags.yLabelEditable) {
              var grp = svg.getElementById('group');
              if (grp) {
                Event.observe(grp, 'click', ylabelClick);
              }
            }
            // if needs to set bg color because svg background defaults to white...
            if (Prototype.Browser.WebKit) {
              // get background colour
              var c = $AG.getComputedStyle(divs.bg, 'background-color');
              // set fill to it
              svg.documentElement.style.backgroundColor = c;
            }
          }
        });
        divs.ylabel.appendChild(divs.ylabelsvg);
      }
      if (flags.yLabel) me.setYLabel(me.state.yaxis.label);

      // add a link drop down
      if (flags.toolBar && flags.linkDropDown) {
        var d=this.divs;
        d.linkDropDown = $AG.createElement('div',
          { className: 'link-dropdown'});
        var ddClose = $AG.createElement('div',
          { className: 'graph-dropdown-close' },
         me.options.labels.closeDropDown);
        Event.observe(ddClose, 'click', function() { $AG.Effect.BlindUp(d.linkDropDown); });
        d.linkDropDown.appendChild(ddClose);
        d.linkDropDown.appendChild($AG.createElement('span', {},
          me.options.labels.linkDropDownText1 + "<br />"));

        d.linkUrlBox = $AG.createElement('input',
          { type: 'text' });
        var select = function() { this.select(); return false; };
        Event.observe(d.linkUrlBox, 'click', select);
        d.linkDropDown.appendChild(d.linkUrlBox);
        var aLink = $AG.createElement('a', { target: '_top' }, me.options.labels.goLink);
        d.linkDropDown.appendChild(aLink);
        d.linkDropDown.appendChild($AG.createElement('br'));

        d.linkDropDown.appendChild($AG.createElement('span', {},
          me.options.labels.linkDropDownText2 + "<br />"));
        d.linkEmbedBox = $AG.createElement('input',
          { type: 'text' });
        var select = function() { this.select(); };
        Event.observe(d.linkEmbedBox, 'click', select);
        d.linkDropDown.appendChild(d.linkEmbedBox);
        d.linkDropDown.appendChild($AG.createElement('br'));
        d.linkDropDown.hide();

        d.main.appendChild(d.linkDropDown);

        // link drop down button
        d.linkBtn = $AG.createElement('div', {
          className: 'link-btn'
        }, me.options.labels.linkButton);
        d.toolbar.insert( { top: d.linkBtn } );
        Event.observe(d.linkBtn, 'click', function() {
          // if drop down is open, close it
          if (flags.optionsDropDown && d.dropDown.visible()) d.dropDown.hide();

          // open link dd
          var v = !d.linkDropDown.visible();
          $AG.Effect.BlindToggle(d.linkDropDown);

          // form link
          var state = me.saveState();
          var w = d.main.clientWidth+15, h = d.main.clientHeight+15;
          d.linkUrlBox.value = me.options.urls.bookmarkLink.replace(/\{\{state\}\}/g, state);
          aLink.href = d.linkUrlBox.value;
          d.linkEmbedBox.value = me.options.urls.embedTag.replace(/\{\{state\}\}/g, state)
                                                         .replace(/\{\{width\}\}/g, w)
                                                         .replace(/\{\{height\}\}/g, h);
        });

        var tdd = $AG.createElement('select', {
            className: 'link-btn',
            size: 1
        });
        var exportOption=$AG.createElement('option', {
              value: me.options.labels.exportText,
              selected: 1
        }, me.options.labels.exportText);
        tdd.appendChild(exportOption);
        Event.observe(tdd, 'change', function() {
            exportOption.selected = true;
            var url = me.adapter.url;
            var params = $H( {
                hsm: me.getSeries(),
                title: me.getTitle(),
                start: Math.round(me.getDataRanges().xaxis.from / 1000),
                end: Math.round(me.getDataRanges().xaxis.to / 1000),
                output: 'csv'
            });
            window.open( url+"?"+params.toQueryString() );
        } );
        tdd.appendChild($AG.createElement('option', {
                value: 'CSV',
                selected: 0
        }, 'CSV'));
        d.toolbar.insert( { top: tdd } );

	if (flags.optionsDropDown) {
          Event.observe(d.dropDownButton, 'click', function() {
            // if link drop down is open, close it
            if (d.linkDropDown.visible()) d.linkDropDown.hide();
          });
        }
      }

      // layout
      var me = this;
      ResizeEvent.addElement(divs.main);
      Event.observe(divs.main, 'dom:resized', function() {
        if (me.state.size == null) me.state.size = {};
        me.state.size.w = divs.main.clientWidth;
        me.state.size.h = divs.main.clientHeight;
        me.layout();
      });
      me.layout();
    },

    // layout HTML elements
    layout: function() {
      var divs = this.divs, flags = this.options.flags;

      // needed because IE ignores right, and bottom css elements!
      var h = $AG.int(divs.main.clientHeight);
      var w = $AG.int(divs.main.clientWidth);
      if (Prototype.Browser.IE) {
        var hh = $AG.int((flags.titleBar ? divs.title.clientHeight : 0) +
                         (flags.toolBar ? divs.toolbar.clientHeight : 0));
        var lw = $AG.int(flags.yLabel ? divs.ylabel.clientWidth : 0);
        if (flags.xOverview) divs.overview.style.width = (w - lw - 20) + "px";
        var oh = flags.xOverview ? $AG.int(divs.overview.clientHeight) : 0;
        divs.graph.style.width = (w - lw) + "px";
        divs.graph.style.height = (h - hh - oh) + "px";
        if (flags.yLabel) divs.ylabel.style.height = (h - hh - oh) + "px";
      }

      // redraw graphs
      this.drawGraph();
      this.drawOverview();
    },

    // creates graphs, and registers events
    initGraphs: function() {
      // register for selection events on divs
      var me = this;
      var g = $J(me.divs.graph);
      g.bind("plotselected", function (event, ranges) {
        // update state
        me.setRanges(ranges);

        // redraw graph
        me.drawGraph();

        // don't fire event on the overview to prevent eternal loop
        me.graphs.overview.setSelection(ranges, true);
      });
      $J(me.divs.overview).bind("plotselected", function (event, ranges) {
        me.graphs.main.setSelection(ranges);
      });

      // init for hovering and tooltips
      var enableHover = false;
      var highlighted = null;
      if (pointTooltip == null) pointTooltip = new TooltipControl('ajaxgraph-tooltip');

      // turn on/of when mouse over/out
      Event.observe(this.divs.graph, 'mouseover', function() {
        enableHover = true;
      });
      Event.observe(this.divs.graph, 'mouseout', function() {
        // hide tooltip when leaves graph area
        enableHover = false;
        pointTooltip.hide();
      });

      // show tooltip of nearest point
      if (me.options.flags.showTooltip) {
      g.bind("plothover", function (event, pos, item) {
        // unhighlight currently highlighted
        if (highlighted != null) {
          if (highlighted.si >= 0 && highlighted.si < me.data.raw.length)
            me.graphs.main.unhighlight(highlighted.si, highlighted.di);
          highlighted = null;
        }

        // if in area and tooltip enabled
        if (enableHover && me.options.flags.showTooltip) {
         var p = {};
         if (item) {
           // flot has selected a point
           p = {
             pageX: item.pageX,
             pageY: item.pageY,
             x: item.datapoint[0],
             y: item.datapoint[1],
             series: item.series,
             si: item.seriesIndex,
             di: item.dataIndex
           };
         } else {
           // we need to choose a point ourselves

           // for each series
           var pa = [];
           var ds = me.graphs.main.getData();
           if (ds.length > 0) {
             for (var si=0,sl=ds.length;si<sl;si++) {
               // find 2 data points either side of x-value
               var d = ds[si].data;
               var i=0,l=d.length;
               while (i<l && (d[i] == null || d[i][0] < pos.x)) i++;
               for (var c=0; i>=0 && c<2; c++) {
                 if (d[i] != null)
                   pa.push({x: d[i][0], y: d[i][1], series: ds[si], si: si, di: i});
                 i--;
               }
             }

             // choose nearest of these points
             var mind=1000000000000,p=false;
             for (var i=0,l=pa.length;i<l;i++) {
               // calculate distance
               var dx = $AG.Math.mag(pos.x - pa[i].x),
                   dy = $AG.Math.mag(pos.y - pa[i].y);
               var d = Math.sqrt(dx*dx + dy*dy);
               // find min
               if (d < mind) {
                 mind = d;
                 p = pa[i];
               }
             }
           }

           // highlight point
           if (p && typeof p.si != 'undefined' && typeof p.di != 'undefined') {
             highlighted = p;
             me.graphs.main.highlight(p.si, p.di);
           }

           // get page coords for mouse
           p.pageX = pos.pageX;
           p.pageY = pos.pageY;
         }

         // show tooltip
         if (p) {
           // get point from raw data (before graph type applied)
           var xy = (p.si >= 0) ? me.data.raw[p.si].data[p.di] : [p.x, p.y];
           if (xy == null) xy = [p.x, p.y];

           // get po
           var x = me.valueToString(xy[0],'x'),
               y = me.valueToString(xy[1],'y');

           // On IE7, xy[1] could be undef when first loaded
           if (typeof xy[1] != 'undefined') {
             var raw = xy[1].toPrecision();

             // show at right location
             pointTooltip.getElement().update(x+'<br/>&nbsp;'+me.options.labels.hoverOverPlotPointLabelAuto+': '+y+'<br/>&nbsp;'+me.options.labels.hoverOverPlotPointLabelRaw+': '+raw);
             pointTooltip.setLocation(p.pageX+5, p.pageY+5);
             if (p.series) {
              var c = p.series.color;
              pointTooltip.setColor(c);
              pointTooltip.show();
             }
           }
         }
         // hide tooltip
         else {
           pointTooltip.hide();
         }
       }
      });
      }

      // init legend tooltip
      if (legendTooltip == null) legendTooltip = new TooltipControl('ajaxgraph-tooltip', true);
      this.options.flot.main.legend.labelFormatter = function(label) {
        var visname = me.getSeriesOptions(label).customName;
        if (visname == null) visname = label;
        return "<span class='ajaxgraph-legend'><span style='display: none;'>" + label + "</span>"+visname+"</span>";
      };

      // if there are series to get...
      if (this.state.series.length > 0) {
        // init overview graph with data
        this.requestOverviewData(this.state.series);
        // init main graph with data
        this.requestData(this.state.series);
      }
    },

    // draw graph
    drawGraph: function(dontRedraw) {
      // set number of ticks to aim for
      var yticks = this.divs.graph.clientHeight / 22; // 1 per 25px

      // ranges set in flot options
      var r = this.getRanges();
      this.options.flot.main = $J.extend(true, this.options.flot.main, {
        xaxis: { min: r.xaxis.from, max: r.xaxis.to },
        yaxis: { min: r.yaxis.from, max: r.yaxis.to, ticks: yticks }
      });

      // if autoscaling
      if (this.state.autoScale.y) {
        // loop over data in range to find max & min
        var yminmax = getYDataRange(this.data.graph, r.xaxis);
        if (yminmax != null && yminmax.length >= 2 &&
            typeof yminmax[0] == 'number' && typeof yminmax[1] == 'number') {
          var dy = (yminmax[1] - yminmax[0])/10;
          this.options.flot.main.yaxis.min = yminmax[0] - dy;
          this.options.flot.main.yaxis.max = yminmax[1] + dy;
        }
      }

      // choose units
      this.setUnits('x', this.state.xaxis.unit, true);
      this.setUnits('y', this.state.yaxis.unit, true);

      // draw graph
      var g = $J(this.divs.graph);
      this.graphs.main = $J.plot(g, this.data.graph, this.options.flot.main);

      // force graph to position absolute, not relative
      this.divs.graph.style.position = "absolute";

      // for all legend elements
      var me = this;
      var shown = false;
      g.find(".ajaxgraph-legend").each(function() {
        // show tooltip
        Event.observe(this, 'mouseover', function(ev) {
          // set tooltip location to mouse coords
          var p;
          if(ev.pageX || ev.pageY) {
            p = {x:ev.pageX, y:ev.pageY};
          } else {
            p = {
              x:ev.clientX + document.body.scrollLeft - document.body.clientLeft,
              y:ev.clientY + document.body.scrollTop  - document.body.clientTop
            };
          }
          legendTooltip.setLocation(p.x+5, p.y+15);

          // set tooltip text to legend description
          var l = this.firstChild.innerHTML; // legend name
          var s = findSeries(me.data.raw, l);
          if (s != null && typeof s.description == 'string') l = s.description;
          legendTooltip.getElement().update(l);

          // show tooltip
          legendTooltip.show();
          shown = true;
        });

        // hide tooltip
        Event.observe(this, 'mouseout', function(ev) {
          // hide after 0.5s (unless has been shown again)
          shown = false;
          setTimeout(function () {
            if (!shown) legendTooltip.hide();
          }, 500);
        });

        // toggle visibility
        Event.observe(this, 'click', function(ev) {
          // change visibility
          var s = this.firstChild.innerHTML;
          me.setSeriesOptions(s, { visible: !me.getSeriesOptions(s).visible });
        });

      });

      // for all tick label divs
      var maxW = 25;
      g.find("div.tickLabels > div.tickLabel").each(function() {
        if (this.style.textAlign == 'right') {
          // remove explicit width (as prevents aligning right)
          this.style.width = "auto";
          // find max label width
          if (this.clientWidth > maxW) maxW = this.clientWidth;
        }
      });

      // if recursive drawing allowed
      if (!(typeof dontRedraw == 'boolean' && dontRedraw)) {
        // if labels dont fit well, change label width, and redraw
        var yax = this.options.flot.main.yaxis;
        if (maxW > yax.labelWidth || maxW < (yax.labelWidth - 5) ) {
          yax.labelWidth = maxW;
          this.drawGraph(true);
        }
      }
    },

    // draw overview
    drawOverview: function() {
      if (this.options.flags.xOverview) {
        // put in max/min ticks
        var opts = this.options.flot.overview;
        opts.yaxis.ticks = [
          opts.yaxis.min,
          opts.yaxis.max
        ];

        this.graphs.overview = $J.plot($J(this.divs.overview), this.data.overview, opts);
        this.divs.overview.style.position = "absolute";

        // draw selection
        this.graphs.overview.setSelection(this.getRanges(), true);
      }
    },

    // set ranges
    setRanges: function(range, dontRequestData) {
      if (typeof dontRequestData == 'undefined') dontRequestData = false;

      var s = this.state, dr = this.data.ranges;
      // set in state
      if (range.xaxis) {
        s.xaxis.min = range.xaxis.from;
        s.xaxis.max = range.xaxis.to;
      }
      if (range.yaxis) {
        s.yaxis.min = range.yaxis.from;
        s.yaxis.max = range.yaxis.to;
      }

      // TODO: There is probably some tweaking that can be done here. On initial page load,
      // 3 calls are made to get RRD data, when only 2 should be necessary. See OPS-885
      // if new ranges changed outside current dataset
      // or if zoomed in so viewing dataset at more than 2x
      var dw = (dr.xaxis.to - dr.xaxis.from)/2, // remember data window view*2 to start with...
          dh = (dr.yaxis.to - dr.yaxis.from)/2,
          vw = s.xaxis.max - s.xaxis.min,
          vh = s.yaxis.max - s.yaxis.min;
      if (s.xaxis.min < dr.xaxis.from || // check outside data bounds
          s.xaxis.max > dr.xaxis.to ||
          s.yaxis.min < dr.yaxis.from ||
          s.yaxis.max > dr.yaxis.to ||
          vw < (dw/2) || // check if viewing data at more than 2x
          vh < (vh/2))
      {
        // get data for new ranges
        this.data.ranges = this.getDataRanges();
        if (!dontRequestData)
        	this.requestData(this.state.series);
      } else {
        // redraw graph
        this.drawGraph();
      }

      // update overview selection
      if (this.options.flags.xOverview)
        this.graphs.overview.setSelection(this.getRanges(), true);

      // clear all selected zoom buttons
      if (this.options.flags.toolBar && this.options.flags.zoomButtons) {
        var btns = this.divs.zoomBtns.childNodes;
        for (var i=0,l=btns.length;i<l;i++) {
          var b = $(btns[i]);
          if (b.hasClassName('selected')) b.removeClassName('selected');
        }
      }
    },

    // get ranges
    getRanges: function() {
      var s = this.state;
      return {
        xaxis: { from: s.xaxis.min, to: s.xaxis.max },
        yaxis: { from: s.yaxis.min, to: s.yaxis.max }
      };
    },

    // get ranges with overlap
    getDataRanges: function() {
      var r = this.getRanges();
      var dx = (r.xaxis.to - r.xaxis.from) / 2,
          dy = (r.yaxis.to - r.yaxis.from) / 2;
      r.xaxis.from -= dx;
      r.xaxis.to += dx;
      r.yaxis.from -= dy;
      r.yaxis.to += dy;
      return r;
    },

    // sets width and height ranges of
    // display
    setZoom: function(zoom) {
      // change ranges
      var r = this.getRanges();
      if (zoom.width) {
        var d = zoom.width/2;
        var c = r.xaxis.from + ((r.xaxis.to - r.xaxis.from)/2);
        r.xaxis.from = c - d;
        r.xaxis.to = c + d;
      }
      if (zoom.height) {
        var d = zoom.height/2;
        var c = r.yaxis.from + ((r.yaxis.to - r.yaxis.from)/2);
        r.yaxis.from = c - d;
        r.yaxis.to = c + d;
      }
      if (zoom.width || zoom.height) {
        this.setRanges(r, true);
      }
    },

    // add series to list. Call requestAllData() to update graphs
    addSeries: function(series, hidden, opts) {
      $AG.assert(series.length <= 255, "Series too long (max 255 chars) '"+series+"'");
      // if already in graph, return
      for (var i=0,l=this.state.series.length;i<l;i++) {
        if (this.state.series[i] == series) return;
      }

      // add to state
      this.state.series.push(series);
      var o = {
        visible: true,
        customName: null
      };
      if (opts !== undefined && o != null) o = $J.extend(true, o, opts);
      this.state.seriesOptions.push(o);
      this.options.flags.seriesChanged=1;

      // show heading
      var flags = this.options.flags;
      if (flags.toolBar && flags.optionsDropDown && flags.seriesListControl) {
        this.divs.seriesListHeading.show();

        // add to list element
        if (hidden === undefined || !hidden) {
          addSeriesToHTMLList(series, this);
        }
      }
    },
    requestAllData: function() {
        this.requestData(this.state.series);
        this.requestOverviewData(this.state.series);
    },

    // remove series from list
    removeSeries: function(series) {
      // remove from state
      var s = this.state.series;
      for (var i=0,l=s.length;i<l;i++) {
        if (s[i] == series) { s.splice(i,1); this.state.seriesOptions.splice(i,1); break; }
      }
      // remove from list element
      if (this.options.flags.seriesListControl) {
        var lst = this.divs.seriesList.childNodes;
        for (var i=0,l=lst.length;i<l;i++) {
          if (lst[i].title == series) {
            this.divs.seriesList.removeChild(lst[i]);
            break;
          }
        }
        // if none, hide list heading
        if (s.length == 0) this.divs.seriesListHeading.hide();
      }
      // remove series data (from raw & graph & overview)
      removeSeriesFromData(this.data.raw, series);
      removeSeriesFromData(this.data.graph, series);
      removeSeriesFromData(this.data.overview, series);
      this.options.flags.seriesChanged=1;

      // redraw graphs
      this.drawGraph();
      this.drawOverview();
    },

    // returns a function that when called removes the
    // given series from this graph
    removeSeriesFunction: function(series) {
      var me = this;
      return function() {
        me.removeSeries(series);
      };
    },

    // returns list of all series
    getSeries: function() {
      return this.state.series.clone();
    },

    // per series options
    setSeriesOptions: function(sname, opts) {
      var s = this.state;
      var idx = s.series.indexOf(sname);
      if (idx >= 0) {
        // set in state
        s.seriesOptions[idx] = $J.extend(true, s.seriesOptions[idx], opts);

        // if changed vis, update graph
        if (typeof opts.visible == 'boolean') {
          // remove from visible data
          this.applyGraphType();
          // redraw graph
          this.drawGraph();
        }

        // if changed custom name, redraw
        if (typeof opts.customName == 'string') {
          this.drawGraph();
        }

        // return new options
        return s.seriesOptions[idx];
      }
    },

    // per series options
    getSeriesOptions: function(sname) {
      var idx = this.state.series.indexOf(sname);
      if (idx >= 0) return this.state.seriesOptions[idx];
      else throw ("Series " + sname + " does not exist in the graph.");
    },

    // set title
    setTitle: function(title) {
      $AG.assert(title.length <= 255, "Title too long (max 255 chars) '"+title+"'");
      this.state.title = title;
      if (this.options.flags.titleBar) {
        this.divs.title.update(title);
        if (this.options.flags.titleEditable) this.divs.titleEdit.value = title;
      }
    },

    // get title
    getTitle: function() {
      return this.state.title;
    },

    // set y label
    setYLabel: function(label) {
      if (typeof label == 'string') {
        $AG.assert(label.length <= 255, "Y Label too long (max 255 chars) '"+label+"'");
        this.state.yaxis.label = label;
        if (this.options.flags.yLabel) {
          label = label.replace(/\{\{.*\}\}/g, "");
          var el = this.divs.ylabel;
          if (Prototype.Browser.IE) {
            // in IE use div
            el.update(label);
          } else {
            // update svg
            var lbl = this.divs.ylabelsvg_label;
            if (lbl) {
              lbl.replaceChild(document.createTextNode(label), lbl.childNodes[0]);
            }
          }
        }
      }
    },

    // get y label
    getYLabel: function() {
      return this.state.yaxis.label;
    },

    // set graph type
    setGraphType: function(type) {
      // check it exists
      $AG.assert(typeof this.options.graphTypes[type] == 'function',
        "AjaxGraphs.setGraphType: type must be defined in options.graphTypes: "+ type);
      // if changed
      if (type != this.state.graphType) {
        // change state
        this.state.graphType = type;
        // apply new graph type
        this.applyGraphType();
        // redraw
        this.drawGraph();
      }
    },

    // apply graph type to data
    applyGraphType: function() {
      // apply series options to series data
      var ds = [];
      for (var i=0,l=this.data.raw.length;i<l;i++) {
        var s = this.data.raw[i];
        var opts = this.getSeriesOptions(s.label);

        // if not visible, remove data
        if (opts.visible) ds.push(s);
        else ds.push( { label:s.label, data:[], color: '#eeeeee' } );
      }

      // process data with graph type function
      this.data.graph = this.options.graphTypes[this.state.graphType](ds);
    },

    // get graph type
    getGraphType: function() {
      return this.state.graphType;
    },

    getYUnitArrayByUOM: function() {
      var lst;
      var uom = this.data.uom;
      if (typeof this.options.unitsPerUOM[uom] == 'object') {
        lst = this.options.unitsPerUOM[uom];
      } else {
        lst = this.options.units.yaxis;
      }
      return lst;
    },

    // set units
    // axis - 'x' or 'y'
    // i - the unit; 'auto' or the index into the units array
    setUnits: function(axis, i, preventRedraw) {
      var lst;
      if ( axis == 'x' ) {
        lst = this.options.units.xaxis;
      } else {
        lst = this.getYUnitArrayByUOM();
      }
      if (lst.length <= 0) return; // no units
      var i = (i == null) ? -1 : parseInt(i);

      // save in state
      var u = (axis == 'x') ? this.state.xaxis : this.state.yaxis;

      // This is required to store the unit information for the graph options to display
      u.unit = (i < 0) ? null : i;

      // select unit
      var unit = null;
      if (i < 0) {
        // automatically select, based on ranges
        var r = this.options.flot.main;
        var p;
        if (axis == 'x') {
            p = Math.max(Math.abs(r.xaxis.min), Math.abs(r.xaxis.max));
        } else {
            p = Math.max(Math.abs(r.yaxis.min), Math.abs(r.yaxis.max));
        }
        for (i=0,l=lst.length;i<l;i++) {
          u = lst[i];
          if (typeof u.min == 'number' && typeof u.max == 'number' && u.min <= p && p < u.max) {
            unit = u;
            break;
          }
        }
        if (unit == null) unit = lst[0];
      } else {
        // select manually
        unit = lst[i];
      }

      if (unit !== undefined) {
        // assign current unit
        var c = this.options.units.current;
        if (axis == 'x') c.xaxis = unit;
        else c.yaxis = unit;

         // assign tick formatter to flot options
        var tf = function(m) {
          var ax = (axis == 'x') ? m.xaxis : m.yaxis;
          ax.tickFormatter = unit.f;
        }
        tf(this.options.flot.main);
        tf(this.options.flot.overview);

        // redraw axes
        if (typeof preventRedraw == 'undefined' || !preventRedraw)
          this.drawGraph();
      }
    },

    // uses units to convert a value to text
    valueToString: function(n, axis) {
      // if n is null
      if (n == null) return 'no data';

      // if axis not defined, return to 3sf
      if (typeof axis == 'undefined') return n.toPrecision(3);

      // check for time
      var axn = (axis == 'x') ? 'xaxis' : 'yaxis';
      var ax = this.options.flot.main[axn];
      if (ax.mode == 'time') {
        // We have to return UTC DateTime because all the plot points are in epoch+offset values
        var d = new Date(n);
        return d.toUTCDateTimeString();
      }

      // use units
      var u = this.options.units.current[axn];
      if (u != null && typeof u.f == 'function') return u.f(n, ax);
      else return n.toPrecision(3);
    },

    // queries overview data, and updates overview graph
    requestOverviewData: function(series) {
      // if disabled dont bother
      if (!this.options.flags.xOverview) return;
      // init overview graph
      var me = this;
      var o = this.options.flot.overview;
      this.adapter.query({
        series: this.state.series.clone(),
        ranges: {
          xaxis: { from: o.xaxis.min, to: o.xaxis.max },
          yaxis: { from: o.yaxis.min, to: o.yaxis.max }
        }
      },
      function(success, query, data) {
        if (success) {
          // add data to data array
          addDataToData(me.data.overview, data.lines);
          // draw overview graph
          me.drawOverview();
        } else {
          throw data;
        }
      });
    },

    // queries data, and updates graph
    requestData: function(series) {
      // toolbar enabled
      var tbar = this.options.flags.toolBar;
      // if not empty
      if (series.length > 0) {
        if (typeof series[0] == 'undefined')
		alert("cant request undefined series");
        // loading
        if (tbar) this.divs.loading.show();
        // get replacement data, for all series
        var me = this;
        me.adapter.query({
          series: series.clone(),
          ranges: this.data.ranges
        },
        function(success, query, data) {
          if (success) {
            // add data to data array
            addDataToData(me.data.raw, data.lines);
            // apply graph type to data
            me.applyGraphType();
            // draw graph
            me.drawGraph();

            // Change drop down options, only if a series change has occurred
            // I don't think this works too well at the moment when changing
            // series in the graph options, but it works on load
            if (me.options.flags.seriesChanged) {
              // Set uom. Use first one as this is what is displayed as y-axis
              if (typeof me.data.raw[0].uom != 'undefined') {
                me.data.uom = me.data.raw[0].uom;
              }
              me.divs.graphOptions.yunitsDropDownRefresh();
              me.options.flags.seriesChanged=0;
            }

            // hide error
            if (tbar) me.divs.error.hide();
          } else {
            // show error icon
            if (tbar) {
              me.divs.error.show();
              me.divs.error.title = me.options.labels.connectionError + ": " + data;
            }
          }
          // done
          if (tbar) me.divs.loading.hide();
        });
      }
    },

    // show / hide options menu
    getOptionsMenuVisibility: function() {
      return this.options.flags.toolBar && this.options.flags.optionsDropDown && this.divs.dropDown.visible();
    },

    setOptionsMenuVisibility: function(vis) {
      if (this.options.flags.toolBar && this.options.flags.optionsDropDown)
        $AG.Effect.Blind(this.divs.dropDown, vis);
    }

  });

  // Composite pattern, a group of graphs
  var GraphGroup = Class.create(Serializable, {
    initialize: function($super, graphConstructor) {
      $super();

      // children
      this.children = [];

      // create composite functions
      this.drawOverview = $AG.foreachFunction(this.children, 'drawOverview');
      this.drawGraph = $AG.foreachFunction(this.children, 'drawGraph');
      this.layout = $AG.foreachFunction(this.children, 'layout');
      this.setRanges = $AG.foreachFunction(this.children, 'setRanges');
      this.setZoom = $AG.foreachFunction(this.children, 'setZoom');
      this.addSeries = $AG.foreachFunction(this.children, 'addSeries');
      this.removeSeries = $AG.foreachFunction(this.children, 'removeSeries');
      this.setSeriesOptions = $AG.foreachFunction(this.children, 'setSeriesOptions');
      this.setGraphType = $AG.foreachFunction(this.children, 'setGraphType');
      this.setTitle = $AG.foreachFunction(this.children, 'setTitle');
      this.setYLabel = $AG.foreachFunction(this.children, 'setYLabel');
      this.setUnits = $AG.foreachFunction(this.children, 'setUnits');
      this.getOptionsMenuVisibility = $AG.foreachFunction(this.children, 'getOptionsMenuVisibility');
      this.setOptionsMenuVisibility = $AG.foreachFunction(this.children, 'setOptionsMenuVisibility');

      // function() { return new AjaxGraph(...); }
      this.graphConstructor = typeof graphConstructor == 'function' ? graphConstructor : null;
    },

    // children.add(graph)

    // children.remove(graph)

    // type info for serialization
    getTypeInfo: function($super) {
      var a = $super();
      a.push(['children', { array: Graph.prototype.getTypeInfo() }]);
      return a;
    },

    // void loadState(stateStr)
    loadState: function(stateStr) {
      var a = Serialization.deserialize(stateStr, { array: 'string' });
      // if not enough graphs, create more
      if (a.length > this.children.length) {
        if (this.graphConstructor != null) {
          for (var i=0,l=a.length-this.children.length;i<l;i++) this.children.push(this.graphConstructor());
        } else {
          throw("Can't load graph group from state as there are graphs in the state than in the group. " +
                "Please define graphConstructor to allow the group to create more child graphs dynamically.");
        }
      }
      for (var i=0,l=a.length;i<l;i++)
        this.children[i].loadState(a[i]);
    },

    // string saveState()
    saveState: function() {
      var a = [];
      for (var i=0,l=this.children.length;i<l;i++) {
        a.push(this.children[i].saveState());
      }
      return Serialization.serialize(a, { array: 'string' });
    },

    // void drawOverview()
    drawOverview: null,

    // void drawGraph()
    drawGraph: null,

    // void layout()
    layout: null,

    // gets the range of all the graphs (max/min of all)
    // { xaxis: { from: 0, to: 1 }, yaxis: { from: 0, to: 1} } getRanges()
    getRanges: function() {
      var a = { xaxis: { from: Number.POSITIVE_INFINITY, to: Number.NEGATIVE_INFINITY },
                yaxis: { from: Number.POSITIVE_INFINITY, to: Number.NEGATIVE_INFINITY } };
      for (var i=0,l=this.children.length;i<l;i++) {
        var b = this.children[i].getRanges();
        a.xaxis.from = Math.min(a.xaxis.from, b.xaxis.from);
        a.yaxis.from = Math.min(a.yaxis.from, b.yaxis.from);
        a.xaxis.to = Math.max(a.xaxis.to, b.xaxis.to);
        a.yaxis.to = Math.max(a.yaxis.to, b.yaxis.to);
      }
      return a;
    },

    // void setRanges(ranges)
    // ranges - { xaxis: { from: 0, to: 1 }, yaxis: { from: 0, to: 1 } }
    setRanges: null,

    // void setZoom(zoom)
    // zoom - { width: 10, height: 10 }
    setZoom: null,

    // collates series from all graphs into a single array
    // string[] getSeries()
    getSeries: function() {
      var lst = [];
      for (var i=0,l=this.children.length;i<l;i++) {
        var s = this.children[i].getSeries();
        for (var si=0,sl=s.length;si<sl;si++) {
          if (lst.indexOf(s[si] < 0)) lst.push(s[si]);
        }
      }
      return lst;
    },

    // adds the series to all graphs
    // void addSeries(series)
    // series - string
    addSeries: null,

    // removes the series from all graphs
    // void removeSeries(series)
    // series - string
    removeSeries: null,

    // sets the any of the per series options on all graphs
    // { visible: true/false, customName: null/"a short name" }
    setSeriesOptions: null,

    // set type of all graphs
    // void setGraphType(type)
    setGraphType: null,

    // set title of all graphs
    // void setTitle(title)
    setTitle: null,

    // set ylabel on all graphs
    // void setYLabel(ylabel)
    setYLabel: null,

    // set units on all graphs
    // void setUnits(axis, unit, preventRedraw)
    // axis - 'x' or 'y'
    // unit - 'auto' or the index into the units array
    // preventRedraw - when true doesnt redraw graph
    setUnits: null,

    // get best unit range based on UOM
    getYUnitArrayByUOM: null,

    // control visibility of options menus
    // void setOptionsMenuVisibility(boolean);
    setOptionsMenuVisibility: null,

    // boolean getOptionsMenuVisibility()
    getOptionsMenuVisibility: null
  });

  // Public
  return {
    DataAdapter: DataAdapter, // abstract data adapter, for extending
    Graph: Graph, // base graph class
    GraphGroup: GraphGroup, // graph collection
    GraphTypes: GraphTypes, // graph types, collection of fn(dataset)->dataset
    State: State, // serializable graph state
    AddSeriesControl: AddSeriesControl, // add series to series list
    SeriesItemControl: SeriesItemControl, // item in series list
    OptionsControl: OptionsControl, // graph options control, in drop down
    foreachPoint: foreachPoint, // helper function
    getYDataRange: getYDataRange // helper function
  };

}();
