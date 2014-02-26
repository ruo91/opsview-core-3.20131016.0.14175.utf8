/*
 * This code taken from
 *    http://scriptnode.com/article/javascript-print_r-or-var_dump-equivalent/
 */

/**
 * Concatenates the values of a variable into an easily readable string
 * by Matt Hackett [scriptnode.com]
 * @param {Object} x The variable to debug
 * @param {Number} max The maximum number of recursions allowed (keep low, around 5 for HTML elements to prevent errors) [default: 10]
 * @param {String} sep The separator to use between [default: a single space ' ']
 * @param {Number} l The current level deep (amount of recursion). Do not use this parameter: it's for the function's own use
 */

 /* examples 
  // EXAMPLE 1
  var myVar1 = {'true' : true, 'false' : false, num : 3};
  alert(print_r(myVar1));

  // EXAMPLE 2
  var myVar2 = [{'legend' : 'zelda'}, {'foo' : {'bar' : null}}, 'a', 'b', [1, 2, { 'key' : 'value'}, 'bill', 'ted']];
  alert(print_r(myVar2, 10, "\t"));

  // EXAMPLE 3 (this one outputs a LOT, even with a max of 5)
  var myVar3 = document.body;
  alert(print_r(myVar3, 5));

  for more complex examples you could use
  document.writeln(print_r(xxxx))
*/

function print_r(x, max, sep, l) {

    l = l || 0;
    max = max || 10;
    sep = sep || ' ';

    if (l > max) {
        return "[WARNING: Too much recursion]\n";
    }

    var
        i,
        r = '',
        t = typeof x,
        tab = '';

    if (x === null) {
        r += "(null)\n";
    } else if (t == 'object') {

        l++;

        for (i = 0; i < l; i++) {
            tab += sep;
        }

        if (x && x.length) {
            t = 'array';
        }

        r += '(' + t + ") :\n";

        for (i in x) {
            try {
                r += tab + '[' + i + '] : ' + print_r(x[i], max, sep, (l + 1));
            } catch(e) {
                return "[ERROR: " + e + "]\n";
            }
        }

    } else {

        if (t == 'string') {
            if (x == '') {
                x = '(empty)';
            }
        }

        r += '(' + t + ') ' + x + "\n";

    }

    return r;

};
var_dump = print_r;

function firebug() {
    try {
        console.log( "bing" + arguments.join ( ' ' ) );
    } catch (e) {
        // too noisy on IE so do nothing here
        //alert("You don't have Firebug!\nFor shame...");
    }
};
