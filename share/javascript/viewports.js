// viewportsView module
viewportsView = function() {

  var config = {
    moduleName: "viewportsView",
    labels: {
      removeFromList: "(-)", // [remove]
      keyword: "Keyword"
    },
    url: '/viewport?output=ajax',
    hasOwnRefresh: false,
    queryParams: {},
    attributes: {},
    CSS: {
      IDs: {
        filter: {
          summary: "filter_summary", // filter summary text
          form: { 
            container: "filter_form",
            keyword: {
              list: "filter_keyword_list", // span containing keywords
              select: "filter_keyword_select" // select containing keywords
            }
          }
        }
      }
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
    overrideSettings(config.attributes, config.queryParams);
    var keywords = History.get("keyword");
    if (keywords) {
        if (! Object.isArray(keywords)) {
            keywords = [ keywords ];
        }
        config.attributes.keyword = keywords;
    }
    var style = History.get("style");
    if (style)
        config.attributes.style = style;
  };

  // change a filter setting
  function setFilterSetting(name, value) {
    var s = config.attributes;
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
    filterChanged();
    viewportsView.refreshData();
  };

  // adds a string value to the string array named 'listname'
  // in the table's settings
  function addToFilterList(listname, value, box) {
    // ignore add to filter
    if (value == "") return;

    // get settings
    var s = config.attributes;
    var values = s[listname];

    // if not already in list
    if (values.indexOf(value) < 0) {
      // add to list
      values.push(value);
      filterChanged();
      viewportsView.refreshData();
    }

    // return to top
    if (box) box.selectedIndex = 0;
  }

  // removes the string value from the string array names 'listname'
  // in the table's settings
  function removeFromFilterList(listname, value) {
    // get settings
    var s = config.attributes;
    var values = s[listname];
  
    // remove from array
    var idx = values.indexOf(value);
    if (idx >= 0) {
      // remove from list
      values.splice(idx, 1);
    }
    filterChanged();
    viewportsView.refreshData();
  };

  // refreshes the data
  function refreshData(callback) {
    if (viewportsView.config.hasOwnRefresh)
        return
    var cb = function(transport, wasError) {
      // if was an error, set the error message
      var errorMsg = wasError ? transport.status + ":" + transport.statusText : false;
      if (Object.isFunction(callback)) {
        callback(transport, errorMsg);
      }
    };
    //alert(Object.toQueryString(config.attributes));
    new Ajax.Updater({
      success: 'main_content',
      failure: 'ignored' },
      config.url,
      {
        asynchronous:true,
        evalScripts:true,
        method:'post',
        postBody: Object.toQueryString(config.attributes),
        onSuccess: function(t) { refreshTimer.refresh_finish(t); },
        onFailure: function(t) { refreshTimer.refresh_finish(t, t.status + ": " + t.statusText); }
      });
  };

  function setPageTitle( title ) {
    if (title=="")
      title=config.labels.default_page_title;
    var escaped = title.escapeHTML();
    $('page_header').innerHTML=escaped;
    document.title = config.labels.window_title + title;
  };

  function assert_notnull(value, desc, obj) {
    if (typeof value == 'undefined') {
      var dump = "";
      if (typeof obj != 'undefined') dump = Object.toJSON(obj);
      alert("Assertion 'not null' failed: " + desc + "\n\n" + dump);
    }
  };

  var filterChanged = function(first_run) {
      var s = config.attributes;

      // update filter text boxes
      function setVal(id, val) {
          var e = $(id);
          if (e) e.value = val;
      }

      // update filter multiselects
      function setArraySpan(listname) {
        function notin(lst,value) { var c=lst.childElements; for(var i=0;i<c.length;i++) { 
            if (c[i].title == value) return false; } return true; }

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
      if (config.attributes.keyword) {
        setArraySpan('keyword');
        !first_run && History.set("keyword", config.attributes.keyword);
      }
      if (config.attributes.style) 
        !first_run && History.set("style", config.attributes.style);
      if (typeof config.attributes.page_title != 'undefined') {
        setPageTitle(config.attributes.page_title);
        !first_run && History.set("page_title", config.attributes.page_title);
      }
    };
  function init() {
    // Save initial page header, for when page title is given as blank
    config.labels.default_page_title = $('page_header').innerHTML;
    var page_title = History.get("page_title");
    if (Object.isString(page_title)) {
        $('filter_page_title').value = page_title;
        setPageTitle(page_title);
    }
    filterChanged(1);
  };

  // public members
  return { 
    config: config, // config object
    overrideConfig: overrideConfig, // overrides config settings with those defined (call before init/doc load)
    init: init, // init module
    setFilterSetting: setFilterSetting, // sets a filter setting
    addToFilterList: addToFilterList, // adds a flag to a filter list
    removeFromFilterList: removeFromFilterList, // removes a flag from a filter list
    refreshData: refreshData // refresh data from server
  };

}();

$J(document).ready(function() { 
  // init events view
  viewportsView.init(); 

  // setup refresh timer
  if (typeof refreshTimer == 'object') {
    refreshTimer.setUseAjaxUpdater(false);
    refreshTimer.addListener(function (cb) {
      viewportsView.refreshData(cb);
    });
  };
  // Load first time
  viewportsView.refreshData();
});

