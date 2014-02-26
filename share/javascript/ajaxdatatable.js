// revert '$' back to prototype so avoid compatability issues
$J = jQuery.noConflict();

// start observing history changes
History.Observer.start();

// Ajax Data Table 
// -------------------------
// Uses jquery.dataTables & prototypextensions.History
// to provide an abstract table class which downloads
// data one page at a time via ajax & features 
// history preservation & bookmarking.
// ----------------------------

// AjaxDataTableSettings abstract class
// base class for all data table settings
// stores current table's filter, sort, & page state
var AjaxDataTableSettings = Class.create(Serializable, {
  // constructor
  initialize: function($super) {
    // call super constructor
    $super();

    // automatically update table when settings change?
    this.autoupdate = true;

    // fields
    this.pages = 1; // number of pages available
    this.page = 1; // current page number (starts at 1)
    this.rows = 50; // number of rows to return
    this.sortby = []; // list of 2 element lists e.g. [[1, "asc"], [2, "desc"]] 
    this.cols = []; // array of column indexes (which are visible) e.g. [1, 3, 4]
  },

  // return field types
  getTypeInfo: function() {
    return [
      ['pages', 'integer'],
      ['page', 'integer'],
      ['rows', 'integer'],
      ['cols', { array: 'byte', // byte[]
                 lengthsize: 1 }], // 1B used to store length (up to 255 elements)
      ['sortby', { array: { tuple: ['byte', { enumerated: ['asc', 'desc'] } ] }, 
                   lengthsize: 1 }] // up to 255 elements
    ];
  },

  // returns true if sortby contains the column
  sortContains: function(colidx) {
    for (var i = 0, l = this.sortby.length; i<l; i++) {
      if (this.sortby[i][0] == colidx) return true;
    }
    return false;
  },

  // methods
  // returns a hash of the fields (ommiting those that are
  // empty strings or empty arrays
  toHash: function(fields) {
    var h = {};
    if (fields) { 
      for (var i = 0; i<fields.length; i++) {
        var v = this[fields[i]]; 
        if (v != "" && !(v instanceof Array && v.length == 0)) 
          h[fields[i]] = v; }
    } else {
      for (var k in this) {
        if (typeof this[k] != "function") 
          var v = this[k];
          if (v != "" && !(v instanceof Array && v.length == 0))
            h[k] = v; }
    }
    return h;
  },

  // returns the values of the array of fields
  toArray: function(fields) {
    var a = []; 
    for (var i = 0; i<fields.length; i++) {
      var v = this[fields[i]];
      if (!v) v = "";
      a.push(v); }
   return a;
  },
  fromArray: function(fields, arr) {
    for (var i = 0; i<fields.length; i++) {
      this[fields[i]] = arr[i]; }
  },

  // return settings as hash of parameters for the webservice
  toParameters: function() {
    alert("AjaxDataTableSettings - toParameters not implemented");
  },

  // serialize as a short string (for bookmarking & history)
  toString: function() {
    return this.serialize();
  },

  // deserialize from a short string (for bookmarking & history)
  fromString: function(str) {
    return this.deserialize(str);
  }

});

// AjaxDataTable abstract class
// stores: filter settings, with accessors
// mirrors filter settings in url to preserve history (&allow bookmarking)
// updates table layout when filter settings change
// updates table data when filter settings change
// method "updateTable" updates table with new data from the server

var AjaxDataTable = Class.create({
  // Constructor
  // String tableId - required - id of <table>
  // String url - required - url of webservice
  // AjaxDataTableSettings settings - required - default settings & table state info
  initialize: function(tableId, url, settings, dtOptions) {
    // instance
    var me = this;
    this.tableId = tableId;
    this.dataUrl = url;
    this.tableSettings = settings;

    // alternating row classes
    this.rowClasses = ['odd', 'even'];
    this.rowNum = 0;

    // used to supress recursive updates
    this.__prevHash = ""; // only update when user caused history change
    this.__dontSort = false; // only update when user caused resort

    // used to check for new data
    this.__settingsChangedSinceUpdate = true; // flag so know when settings have changed between updates
    this.__previousData = null;

    // listener arrays
    this.settingsChangedListeners = [];
    this.tableUpdatedListeners = [];
    this.initCompleteListeners = [];   

    // if defined init settings from url hash
    var histSettings = History.get(this.tableId);
    if (histSettings) {
      this.tableSettings.fromString(histSettings);
    }

    // create data table options
    if (typeof dtOptions != 'object') var dtOptions = {};
    dtOptions = $J.extend(true, {
                    "aaSorting": this.tableSettings.sortby,
                    "bPaginate": false,
                    "bLengthChange": false,
                    "bFilter": false,
                    "bSort": true,
                    "bInfo": false,
                    "bAutoWidth": false 
                  }, 
                  dtOptions, {
                    "fnCustomSort": function(dtSettings) {
                       if (!me.__dontSort) { // user caused re-sort
                         // change settings to reflect sort (&updates)
                         var s = me.getTableSettings();
                         s.sortby = dtSettings.aaSorting;
                         s.page = 1; // reset to first page when resort
                         me.setTableSettings(s);
                         me.oTable.fnDraw(true);
                       }
                     }
                });
  
    // create data table
    this.oTable = $J('#' + tableId).dataTable(dtOptions);

    // download data
    me.updateTable();

    // register history observer to update settings & table
    this.__prevHash = History.get(this.tableId);
    History.Registry.set({id: this.tableId, onStateChange: function(value) {
      // in firefox keeps firing every 200ms! workaround = see if changed
      if (me.__prevHash != value) {
        // remember hash (at top so wont keep firing if rest takes long time)
        me.__prevHash = value;
        
        // load settings from hash
        me.tableSettings.fromString(value);
        me.setTableSettings(me.tableSettings);
      }
    }});

    // init complete
    this.dispatchEvent(this.initCompleteListeners);
  },

  // Get/Set Table Settings (calls updateTable, unless dontupdate is true)
  setTableSettings: function(settings, dontupdate) {
    // set settings
    this.tableSettings = settings;
 
    // set flag
    this.__settingsChangedSinceUpdate = true;
   
    // update history only if changed
    var hashStr = this.tableSettings.toString();
    if (hashStr != History.get(this.tableId)) {
      this.__prevHash = hashStr; // incase history observer fires wrongly (supresses update)
      History.set(this.tableId, hashStr);
    }

    // start updating table data (unless told not to)
    if (!dontupdate && this.tableSettings.autoupdate) { 
      this.updateTable(function (t, err) {
        if (err) {
          if (typeof refreshTimer == 'object') 
            refreshTimer.setErrorMessage("Error updating table");
        } else {
          if (typeof refreshTimer == 'object') 
            refreshTimer.clearErrorMessage();
        } 
      });
    }

    // fire any settingschanged events
    this.dispatchEvent(this.settingsChangedListeners);
  },
  getTableSettings: function() {
    // get settings
    return this.tableSettings;
  },

  // Add an event listener
  // Events: "settingschanged": whenever the table settings may have been modified 
  addEventListener: function(type, listener) {
    if (type == "settingschanged") {
      this.settingsChangedListeners.push(listener);
    } else if (type == "tableupdated") {
      this.tableUpdatedListeners.push(listener);
    } else if (type == "initcomplete") {
      this.initCompleteListeners.push(listener);
    }
  },
  // Removes a registered event listener
  removeEventListener: function(type, listener) {
    alert("removeEventListener not implemented (type=" + type + ")");
  },
  // Dispatch event
  dispatchEvent: function(listenerList) {
     var ev = {tableId: this.tableId, tableSettings: this.tableSettings, table: this};
     for (var i = 0; i<listenerList.length; i++) {
       listenerList[i](ev);
     }
  },

  // Update Table Layout/Data
  updateTable: function(cb, forceNewData) {
    var me = this;

    // convert table settings to parameters
    var params = me.tableSettings.toParameters();
    if (forceNewData) params.time = Date().toString();

    // start to download table data
    new Ajax.Request(this.dataUrl, {
      method: 'get',
      parameters: params,
      requestHeaders: {Accept: 'application/json'},
      onSuccess: function(transport){
        // double check for error
        if (transport.status == 0) {
          if (Object.isFunction(cb)) cb(transport, true);
          return false;
        }

        // clear table data
        me.oTable.fnClearTable(0);
    
        // populate html buffer array
        me.html = []; me.htmlNode = null; me.rowArray = null; me.rowNum = 0;
	me.populateTable(transport.responseText);

        // hide any hidden columns
        me.oTable.fnForeachRow(["thead", "tfoot"], 
          function(row, cells, othis) {
            var cols = othis.getTableSettings().cols;
            for (var c = 0, l = cells.length; c<l; c++) {
              if (cols.indexOf(c) >= 0) cells[c].style.display = ""; // "table-cell"; // non ie6!
              else cells[c].style.display = "none";
          }
        }, me);

        // set column sorting
        me.__dontSort = true; // ensure don't trigger update
        me.oTable.fnSort(me.tableSettings.sortby);
        me.__dontSort = false; 

        // redraw from html buffer
        if (me.html.length > 0)
          me.oTable.fnReplaceBody(me.html.join(""));
        if (me.htmlNode !== null)
          me.oTable.fnReplaceBody(me.htmlNode);
        if (typeof me.rowArray == 'object' && Object.isArray(me.rowArray) && me.rowArray.length > 0) {
          me.oTable.fnClearTable();
          me.oTable.fnAddData(me.rowArray);
        }

        // table updated event
        me.dispatchEvent(me.tableUpdatedListeners);

        // if settings havent changed (i.e. data should be identical to last update)
        if (!me.__settingsChangedSinceUpdate) {
          //if (transport.responseText != me.__previousData) {
          //  refreshTimer.audibleAlert("Data changed!", "Table data changed!");
          //}
        }
        me.__settingsChangedSinceUpdate = false;
        me.__previousData = transport.responseText;

        // if callback
        if (Object.isFunction(cb)) cb(transport, false);
      },
      onFailure: function(transport) {
        if (Object.isFunction(cb)) cb(transport, true); 
      }
    });
  },

  // adds a row to the table
  addRow: function(row) {
    var rowClass = this.rowClasses[this.rowNum % this.rowClasses.length];
    this.html.push("<tr class='", row.className, " ", rowClass, "'>");

    var s = this.getTableSettings();
    for (var i = 0,l=row.cells.length; i<l; i++) {
      var c = row.cells[i];
      var style = ""; 
      var colClass = c.classes || [];

      // if col should be hidden
      if (s.cols.indexOf(i) < 0) style = " style='display: none;'";
      // if sorting on it
      else if (s.sortContains(i)) colClass.push("gradeU"); 

      // add to buffer
      this.html.push("<td", style, " class='", colClass.join(" "), "'>", c.innerHTML, "</td>");
    }

    this.html.push("</tr>\n");
    this.rowNum++;
  },

  // Sets current page number (if changes will trigger updateTable)
  setPage: function(value) {
    if (value) {
      var s = this.getTableSettings();

      // 
      if (typeof s.page != "number") alert(typeof s.page);
     
      // if changed
      if (value != s.page) {
        // set
        s.page = value;

        // check bounds
        if (value <= 1) { s.page = 1; }
        else if (value >= s.pages) { s.page = s.pages; }

        // assign to settings
        this.setTableSettings(s);
      }
      return s.page;
    } 
    else alert("AjaxDataTable.setPage Null page number");
  },
  // Gets current page number
  getPage: function($super) {
    return this.tableSettings.page;
  },
  // Increment page by an integer
  incPage: function(diff) {
    if (!diff) alert("AjaxDataTable.incPage Null diff number");
    else return this.setPage(this.getPage() + diff);
  },
  // Get number of pages
  getNumberOfPages: function() {
    return this.tableSettings.pages;
  },

  // Takes the responseText and populates the table with the data 
  populateTable: function(responseText) {
    alert("populateTable not implemented (reponseText=" + Object.toJSON(data) + ")");
  }

});

// Iterates over table headers and rows calling
// processRow(row, cells) for all of them
// sections = ["thead", "tbody", "tfoot"]
$J.fn.dataTableExt.oApi.fnForeachRow = function ( oSettings, sections, processRow, args ) {
  if (processRow) { 
    // row func
    function processRows(section, celltype) {
      var rows = $J(section+' tr', oSettings.nTable);
      for (var i = 0; i < rows.length; i++) {
        var cells = rows[i].getElementsByTagName(celltype);
        processRow(rows[i], cells, args);
      }
    }
    // call for each section
    for (var i = 0, l = sections.length; i<l; i++) {
      var celltype = (sections[i] == "tbody") ? "td" : "th";
      processRows(sections[i], celltype); 
    }
  }
}

// Adds some more html to end
$J.fn.dataTableExt.oApi.fnReplaceBody = function ( oSettings, innerHTML ) {
  // create new tbody
//  var newbody = $(document.createElement('tbody'));
//  newbody.update(innerHTML);
  // get old tbody
  var t = $J('tbody', oSettings.nTable)[0]; // for some reason the content of t isnt editable in ie?!
  var oldbody = $(t); // but this is...
  if (typeof innerHTML == 'string') {
    oldbody.update(innerHTML);
  } else {
    oldbody.parentNode.replaceChild(innerHTML,oldbody);
  }
  return oldbody;
  // insert new tbody before old
//  oldbody.insert({ after: newbody });
  // delete old one
//  oldbody.parentNode.removeChild(oldbody);
  // return new tbody
//  return newbody;
}
