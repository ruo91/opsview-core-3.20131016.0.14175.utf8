// eventsView module
eventsView = function() {

  var config = {
    moduleName: "eventsView",
    auto_refresh: "false",
    host: [],
    service: [],
    CSS: {
      classes: {
        paging: { // marks paging elements
          group: "page_buttons",
          prev: "page_prev",
          next: "page_next",
          prevLinks: "page_prev_links",
          nextLinks: "page_next_links",
          num: "page_num"
        },
        filter: { // marks elements to be updated with filter summaries
          time: "filter_summary_time",
          host: "filter_summary_host",
          host_group: "filter_summary_host_group",
          service: "filter_summary_service",
          state: "filter_summary_state",
          state_type: "filter_summary_state_type"
        },
        textLink: "linktext", // a link
        table: {
          rows: ["odd", "even"], // alternating classes for rows
          new_event_highlight: "new_event"
        },
        menu: "menu" // menu icons
      },
      IDs: {
        table: "event_table", // the table element
        timeline: "event_timeline", // the timeline's div
        timelineContainer: "event_timeline_container", // timeline container div
        timelineLink: "event_timeline_showhide", // timeline show/hide link
        timelineLinkIcon: "event_timeline_showhide_icon", // timeline show/hide link icon
        playSoundsButton: "event_mute_btn", // play/mute sounds
        playSoundsButtonIcon: "event_mute_btn_icon", // play/mute sounds icon
        newevents: {
           container: "newevents", // container div
           acknowledge_btn: "newevents_ack_btn", // ack button
           lastdate_span: "newevents_lastdate", // last date comparing to
           count_span: "newevents_count" // number of events since marker
        },
        filter: {
          summary: "filter_summary", // filter summary text
          form: {
            container: "filter_form",
            showCol: "filter_show_col", // show column text boxes showCol+0,1,2...
            rows: "filter_rows", // row count drop down
            startTime: "filter_startTime", // start time
            endTime: "filter_endTime", // end time
            search: "filter_search", // search box
            host: {
              list: "filter_host_list", // span containing list of host element
              select: "filter_host_select" // select containing hosts
            },
            host_group: {
              list: "filter_host_group_list", // span containing host groups
              select: "filter_host_group_select", // select containing host groups
              getNameFromDropDown: true // set when name is different to value
            },
            service: {
              list: "filter_service_list", // span containign list of services
              select: "filter_service_select" // select containign list of services
            },
            host_state: {
              list: "filter_host_state_list", // span containing list of states
              select: "filter_host_state_select" // select containing list of states
            },
            service_state: {
              list: "filter_service_state_list", // span containing list of states
              select: "filter_service_state_select" // select containing list of states
            },
            state_type: {
              list: "filter_state_type_list",
              select: "filter_state_type_select"
            },
            keyword: {
              list: "filter_keyword_list", // span containing keywords
              select: "filter_keyword_select" // select containing keywords
            }
          }
        }
      }
    },
    labels: {
      removeFromList: "(-)", // [remove]
      pagingOf: "of", // 1 of 12
      host: "Host", // column names
      host_group: "Host group",
      service: "Service",
      state: "State",
      host_state: "Host state",
      service_state: "Service state",
      state_type: "State type",
      keyword: "Keyword",
      time: "Time",
      output: "Output",
      search: "Search",
      beforeTime: "Before", // before <time>
      afterTime: "After", // after <time>
      anyTime: "Any", // any
      anyFilter: "Any", // any
      showTimeline: "Show timeline", // to show timeline
      hideTimeline: "Hide timeline", // to hide timeline
      viewTimeline: "View timeline", // tooltip for time links
      playSounds: "Play alerts", // play sounds
      muteSounds: "Mute alerts", // mute sounds
      timelineUpdateError: "Error updating timeline",
      documentTitle: "Opsview> Events: ", // page title
      menu: "Menu" // tooltip for menu images
    },
    URLs: {
      json: "/event?output=json", // webservice url
      stateImage: {pre: "/images/", post: "-16x16.png"}, // state icon url <pre>critical<post>
      newEventSound: "/media/state_change.wav",
      menuImage: "/images/menu.png",
      serviceMenu: {pre: "/state/service/", post: "/menus"},
      hostMenu: {pre: "/state/host/name/", post: "/menus"},
      hostgroupMenu: {pre: "/state/hostgroup/", post: "/menus"}
    },
    names: {
      // contains hashes of <ID> => <Name/Path> for getName to use...
      // to be populated by page from DB using overrideConfig function
    },
    stateIcon: function( event ) {
      var objecttype = (typeof event.servicename == "string" && event.servicename.length > 0) ? "service" : "host";
      var url = config.URLs.stateImage.pre + objecttype + "-" + event.state.toLowerCase() + config.URLs.stateImage.post
      return url;
    }
  };

  // if is defined in config, returns the name for the id,
  // otherwise returns id
  config.getName = function(category, id) {
    if (typeof config.names[category] == "object") {
      var cat = config.names[category];
      if (typeof cat[id] == "string") return cat[id];
    }
    return id;
  };

  var playSounds;
  var initialTimelineVisible;
  // set any overrides to the config
  function overrideConfig(configChanges) {
    // recursive function
    function overrideSettings(obj, ovr) {
      for(var k in ovr) {
        var o = ovr[k];
        if (typeof o == "object" && !Object.isArray(o)) {
          // recurse
          if (typeof obj[k] == "undefined") obj[k] = {};
          overrideSettings(obj[k], o);
        } else {
          // override scalar or array value
          obj[k] = o;
        }
      }
    }
    // root call
    overrideSettings(config, configChanges);
    initialTimelineVisible=config.initialTimelineVisible;
    playSounds=config.playSounds;
  };

  // when you need a unique identifier
  var uuid = 0;
  function getUUID() { return uuid++; };

  // EventsViewDataTableSettings class extends AjaxDataTableSettings
  // defines table filter settings members & serialization
  var EventsViewDataTableSettings = Class.create(AjaxDataTableSettings, {

    initialize: function($super) {
      // call super constructor
      $super();

      // state settings
      this.detectNewData = true;
      this.saved_maxeventid = null;

      // filter settings
      this.startTime = "";
      this.endTime = "";
      this.host = config.host;
      this.host_group = [];
      this.service = config.service;
      this.keyword = [];
      this.host_state = [];
      this.service_state = [];
      this.state_type = ["HARD"];
      this.search = [];

      // fields to include in bookmark
      this.fields = ["page", "rows", "sortby", "cols",
                   "startTime", "endTime", "host", "host_group",
                   "service", "keyword", "host_state", "service_state",
                   "state_type", "search"];

      // date regexp
      this.dateRegexp = new RegExp("([0-9]{4})\-([0-9]{2})\-([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2})?");
    },

    // get field types
    getTypeInfo: function($super) {
      var lst = $super();
      lst.push(['startTime', 'shortstring']); // string
      lst.push(['endTime', 'shortstring']); // string
      // lengthsize: 1 (1B used for array.length => up to 255 elements)
      lst.push(['host', { array: 'shortstring', lengthsize: 1} ]); // string[]
      lst.push(['host_group', { array: 'shortstring', lengthsize: 1} ]); // string[]
      lst.push(['service', { array: 'shortstring', lengthsize: 1 } ]); // string[]
      lst.push(['keyword', { array: 'shortstring', lengthsize: 1 } ]); // string[]
      lst.push(['host_state', { array: { enumerated: ['UP', 'DOWN', 'UNREACHABLE']},
                                lengthsize: 1 } ]); // string[]
      lst.push(['service_state', { array: { enumerated: ['OK', 'WARNING', 'CRITICAL', 'UNKNOWN'] },
                                lengthsize: 1 } ]); // string[]
      lst.push(['state_type', { array: { enumerated: ['SOFT', 'HARD'] },
                               lengthsize: 1 } ]); // string[]
      lst.push(['search', { array: 'shortstring', lengthsize: 1 } ]); // string[]
      return lst;
    },

    // methods
    // return settings as hash of parameters for the webservice
    toParameters: function() {
      var h = this.toHash(this.fields);

      // get col name for a given index
      function colname(idx) {
        switch(idx) {
          case 0: return "time";
          case 1: return "hostname";
          case 2: return "host_group";
          case 3: return "servicename";
          case 4: return "state";
          case 5: return "state_type";
          case 6: return "output";
          default: alert("Error at: EventsViewDataTableSettings.toParameters.colname bad col index " + idx);
        }
      }

      // encode cols array
      var cls = {};
      for (var i = 0, l=this.cols.length; i<l; i++) { cls[colname(this.cols[i])] = 1 }
      cls.time = 1; // always request time
      cls.eventid = 1; // always event id
      cls.servicename = 1; // always service name
      cls.objectid = 1; // always service id
      h.cols = []; for (var cl in cls) { h.cols.push(cl); }

      // encode sortby, as json string
      var sb = [];
      if (typeof this.sortby == "object" && this.sortby.length) {
        for (var i = 0; i < this.sortby.length; i++) {
          if (typeof this.sortby[i] == "object" && this.sortby[i].length == 2) {
            var o = { col: colname(this.sortby[i][0]) };
            if (this.sortby[i][1] == "desc") o.order = "desc";
            sb.push(o);
          }
        }
      }
      if (sb.length > 0) h.sortby = Object.toJSON(sb);

      // include saved maxeventid
      if (this.detectNewData && typeof this.saved_maxeventid == 'number') {
        h.saved_maxeventid = this.saved_maxeventid;
      }

      return h;
    },

    // serialize as a short string (for bookmarking & history)
    toString: function() {
      // Deprecated:
      var a = this.toArray(this.fields);
      var s = Object.toJSON(a);

      // serialization test
      var str = this.serialize();
      /*alert(str);
      var obj = Serialization.deserialize(str, this.getTypeInfo());
      alert(Object.toJSON(obj));
      alert("Original length: " + s.length + "; Serialized length: " + str.length);*/
      return str;

      // return s;
    },

    // deserialize from a short string (for bookmarking & history)
    fromString: function(str) {
     // Deprecated:
     //var a = str.evalJSON(true);
     //this.fromArray(this.fields, a);

      this.deserialize(str);
      //alert("Deserialized: " + Object.toJSON(this));
    },

    // return a human readable description of the settings
    // when notags defined and true, will return plain text without html
    toHTMLDescription: function(notags) {
      if (typeof notags == 'undefined') notags = false;
      function getnames(cat,arr) { var r=[]; for(var i=0,l=arr.length;i<l;i++) r.push(config.getName(cat,arr[i])); return r; }
      function trunc(s,l) {
        if (s.length>l) {
          return (notags ? '' : "<span title=\""+s+"\">") +
                   s.substring(0,l) + "..." +
                 (notags ? "" : "</span>");
        } else { return s; }
      }
      var a = [];
      if (this.host.length > 0) a.push(config.labels.host + ": " + trunc(this.host.join(", "), 50));
      if (this.host_group.length > 0) a.push(config.labels.host_group + ": " + trunc(getnames("host_group",this.host_group).join(", "), 50));i
      if (this.service.length > 0) a.push(config.labels.service + ": " + trunc(this.service.join(", "), 50));
      if (this.host_state.length > 0) a.push(config.labels.host_state + ": " + trunc(getnames("host_state",this.host_state).join(", "), 50));
      if (this.service_state.length > 0) a.push(config.labels.service_state + ": " + trunc(getnames("service_state",this.service_state).join(", "), 50));
      if (this.keyword.length > 0) a.push(config.labels.keyword + ": " + trunc(this.keyword.join(", "), 50));
      if (this.state_type.length > 0) a.push(config.labels.state_type + ": " + trunc(getnames("state_type", this.state_type).join(", "), 50));
      if (this.startTime && this.startTime != "") a.push(config.labels.afterTime + ": " + this.startTime);
      if (this.endTime && this.endTime != "") a.push(config.labels.beforeTime+": " + this.endTime);
      if (this.search.length > 0) a.push(config.labels.search + ": " + trunc(this.search.join(", "), 50));
      notags = true;
      return trunc(a.join(", \n"), 75);
    },

    // Converts JS Date to 2009-07-22 03:42:29
    dateToStr: function(d) {
      function pad(n, digits) { var s=''+n; while(s.length<digits) s='0'+s; return s; }
      return d.getFullYear() + '-' +
             pad(d.getMonth()+1,2) + '-' +
             pad(d.getDate(),2) + ' ' +
             pad(d.getHours(),2) + ':' +
             pad(d.getMinutes(),2) + ':' +
             pad(d.getSeconds(),2);
    },

    // Converts 2009-07-22 03:42:29 to a Date
    strToDate: function(s) {
      var a = this.dateRegexp.exec(s);
      if (!Object.isArray(a) || a.length < 5) return null;
      function num(s) { return parseInt(s, 10); }
      if (a.length < 6) a.push(0); // if no secs, add 0s
      var d = new Date(Date.UTC(num(a[1]), num(a[2])-1, num(a[3]), num(a[4]), num(a[5]), num(a[6])));
      return d;
    },

    // clone settings
    clone: function() {
      function cpy_array(a) { var r=[]; for(var i=0;i<a.length;i++) r[i]=a[i]; return r; }
      var copy = new EventsViewDataTableSettings();
      for (var k in this) {
        var o = this[k];
        if (!Object.isFunction(o)) {
          if (Object.isArray(o)) o = cpy_array(o);
          copy[k] = o;
        }
      }
      return copy;
    }
  });

  // EventsViewDataTable class extends AjaxDataTable
  // defines populateTable method for the events view table
  var EventsViewDataTable = Class.create(AjaxDataTable, {

    // clear all highlighted new events
    clearNewEventHighlighting: function() {
        this.oTable.fnForeachRow(["tbody"],
          function(row, cells, me) {
            row = $(row);
            if (row.hasClassName(config.CSS.classes.table.new_event_highlight))
              row.removeClassName(config.CSS.classes.table.new_event_highlight);
        }, this);
    },

    // Takes the responseText and populates the table accordingly
    populateTable: function($super, responseText) {
      // parse JSON object
      var json = responseText.evalJSON(true);
      var smry = json.ResultSet.summary;
      var s = this.getTableSettings();
      function num(n) { if (typeof n != "number") return parseInt(n); else return n; }

      // init marker
      if (typeof markerEventID != 'number') {
        markerEventID = num(smry.maxeventid);
        s.saved_maxeventid = markerEventID;
        markerDate = new Date();
      }

      // init current max event id
      if (typeof currentMaxEventID != 'number') {
        currentMaxEventID = markerEventID;
        currentNewEventCount = 0;
      }

      // update page number & number of pages
      var pages = num(json.ResultSet.summary.pages);
      var page = num(json.ResultSet.summary.page);
      if (s.page != page || s.pages != pages) {
        s.pages = pages;
        s.page = page;
        // only dispatch if changed
        this.dispatchEvent(this.settingsChangedListeners); // notify UI, but DONT UPDATE !!
      }

      // if not defined, empty string
      function str(s) { if (!s) return ""; else return ""+s; }

      // is sorting on?
      function sorton(idx) { return s.cols.indexOf(idx) >= 0; }

      function filterlink(name, text, value) {
        if (value) return "<a href='javascript:"+config.moduleName+".setFilterSetting(\""+name+"\", [\""
                         + value + "\"]);'>"+text+"</a>";
        else return "";
      }

      function contextMenu(url) {
        var id = "menu_" + getUUID();
        return '<img onClick="javascript:load_context_menu(event,\'' + url + '\')" class="menu right" src="'+config.URLs.menuImage+'" width="20" height="20" />';
      }

      // add data to table
      var markdownConverter = new Showdown.converter();
      var classes = config.CSS.classes.table.rows;
      var list = json.ResultSet.list;
      var set_timeline_to_first_row_flag = 0;
      for (var i = 0; i < list.length; i++) {
        var ev = list[i];

        try {
        // time
        var time = s.strToDate(ev.time);
        if (set_timeline_to_first_row_flag == 0) {
            setCenterVisibleDateIfVisible(time);
            set_timeline_to_first_row_flag=1;
        }
        var timeStrs = ev.time.split(' ');
        var timeStr = "<span style='float: right;'>" + timeStrs[1] + "</span>" +
                      "<span style='text-align: left;'>" + timeStrs[0] + "</span>";
        var timeLink = "<a title='"+config.labels.viewTimeline+
                         "' href='javascript:"+config.moduleName+".setTimelineTime(new Date("+
                         time.getTime()+"/*"+time+"*/))'>"+timeStr+"</a>";

        // service, host, hostgroup
        var serviceLink = filterlink("service", ev.servicename, ev.servicename)
        if (typeof ev.servicename == "string" && ev.servicename.length > 0)
          serviceLink = contextMenu(config.URLs.serviceMenu.pre+ev.objectid+config.URLs.serviceMenu.post) + serviceLink;
        var hostLink = filterlink("host", ev.hostname, ev.hostname);
        if (typeof ev.hostname == "string" && ev.hostname.length > 0)
          hostLink = contextMenu(config.URLs.hostMenu.pre+ev.hostname+config.URLs.hostMenu.post) + hostLink;
        var hostgroupLink = filterlink("host_group", config.getName("host_group", ev.host_group), ev.host_group)
        if (typeof ev.host_group != "undefined")
          hostgroupLink = contextMenu(config.URLs.hostgroupMenu.pre+ev.hostgroup+config.URLs.hostgroupMenu.post) + hostgroupLink;
        var stateTypeLink = filterlink("state_type", config.getName("state_type", ev.state_type.toUpperCase()), ev.state_type.toUpperCase());

        // state
        var stateLink = "";
        if (ev.state) {
          var statename = ev.state.toLowerCase();
          var eventType = (typeof ev.servicename == "string" && ev.servicename.length > 0) ? "service_state" : "host_state";
          var stateLink = filterlink(eventType, config.getName(eventType, ev.state.toUpperCase()), ev.state.toUpperCase());
          stateLink = "<img src='" + config.stateIcon(ev) +
                      "' alt='' title='" + statename + "' /> " + stateLink;
        }

        // is the event "new"?
        var rowClass = "";
        var outputClasses = [];
        if (this.tableSettings.detectNewData && ev.eventid > markerEventID)
          rowClass = config.CSS.classes.table.new_event_highlight;

        // add row to array
        if (ev.markdown == 1) {
            ev.output = markdownConverter.makeHtml(ev.output);
            outputClasses.push("markdown");
        }
        var row = {className: rowClass,
                   cells: [{innerHTML: timeLink},
                           {innerHTML: str(hostLink)},
                           {innerHTML: hostgroupLink},
                           {innerHTML: str(serviceLink)},
                           {innerHTML: str(stateLink)},
                           {innerHTML: stateTypeLink},
                           {classes: outputClasses, innerHTML: str(ev.output)}]};
        this.addRow(row);

        } catch (ex) {
          // dont break whole table if so rows go wrong...
          alert("Error rendering row: " + ex + "\n\n" + Object.toJSON(ev));
        }
      }

      // get new event count
      var maxEventID = typeof smry.filtered_maxeventid != 'undefined' ?
                         num(smry.filtered_maxeventid) : 0;
      var newEventCount = typeof smry.filtered_new_event_count != 'undefined' ?
                            num(smry.filtered_new_event_count) : 0;

      // if auto refresh is on
      if (s.detectNewData) {
        // have there been events since previous refresh?
        if (newEventCount > currentNewEventCount) {
          // audible alert
          if (typeof Sound != "undefined" && playSounds) {
            Sound.play(config.URLs.newEventSound, {replace:true});
          }
        }

        // ensure reset highlight button is visible, if new events
        var e = $(config.CSS.IDs.newevents.container);
        if (e) {
          if (newEventCount > 0) e.show();
          else e.hide();
        }
        // update number of events since marker
        e = $(config.CSS.IDs.newevents.count_span);
        if (e) e.update(newEventCount);
        e = $(config.CSS.IDs.newevents.lastdate_span);
        if (e) e.update(this.tableSettings.dateToStr(markerDate));
      }

      // update current maximum event id, and new event count
      currentMaxEventID = maxEventID;
      currentNewEventCount = newEventCount;
    }

  });

  // table object
  var table;

  // timeline objects
  var timeline;
  var timeline_eventSource;
  var timeline_minDate; // limits of current timeline data
  var timeline_maxDate;

  // new data detection
  var markerEventID; // events with greater id, are new & should be highlighted
  var markerDate; // time of this marker
  var currentMaxEventID; // max event id of last update
  var currentNewEventCount = 0; // number of new events at last update, count > this, should beep

  function assert_notnull(value, desc, obj) {
    if (typeof value == 'undefined') {
      var dump = "";
      if (typeof obj != 'undefined') dump = Object.toJSON(obj);
      alert("Assertion 'not null' failed: " + desc + "\n\n" + dump);
    }
  };

  function init() {
    // default table settings
    var tableSettings = new EventsViewDataTableSettings();
    tableSettings.sortby = [[0, "desc"]]; // by time, descending
    tableSettings.cols = [0,1,3,4,6];
    tableSettings.rows = 15;

    // create data table
    table = new EventsViewDataTable(config.CSS.IDs.table,
                      config.URLs.json, tableSettings);

    // default timeline settings
    var theme = Timeline.ClassicTheme.create(); // create the theme
    theme.mouseWheel = "zoom";
    timeline_eventSource = new Timeline.DefaultEventSource();
    var bandInfos = [
      Timeline.createBandInfo({
        eventSource: timeline_eventSource,
        width:          "85%",
        intervalUnit:   Timeline.DateTime.HOUR,
        intervalPixels: 35,
        zoomIndex: 10,
        zoomSteps: [
              {pixelsPerInterval: 60,  unit: Timeline.DateTime.SECOND},
              {pixelsPerInterval: 20,  unit: Timeline.DateTime.SECOND},
              {pixelsPerInterval: 280,  unit: Timeline.DateTime.MINUTE},
              {pixelsPerInterval: 100,  unit: Timeline.DateTime.MINUTE},
              {pixelsPerInterval: 60,  unit: Timeline.DateTime.MINUTE},
              {pixelsPerInterval: 20,  unit: Timeline.DateTime.MINUTE},
              {pixelsPerInterval: 280,  unit: Timeline.DateTime.HOUR},
              {pixelsPerInterval: 100,  unit: Timeline.DateTime.HOUR},
              {pixelsPerInterval:  70,  unit: Timeline.DateTime.HOUR},
              {pixelsPerInterval:  35,  unit: Timeline.DateTime.HOUR},
        ],
        theme: theme
     }),
     Timeline.createBandInfo({
         width:          "15%",
         intervalUnit:   Timeline.DateTime.DAY,
         intervalPixels: 200
     })
    ];
    bandInfos[1].syncWith = 0;
    bandInfos[1].highlight = true;

    // create timeline
    timeline = Timeline.create($(config.CSS.IDs.timeline), bandInfos);
    timeline.layout();

    // init date bounds
    timeline_minDate = timeline.getBand(0).getMinVisibleDate();
    timeline_maxDate = timeline.getBand(0).getMaxVisibleDate();

    var updatingViaScroll = 0;
    // timeline scrolling - gets called as soon as timeline is drawn or moved
    timeline.getBand(0).addOnScrollListener(function(band) {
      if(updatingViaScroll) {
        return;
      }
      var minDate = band.getMinVisibleDate();
      var maxDate = band.getMaxVisibleDate();

      // if beyond bounds
      if (minDate <= timeline_minDate || maxDate >= timeline_maxDate) {
        // update bounds
        var dateOverlap = maxDate.getTime() - minDate.getTime();
        timeline_minDate.setTime(minDate.getTime() - dateOverlap);
        timeline_maxDate.setTime(maxDate.getTime() + dateOverlap);

        // start async download
        updatingViaScroll=1;
        updateTimeline( function(){ updatingViaScroll=0 } );
      }
    });

    // timeline resizing
    var resizeTimerID = null;
    Event.observe(document.body, 'resize', function() {
      if (resizeTimerID == null) {
        resizeTimerID = window.setTimeout(function() {
            resizeTimerID = null;
            timeline.layout();
        }, 500);
      }
    });

    // table data updates
    var tableUpdated = function(ev) {
      // page buttons
      var page = ev.table.getPage();
      var pages = ev.table.getNumberOfPages();
      function disableButton() { this.disabled = true; }
      function enableButton() { this.disabled = false; }

      // page back buttons
      var backButtons = $J('.'+config.CSS.classes.paging.prev);
      if (page <= 1) backButtons.each(disableButton);
      else backButtons.each(enableButton);

      // page forward buttons
      var forwardButtons = $J('.'+config.CSS.classes.paging.next);
      if (page >= pages) forwardButtons.each(disableButton);
      else forwardButtons.each(enableButton);

      // update page number
      $J('.'+config.CSS.classes.paging.num).each(function() {
        this.innerHTML = "" + page;
      });

      // previous & next page links (parameterized function)
      function setlinks(diff) { return function() {
        var links = "";
        var start = page+1; var end = page+diff;
        if (diff < 0) { start = page+diff; end = page-1; }
        for (var i = start; i <= end; i++) {
          if (i > 1 && i < pages)
            links += "<a class='" + config.CSS.classes.textLink +
                     "' onclick='"+config.moduleName+".setPage("+i+");'>"+i+"</a>\n";
        }
        if (diff < 0) { if (page > 1) links = "<a class='" + config.CSS.classes.textLink +
                     "' onclick='"+config.moduleName+".setPage(1);'>1</a>..." + links; }
        else { if (page < pages) links = links + "...<a class='" + config.CSS.classes.textLink +
                     "' onclick='"+config.moduleName+".setPage("+pages+");'>"+pages+"</a>\n"; }
        this.innerHTML = links;
      };}
      $J('.'+config.CSS.classes.paging.prevLinks).each(setlinks(-3));
      $J('.'+config.CSS.classes.paging.nextLinks).each(setlinks(3));
    };
    table.addEventListener("tableupdated", tableUpdated);
    tableUpdated({ table: table, tableSettings: table.getTableSettings(), tableId: table.tableId }); // init buttons

    // filter settings change
    var __previousTableSettings;
    var first_load=1;
    var filterChanged = function(ev) {
      var s = ev.tableSettings;

      // update filter text boxes
      function setVal(id, val) {
          var e = $(id);
          if (e) e.value = val;
      }
      setVal(config.CSS.IDs.filter.form.startTime, s.startTime);
      setVal(config.CSS.IDs.filter.form.endTime, s.endTime);
      setVal(config.CSS.IDs.filter.form.search, s.search.join(" "));

      // update rows dropdown
      var rowDropDown = $(config.CSS.IDs.filter.form.rows);
      var opts = rowDropDown.options;
      for (var i = 0; i<opts.length; i++) {
        if (opts[i].value == ""+s.rows) {
          opts[i].selected = "true";
          rowDropDown.selectedIndex = i;
          break;
        }
      }

      // update filter multiselects
      function setArraySpan(listname) {
        function notin(lst,value) { var c=lst.childElements; for(var i=0;i<c.length;i++) {
            if (c[i].title == value) return false; } return true; }

        var tableId = ev.tableId;
        var arry = s[listname];
        var lst = $(config.CSS.IDs.filter.form[listname].list);
        assert_notnull(lst, config.CSS.IDs.filter.form[listname].list);
        lst.update(); // clear list

        // add items to list
        for (var i = 0; i < arry.length; i++) {
          var value = arry[i];
          // if not already in span
          if (notin(lst, value)) {
            // get name of element
            var name = config.getName(listname, value);
            // add to list element
            var spn = new Element('span', { title: value }).update("<br />"+name+' ');
            spn.appendChild(new Element('a',
              {href: "javascript:"+config.moduleName+".removeFromFilterList('"
                 + listname + "', '" + value + "')"}).update(config.labels.removeFromList));
            lst.appendChild(spn);
          }
        }
      }
      setArraySpan('host');
      setArraySpan('host_group');
      setArraySpan('service');
      setArraySpan('host_state');
      setArraySpan('service_state');
      setArraySpan('keyword');
      setArraySpan('state_type');

      // update column check boxes
      function setCol(idx) { var o = $(config.CSS.IDs.filter.form.showCol+idx); o.checked = (s.cols.indexOf(idx) >= 0); }
      for (var i = 0; i <= 6; i++) { setCol(i); }

      // update page title & filter summary
      var summary = s.toHTMLDescription();
      $(config.CSS.IDs.filter.summary).update(summary);
      document.title = config.labels.documentTitle + s.toHTMLDescription(true);

      // update summarys of filter
      function setVals(cls, value) {
        $J('.' + cls).each(function() {
          this.innerHTML = value;
        });
      }
      // time
      var msg = s.startTime + " - " + s.endTime;
      if (s.startTime == "") msg = config.labels.beforeTime + " " + s.endTime;
      if (s.endTime == "") {
        if (s.startTime != "") msg = config.labels.afterTime + " " + s.startTime;
        else msg = config.labels.anyTime;
      }
      setVals(config.CSS.classes.filter.time, msg);
      // host, service, state, state_type
      function summarizeArray(arr) {
        if (arr.length == 0) return config.labels.anyFilter;
        else {
          var s = arr[0];
          if (s.length>30) s=s.substring(0,30)+"...";
          if (arr.length > 1) s += "...";
          return s;
        }
      }
      assert_notnull(s.host, "settings.host", s);
      setVals(config.CSS.classes.filter.host, summarizeArray(s.host));
      assert_notnull(s.service, "settings.service", s);
      setVals(config.CSS.classes.filter.service, summarizeArray(s.service));
      assert_notnull(s.host_state, "settings.host_state", s);
      assert_notnull(s.service_state, "settings.service_state", s);
      var state = s.host_state.clone();
      for (var i=0,l=s.service_state.length;i<l;i++) state.push(s.service_state[i]);
      setVals(config.CSS.classes.filter.state, summarizeArray(state));
      assert_notnull(s.host_group, "settings.host_group", s);
      var groups = [];
      for (var i=0,l=s.host_group.length;i<l;i++) groups[i] = config.getName('host_group', s.host_group[i]);
      setVals(config.CSS.classes.filter.host_group, summarizeArray(groups));
      assert_notnull(s.state_type, "settings.state_type", s);
      setVals(config.CSS.classes.filter.state_type, summarizeArray(s.state_type));

      // helper functions, see if a filter setting relevant to timeline data has changed
      function array_eq(a,b) {
        if (a.length!=b.length) return false;
        for (var i=0; i< a.length; i++) if (a[i] != b[i]) return false;
        return true;
      }
      function relevantSettingChanged(s, ps) {
        return !array_eq(ps.host, s.host) || !array_eq(ps.service, s.service) ||
               !array_eq(ps.keyword, s.keyword) || !array_eq(ps.host_state, s.host_state) ||
               !array_eq(ps.service_state, s.service_state) || !array_eq(ps.state_type, s.state_type) ||
               !array_eq(ps.search, s.search) || !array_eq(ps.host_group, s.host_group);
      }

      // if filter changed, ignoring: page, sort & time changes
      var ps = __previousTableSettings;
      if (!ps || relevantSettingChanged(s, ps)) {
        __previousTableSettings = s.clone();
        ps = __previousTableSettings;

        // update timeline data
        // Ignore unnecessary first load - not sure where this is set
        if (!first_load)
          updateTimeline();
        else
          first_load=0;

        // Reset timer
        refreshTimer.start();
      }

      // update timeline position if time has changed
      if (ps.startTime != s.startTime && s.startTime && s.startTime != "")
        timeline.getBand(0).setMinVisibleDate(s.strToDate(s.startTime));
      if (ps.endTime != s.endTime && s.endTime && s.endTime != "")
        timeline.getBand(0).setMaxVisibleDate(s.strToDate(s.endTime));
    };
    table.addEventListener("settingschanged", filterChanged);
    filterChanged({ table: table, tableSettings: table.getTableSettings(), tableId: table.tableId });

  };

  // update timeline data if visible
  function updateTimeline(callback) {
    var vis = $(config.CSS.IDs.timelineContainer).visible();
    if (vis)
        _updateTimelineRequest(callback);
  }

  function _updateTimelineRequest(callback) {
    // params for webservice
    var settings = table.getTableSettings();
    var params = settings.toParameters();
    params.startTime = settings.dateToStr(timeline_minDate);
    params.endTime = settings.dateToStr(timeline_maxDate);
    params.page = 1;
    params.cols = ["time", "hostname", "servicename", "state", "state_type", "output"];
    delete params['rows']; // max rows
    delete params['sortby']; // default sort

    // download data
    function ifdef(o, str) { if (o) return str; else return ""; }
    new Ajax.Request(config.URLs.json, {
      method: 'get',
      parameters: params,
      requestHeaders: {Accept: 'application/json'},
      onSuccess: function(transport){
        //console.log(new Date + ": Finished callback");
        var json = transport.responseText.evalJSON(true);
        var list = json.ResultSet.list;

        // format data
        //console.log(new Date + ": Reformat data");
        var data = {'dateTimeFormat': 'iso8601', 'events': []};
        var markdownConverter = new Showdown.converter();
        for (var i = 0, l=list.length; i<l; i++) {
          var ev = list[i];
          var outputClasses = [ "opsview-timeline-output", ev.state.toLowerCase() ];
          if (ev.markdown == 1) {
            ev.output = markdownConverter.makeHtml(ev.output);
            outputClasses.push("markdown");
          }
          var o = {
            start: ev.time+"Z",
            title: ev.hostname,
            caption: ev.hostname + ( ev.servicename ? "::" + ev.servicename : "" ),
            description: config.labels.host + ": " + ev.hostname + "<br />\n" +
                         ( ev.servicename ? config.labels.service + ": " + ev.servicename + "<br />\n" : "" ) +
                         config.labels.state + ": " + ev.state + "<br />\n" +
                         config.labels.time + ": " + ev.time + "<br />\n" +
                         ifdef(ev.output, "<div class='" + outputClasses.join(" ") + "'>" + ev.output + "</div>")
          };
          if (ev.state) {
            o.icon = config.stateIcon(ev);
            o.image = o.icon;
          }
          data.events.push(o);
        }

        //console.log(new Date + ": Load data");
        // load into timeline
        timeline_eventSource.clear();
        timeline_eventSource.loadJSON(data, '.');
        //console.log(new Date + ": Fin");

        // callback
        if (typeof refreshTimer == "object") refreshTimer.clearErrorMessage();
        if (Object.isFunction(callback)) callback(transport, false);
      },
      onFailure: function(transport) {
        // callback
        if (typeof refreshTimer == "object") refreshTimer.setErrorMessage(config.labels.timelineUpdateError);
        if (Object.isFunction(callback)) callback(transport, true);
      }
    });
  };

  // set time of timeline
  function setTimelineTime(dt) {
    var e = $(config.CSS.IDs.timelineContainer);
    if (!e.visible()) {
      e.show();
      timeline.layout();
      setTimelineLinkText(false);
    }
    setCenterVisibleDateIfVisible(dt);
  };

  // Use this so table updates do not change centering of timeline
  function setCenterVisibleDateIfVisible(dt) {
    var vis = $(config.CSS.IDs.timelineContainer).visible();
    if (vis) {
        timeline.getBand(0).setCenterVisibleDate(dt);
    }
  }

  // toggle whether timeline is visible or not
  function toggleTimelineVisibility() {
    var e = $(config.CSS.IDs.timelineContainer);
    e.toggle();
    var vis = e.visible();
    setTimelineLinkText(vis);
    if (vis) {
      if (initialTimelineVisible==false) {
        // Need to draw layout otherwise empty timeline
        // This also calls updateTimeline()
        timeline.layout();
        initialTimelineVisible=true;
        setCenterVisibleDateIfVisible(new Date);
      }
      else {
        // Always update timeline when toggling
        updateTimeline();
      }
    }
  };

  function setTimelineLinkText(state) {
    var msg = state ? config.labels.hideTimeline : config.labels.showTimeline;
    $(config.CSS.IDs.timelineLink).setAttribute('title', msg);
    var icon = state ? config.icons.timelineToggleOn : config.icons.timelineToggleOff;
    $(config.CSS.IDs.timelineLinkIcon).setAttribute('src', icon);
  }

  // toggle whether timeline is visible or not
  function togglePlaySounds() {
    playSounds = !playSounds;
    setPlaySoundsButton(playSounds);
  };


  function setPlaySoundsButton(state) {
    var msg = state ? config.labels.muteSounds : config.labels.playSounds;
    $(config.CSS.IDs.playSoundsButton).setAttribute('title', msg);
    var icon = state ? config.icons.playSounds : config.icons.muteSounds;
    $(config.CSS.IDs.playSoundsButtonIcon).setAttribute('src', icon);
  }

  // sets whether a column in the table is visible
  function setColumnVisibility(idx, value) {
    var s = table.getTableSettings();
    var i = s.cols.indexOf(idx);
    if (i >= 0) {
      if (!value) s.cols.splice(i, 1);
    } else {
      if (value) s.cols.push(idx);
    }
    table.setTableSettings(s);
  };

  // change a filter setting
  function setFilterSetting(name, value) {
    var s = table.getTableSettings();
    if (Object.isString(name)) {
      // set a single setting
      if (Object.isArray(value) && value.length == 1 && value[0] == "") value = [];
      s[name] = value;
    } else if (typeof name == "object") {
      // set multiple settings
      var values = name;
      for (var n in values) {
        s[n] = values[n];
      }
    }
    s.page = 1; // return to first page
    table.setTableSettings(s);
  };

  // adds a string value to the string array named 'listname'
  // in the table's settings
  function addToFilterList(listname, value, box) {
    // ignore add to filter
    if (value == "") return;

    // get settings
    var s = table.getTableSettings();
    var values = s[listname];

    // if not already in list
    if (values.indexOf(value) < 0) {
      // add to list
      values.push(value);
      table.setTableSettings(s);
    }

    // return to top
    if (box) box.selectedIndex = 0;
  }

  // removes the string value from the string array names 'listname'
  // in the table's settings
  function removeFromFilterList(listname, value) {
    // get settings
    var s = table.getTableSettings();
    var values = s[listname];

    // remove from array
    var idx = values.indexOf(value);
    if (idx >= 0) {
      // remove from list
      values.splice(idx, 1);
      table.setTableSettings(s);
    }
  };

  // set current page
  function setPage(value) {
    table.setPage(value);
  };

  // get current page number
  function getPage() {
    return table.getPage();
  };

  // get number of pages
  function getPageCount() {
    return table.getNumberOfPages();
  };

  // export events from the current filter
  function exportData(outputType, box) {
    if (outputType != "") {
      var params = table.getTableSettings().toParameters();
      params.page = 1;
      params.output = outputType;
      delete params['rows']; // max rows
      window.open("?" + Object.toQueryString(params));
      if (box) box.selectedIndex = 0;
    }
  };

  // refreshes the data
  function refreshData(callback) {
    var cb = function(transport, wasError) {
      // if was an error, set the error message
      var errorMsg = wasError ? transport.status + ":" + transport.statusText : false;
      if (Object.isFunction(callback)) {
        callback(transport, errorMsg);
      }
    };
    table.updateTable(cb, true);
    updateTimeline();
  };

  // resets event id marker for new data
  function acknowledgeNewEvents() {
    // reset id
    markerDate = new Date();
    markerEventID = currentMaxEventID;
    table.tableSettings.saved_maxeventid = currentMaxEventID;
    // hide ack button
    var e = $(config.CSS.IDs.newevents.container);
    if (e) e.hide();
    // unhighlight highlighted rows
    table.clearNewEventHighlighting();
  };

  // sets if auto refresh is enabled or not
  function setAutoRefreshEnabled(enabled) {
      table.tableSettings.detectNewData = enabled;
      // enable/disable timer
      refreshTimer.setEnabled(enabled);
  };

  function postLoad() {
    setTimelineLinkText(initialTimelineVisible);
  }

  // public members
  return {
    config: config, // config object
    overrideConfig: overrideConfig, // overrides config settings with those defined (call before init/doc load)
    init: init, // init module
    setTimelineTime: setTimelineTime, // sets current timeline time
    toggleTimelineVisibility: toggleTimelineVisibility, // toggles timeline vis
    togglePlaySounds: togglePlaySounds, // toggles play/mute sounds
    setColumnVisibility: setColumnVisibility, // sets a table column vis
    setFilterSetting: setFilterSetting, // sets a filter setting
    addToFilterList: addToFilterList, // adds a flag to a filter list
    removeFromFilterList: removeFromFilterList, // removes a flag from a filter list
    setPage: setPage, // sets the current page
    getPage: getPage, // gets the current page
    getPageCount: getPageCount, // gets the number of pages in result set
    exportData: exportData, // redirects to export data
    refreshData: refreshData, // refresh data from server
    acknowledgeNewEvents: acknowledgeNewEvents, //  resets marker max event id, and clears highlighted rows
    setAutoRefreshEnabled: setAutoRefreshEnabled, // enables/disables auto refresh
    postLoad: postLoad // postLoad functions
  };

}();

$J(document).ready(function() {
  // Check for Showdown
  if (typeof Showdown != "object") {
    alert("showdown.js not found");
  }
  // init events view
  eventsView.init();

  // setup refresh timer
  if (typeof refreshTimer == 'object') {
    refreshTimer.setUseAjaxUpdater(false);
    refreshTimer.addListener(function (cb) {
      eventsView.refreshData(cb);
    });
  };
  eventsView.setAutoRefreshEnabled(eventsView.config.auto_refresh);
  eventsView.postLoad();
});

