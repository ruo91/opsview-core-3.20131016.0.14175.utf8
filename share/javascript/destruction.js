// Destruction
// JavaScript object destruction framework
// Requires: prototype
// Author: Tristan Aubrey-Jones, Opsview Limited 15/10/2009

// Destruction namespace
var Destruction = function() {

  // dismantle object references, so can be garbage collected
  // void destroy(obj1, obj2, obj3...)
  function destroy() {
    // for each argument
    for (var i=0,l=arguments.length;i<l;i++) {
      try {
        var o = arguments[i];
        var t = typeof o;
        // if an object
        if (t == 'object') {
          // delete all properties recursively
          for (var k in o) {
            destroy(o[k]);
            delete o[k];
          }
        }
      } catch (ex) {
        // fail silently...
      }
    }
  };

  // if prototype
  var Destructable = null;
  if (typeof Prototype == 'object') {
    Destructable = Class.create({
      initialize: function() {},
      destroy: function() {
        return destroy(this);
      }
    });
  }

  // public
  return {
    destroy: destroy,
    Destructable: Destructable
  };

}();

