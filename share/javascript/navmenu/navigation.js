var jQuery = window.jQuery171;
/*
* jQuery Mobile Framework : events
* Copyright (c) jQuery Project
* Dual licensed under the MIT or GPL Version 2 licenses.
* http://jquery.org/license
*/
(function(a,b,c){function i(b,c,d){var e=d.type;d.type=c;a.event.handle.call(b,d);d.type=e}a.each(("touchstart touchmove touchend orientationchange throttledresize "+"tap taphold swipe swipeleft swiperight scrollstart scrollstop").split(" "),function(b,c){a.fn[c]=function(a){return a?this.bind(c,a):this.trigger(c)};a.attrFn[c]=true});var d=a.support.touch,e="touchmove scroll",f=d?"touchstart":"mousedown",g=d?"touchend":"mouseup",h=d?"touchmove":"mousemove";a.event.special.scrollstart={enabled:true,setup:function(){function g(a,c){d=c;i(b,d?"scrollstart":"scrollstop",a)}var b=this,c=a(b),d,f;c.bind(e,function(b){if(!a.event.special.scrollstart.enabled){return}if(!d){g(b,true)}clearTimeout(f);f=setTimeout(function(){g(b,false)},50)})}};a.event.special.tap={setup:function(){var b=this,c=a(b);c.bind("vmousedown",function(d){function k(a){j();if(e==a.target){i(b,"tap",a)}}function j(){h();c.unbind("vclick",k).unbind("vmouseup",h).unbind("vmousecancel",j)}function h(){clearTimeout(g)}if(d.which&&d.which!==1){return false}var e=d.target,f=d.originalEvent,g;c.bind("vmousecancel",j).bind("vmouseup",h).bind("vclick",k);g=setTimeout(function(){i(b,"taphold",a.Event("taphold"))},750)})}};a.event.special.swipe={scrollSupressionThreshold:10,durationThreshold:1e3,horizontalDistanceThreshold:30,verticalDistanceThreshold:75,setup:function(){var b=this,d=a(b);d.bind(f,function(b){function j(b){if(!f){return}var c=b.originalEvent.touches?b.originalEvent.touches[0]:b;i={time:(new Date).getTime(),coords:[c.pageX,c.pageY]};if(Math.abs(f.coords[0]-i.coords[0])>a.event.special.swipe.scrollSupressionThreshold){b.preventDefault()}}var e=b.originalEvent.touches?b.originalEvent.touches[0]:b,f={time:(new Date).getTime(),coords:[e.pageX,e.pageY],origin:a(b.target)},i;d.bind(h,j).one(g,function(b){d.unbind(h,j);if(f&&i){if(i.time-f.time<a.event.special.swipe.durationThreshold&&Math.abs(f.coords[0]-i.coords[0])>a.event.special.swipe.horizontalDistanceThreshold&&Math.abs(f.coords[1]-i.coords[1])<a.event.special.swipe.verticalDistanceThreshold){f.origin.trigger("swipe").trigger(f.coords[0]>i.coords[0]?"swipeleft":"swiperight")}}f=i=c})})}};(function(a,b){function g(){var a=e();if(a!==f){f=a;c.trigger("orientationchange")}}var c=a(b),d,e,f;a.event.special.orientationchange=d={setup:function(){if(a.support.orientation){return false}f=e();c.bind("throttledresize",g)},teardown:function(){if(a.support.orientation){return false}c.unbind("throttledresize",g)},add:function(a){var b=a.handler;a.handler=function(a){a.orientation=e();return b.apply(this,arguments)}}};a.event.special.orientationchange.orientation=e=function(){var a=document.documentElement;return a&&a.clientWidth/a.clientHeight<1.1?"portrait":"landscape"}})(jQuery,b);(function(){a.event.special.throttledresize={setup:function(){a(this).bind("resize",c)},teardown:function(){a(this).unbind("resize",c)}};var b=250,c=function(){f=(new Date).getTime();g=f-d;if(g>=b){d=f;a(this).trigger("throttledresize")}else{if(e){clearTimeout(e)}e=setTimeout(c,b-g)}},d=0,e,f,g})();a.each({scrollstop:"scrollstart",taphold:"tap",swipeleft:"swipe",swiperight:"swipe"},function(b,c){a.event.special[b]={setup:function(){a(this).bind(c,a.noop)}}})})(jQuery,this)


jQuery.fn.megaMenu = function()
{

	var	menuItem = jQuery('.opsview_menu li'),
	    menuItemLink = jQuery(menuItem).find('a');
	    menuItemChildren = jQuery(menuItem).children('div');

	function openCloseMegamenu() {

		jQuery(menuItemLink).bind({

			touchstart: function(e) {

				var $this = jQuery(this);

				$this.parent('li').toggleClass('isvisible');

				if( $this.parent('li').hasClass('isvisible') ) {
					if( $this.parent('li').hasClass('right') ) {
						$this.parent('li').removeClass('noactive').children('div').css("left", "auto");
					}
					else {
						if( $this.next('div').hasClass('dropdown_fullwidth') ) {
							$this.parent('li').removeClass('noactive').children('div').css("left", "20px");
						}
						else {
							$this.parent('li').removeClass('noactive').children('div').css("left", "0px");
						}
					}
					$this.parent('li').siblings().addClass('noactive').removeClass('isvisible').children('div').css("left", "-999em");
				}

				else {
					$this.parent('li').addClass('noactive').children('div').css("left", "-999em");
				}
			}

		});

		jQuery('.opsview_menu').bind('touchstart', function(e) {
			e.stopPropagation();
		});
		jQuery(document).bind('touchstart', function(){
			jQuery(menuItemChildren).css("left", "-999em");
			jQuery(menuItem).addClass('noactive').removeClass('isvisible');
		});


	}

	openCloseMegamenu();

}

var opsview_timer;
var opsview_status_colors = {
  "ok":"#9ED515",
  "warn":"#FFDB58",
  "crit":"#ff5555"
};
function getStatusForBar() {
    jQuery.ajax({
        url: OpsviewNavigation.uri.admin_status_opsview,
        type: 'POST',
        dataType: 'xml',
        processData: true,
        success: updateLights
    });
}

function updateLights(xmlOpsview) {
    /* xmlOpsview will be null when connection is terminated except IE, so check length of childNodes */
    if (xmlOpsview && xmlOpsview.childNodes.length > 0) {
        setLights(xmlOpsview);
    }
    if ( OpsviewNavigation.check_status_interval ) {
        opsview_timer = window.setTimeout("getStatusForBar()", 30000);
    }
}
function setLights(xmlOpsview) {
    var opsview_status;
    var opsview_configuration;
    var el;
    if (el = xmlOpsview.getElementsByTagName('status').item(0) ) {
        opsview_status = el.firstChild.data;
    }
    if (el = xmlOpsview.getElementsByTagName('configuration').item(0) ) {
        opsview_configuration = el.firstChild.data;
    }

    // status:
    //		0 - ok
    //		1 - reloading
    //		2 - fatal nagios problem
    //		3 - fatal opsview problem
    //		4 - non-fatal opsview problem

    if (opsview_status == "0" || opsview_status == "4") {
        jQuery('#opsview_server_status_box')
            .css('background-color', opsview_status_colors['ok'])
            .children(':first')
            .html(OpsviewNavigation.labels.running);
    } else if (opsview_status == "1" || opsview_status == "3") {
        jQuery('#opsview_server_status_box')
            .css('background-color', opsview_status_colors['warn'])
            .children(':first')
            .html(OpsviewNavigation.labels.warning);
    } else { // 2
        jQuery('#opsview_server_status_box')
            .css('background-color', opsview_status_colors['crit'])
            .children(':first')
            .html(OpsviewNavigation.labels.critical);
    }
    if (opsview_configuration == "pending") {
        jQuery('#opsview_config_apply_changes_link')
            .html(OpsviewNavigation.labels.apply_changes);
        if ( opsview_status == "3" ) {
            jQuery('#opsview_config_status_box')
                .css('background-color', opsview_status_colors['crit'])
                .children(':first')
                .html(OpsviewNavigation.help.reloadFailure);
        } else {
            jQuery('#opsview_config_status_box')
                .css('background-color', opsview_status_colors['warn'])
                .children(':first')
                .html(OpsviewNavigation.help.uncommittedChanges);
        }
    } else if (opsview_configuration == "uptodate") {
        jQuery('#opsview_config_apply_changes_link')
            .html(OpsviewNavigation.help.reload);
        jQuery('#opsview_config_status_box')
            .css('background-color', opsview_status_colors['ok'])
            .children(':first')
            .html(OpsviewNavigation.labels.no_changes);
    }
}

jQuery(document).ready(function() {
    jQuery(".opsview_menu").megaMenu();

    jQuery('#opsview_sidenav_search_autocomplete')
        .placeholder()
        .autocomplete({
            appendTo: '#opsview_navigation_logo_row',
            position: { my : "right top", at: "right bottom" },
            minLength: 2,
            source: function( req, res_cb ) {
                jQuery.ajax({
                    url: OpsviewNavigation.uri.search_host,
                    type: 'POST',
                    data: {
                        q: req.term
                    },
                    dataType: 'text',
                    success: function(html) {
                        var res = jQuery(html);
                        res_cb(
                            jQuery.map( jQuery(html).children('li'), function(li) {
                                var li = jQuery(li);
                                var label = li.text();
                                li.children('span').remove();
                                var value = li.text();
                                return {
                                    value: value,
                                    label: label
                                };
                            })
                        );
                    }
                });
            }
        });
    if ( OpsviewNavigation.check_status ) {
        getStatusForBar();
    }
});

