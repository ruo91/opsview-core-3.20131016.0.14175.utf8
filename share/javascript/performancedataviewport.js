  var PerformanceViewportDataTableState = Class.create(AjaxDataTableSettings, {
    initialize: function($super) {
      $super();

      // dont automatically update data when settings change
      this.autoupdate = false;

      // general
      this.slRefreshPeriod = 5*60*1000; // 5mins
      this.cvRefreshPeriod = 30*1000; // 30s

      // filter
      this.keyword = "";
      this.duration = 7*24*60*60*1000; // 7 days
      this.fields = ["page", "rows", "sortby", "cols", "keyword"];
      this.cols = [0, 1, 2, 3, 4]; // start all visible
      this.sortby = [[0, 'asc']];
    },

    getTypeInfo: function($super) {
      var lst = $super();
      lst.push(['keyword', 'shortstring']); // string
      lst.push(['duration', 'integer']);
      return lst;
    },

    toParameters: function() {
      var et = (new Date()).getTime();
      return {
        keyword: this.keyword,
        start: Math.round((et - this.duration) / 1000),
        end: Math.round(et / 1000)
      };
      //return this.toHash(this.fields);
    }

  });

  // Datatable for performance data
  var PerformanceViewportDataTable = Class.create(AjaxDataTable, {

    // Initialize
    initialize: function($super, tableId, url, slurl, graph_url, state, sloptions, lang, menu_image, base_menu_url) {
      // initializing flag
      var me = this;
      var ready = false;
      var initDone = false;
      this.graph_url = graph_url;
      this.menu_image = menu_image; // This also acts as a switch of whether to display the menu or not
      this.base_menu_url = base_menu_url;

      // draw/redraw graphs when table is drawn
      var onDraw = function() {
        if (ready) {
          if (!initDone) {
            // init sparklines
            me.refreshSparklines();
            initDone= true;
          } else {
            // redraw sparklines
            me.redrawSparklines();
          }
        }
      };

      // super constructor
      $super(tableId, url, state, {'bFilter': true,
                                    "sDom": '<"perftop"f><"clear">rt<"clear">',
                                   "aoColumns": [
			             { "sType": "string"},
			             { "sType": "string"},
			             { "sType": "string"},
			             { "sType": "html"},
			             { "sType": "html", "bSortable": false, "bSearchable": false }],
                                    "fnDrawCallback": onDraw,
                                    "oLanguage": {"sSearch": (typeof lang == 'object' ? lang.filter : "Filter") + ": " }});

      // init sparklines
      this.state = state;
      this.dataAdapter = new AjaxSparkline.JSONDataAdapter(slurl);
      this.sparklines = new AjaxSparkline.Group(this.dataAdapter,
        state.keyword, state.duration, sloptions, lang);

      // refreshing
      var me = this;
      if (typeof refreshTimer === 'object') {
        // refresh
        var tmr = new Date().getTime();
        refreshTimer.addListener(function(cb) {
          // refresh status
          var f = function(a,b,c) {
            // if 5 mins up, refresh sparklines
            var t = new Date().getTime();
            if (t > tmr + state.slRefreshPeriod) {
              me.refreshSparklines(cb);
              tmr = t;
            } else {
              cb(a,b,c);
            }
          };
          me.refreshStatus(f);
        });
      } else {
        alert("Error: Performance data viewport requires 'refreshTimer' javascript to function correctly.");
      }

      // marks as ready for onDraw function
      ready = true;
    },

    // refresh current values
    refreshStatus: function(cb) {
      this.updateTable(cb);
    },

    // refresh sparklines
    refreshSparklines: function(cb, d) {
      this.sparklines.keyword = this.state.keyword;
      if(d)
        this.sparklines.duration = d;
      this.sparklines.refresh(cb);
    },

    // redraw sparklines using saved data
    redrawSparklines: function() {
      this.sparklines.redraw();
    },

    contextMenu: function(url){
        if (! this.menu_image) { return "" };
	return '<img onClick="javascript:load_context_menu(event,\'' + url + '\')" class="menu right" src="'+ this.menu_image + '" width="20" height="20" />';
    },

    // Takes the responseText and populates the table accordingly
    populateTable: function($super, responseText) {
      // get json
      var json = responseText.evalJSON(true);
      this.json = json;

      // create table rows and sparklines
      this.rowArray = [];
      var hosts = json.ResultSet.list;
      for (var h = 0; h<hosts.length; h++) {
        var host = hosts[h];

        // services
        var services = host.services;
        for (var s =0; s<services.length; s++) {
          var service = services[s];

          // metrics
          if (service.perfdata_available) {
            for (var m=0; m<service.metrics.length; m++) {
              var metric = service.metrics[m];
              var value = typeof metric.value == "undefined" ? "&nbsp;" :
                            metric.value + (typeof metric.uom == "undefined" ? "" : metric.uom);

              // create hsm
              var hsm = host.name + "::" + service.name + "::" + metric.name;
              var hsh = AjaxSparkline.hashString(hsm);

              // add row to table data
              this.rowArray.add([
                this.contextMenu(this.base_menu_url + "/service/" + service.service_object_id + "/menus") + service.name,
                this.contextMenu(this.base_menu_url + "/host/name/" + host.name + "/menus") + host.name,
                metric.name,
                "<span id=\"val_" + hsh + "\">"+value+"</span>",
                "<a href='" + this.graph_url + "?host="+host.name+"&service="+service.name+"&metric="+metric.name+"'><span class=\"sparkline\" id=\"spl_" + hsh + "\"></span></a>&nbsp;"]);

              // add spans to sparkline manager
              this.sparklines.add(hsm, "spl_" + hsh, {});
            }
          }
        }
      }
    }

  });
