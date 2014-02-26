jQuery171(document).ready(function($){
    $('#filter_search').placeholder();

});


function toggleModalContentBox(linkID, contentBoxID, labelOn, labelOff, position, sourceURL, sourceElemID) {
    var $ = window.jQuery171;
    if ( ! $('#'+ contentBoxID).hasClass('ui-dialog') ) {
        $('#'+ contentBoxID).dialog({
            autoOpen: false,
            modal: false,
            height: 400,
            width: 600,
            draggable: true,
            resizable: false,
            position: position,
            zIndex: 20001,
            close: function(ev, ui) {
                $('#'+ linkID).text(labelOff);
            }
        });
    }
    if ( $('#'+ contentBoxID).dialog('isOpen') ) {
        $('#'+ linkID).text(labelOff);
        $('#'+ contentBoxID).dialog('close');
        return false;
    }
    if ( sourceURL ) {
        $.ajax({
            url: sourceURL,
            cache: true,
            dataType: 'html',
            success: function(data) {
                $('#'+ contentBoxID).html( data ).dialog('open');
            },
            error: ajaxUpdaterFailures
        });
    } else {
        $('#'+ contentBoxID).dialog('open');
    }
    $('#'+ linkID).text(labelOn);
    return false;
}

function service_exec_popup(id, url) {
    var $ = window.jQuery171;
    $.ajax({
        url: url,
        cache: false,
        dataType: 'html',
        success: function(data) {
            $(data).appendTo($(document.body));
            $('#service_exec_plugin_window_'+id).dialog({
                modal: true,
                height: 400,
                width: 600,
                draggable: true,
                resizable: false,
                zIndex: 20000,
                close: function(ev) {
                    $('#service_exec_plugin_window_'+ id).dialog("destroy");
                    $('#service_exec_plugin_help_output_'+ id).dialog("destroy");
                    $('#service_exec_macro_help_output_'+ id).dialog("destroy");
                    $('#service_exec_plugin_window_'+ id).remove();
                    $('#service_exec_plugin_help_output_'+ id).remove();
                    $('#service_exec_macro_help_output_'+ id).remove();
                    $('#service_exec_plugin_window_wrapper_'+ id).remove();
                }
            });
        }
    });
    return false;
};

function service_exec_print_dot(id) {
    var $ = window.jQuery171;
    $('#service_exec_plugin_output_'+ id).text(
        $('#service_exec_plugin_output_'+ id).text() + '.'
    );
}

function service_exec_command(id, url) {
    var $ = window.jQuery171;
    var args = $('#service_exec_plugin_args_'+ id).val();
    $('#service_exec_plugin_output_'+ id).html('.');
    var dots = window.setInterval("service_exec_print_dot("+ id +")", 500);
    $.ajax({
        type: 'POST',
        url: url,
        cache: false,
        data: {
            plugin_args: args,
            ".auth_cookie": jQuery171.cookie('auth_tkt')
        },
        dataType: 'text',
        beforeSend: function(jqXHR, settings) {
        },
        success: function(data) {
            window.clearInterval(dots);
            $('#service_exec_plugin_output_'+ id).html( data );
        },
        error: function(jqXHR, textStatus, errorThrown) {
            window.clearInterval(dots);
            $('#service_exec_plugin_output_'+ id).html( errorThrown );
        }
    });
}

// Loads the contextual menu with the contents of url
function load_context_menu(e, url) {
    var cm = jQuery171('#ov-context-menu');
    if (cm.length==0) {
        jQuery171('body').append('<div id="ov-context-menu"></div>');
        cm = jQuery171('#ov-context-menu');
    }
    var y=e.pageY, x=e.pageX;
    if(y===undefined) {
        // Below for IE8. From prototype.js
        var docElement = document.documentElement,
             body = document.body || { scrollLeft: 0 };
        x=(event.clientX + (docElement.scrollLeft || body.scrollLeft) - (docElement.clientLeft || 0));
        y=(event.clientY + (docElement.scrollTop || body.scrollTop) - (docElement.clientTop || 0));
    }
    cm.hide();
    // We position the menu slightly inside the pointer, so that you do not tend to leave the menu "hanging around"
    cm.css({position:"absolute",top:y-5,left:x-2});
    cm.load(url,function(){cm.show();cm.mouseleave(function(){cm.hide()})});
}
