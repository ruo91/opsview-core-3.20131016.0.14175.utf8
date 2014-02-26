#
# AUTHORS:
#	Copyright (C) 2003-2013 Opsview Limited. All rights reserved
#
#    This file is part of Opsview
#
#    Opsview is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    Opsview is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Opsview; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
package Opsview::Utils::NDOLogsImporter;
use strict;
use Opsview::Config;
use Opsview::Utils::NDOLogsImporter::XS
  qw( timeval parse_in_chunks parser_reset_iterator );
use DBI;

### include/protoapi.h

sub NDO_API_NONE() {""}

sub NDO_API_HELLO()   {"HELLO"}
sub NDO_API_GOODBYE() {"GOODBYE"}

sub NDO_API_PROTOCOL()     {"PROTOCOL"}
sub NDO_API_AGENT()        {"AGENT"}
sub NDO_API_AGENTVERSION() {"AGENTVERSION"}
sub NDO_API_DISPOSITION()  {"DISPOSITION"} ## archived or realtime
sub NDO_API_CONNECTION()   {"CONNECTION"}  ## immediate or deferred
sub NDO_API_CONNECTTYPE()  {"CONNECTTYPE"} ## initial or reconnection

sub NDO_API_DISPOSITION_ARCHIVED()  {"ARCHIVED"}
sub NDO_API_DISPOSITION_REALTIME()  {"REALTIME"}
sub NDO_API_CONNECTION_FILE()       {"FILE"}
sub NDO_API_CONNECTION_UNIXSOCKET() {"UNIXSOCKET"}
sub NDO_API_CONNECTION_TCPSOCKET()  {"TCPSOCKET"}
sub NDO_API_CONNECTTYPE_INITIAL()   {"INITIAL"}
sub NDO_API_CONNECTTYPE_RECONNECT() {"RECONNECT"}

sub NDO_API_STARTDATADUMP() {"STARTDATADUMP"}
sub NDO_API_STARTTIME()     {"STARTTIME"}
sub NDO_API_ENDTIME()       {"ENDTIME"}

sub NDO_API_CONFIGDUMP_ORIGINAL() {"ORIGINAL"}
sub NDO_API_CONFIGDUMP_RETAINED() {"RETAINED"}

sub NDO_API_INSTANCENAME() {"INSTANCENAME"}

sub NDO_API_STARTCONFIGDUMP() {900}
sub NDO_API_ENDCONFIGDUMP()   {901}
sub NDO_API_ENDDATA()         {999}
sub NDO_API_ENDDATADUMP()     {1000}

# ******************** DATA TYPES *******************

sub NDO_API_LOGENTRY() {100}

sub NDO_API_PROCESSDATA()                   {200}
sub NDO_API_TIMEDEVENTDATA()                {201}
sub NDO_API_LOGDATA()                       {202}
sub NDO_API_SYSTEMCOMMANDDATA()             {203}
sub NDO_API_EVENTHANDLERDATA()              {204}
sub NDO_API_NOTIFICATIONDATA()              {205}
sub NDO_API_SERVICECHECKDATA()              {206}
sub NDO_API_HOSTCHECKDATA()                 {207}
sub NDO_API_COMMENTDATA()                   {208}
sub NDO_API_DOWNTIMEDATA()                  {209}
sub NDO_API_FLAPPINGDATA()                  {210}
sub NDO_API_PROGRAMSTATUSDATA()             {211}
sub NDO_API_HOSTSTATUSDATA()                {212}
sub NDO_API_SERVICESTATUSDATA()             {213}
sub NDO_API_ADAPTIVEPROGRAMDATA()           {214}
sub NDO_API_ADAPTIVEHOSTDATA()              {215}
sub NDO_API_ADAPTIVESERVICEDATA()           {216}
sub NDO_API_EXTERNALCOMMANDDATA()           {217}
sub NDO_API_AGGREGATEDSTATUSDATA()          {218}
sub NDO_API_RETENTIONDATA()                 {219}
sub NDO_API_CONTACTNOTIFICATIONDATA()       {220}
sub NDO_API_CONTACTNOTIFICATIONMETHODDATA() {221}
sub NDO_API_ACKNOWLEDGEMENTDATA()           {222}
sub NDO_API_STATECHANGEDATA()               {223}
sub NDO_API_CONTACTSTATUSDATA()             {224}
sub NDO_API_ADAPTIVECONTACTDATA()           {225}

sub NDO_API_MAINCONFIGFILEVARIABLES()     {300}
sub NDO_API_RESOURCECONFIGFILEVARIABLES() {301}
sub NDO_API_CONFIGVARIABLES()             {302}
sub NDO_API_RUNTIMEVARIABLES()            {303}

sub NDO_API_HOSTDEFINITION()              {400}
sub NDO_API_HOSTGROUPDEFINITION()         {401}
sub NDO_API_SERVICEDEFINITION()           {402}
sub NDO_API_SERVICEGROUPDEFINITION()      {403}
sub NDO_API_HOSTDEPENDENCYDEFINITION()    {404}
sub NDO_API_SERVICEDEPENDENCYDEFINITION() {405}
sub NDO_API_HOSTESCALATIONDEFINITION()    {406}
sub NDO_API_SERVICEESCALATIONDEFINITION() {407}
sub NDO_API_COMMANDDEFINITION()           {408}
sub NDO_API_TIMEPERIODDEFINITION()        {409}
sub NDO_API_CONTACTDEFINITION()           {410}
sub NDO_API_CONTACTGROUPDEFINITION()      {411}
sub NDO_API_HOSTEXTINFODEFINITION()       {412} # no longer used
sub NDO_API_SERVICEEXTINFODEFINITION()    {413} # no longer used

# ************** COMMON DATA ATTRIBUTES **************

sub NDO_MAX_DATA_TYPES() {410}

sub NDO_DATA_NONE() {0}

sub NDO_DATA_TYPE()       {1}
sub NDO_DATA_FLAGS()      {2}
sub NDO_DATA_ATTRIBUTES() {3}
sub NDO_DATA_TIMESTAMP()  {4}

# *************** LIVE DATA ATTRIBUTES ***************

sub NDO_DATA_ACKAUTHOR()                   {5}
sub NDO_DATA_ACKDATA()                     {6}
sub NDO_DATA_ACKNOWLEDGEMENTTYPE()         {7}
sub NDO_DATA_ACTIVEHOSTCHECKSENABLED()     {8}
sub NDO_DATA_ACTIVESERVICECHECKSENABLED()  {9}
sub NDO_DATA_AUTHORNAME()                  {10}
sub NDO_DATA_CHECKCOMMAND()                {11}
sub NDO_DATA_CHECKTYPE()                   {12}
sub NDO_DATA_COMMANDARGS()                 {13}
sub NDO_DATA_COMMANDLINE()                 {14}
sub NDO_DATA_COMMANDSTRING()               {15}
sub NDO_DATA_COMMANDTYPE()                 {16}
sub NDO_DATA_COMMENT()                     {17}
sub NDO_DATA_COMMENTID()                   {18}
sub NDO_DATA_COMMENTTIME()                 {19}
sub NDO_DATA_COMMENTTYPE()                 {20}
sub NDO_DATA_CONFIGFILENAME()              {21}
sub NDO_DATA_CONFIGFILEVARIABLE()          {22}
sub NDO_DATA_CONFIGVARIABLE()              {23}
sub NDO_DATA_CONTACTSNOTIFIED()            {24}
sub NDO_DATA_CURRENTCHECKATTEMPT()         {25}
sub NDO_DATA_CURRENTNOTIFICATIONNUMBER()   {26}
sub NDO_DATA_CURRENTSTATE()                {27}
sub NDO_DATA_DAEMONMODE()                  {28}
sub NDO_DATA_DOWNTIMEID()                  {29}
sub NDO_DATA_DOWNTIMETYPE()                {30}
sub NDO_DATA_DURATION()                    {31}
sub NDO_DATA_EARLYTIMEOUT()                {32}
sub NDO_DATA_ENDTIME()                     {33}
sub NDO_DATA_ENTRYTIME()                   {34}
sub NDO_DATA_ENTRYTYPE()                   {35}
sub NDO_DATA_ESCALATED()                   {36}
sub NDO_DATA_EVENTHANDLER()                {37}
sub NDO_DATA_EVENTHANDLERENABLED()         {38}
sub NDO_DATA_EVENTHANDLERSENABLED()        {39}
sub NDO_DATA_EVENTHANDLERTYPE()            {40}
sub NDO_DATA_EVENTTYPE()                   {41}
sub NDO_DATA_EXECUTIONTIME()               {42}
sub NDO_DATA_EXPIRATIONTIME()              {43}
sub NDO_DATA_EXPIRES()                     {44}
sub NDO_DATA_FAILUREPREDICTIONENABLED()    {45}
sub NDO_DATA_FIXED()                       {46}
sub NDO_DATA_FLAPDETECTIONENABLED()        {47}
sub NDO_DATA_FLAPPINGTYPE()                {48}
sub NDO_DATA_GLOBALHOSTEVENTHANDLER()      {49}
sub NDO_DATA_GLOBALSERVICEEVENTHANDLER()   {50}
sub NDO_DATA_HASBEENCHECKED()              {51}
sub NDO_DATA_HIGHTHRESHOLD()               {52}
sub NDO_DATA_HOST()                        {53}
sub NDO_DATA_ISFLAPPING()                  {54}
sub NDO_DATA_LASTCOMMANDCHECK()            {55}
sub NDO_DATA_LASTHARDSTATE()               {56}
sub NDO_DATA_LASTHARDSTATECHANGE()         {57}
sub NDO_DATA_LASTHOSTCHECK()               {58}
sub NDO_DATA_LASTHOSTNOTIFICATION()        {59}
sub NDO_DATA_LASTLOGROTATION()             {60}
sub NDO_DATA_LASTSERVICECHECK()            {61}
sub NDO_DATA_LASTSERVICENOTIFICATION()     {62}
sub NDO_DATA_LASTSTATECHANGE()             {63}
sub NDO_DATA_LASTTIMECRITICAL()            {64}
sub NDO_DATA_LASTTIMEDOWN()                {65}
sub NDO_DATA_LASTTIMEOK()                  {66}
sub NDO_DATA_LASTTIMEUNKNOWN()             {67}
sub NDO_DATA_LASTTIMEUNREACHABLE()         {68}
sub NDO_DATA_LASTTIMEUP()                  {69}
sub NDO_DATA_LASTTIMEWARNING()             {70}
sub NDO_DATA_LATENCY()                     {71}
sub NDO_DATA_LOGENTRY()                    {72}
sub NDO_DATA_LOGENTRYTIME()                {73}
sub NDO_DATA_LOGENTRYTYPE()                {74}
sub NDO_DATA_LOWTHRESHOLD()                {75}
sub NDO_DATA_MAXCHECKATTEMPTS()            {76}
sub NDO_DATA_MODIFIEDHOSTATTRIBUTE()       {77}
sub NDO_DATA_MODIFIEDHOSTATTRIBUTES()      {78}
sub NDO_DATA_MODIFIEDSERVICEATTRIBUTE()    {79}
sub NDO_DATA_MODIFIEDSERVICEATTRIBUTES()   {80}
sub NDO_DATA_NEXTHOSTCHECK()               {81}
sub NDO_DATA_NEXTHOSTNOTIFICATION()        {82}
sub NDO_DATA_NEXTSERVICECHECK()            {83}
sub NDO_DATA_NEXTSERVICENOTIFICATION()     {84}
sub NDO_DATA_NOMORENOTIFICATIONS()         {85}
sub NDO_DATA_NORMALCHECKINTERVAL()         {86}
sub NDO_DATA_NOTIFICATIONREASON()          {87}
sub NDO_DATA_NOTIFICATIONSENABLED()        {88}
sub NDO_DATA_NOTIFICATIONTYPE()            {89}
sub NDO_DATA_NOTIFYCONTACTS()              {90}
sub NDO_DATA_OBSESSOVERHOST()              {91}
sub NDO_DATA_OBSESSOVERHOSTS()             {92}
sub NDO_DATA_OBSESSOVERSERVICE()           {93}
sub NDO_DATA_OBSESSOVERSERVICES()          {94}
sub NDO_DATA_OUTPUT()                      {95}
sub NDO_DATA_PASSIVEHOSTCHECKSENABLED()    {96}
sub NDO_DATA_PASSIVESERVICECHECKSENABLED() {97}
sub NDO_DATA_PERCENTSTATECHANGE()          {98}
sub NDO_DATA_PERFDATA()                    {99}
sub NDO_DATA_PERSISTENT()                  {100}
sub NDO_DATA_PROBLEMHASBEENACKNOWLEDGED()  {101}
sub NDO_DATA_PROCESSID()                   {102}
sub NDO_DATA_PROCESSPERFORMANCEDATA()      {103}
sub NDO_DATA_PROGRAMDATE()                 {104}
sub NDO_DATA_PROGRAMNAME()                 {105}
sub NDO_DATA_PROGRAMSTARTTIME()            {106}
sub NDO_DATA_PROGRAMVERSION()              {107}
sub NDO_DATA_RECURRING()                   {108}
sub NDO_DATA_RETRYCHECKINTERVAL()          {109}
sub NDO_DATA_RETURNCODE()                  {110}
sub NDO_DATA_RUNTIME()                     {111}
sub NDO_DATA_RUNTIMEVARIABLE()             {112}
sub NDO_DATA_SCHEDULEDDOWNTIMEDEPTH()      {113}
sub NDO_DATA_SERVICE()                     {114}
sub NDO_DATA_SHOULDBESCHEDULED()           {115}
sub NDO_DATA_SOURCE()                      {116}
sub NDO_DATA_STARTTIME()                   {117}
sub NDO_DATA_STATE()                       {118}
sub NDO_DATA_STATECHANGE()                 {119}
sub NDO_DATA_STATECHANGETYPE()             {120}
sub NDO_DATA_STATETYPE()                   {121}
sub NDO_DATA_STICKY()                      {122}
sub NDO_DATA_TIMEOUT()                     {123}
sub NDO_DATA_TRIGGEREDBY()                 {124}
sub NDO_DATA_LONGOUTPUT()                  {125}

# *********** OBJECT CONFIG DATA ATTRIBUTES **********

sub NDO_DATA_ACTIONURL()                         {126}
sub NDO_DATA_COMMANDNAME()                       {127}
sub NDO_DATA_CONTACTADDRESS()                    {128}
sub NDO_DATA_CONTACTALIAS()                      {129}
sub NDO_DATA_CONTACTGROUP()                      {130}
sub NDO_DATA_CONTACTGROUPALIAS()                 {131}
sub NDO_DATA_CONTACTGROUPMEMBER()                {132}
sub NDO_DATA_CONTACTGROUPNAME()                  {133}
sub NDO_DATA_CONTACTNAME()                       {134}
sub NDO_DATA_DEPENDENCYTYPE()                    {135}
sub NDO_DATA_DEPENDENTHOSTNAME()                 {136}
sub NDO_DATA_DEPENDENTSERVICEDESCRIPTION()       {137}
sub NDO_DATA_EMAILADDRESS()                      {138}
sub NDO_DATA_ESCALATEONCRITICAL()                {139}
sub NDO_DATA_ESCALATEONDOWN()                    {140}
sub NDO_DATA_ESCALATEONRECOVERY()                {141}
sub NDO_DATA_ESCALATEONUNKNOWN()                 {142}
sub NDO_DATA_ESCALATEONUNREACHABLE()             {143}
sub NDO_DATA_ESCALATEONWARNING()                 {144}
sub NDO_DATA_ESCALATIONPERIOD()                  {145}
sub NDO_DATA_FAILONCRITICAL()                    {146}
sub NDO_DATA_FAILONDOWN()                        {147}
sub NDO_DATA_FAILONOK()                          {148}
sub NDO_DATA_FAILONUNKNOWN()                     {149}
sub NDO_DATA_FAILONUNREACHABLE()                 {150}
sub NDO_DATA_FAILONUP()                          {151}
sub NDO_DATA_FAILONWARNING()                     {152}
sub NDO_DATA_FIRSTNOTIFICATION()                 {153}
sub NDO_DATA_HAVE2DCOORDS()                      {154}
sub NDO_DATA_HAVE3DCOORDS()                      {155}
sub NDO_DATA_HIGHHOSTFLAPTHRESHOLD()             {156}
sub NDO_DATA_HIGHSERVICEFLAPTHRESHOLD()          {157}
sub NDO_DATA_HOSTADDRESS()                       {158}
sub NDO_DATA_HOSTALIAS()                         {159}
sub NDO_DATA_HOSTCHECKCOMMAND()                  {160}
sub NDO_DATA_HOSTCHECKINTERVAL()                 {161}
sub NDO_DATA_HOSTCHECKPERIOD()                   {162}
sub NDO_DATA_HOSTEVENTHANDLER()                  {163}
sub NDO_DATA_HOSTEVENTHANDLERENABLED()           {164}
sub NDO_DATA_HOSTFAILUREPREDICTIONENABLED()      {165}
sub NDO_DATA_HOSTFAILUREPREDICTIONOPTIONS()      {166}
sub NDO_DATA_HOSTFLAPDETECTIONENABLED()          {167}
sub NDO_DATA_HOSTFRESHNESSCHECKSENABLED()        {168}
sub NDO_DATA_HOSTFRESHNESSTHRESHOLD()            {169}
sub NDO_DATA_HOSTGROUPALIAS()                    {170}
sub NDO_DATA_HOSTGROUPMEMBER()                   {171}
sub NDO_DATA_HOSTGROUPNAME()                     {172}
sub NDO_DATA_HOSTMAXCHECKATTEMPTS()              {173}
sub NDO_DATA_HOSTNAME()                          {174}
sub NDO_DATA_HOSTNOTIFICATIONCOMMAND()           {175}
sub NDO_DATA_HOSTNOTIFICATIONINTERVAL()          {176}
sub NDO_DATA_HOSTNOTIFICATIONPERIOD()            {177}
sub NDO_DATA_HOSTNOTIFICATIONSENABLED()          {178}
sub NDO_DATA_ICONIMAGE()                         {179}
sub NDO_DATA_ICONIMAGEALT()                      {180}
sub NDO_DATA_INHERITSPARENT()                    {181}
sub NDO_DATA_LASTNOTIFICATION()                  {182}
sub NDO_DATA_LOWHOSTFLAPTHRESHOLD()              {183}
sub NDO_DATA_LOWSERVICEFLAPTHRESHOLD()           {184}
sub NDO_DATA_MAXSERVICECHECKATTEMPTS()           {185}
sub NDO_DATA_NOTES()                             {186}
sub NDO_DATA_NOTESURL()                          {187}
sub NDO_DATA_NOTIFICATIONINTERVAL()              {188}
sub NDO_DATA_NOTIFYHOSTDOWN()                    {189}
sub NDO_DATA_NOTIFYHOSTFLAPPING()                {190}
sub NDO_DATA_NOTIFYHOSTRECOVERY()                {191}
sub NDO_DATA_NOTIFYHOSTUNREACHABLE()             {192}
sub NDO_DATA_NOTIFYSERVICECRITICAL()             {193}
sub NDO_DATA_NOTIFYSERVICEFLAPPING()             {194}
sub NDO_DATA_NOTIFYSERVICERECOVERY()             {195}
sub NDO_DATA_NOTIFYSERVICEUNKNOWN()              {196}
sub NDO_DATA_NOTIFYSERVICEWARNING()              {197}
sub NDO_DATA_PAGERADDRESS()                      {198}
sub NDO_DATA_PARALLELIZESERVICECHECK()           {199} # no longer used
sub NDO_DATA_PARENTHOST()                        {200}
sub NDO_DATA_PROCESSHOSTPERFORMANCEDATA()        {201}
sub NDO_DATA_PROCESSSERVICEPERFORMANCEDATA()     {202}
sub NDO_DATA_RETAINHOSTNONSTATUSINFORMATION()    {203}
sub NDO_DATA_RETAINHOSTSTATUSINFORMATION()       {204}
sub NDO_DATA_RETAINSERVICENONSTATUSINFORMATION() {205}
sub NDO_DATA_RETAINSERVICESTATUSINFORMATION()    {206}
sub NDO_DATA_SERVICECHECKCOMMAND()               {207}
sub NDO_DATA_SERVICECHECKINTERVAL()              {208}
sub NDO_DATA_SERVICECHECKPERIOD()                {209}
sub NDO_DATA_SERVICEDESCRIPTION()                {210}
sub NDO_DATA_SERVICEEVENTHANDLER()               {211}
sub NDO_DATA_SERVICEEVENTHANDLERENABLED()        {212}
sub NDO_DATA_SERVICEFAILUREPREDICTIONENABLED()   {213}
sub NDO_DATA_SERVICEFAILUREPREDICTIONOPTIONS()   {214}
sub NDO_DATA_SERVICEFLAPDETECTIONENABLED()       {215}
sub NDO_DATA_SERVICEFRESHNESSCHECKSENABLED()     {216}
sub NDO_DATA_SERVICEFRESHNESSTHRESHOLD()         {217}
sub NDO_DATA_SERVICEGROUPALIAS()                 {218}
sub NDO_DATA_SERVICEGROUPMEMBER()                {219}
sub NDO_DATA_SERVICEGROUPNAME()                  {220}
sub NDO_DATA_SERVICEISVOLATILE()                 {221}
sub NDO_DATA_SERVICENOTIFICATIONCOMMAND()        {222}
sub NDO_DATA_SERVICENOTIFICATIONINTERVAL()       {223}
sub NDO_DATA_SERVICENOTIFICATIONPERIOD()         {224}
sub NDO_DATA_SERVICENOTIFICATIONSENABLED()       {225}
sub NDO_DATA_SERVICERETRYINTERVAL()              {226}
sub NDO_DATA_SHOULDBEDRAWN()                     {227} # no longer used
sub NDO_DATA_STALKHOSTONDOWN()                   {228}
sub NDO_DATA_STALKHOSTONUNREACHABLE()            {229}
sub NDO_DATA_STALKHOSTONUP()                     {230}
sub NDO_DATA_STALKSERVICEONCRITICAL()            {231}
sub NDO_DATA_STALKSERVICEONOK()                  {232}
sub NDO_DATA_STALKSERVICEONUNKNOWN()             {233}
sub NDO_DATA_STALKSERVICEONWARNING()             {234}
sub NDO_DATA_STATUSMAPIMAGE()                    {235}
sub NDO_DATA_TIMEPERIODALIAS()                   {236}
sub NDO_DATA_TIMEPERIODNAME()                    {237}
sub NDO_DATA_TIMERANGE()                         {238}
sub NDO_DATA_VRMLIMAGE()                         {239}
sub NDO_DATA_X2D()                               {240}
sub NDO_DATA_X3D()                               {241}
sub NDO_DATA_Y2D()                               {242}
sub NDO_DATA_Y3D()                               {243}
sub NDO_DATA_Z3D()                               {244}

sub NDO_DATA_CONFIGDUMPTYPE() {245}

sub NDO_DATA_FIRSTNOTIFICATIONDELAY()     {246}
sub NDO_DATA_HOSTRETRYINTERVAL()          {247}
sub NDO_DATA_NOTIFYHOSTDOWNTIME()         {248}
sub NDO_DATA_NOTIFYSERVICEDOWNTIME()      {249}
sub NDO_DATA_CANSUBMITCOMMANDS()          {250}
sub NDO_DATA_FLAPDETECTIONONUP()          {251}
sub NDO_DATA_FLAPDETECTIONONDOWN()        {252}
sub NDO_DATA_FLAPDETECTIONONUNREACHABLE() {253}
sub NDO_DATA_FLAPDETECTIONONOK()          {254}
sub NDO_DATA_FLAPDETECTIONONWARNING()     {255}
sub NDO_DATA_FLAPDETECTIONONUNKNOWN()     {256}
sub NDO_DATA_FLAPDETECTIONONCRITICAL()    {257}
sub NDO_DATA_DISPLAYNAME()                {258}
sub NDO_DATA_DEPENDENCYPERIOD()           {259}
sub NDO_DATA_MODIFIEDCONTACTATTRIBUTE()   {260} # LIVE DATA
sub NDO_DATA_MODIFIEDCONTACTATTRIBUTES()  {261} # LIVE DATA
sub NDO_DATA_CUSTOMVARIABLE()             {262}
sub NDO_DATA_HASBEENMODIFIED()            {263}
sub NDO_DATA_CONTACT()                    {264}
sub NDO_DATA_LASTSTATE()                  {265}

## Extra attributes added by Opsview
sub NDO_DATA_HOSTSTATE()     {400}
sub NDO_DATA_HOSTSTATETYPE() {401}

################# Object types #################

sub NDO2DB_OBJECTTYPE_HOST()              {1}
sub NDO2DB_OBJECTTYPE_SERVICE()           {2}
sub NDO2DB_OBJECTTYPE_HOSTGROUP()         {3}
sub NDO2DB_OBJECTTYPE_SERVICEGROUP()      {4}
sub NDO2DB_OBJECTTYPE_HOSTESCALATION()    {5}
sub NDO2DB_OBJECTTYPE_SERVICEESCALATION() {6}
sub NDO2DB_OBJECTTYPE_HOSTDEPENDENCY()    {7}
sub NDO2DB_OBJECTTYPE_SERVICEDEPENDENCY() {8}
sub NDO2DB_OBJECTTYPE_TIMEPERIOD()        {9}
sub NDO2DB_OBJECTTYPE_CONTACT()           {10}
sub NDO2DB_OBJECTTYPE_CONTACTGROUP()      {11}
sub NDO2DB_OBJECTTYPE_COMMAND()           {12}

################ EVENT BROKER OPTIONS ################

sub BROKER_NOTHING()    {0}
sub BROKER_EVERYTHING() {1048575}

sub BROKER_PROGRAM_STATE()        {1}     ## DONE
sub BROKER_TIMED_EVENTS()         {2}     ## DONE
sub BROKER_SERVICE_CHECKS()       {4}     ## DONE
sub BROKER_HOST_CHECKS()          {8}     ## DONE
sub BROKER_EVENT_HANDLERS()       {16}    ## DONE
sub BROKER_LOGGED_DATA()          {32}    ## DONE
sub BROKER_NOTIFICATIONS()        {64}    ## DONE
sub BROKER_FLAPPING_DATA()        {128}   ## DONE
sub BROKER_COMMENT_DATA()         {256}   ## DONE
sub BROKER_DOWNTIME_DATA()        {512}   ## DONE
sub BROKER_SYSTEM_COMMANDS()      {1024}  ## DONE
sub BROKER_OCP_DATA_UNUSED()      {2048}  ## reusable
sub BROKER_STATUS_DATA()          {4096}  ## DONE
sub BROKER_ADAPTIVE_DATA()        {8192}  ## DONE
sub BROKER_EXTERNALCOMMAND_DATA() {16384} ## DONE
sub BROKER_RETENTION_DATA()       {32768} ## DONE
sub BROKER_ACKNOWLEDGEMENT_DATA() {65536}
sub BROKER_STATECHANGE_DATA()     {131072}
sub BROKER_RESERVED18()           {262144}
sub BROKER_RESERVED19()           {524288}

####### EVENT TYPES #########################

sub NEBTYPE_NONE() {0}

sub NEBTYPE_HELLO()   {1}
sub NEBTYPE_GOODBYE() {2}
sub NEBTYPE_INFO()    {3}

sub NEBTYPE_PROCESS_START()     {100}
sub NEBTYPE_PROCESS_DAEMONIZE() {101}
sub NEBTYPE_PROCESS_RESTART()   {102}
sub NEBTYPE_PROCESS_SHUTDOWN()  {103}
sub NEBTYPE_PROCESS_PRELAUNCH() {104} ## before objects are read or verified
sub NEBTYPE_PROCESS_EVENTLOOPSTART() {105}
sub NEBTYPE_PROCESS_EVENTLOOPEND()   {106}

sub NEBTYPE_TIMEDEVENT_ADD()     {200}
sub NEBTYPE_TIMEDEVENT_REMOVE()  {201}
sub NEBTYPE_TIMEDEVENT_EXECUTE() {202}
sub NEBTYPE_TIMEDEVENT_DELAY()   {203} ## NOT IMPLEMENTED
sub NEBTYPE_TIMEDEVENT_SKIP()    {204} ## NOT IMPLEMENTED
sub NEBTYPE_TIMEDEVENT_SLEEP()   {205}

sub NEBTYPE_LOG_DATA()     {300}
sub NEBTYPE_LOG_ROTATION() {301}

sub NEBTYPE_SYSTEM_COMMAND_START() {400}
sub NEBTYPE_SYSTEM_COMMAND_END()   {401}

sub NEBTYPE_EVENTHANDLER_START() {500}
sub NEBTYPE_EVENTHANDLER_END()   {501}

sub NEBTYPE_NOTIFICATION_START()              {600}
sub NEBTYPE_NOTIFICATION_END()                {601}
sub NEBTYPE_CONTACTNOTIFICATION_START()       {602}
sub NEBTYPE_CONTACTNOTIFICATION_END()         {603}
sub NEBTYPE_CONTACTNOTIFICATIONMETHOD_START() {604}
sub NEBTYPE_CONTACTNOTIFICATIONMETHOD_END()   {605}

sub NEBTYPE_SERVICECHECK_INITIATE()       {700}
sub NEBTYPE_SERVICECHECK_PROCESSED()      {701}
sub NEBTYPE_SERVICECHECK_RAW_START()      {702} ## NOT IMPLEMENTED
sub NEBTYPE_SERVICECHECK_RAW_END()        {703} ## NOT IMPLEMENTED
sub NEBTYPE_SERVICECHECK_ASYNC_PRECHECK() {704}

sub NEBTYPE_HOSTCHECK_INITIATE() {
    800;
} ## a check of the route to the host has been initiated

sub NEBTYPE_HOSTCHECK_PROCESSED() {
    801;
} ## the processed/final result of a host check
sub NEBTYPE_HOSTCHECK_RAW_START()      {802} ## the start of a "raw" host check
sub NEBTYPE_HOSTCHECK_RAW_END()        {803} ## a finished "raw" host check
sub NEBTYPE_HOSTCHECK_ASYNC_PRECHECK() {804}
sub NEBTYPE_HOSTCHECK_SYNC_PRECHECK()  {805}

sub NEBTYPE_COMMENT_ADD()    {900}
sub NEBTYPE_COMMENT_DELETE() {901}
sub NEBTYPE_COMMENT_LOAD()   {902}

sub NEBTYPE_FLAPPING_START() {1000}
sub NEBTYPE_FLAPPING_STOP()  {1001}

sub NEBTYPE_DOWNTIME_ADD()    {1100}
sub NEBTYPE_DOWNTIME_DELETE() {1101}
sub NEBTYPE_DOWNTIME_LOAD()   {1102}
sub NEBTYPE_DOWNTIME_START()  {1103}
sub NEBTYPE_DOWNTIME_STOP()   {1104}

sub NEBTYPE_PROGRAMSTATUS_UPDATE() {1200}
sub NEBTYPE_HOSTSTATUS_UPDATE()    {1201}
sub NEBTYPE_SERVICESTATUS_UPDATE() {1202}
sub NEBTYPE_CONTACTSTATUS_UPDATE() {1203}

sub NEBTYPE_ADAPTIVEPROGRAM_UPDATE() {1300}
sub NEBTYPE_ADAPTIVEHOST_UPDATE()    {1301}
sub NEBTYPE_ADAPTIVESERVICE_UPDATE() {1302}
sub NEBTYPE_ADAPTIVECONTACT_UPDATE() {1303}

sub NEBTYPE_EXTERNALCOMMAND_START() {1400}
sub NEBTYPE_EXTERNALCOMMAND_END()   {1401}

sub NEBTYPE_AGGREGATEDSTATUS_STARTDUMP() {1500}
sub NEBTYPE_AGGREGATEDSTATUS_ENDDUMP()   {1501}

sub NEBTYPE_RETENTIONDATA_STARTLOAD() {1600}
sub NEBTYPE_RETENTIONDATA_ENDLOAD()   {1601}
sub NEBTYPE_RETENTIONDATA_STARTSAVE() {1602}
sub NEBTYPE_RETENTIONDATA_ENDSAVE()   {1603}

sub NEBTYPE_ACKNOWLEDGEMENT_ADD()    {1700}
sub NEBTYPE_ACKNOWLEDGEMENT_REMOVE() {1701} ## NOT IMPLEMENTED
sub NEBTYPE_ACKNOWLEDGEMENT_LOAD()   {1702} ## NOT IMPLEMENTED

sub NEBTYPE_STATECHANGE_START() {1800}      ## NOT IMPLEMENTED
sub NEBTYPE_STATECHANGE_END()   {1801}

####### EVENT FLAGS #########################

sub NEBFLAG_NONE()              {0}
sub NEBFLAG_PROCESS_INITIATED() {1} ## event was initiated by Nagios process
sub NEBFLAG_USER_INITIATED()    {2} ## event was initiated by a user request

sub NEBFLAG_MODULE_INITIATED() {
    3;
} ## event was initiated by an event broker module

####### EVENT ATTRIBUTES ####################

sub NEBATTR_NONE() {0}

sub NEBATTR_SHUTDOWN_NORMAL()   {1}
sub NEBATTR_SHUTDOWN_ABNORMAL() {2}
sub NEBATTR_RESTART_NORMAL()    {4}
sub NEBATTR_RESTART_ABNORMAL()  {8}

sub NEBATTR_FLAPPING_STOP_NORMAL() {1}

sub NEBATTR_FLAPPING_STOP_DISABLED() {
    2;
} ## flapping stopped because flap detection was disabled

sub NEBATTR_DOWNTIME_STOP_NORMAL()    {1}
sub NEBATTR_DOWNTIME_STOP_CANCELLED() {2}

##******************* HOST STATUS ********************

sub HOST_UP()          {0}
sub HOST_DOWN()        {1}
sub HOST_UNREACHABLE() {2}

##****************** STATE LOGGING TYPES *************

sub INITIAL_STATES() {1}
sub CURRENT_STATES() {2}

##*********** SERVICE DEPENDENCY VALUES **************

sub DEPENDENCIES_OK()     {0}
sub DEPENDENCIES_FAILED() {1}

##********** ROUTE CHECK PROPAGATION TYPES ***********

sub PROPAGATE_TO_PARENT_HOSTS() {1}
sub PROPAGATE_TO_CHILD_HOSTS()  {2}

##***************** SERVICE STATES *******************

sub STATE_OK()       {0}
sub STATE_WARNING()  {1}
sub STATE_CRITICAL() {2}
sub STATE_UNKNOWN()  {3} ## changed from -1 on 02/24/2001

##***************** FLAPPING TYPES *******************

sub HOST_FLAPPING()    {0}
sub SERVICE_FLAPPING() {1}

##*************** NOTIFICATION TYPES *****************

sub HOST_NOTIFICATION()    {0}
sub SERVICE_NOTIFICATION() {1}

##************ NOTIFICATION REASON TYPES **************

sub NOTIFICATION_NORMAL()            {0}
sub NOTIFICATION_ACKNOWLEDGEMENT()   {1}
sub NOTIFICATION_FLAPPINGSTART()     {2}
sub NOTIFICATION_FLAPPINGSTOP()      {3}
sub NOTIFICATION_FLAPPINGDISABLED()  {4}
sub NOTIFICATION_DOWNTIMESTART()     {5}
sub NOTIFICATION_DOWNTIMEEND()       {6}
sub NOTIFICATION_DOWNTIMECANCELLED() {7}
sub NOTIFICATION_CUSTOM()            {99}

##*************** EVENT HANDLER TYPES ****************

sub HOST_EVENTHANDLER()           {0}
sub SERVICE_EVENTHANDLER()        {1}
sub GLOBAL_HOST_EVENTHANDLER()    {2}
sub GLOBAL_SERVICE_EVENTHANDLER() {3}

##**************** STATE CHANGE TYPES ****************

sub HOST_STATECHANGE()    {0}
sub SERVICE_STATECHANGE() {1}

##**************** OBJECT CHECK TYPES ****************
sub SERVICE_CHECK() {0}
sub HOST_CHECK()    {1}

##****************** EVENT TYPES *********************

sub EVENT_SERVICE_CHECK()      {0} ## active service check
sub EVENT_COMMAND_CHECK()      {1} ## external command check
sub EVENT_LOG_ROTATION()       {2} ## log file rotation
sub EVENT_PROGRAM_SHUTDOWN()   {3} ## program shutdown
sub EVENT_PROGRAM_RESTART()    {4} ## program restart
sub EVENT_CHECK_REAPER()       {5} ## reaps results from host and service checks
sub EVENT_ORPHAN_CHECK()       {6} ## checks for orphaned hosts and services
sub EVENT_RETENTION_SAVE()     {7} ## save (dump) retention data
sub EVENT_STATUS_SAVE()        {8} ## save (dump) status data
sub EVENT_SCHEDULED_DOWNTIME() {9} ## scheduled host or service downtime
sub EVENT_SFRESHNESS_CHECK() {10}  ## checks service result "freshness"

sub EVENT_EXPIRE_DOWNTIME() {
    11;
} ## checks for (and removes) expired scheduled downtime
sub EVENT_HOST_CHECK()       {12} ## active host check
sub EVENT_HFRESHNESS_CHECK() {13} ## checks host result "freshness"

sub EVENT_RESCHEDULE_CHECKS() {
    14;
} ## adjust scheduling of host and service checks
sub EVENT_EXPIRE_COMMENT() {15} ## removes expired comments

sub EVENT_SLEEP() {
    98;
} ## asynchronous sleep event that occurs when event queues are empty
sub EVENT_USER_FUNCTION() {99} ## USER-defined function (modules)

##****** INTER-CHECK DELAY CALCULATION TYPES *********

sub ICD_NONE()  {0}            ## no inter-check delay
sub ICD_DUMB()  {1}            ## dumb delay of 1 second
sub ICD_SMART() {2}            ## smart delay
sub ICD_USER()  {3}            ## user-specified delay

##****** INTERLEAVE FACTOR CALCULATION TYPES *********

sub ILF_USER()  {0}            ## user-specified interleave factor
sub ILF_SMART() {1}            ## smart interleave

##*********** SCHEDULED DOWNTIME TYPES ***************

sub ACTIVE_DOWNTIME()  {0}     ## active downtime - currently in effect
sub PENDING_DOWNTIME() {1}     ## pending downtime - scheduled for the future

sub SERVICE_DOWNTIME() {1}     ## service downtime
sub HOST_DOWNTIME()    {2}     ## host downtime
sub ANY_DOWNTIME()     {3}     ## host or service downtime

sub HOST_ACKNOWLEDGEMENT()    {0}
sub SERVICE_ACKNOWLEDGEMENT() {1}

sub HOST_COMMENT()    {1}
sub SERVICE_COMMENT() {2}

sub USER_COMMENT()            {1}
sub DOWNTIME_COMMENT()        {2}
sub FLAPPING_COMMENT()        {3}
sub ACKNOWLEDGEMENT_COMMENT() {4}

sub NDO2DB_CONFIGTYPE_ORIGINAL() {0}

sub ARG_SELF() {0}

sub ARG_FILE()     {1}
sub ARG_FILESIZE() {2}

sub ARG_OBJECT_TYPE() {0}
sub ARG_NAME1()       {1}
sub ARG_NAME2()       {2}
sub ARG_OBJECT_ID()   {3}
sub ARG_OBJECT_ID2()  {1}

sub ARG_TABLE()  {0}
sub ARG_COLUMN() {1}

sub ARG_EVENTS() {1}

sub ARG_PARENT()     {0}
sub ARG_GROUP_TYPE() {1}
sub ARG_MEMBERS()    {2}

sub ARG_CONTACTS()   {1}
sub ARG_OBJECT_ID3() {2}

sub ARG_CONTACTGROUPS() {1}

sub ARG_PARENTHOSTS() {0}

sub ARG_TIMERANGES() {0}

sub ARG_CUSTOMVARIABLES() {0}

sub ARG_UPDATE_TIME() {2}

sub NEBATTR_EVENTTYPE_STATECHANGE()     {0}
sub NEBATTR_EVENTTYPE_ACKNOWLEDGEMENT() {1}
sub NEBATTR_EVENTTYPE_DOWNTIME_START()  {2}
sub NEBATTR_EVENTTYPE_DOWNTIME_STOP()   {3}

# end of constants

our @INPUT_DATA_TYPE = map {0} 0 .. NDO_MAX_DATA_TYPES() + 1;
our @HANDLERS;
our $MAX_BUF_SIZE = 1024 * 1024;        # 1 MB
our $PARSE_BUF    = '0' x $MAX_BUF_SIZE;
my $DB_CONNECTED = 0;
my $DBCONNERR =
  qr/(?:server has gone away)|(?:Lost connection to MySQL server during query)|(?:Can't connect to .*? MySQL server)/;
my $LOGGER;
my $DB;
my $LATEST_REALTIME_DATA_TIME   = 0;
my $LOADING_RETENTION_DATA_FLAG = 0;
my $CURRENT_OBJECT_CONFIG_TYPE  = 1;    # was: NDO2DB_CONFIGTYPE_ORIGINAL();
my $OBJECTS_CACHE;

my $LAST_NOTIFICATION_ID         = 0;
my $LAST_CONTACT_NOTIFICATION_ID = 0;

{
    my @input_data_escaped = (
        NDO_DATA_ACKAUTHOR(),
        NDO_DATA_ACKDATA(),
        NDO_DATA_AUTHORNAME(),
        NDO_DATA_CHECKCOMMAND(),
        NDO_DATA_COMMANDARGS(),
        NDO_DATA_COMMANDLINE(),
        NDO_DATA_COMMANDSTRING(),
        NDO_DATA_COMMENT(),
        NDO_DATA_EVENTHANDLER(),
        NDO_DATA_GLOBALHOSTEVENTHANDLER(),
        NDO_DATA_GLOBALSERVICEEVENTHANDLER(),
        NDO_DATA_HOST(),
        NDO_DATA_LOGENTRY(),
        NDO_DATA_OUTPUT(),
        NDO_DATA_LONGOUTPUT(),
        NDO_DATA_PERFDATA(),
        NDO_DATA_SERVICE(),
        NDO_DATA_PROGRAMNAME(),
        NDO_DATA_PROGRAMVERSION(),
        NDO_DATA_PROGRAMDATE(),

        NDO_DATA_COMMANDNAME(),
        NDO_DATA_CONTACTADDRESS(),
        NDO_DATA_CONTACTALIAS(),
        NDO_DATA_CONTACTGROUP(),
        NDO_DATA_CONTACTGROUPALIAS(),
        NDO_DATA_CONTACTGROUPMEMBER(),
        NDO_DATA_CONTACTGROUPNAME(),
        NDO_DATA_CONTACTNAME(),
        NDO_DATA_DEPENDENTHOSTNAME(),
        NDO_DATA_DEPENDENTSERVICEDESCRIPTION(),
        NDO_DATA_EMAILADDRESS(),
        NDO_DATA_HOSTADDRESS(),
        NDO_DATA_HOSTALIAS(),
        NDO_DATA_HOSTCHECKCOMMAND(),
        NDO_DATA_HOSTCHECKPERIOD(),
        NDO_DATA_HOSTEVENTHANDLER(),
        NDO_DATA_HOSTFAILUREPREDICTIONOPTIONS(),
        NDO_DATA_HOSTGROUPALIAS(),
        NDO_DATA_HOSTGROUPMEMBER(),
        NDO_DATA_HOSTGROUPNAME(),
        NDO_DATA_HOSTNAME(),
        NDO_DATA_HOSTNOTIFICATIONCOMMAND(),
        NDO_DATA_HOSTNOTIFICATIONPERIOD(),
        NDO_DATA_PAGERADDRESS(),
        NDO_DATA_PARENTHOST(),
        NDO_DATA_SERVICECHECKCOMMAND(),
        NDO_DATA_SERVICECHECKPERIOD(),
        NDO_DATA_SERVICEDESCRIPTION(),
        NDO_DATA_SERVICEEVENTHANDLER(),
        NDO_DATA_SERVICEFAILUREPREDICTIONOPTIONS(),
        NDO_DATA_SERVICEGROUPALIAS(),
        NDO_DATA_SERVICEGROUPMEMBER(),
        NDO_DATA_SERVICEGROUPNAME(),
        NDO_DATA_SERVICENOTIFICATIONCOMMAND(),
        NDO_DATA_SERVICENOTIFICATIONPERIOD(),
        NDO_DATA_TIMEPERIODALIAS(),
        NDO_DATA_TIMEPERIODNAME(),
        NDO_DATA_TIMERANGE(),

        NDO_DATA_ACTIONURL(),
        NDO_DATA_ICONIMAGE(),
        NDO_DATA_ICONIMAGEALT(),
        NDO_DATA_NOTES(),
        NDO_DATA_NOTESURL(),
        NDO_DATA_CUSTOMVARIABLE(),
        NDO_DATA_CONTACT()
    );

    my @input_data_multi = (
        NDO_DATA_CONTACTGROUP(),
        NDO_DATA_CONTACTGROUPMEMBER(),
        NDO_DATA_SERVICEGROUPMEMBER(),
        NDO_DATA_HOSTGROUPMEMBER(),
        NDO_DATA_SERVICENOTIFICATIONCOMMAND(),
        NDO_DATA_HOSTNOTIFICATIONCOMMAND(),
        NDO_DATA_CONTACTADDRESS(),
        NDO_DATA_TIMERANGE(),
        NDO_DATA_PARENTHOST(),
        NDO_DATA_CONFIGFILEVARIABLE(),
        NDO_DATA_CONFIGVARIABLE(),
        NDO_DATA_RUNTIMEVARIABLE(),
        NDO_DATA_CUSTOMVARIABLE(),
        NDO_DATA_CONTACT()
    );

    my %handlers = (
        NDO_API_NOTIFICATIONDATA()    => 'handle_NOTIFICATIONDATA',
        NDO_API_SERVICECHECKDATA()    => 'handle_SERVICECHECKDATA',
        NDO_API_HOSTCHECKDATA()       => 'handle_HOSTCHECKDATA',
        NDO_API_COMMENTDATA()         => 'handle_COMMENTDATA',
        NDO_API_DOWNTIMEDATA()        => 'handle_DOWNTIMEDATA',
        NDO_API_PROGRAMSTATUSDATA()   => 'handle_PROGRAMSTATUSDATA',
        NDO_API_HOSTSTATUSDATA()      => 'handle_HOSTSTATUSDATA',
        NDO_API_SERVICESTATUSDATA()   => 'handle_SERVICESTATUSDATA',
        NDO_API_CONTACTSTATUSDATA()   => 'handle_CONTACTSTATUSDATA',
        NDO_API_RETENTIONDATA()       => 'handle_RETENTIONDATA',
        NDO_API_ACKNOWLEDGEMENTDATA() => 'handle_ACKNOWLEDGEMENTDATA',
        NDO_API_STATECHANGEDATA()     => 'handle_STATECHANGEDATA',
        NDO_API_STARTCONFIGDUMP()     => 'handle_CONFIGDUMPSTART',
        NDO_API_ENDCONFIGDUMP()       => 'handle_CONFIGDUMPEND',
        NDO_API_HOSTDEFINITION()      => 'handle_HOSTDEFINITION',
        NDO_API_HOSTGROUPDEFINITION() => 'handle_HOSTGROUPDEFINITION',
        NDO_API_SERVICEDEFINITION()   => 'handle_SERVICEDEFINITION',
        NDO_API_SERVICEDEPENDENCYDEFINITION() =>
          'handle_SERVICEDEPENDENCYDEFINITION',
        NDO_API_COMMANDDEFINITION()        => 'handle_COMMANDDEFINITION',
        NDO_API_TIMEPERIODDEFINITION()     => 'handle_TIMEPERIODDEFINITION',
        NDO_API_CONTACTDEFINITION()        => 'handle_CONTACTDEFINITION',
        NDO_API_CONTACTGROUPDEFINITION()   => 'handle_CONTACTGROUPDEFINITION',
        NDO_API_HOSTEXTINFODEFINITION()    => 'handle_HOSTEXTINFODEFINITION',
        NDO_API_SERVICEEXTINFODEFINITION() => 'handle_SERVICEEXTINFODEFINITION',
        NDO_API_PROCESSDATA()              => 'handle_PROCESSDATA',

        NDO_API_CONTACTNOTIFICATIONMETHODDATA() =>
          'handle_CONTACTNOTIFICATIONMETHODDATA',
        NDO_API_CONTACTNOTIFICATIONDATA() => 'handle_CONTACTNOTIFICATIONDATA',
    );

    # done but not used:
    # NDO_API_SERVICEGROUPDEFINITION() => 'handle_SERVICEGROUPDEFINITION',
    # NDO_API_EXTERNALCOMMANDDATA() => 'handle_EXTERNALCOMMANDDATA',

    # ignored:
    # NDO_API_SERVICEESCALATIONDEFINITION() => 'handle_SERVICEESCALATIONDEFINITION',
    # NDO_API_HOSTESCALATIONDEFINITION() => 'handle_HOSTESCALATIONDEFINITION',
    # NDO_API_HOSTDEPENDENCYDEFINITION() => 'handle_HOSTDEPENDENCYDEFINITION',
    # NDO_API_FLAPPINGDATA() => 'handle_FLAPPINGDATA',
    # NDO_API_EVENTHANDLERDATA() => 'handle_EVENTHANDLERDATA',
    # NDO_API_AGGREGATEDSTATUSDATA() => 'handle_AGGREGATEDSTATUSDATA',
    # NDO_API_SYSTEMCOMMANDDATA() => 'handle_SYSTEMCOMMANDDATA',
    # NDO_API_LOGENTRY() => 'handle_LOGENTRY',
    # NDO_API_TIMEDEVENTDATA() => 'handle_TIMEDEVENTDATA',
    # NDO_API_LOGDATA() => 'handle_LOGDATA',
    # NDO_API_ADAPTIVEPROGRAMDATA() => 'handle_ADAPTIVEPROGRAMDATA',
    # NDO_API_ADAPTIVEHOSTDATA() => 'handle_ADAPTIVEHOSTDATA',
    # NDO_API_ADAPTIVESERVICEDATA() => 'handle_ADAPTIVESERVICEDATA',
    # NDO_API_ADAPTIVECONTACTDATA() => 'handle_ADAPTIVECONTACTDATA',
    # NDO_API_MAINCONFIGFILEVARIABLES() => 'handle_MAINCONFIGFILEVARIABLES',
    # NDO_API_RESOURCECONFIGFILEVARIABLES() => 'handle_RESOURCECONFIGFILEVARIABLES',
    # NDO_API_CONFIGVARIABLES() => 'handle_CONFIGVARIABLES',
    # NDO_API_RUNTIMEVARIABLES() => 'handle_RUNTIMEVARIABLES',

    $INPUT_DATA_TYPE[$_] |= 1 for @input_data_escaped;
    $INPUT_DATA_TYPE[$_] |= 2 for @input_data_multi;
    $HANDLERS[$_] = $handlers{$_} for keys %handlers;
}

## END OF SETUP

sub new {
    my ( $class, %args ) = @_;

    $LOGGER = delete $args{logger};

    my $self = bless {
        last_table_trim_time => time(),

        max_nagios_timedevents_age      => 0,
        max_nagios_systemcommands_age   => 0,
        max_nagios_servicechecks_age    => 0,
        max_nagios_hostchecks_age       => 0,
        max_nagios_eventhandlers_age    => 0,
        max_nagios_externalcommands_age => 0,

        event_handlers => \@HANDLERS,

        %args

    }, $class;

    eval {
        $self->db_connect();

        $self->create_default_instance();

        $self->get_cached_object_ids();
    };
    if ( my $e = $@ ) {
        if ( !$DB || $e =~ /$DBCONNERR/ ) {

            # that will block until DB is back
            $self->db_reconnect;
        }
        else {
            $LOGGER->fatal( "Failed to start $0" );
            ${ $self->{break} }++;
        }
    }

    return $self;
}

sub set_latest_data_times {

    my %latest_times = (
        nagios_programstatus   => 'status_update_time',
        nagios_hoststatus      => 'status_update_time',
        nagios_servicestatus   => 'status_update_time',
        nagios_contactstatus   => 'status_update_time',
        nagios_timedeventqueue => 'queued_time',
        nagios_comments        => 'entry_time',
    );
    for my $table ( keys %latest_times ) {
        my $latest_time =
          get_latest_data_time( $table, $latest_times{$table} );

        if ( $latest_time > $LATEST_REALTIME_DATA_TIME ) {
            $LATEST_REALTIME_DATA_TIME = $latest_time;
        }
    }
    my $now = time();
    if ( $LATEST_REALTIME_DATA_TIME > $now ) {
        $LATEST_REALTIME_DATA_TIME = $now;
    }

}

sub create_default_instance {
    my $sth = $DB->prepare_cached(
        q{
            INSERT INTO nagios_instances
            SET
                instance_id=1,
                instance_name='default',
                instance_description=''
        }
    );

    $sth->execute();

    return;
}

sub db_connect {
    my $dsn =
        Opsview::Config->runtime_dbi
      . ":database="
      . Opsview::Config->runtime_db
      . ";host=localhost";

    $DB = DBI->connect(
        $dsn,
        Opsview::Config->runtime_dbuser,
        Opsview::Config->runtime_dbpasswd,
        {
            RaiseError           => 0,
            PrintError           => 0,
            AutoCommit           => 1,
            mysql_auto_reconnect => 1,
            mysql_server_prepare => 1,
            Callbacks            => {
                connected => sub {
                    $_[0]->do( "SET time_zone='+00:00'" );

                    # needs to return undef
                    return;
                  }
            }
        }
    ) or die $DBI::errstr;

    $DB_CONNECTED = 1;

    return;
}

sub parse_c {
    return parse_in_chunks( $_[ ARG_FILE() ], $_[ ARG_FILESIZE() ] );
}

sub send_log {
    $LOGGER->debug(
        "Importing " . $_[ ARG_FILE() ] . ". Size=" . $_[ ARG_FILESIZE() ] )
      if $LOGGER->is_debug;

    $LOADING_RETENTION_DATA_FLAG = 0;

    eval { set_latest_data_times(); };
    if ( my $e = $@ ) {
        if ( !$DB || $e =~ /$DBCONNERR/ ) {

            # that will block until DB is back
            $_[ ARG_SELF() ]->db_reconnect;
        }
        else {
            $LOGGER->fatal( "Error for " . $_[ ARG_FILE() ] . ": $e" );
            return 0;
        }
    }

    $LAST_NOTIFICATION_ID         = 0;
    $LAST_CONTACT_NOTIFICATION_ID = 0;

    my $result = 1;

    parser_reset_iterator();

    #$DB::single=1;
    PARSER:
    while ( my $events =
        $_[ ARG_SELF() ]->parse_c( $_[ ARG_FILE() ], $_[ ARG_FILESIZE() ] ) )
    {
        #$DB::single=1;
        EVENTS: for ( my $i = 0; $i < @$events; $i += 2 ) {

            # caught signal - $self->{break} is the global break
            if ( ${ $_[ ARG_SELF() ]->{break} } ) {
                $result = 0;
                last PARSER;
            }

            # if ( $event_type eq NDO_API_STARTCONFIGDUMP() ) {
            #   there was a reload
            #   fork;
            # }

            if ( my $m = $HANDLERS[ $events->[$i] ] ) {

                eval { $_[ ARG_SELF() ]->$m( $events->[ $i + 1 ] ); };
                if ( my $e = $@ ) {
                    if ( !$DB || $e =~ /$DBCONNERR/ ) {

                        # that will block until DB is back
                        $_[ ARG_SELF() ]->db_reconnect;

                        # restart with failed event
                        redo EVENTS;
                    }
                    else {
                        $LOGGER->fatal(
                            "Error for " . $_[ ARG_FILE() ] . " in $m: $e"
                        );

                        $result = 0;
                        last PARSER;
                    }
                }
            }
        }
    }

    # $_[ ARG_SELF() ]->db_perform_maintenance();

    # in case of file not including 901 it seems to be safer to commit in case
    # the following files do not include 901 either (unlikely, but possible)
    $DB->commit unless $DB->{AutoCommit};

    return $result;
}

sub db_clear_table {

    #my $sth = $DB->prepare_cached( q{ TRUNCATE TABLE } . $_[ ARG_TABLE() ] );
    # TRUNCATE auto-commits and we run config reload in transaction
    my $sth = $DB->prepare_cached( q{ DELETE FROM } . $_[ ARG_TABLE() ] );

    $sth->execute();
}

our $sth_SET_INACTIVE;

sub set_all_objects_as_inactive {

    $sth_SET_INACTIVE = $DB->prepare_cached(
        q{
            UPDATE nagios_objects
            SET
                is_active='0'
            WHERE
                instance_id = 1
        }
    ) unless defined $sth_SET_INACTIVE;

    $sth_SET_INACTIVE->execute();
}

our $sth_SET_ACTIVE;

sub set_object_as_active {
    $sth_SET_ACTIVE = $DB->prepare_cached(
        q{
            UPDATE nagios_objects
            SET
                is_active='1'
            WHERE
                instance_id = 1
                AND
                objecttype_id=?
                AND
                object_id=?
        }
    ) unless defined $sth_SET_ACTIVE;

    $sth_SET_ACTIVE->execute( $_[ ARG_OBJECT_TYPE() ], $_[ ARG_OBJECT_ID2() ]
    );
}

sub get_latest_data_time {

    my $sth = $DB->prepare_cached(
        q{ SELECT UNIX_TIMESTAMP(} . $_[ ARG_COLUMN() ] . q{)
            FROM } . $_[ ARG_TABLE() ] . q{
            ORDER BY } . $_[ ARG_COLUMN() ] . q{ DESC
            LIMIT 1
        }
    );

    $sth->execute();
    my $latest_time;
    while ( my $row = $sth->fetchrow_arrayref ) {
        $latest_time = $row->[0];
    }

    return $latest_time;
}

sub get_object_id_with_insert {
    my ( $name1, $name2 ) = @_[ ARG_NAME1(), ARG_NAME2() ];

    my $defined_and_long1 = defined $name1 && length $name1;
    my $defined_and_long2 = defined $name2 && length $name2;

    # make sure empty strings are set to null
    undef $name1 unless $defined_and_long1;
    undef $name2 unless $defined_and_long2;

    # null names mean no object id
    return 0 if !defined $name1 && !defined $name2;

    # see if the object already exists in cached lookup table
    if ( my $cached_id =
        $OBJECTS_CACHE->[ $_[ ARG_OBJECT_TYPE() ] ]
        ->{ defined $name1 ? $name1 : 'NULL' }
        ->{ defined $name2 ? $name2 : 'NULL' } )
    {
        return $cached_id;
    }

    my $sth_select = $DB->prepare_cached(
        q{
            SELECT object_id
            FROM nagios_objects
            WHERE
                objecttype_id = ?
        }
          . ' AND '
          . ( $defined_and_long1 ? 'name1 = ?' : 'name1 IS NULL' ) . ' AND '
          . ( $defined_and_long2 ? 'name2 = ?' : 'name2 IS NULL' )
    );

    $sth_select->execute(
        $_[ ARG_OBJECT_TYPE() ],
        ( $defined_and_long1 ? $name1 : () ),
        ( $defined_and_long2 ? $name2 : () ),
    );
    my ($object_id) = $sth_select->fetchrow_arrayref;
    $sth_select->finish;

    # object already exists
    return $object_id if $object_id;

    my $sth_insert = $DB->prepare_cached(
        q{
                INSERT INTO nagios_objects SET
                instance_id = 1,
                objecttype_id = ?
            }
          . ( $defined_and_long1 ? ', name1=?' : '' )
          . ( $defined_and_long2 ? ', name2=?' : '' )
    );

    $sth_insert->execute(
        $_[ ARG_OBJECT_TYPE() ],
        ( $defined_and_long1 ? $name1 : () ),
        ( $defined_and_long2 ? $name2 : () ),
    );

    $object_id = $sth_insert->{mysql_insertid};

    # cache object id for later lookups
    add_cached_object_id( $_[ ARG_OBJECT_TYPE() ], $name1, $name2, $object_id );

    return $object_id;
}

sub add_cached_object_id {
    my ( $name1, $name2 ) = @_[ ARG_NAME1(), ARG_NAME2() ];

    # make sure empty strings are set to null
    undef $name1 unless defined $name1 && length $name1;
    undef $name2 unless defined $name2 && length $name2;

    return if !defined $name1 && !defined $name2;

    $name1 = 'NULL' unless defined $name1;
    $name2 = 'NULL' unless defined $name2;

    $OBJECTS_CACHE->[ $_[ ARG_OBJECT_TYPE() ] ]->{$name1}->{$name2} =
      $_[ ARG_OBJECT_ID() ];
}

sub get_cached_object_ids {
    my $sth = $DB->prepare_cached(
        q{
            SELECT objecttype_id, name1, name2, object_id
            FROM nagios_objects
        }
    );

    $sth->execute();
    while ( my $row = $sth->fetchrow_arrayref ) {
        add_cached_object_id(@$row);
    }
}

our $sth_update_handle_NOTIFICATIONDATA;
our $sth_insert_handle_NOTIFICATIONDATA;
our $sth_fetch_ID_handle_NOTIFICATIONDATA;

sub handle_NOTIFICATIONDATA { # 205

    $sth_fetch_ID_handle_NOTIFICATIONDATA = $DB->prepare_cached(
        qq[
            SELECT notification_id
            FROM nagios_notifications
            WHERE
                object_id=?
                AND
                start_time=FROM_UNIXTIME(?)
                AND
                start_time_usec=?
        ]
    ) unless defined $sth_fetch_ID_handle_NOTIFICATIONDATA;

    $sth_update_handle_NOTIFICATIONDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_notifications SET

    instance_id=1,
    notification_type=?,
    notification_reason=?,
    notification_number=?,
    end_time=FROM_UNIXTIME(?),
    end_time_usec=?,
    state=?,
    output=?,
    escalated=?,
    contacts_notified=?

            WHERE
                object_id=?
                AND
                start_time=FROM_UNIXTIME(?)
                AND
                start_time_usec=?
        }
    ) unless defined $sth_update_handle_NOTIFICATIONDATA;

    $sth_insert_handle_NOTIFICATIONDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_notifications SET

    instance_id=1,
    notification_type=?,
    notification_reason=?,
    notification_number=?,
    end_time=FROM_UNIXTIME(?),
    end_time_usec=?,
    state=?,
    output=?,
    escalated=?,
    contacts_notified=?

                ,object_id=?
                ,start_time=FROM_UNIXTIME(?)
                ,start_time_usec=?
        }
    ) unless defined $sth_insert_handle_NOTIFICATIONDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my $object_id = 0;

        if ( $event->[ NDO_DATA_NOTIFICATIONTYPE() ] == SERVICE_NOTIFICATION() )
        {
            $object_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_SERVICE(),
                $event->[ NDO_DATA_HOST() ],
                $event->[ NDO_DATA_SERVICE() ]
            );
        }
        elsif ( $event->[ NDO_DATA_NOTIFICATIONTYPE() ] == HOST_NOTIFICATION() )
        {
            $object_id =
              get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
                $event->[ NDO_DATA_HOST() ]
              );
        }

        my ( $start_time, $start_time_usec ) =
          timeval( $event->[ NDO_DATA_STARTTIME() ] );
        my ( $end_time, $end_time_usec ) =
          timeval( $event->[ NDO_DATA_ENDTIME() ] );

        my @data = (
            @$event[
              NDO_DATA_NOTIFICATIONTYPE(),
            NDO_DATA_NOTIFICATIONREASON(),
            NDO_DATA_CURRENTNOTIFICATIONNUMBER(),
            ],

            $end_time,
            $end_time_usec,

            @$event[
              NDO_DATA_STATE(), NDO_DATA_OUTPUT(),
            NDO_DATA_ESCALATED(), NDO_DATA_CONTACTSNOTIFIED(),
            ],

            $object_id,
            $start_time,
            $start_time_usec,
        );

        my $rv = $sth_insert_handle_NOTIFICATIONDATA->execute(@data);

        if ($rv) {
            if ( $event->[ NDO_DATA_TYPE() ] eq NEBTYPE_NOTIFICATION_START() ) {
                $LAST_NOTIFICATION_ID =
                  $sth_insert_handle_NOTIFICATIONDATA->{mysql_insertid};
            }
        }
        else {
            $sth_update_handle_NOTIFICATIONDATA->execute(@data);

            # get primary key for existing entry
            $sth_fetch_ID_handle_NOTIFICATIONDATA->execute( $object_id,
                $start_time, $start_time_usec );

            ($LAST_NOTIFICATION_ID) =
              $sth_fetch_ID_handle_NOTIFICATIONDATA->fetchrow_array();
            $sth_fetch_ID_handle_NOTIFICATIONDATA->finish();

        }
    }

    return 1;
}

our $sth_insert_handle_SERVICECHECKDATA;

sub handle_SERVICECHECKDATA {

    $sth_insert_handle_SERVICECHECKDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_servicechecks SET

        instance_id=1,
        service_object_id=?,
        check_type=?,
        current_check_attempt=?,
        max_check_attempts=?,
        state=?,
        state_type=?,
        start_time=FROM_UNIXTIME(?),
        start_time_usec=?,
        end_time=FROM_UNIXTIME(?),
        end_time_usec=?,
        timeout=?,
        early_timeout=?,
        execution_time=?,
        latency=?,
        return_code=?,
        output=?,
        perfdata=?

        ,
                command_object_id=?,
                command_args=?,
                command_line=?
        }
    ) unless defined $sth_insert_handle_SERVICECHECKDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        next if $event->[ NDO_DATA_TYPE() ] != NEBTYPE_SERVICECHECK_PROCESSED();

        next
          if $event->[ NDO_DATA_TYPE() ]
          == NEBTYPE_SERVICECHECK_ASYNC_PRECHECK();

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_SERVICE(),
            $event->[ NDO_DATA_HOST() ],
            $event->[ NDO_DATA_SERVICE() ]
        );
        my $command_id = 0;

        if ( defined $event->[ NDO_DATA_COMMANDNAME() ]
            && length $event->[ NDO_DATA_COMMANDNAME() ] )
        {
            $command_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_COMMAND(),
                $event->[ NDO_DATA_COMMANDNAME() ]
            );
        }
        my ( $start_time, $start_time_usec ) =
          timeval( $event->[ NDO_DATA_STARTTIME() ] );
        my ( $end_time, $end_time_usec ) =
          timeval( $event->[ NDO_DATA_ENDTIME() ] );

        my @data = (
            $object_id,

            @$event[
              NDO_DATA_CHECKTYPE(), NDO_DATA_CURRENTCHECKATTEMPT(),
            NDO_DATA_MAXCHECKATTEMPTS(), NDO_DATA_STATE(),
            NDO_DATA_STATETYPE(),
            ],

            $start_time,
            $start_time_usec,
            $end_time,
            $end_time_usec,

            @$event[
              NDO_DATA_TIMEOUT(), NDO_DATA_EARLYTIMEOUT(),
            NDO_DATA_EXECUTIONTIME(), NDO_DATA_LATENCY(),
            NDO_DATA_RETURNCODE(),    NDO_DATA_OUTPUT(),
            NDO_DATA_PERFDATA(),
            ],
            $command_id,
            @$event[ NDO_DATA_COMMANDARGS(), NDO_DATA_COMMANDLINE(), ]
        );

        my $rv = $sth_insert_handle_SERVICECHECKDATA->execute(@data);
        die "Insert failed: ", $sth_insert_handle_SERVICECHECKDATA->errstr, "\n"
          unless $rv;
    }

    return 1;
}

our $sth_insert_handle_HOSTCHECKDATA;

sub handle_HOSTCHECKDATA {

    $sth_insert_handle_HOSTCHECKDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_hostchecks SET
                instance_id=1,

        host_object_id=?,
        check_type=?,
        is_raw_check=?,
        current_check_attempt=?,
        max_check_attempts=?,
        state=?,
        state_type=?,
        start_time=FROM_UNIXTIME(?),
        start_time_usec=?,
        end_time=FROM_UNIXTIME(?),
        end_time_usec=?,
        timeout=?,
        early_timeout=?,
        execution_time=?,
        latency=?,
        return_code=?,
        output=?,
        perfdata=?,
        command_object_id=?,
        command_args=?,
        command_line=?

        }
    ) unless defined $sth_insert_handle_HOSTCHECKDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        next if $event->[ NDO_DATA_TYPE() ] != NEBTYPE_HOSTCHECK_PROCESSED();

        next
          if $event->[ NDO_DATA_TYPE() ] == NEBTYPE_HOSTCHECK_ASYNC_PRECHECK()
          || $event->[ NDO_DATA_TYPE() ] == NEBTYPE_HOSTCHECK_SYNC_PRECHECK();

        my $object_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
            $event->[ NDO_DATA_HOST() ]
          );
        my $command_id = 0;

        if ( defined $event->[ NDO_DATA_COMMANDNAME() ]
            && length $event->[ NDO_DATA_COMMANDNAME() ] )
        {
            $command_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_COMMAND(),
                $event->[ NDO_DATA_COMMANDNAME() ]
            );
        }

        my $is_raw_check =
             $event->[ NDO_DATA_TYPE() ] == NEBTYPE_HOSTCHECK_RAW_START()
          || $event->[ NDO_DATA_TYPE() ] == NEBTYPE_HOSTCHECK_RAW_END() ? 1 : 0;

        my ( $start_time, $start_time_usec ) =
          timeval( $event->[ NDO_DATA_STARTTIME() ] );
        my ( $end_time, $end_time_usec ) =
          timeval( $event->[ NDO_DATA_ENDTIME() ] );

        my @data = (
            $object_id,
            $event->[ NDO_DATA_CHECKTYPE() ],
            $is_raw_check,
            @$event[
              NDO_DATA_CURRENTCHECKATTEMPT(), NDO_DATA_MAXCHECKATTEMPTS(),
            NDO_DATA_STATE(), NDO_DATA_STATETYPE(),
            ],

            $start_time,
            $start_time_usec,
            $end_time,
            $end_time_usec,

            @$event[
              NDO_DATA_TIMEOUT(), NDO_DATA_EARLYTIMEOUT(),
            NDO_DATA_EXECUTIONTIME(), NDO_DATA_LATENCY(),
            NDO_DATA_RETURNCODE(),    NDO_DATA_OUTPUT(),
            NDO_DATA_PERFDATA(),
            ],

            $command_id,
            @$event[ NDO_DATA_COMMANDARGS(), NDO_DATA_COMMANDLINE(), ]
        );

        my $rv = $sth_insert_handle_HOSTCHECKDATA->execute(@data);
        die "Insert failed: ", $sth_insert_handle_HOSTCHECKDATA->errstr, "\n"
          unless $rv;
    }

    return 1;
}

our $sth_update_handle_COMMENTDATA;
our $sth_insert_handle_COMMENTDATA;
our $sth_delete_handle_COMMENTDATA;
our $sth_update_comments_handle_COMMENTDATA;
our $sth_insert_comments_handle_COMMENTDATA;
our $sth_delete_comments_handle_COMMENTDATA;

sub handle_COMMENTDATA {

    $sth_update_handle_COMMENTDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_commenthistory SET

        comment_type=?,
        entry_type=?,
        object_id=?,
        author_name=?,
        comment_data=?,
        is_persistent=?,
        comment_source=?,
        expires=?,
        expiration_time=FROM_UNIXTIME(?)

            WHERE
                comment_time=FROM_UNIXTIME(?)
                AND
                internal_comment_id=?
                AND
                instance_id=1
        }
    ) unless defined $sth_update_handle_COMMENTDATA;

    $sth_insert_handle_COMMENTDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_commenthistory SET

        comment_type=?,
        entry_type=?,
        object_id=?,
        author_name=?,
        comment_data=?,
        is_persistent=?,
        comment_source=?,
        expires=?,
        expiration_time=FROM_UNIXTIME(?)

                ,comment_time=FROM_UNIXTIME(?)
                ,internal_comment_id=?
                ,entry_time=FROM_UNIXTIME(?)
                ,entry_time_usec=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_COMMENTDATA;

    $sth_delete_handle_COMMENTDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_commenthistory
            SET
                deletion_time=FROM_UNIXTIME(?),
                deletion_time_usec=?
            WHERE
                comment_time=FROM_UNIXTIME(?)
                    AND
                internal_comment_id=?
                    AND
                instance_id=1
        }
    ) unless defined $sth_delete_handle_COMMENTDATA;

    $sth_update_comments_handle_COMMENTDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_comments SET

        comment_type=?,
        entry_type=?,
        object_id=?,
        author_name=?,
        comment_data=?,
        is_persistent=?,
        comment_source=?,
        expires=?,
        expiration_time=FROM_UNIXTIME(?)

            WHERE
                comment_time=FROM_UNIXTIME(?)
                AND
                internal_comment_id=?
                AND
                instance_id=1
        }
    ) unless defined $sth_update_comments_handle_COMMENTDATA;

    $sth_insert_comments_handle_COMMENTDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_comments SET

        comment_type=?,
        entry_type=?,
        object_id=?,
        author_name=?,
        comment_data=?,
        is_persistent=?,
        comment_source=?,
        expires=?,
        expiration_time=FROM_UNIXTIME(?)

                ,comment_time=FROM_UNIXTIME(?)
                ,internal_comment_id=?
                ,entry_time=FROM_UNIXTIME(?)
                ,entry_time_usec=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_comments_handle_COMMENTDATA;

    $sth_delete_comments_handle_COMMENTDATA = $DB->prepare_cached(
        q{
            DELETE FROM nagios_comments 
            WHERE
                comment_time=FROM_UNIXTIME(?)
                AND
                internal_comment_id=?
                AND
                instance_id=1
        }
    ) unless defined $sth_delete_comments_handle_COMMENTDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );
        my $comment_time = int( $event->[ NDO_DATA_ENTRYTIME() ] );
        my $expire_time  = int( $event->[ NDO_DATA_EXPIRATIONTIME() ] );

        my $type         = $event->[ NDO_DATA_TYPE() ];
        my $comment_type = $event->[ NDO_DATA_COMMENTTYPE() ];

        my $object_id = 0;
        if ( $comment_type == SERVICE_COMMENT() ) {
            $object_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_SERVICE(),
                $event->[ NDO_DATA_HOST() ],
                $event->[ NDO_DATA_SERVICE() ]
            );
        }
        elsif ( $comment_type == HOST_COMMENT() ) {
            $object_id =
              get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
                $event->[ NDO_DATA_HOST() ]
              );
        }

        my $is_current = $state_time >= $LATEST_REALTIME_DATA_TIME;

        if ( $type == NEBTYPE_COMMENT_ADD() || $type == NEBTYPE_COMMENT_LOAD() )
        {

            my @data = (
                $comment_type,
                $event->[ NDO_DATA_ENTRYTYPE() ],
                $object_id,

                @$event[
                  NDO_DATA_AUTHORNAME(), NDO_DATA_COMMENT(),
                NDO_DATA_PERSISTENT(), NDO_DATA_SOURCE(),
                NDO_DATA_EXPIRES(),
                ],
                $expire_time,

                $comment_time,
                $event->[ NDO_DATA_COMMENTID() ]
            );

            my $rv =
              $sth_insert_handle_COMMENTDATA->execute( @data, $state_time,
                $state_time_usec, );

            unless ($rv) {
                $sth_update_handle_COMMENTDATA->execute(@data);
            }

            if ($is_current) {

                my $rv =
                  $sth_insert_comments_handle_COMMENTDATA->execute( @data,
                    $state_time, $state_time_usec, );

                unless ($rv) {
                    $sth_update_comments_handle_COMMENTDATA->execute(@data);
                }
            }

        }

        if ( $type == NEBTYPE_COMMENT_DELETE() ) {
            my @data = ( $comment_time, $event->[ NDO_DATA_COMMENTID() ] );

            my $rv =
              $sth_delete_handle_COMMENTDATA->execute( $state_time,
                $state_time_usec, @data );
            die "Update failed: ", $sth_delete_handle_COMMENTDATA->errstr, "\n"
              unless $rv;

            if ($is_current) {

                my $rv =
                  $sth_delete_comments_handle_COMMENTDATA->execute(@data);
                die "Update failed: ",
                  $sth_delete_comments_handle_COMMENTDATA->errstr, "\n"
                  unless $rv;

            }

        }
    }

    return 1;
}

our $sth_update_handle_DOWNTIMEDATA;
our $sth_insert_handle_DOWNTIMEDATA;
our $sth_update_start_handle_DOWNTIMEDATA;
our $sth_update_stop_handle_DOWNTIMEDATA;
our $sth_update_schedule_handle_DOWNTIMEDATA;
our $sth_insert_schedule_handle_DOWNTIMEDATA;
our $sth_update_start_schedule_handle_DOWNTIMEDATA;
our $sth_update_stop_schedule_handle_DOWNTIMEDATA;

sub handle_DOWNTIMEDATA {

    $sth_update_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_downtimehistory SET

        downtime_type=?,
        author_name=?,
        comment_data=?,
        triggered_by_id=?,
        is_fixed=?,
        duration=?,
        scheduled_start_time=FROM_UNIXTIME(?),
        scheduled_end_time=FROM_UNIXTIME(?)

            WHERE
                object_id=?
                AND
                entry_time=FROM_UNIXTIME(?)
                AND
                internal_downtime_id=?
                AND
                instance_id=1
        }
    ) unless defined $sth_update_handle_DOWNTIMEDATA;

    $sth_insert_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_downtimehistory SET

        downtime_type=?,
        author_name=?,
        comment_data=?,
        triggered_by_id=?,
        is_fixed=?,
        duration=?,
        scheduled_start_time=FROM_UNIXTIME(?),
        scheduled_end_time=FROM_UNIXTIME(?)

                ,object_id=?
                ,entry_time=FROM_UNIXTIME(?)
                ,internal_downtime_id=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_DOWNTIMEDATA;

    $sth_update_start_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_downtimehistory SET
                actual_start_time=FROM_UNIXTIME(?),
                actual_start_time_usec=?,
                was_started=1
            WHERE
                downtime_type=?
                    AND
                object_id=?
                    AND
                entry_time=FROM_UNIXTIME(?)
                    AND
                scheduled_start_time=FROM_UNIXTIME(?)
                    AND
                scheduled_end_time=FROM_UNIXTIME(?)
                    AND
                was_started=0
                    AND
                instance_id=1
        }
    ) unless defined $sth_update_start_handle_DOWNTIMEDATA;

    $sth_update_stop_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_downtimehistory SET
                actual_end_time=FROM_UNIXTIME(?),
                actual_end_time_usec=?,
                was_cancelled=?
            WHERE
                downtime_type=?
                    AND
                object_id=?
                    AND
                entry_time=FROM_UNIXTIME(?)
                    AND
                scheduled_start_time=FROM_UNIXTIME(?)
                    AND
                scheduled_end_time=FROM_UNIXTIME(?)
                    AND
                instance_id=1
        }
    ) unless defined $sth_update_stop_handle_DOWNTIMEDATA;

    $sth_update_schedule_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_scheduleddowntime SET

        downtime_type=?,
        author_name=?,
        comment_data=?,
        triggered_by_id=?,
        is_fixed=?,
        duration=?,
        scheduled_start_time=FROM_UNIXTIME(?),
        scheduled_end_time=FROM_UNIXTIME(?)

            WHERE
                object_id=?
                AND
                entry_time=FROM_UNIXTIME(?)
                AND
                internal_downtime_id=?
                AND
                instance_id=1
        }
    ) unless defined $sth_update_schedule_handle_DOWNTIMEDATA;

    $sth_insert_schedule_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_scheduleddowntime SET

        downtime_type=?,
        author_name=?,
        comment_data=?,
        triggered_by_id=?,
        is_fixed=?,
        duration=?,
        scheduled_start_time=FROM_UNIXTIME(?),
        scheduled_end_time=FROM_UNIXTIME(?)

                ,object_id=?
                ,entry_time=FROM_UNIXTIME(?)
                ,internal_downtime_id=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_schedule_handle_DOWNTIMEDATA;

    $sth_update_start_schedule_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_scheduleddowntime SET
                actual_start_time=FROM_UNIXTIME(?),
                actual_start_time_usec=?,
                was_started=1
            WHERE
                downtime_type=?
                    AND
                object_id=?
                    AND
                entry_time=FROM_UNIXTIME(?)
                    AND
                scheduled_start_time=FROM_UNIXTIME(?)
                    AND
                scheduled_end_time=FROM_UNIXTIME(?)
                    AND
                was_started=0
                    AND
                instance_id=1
        }
    ) unless defined $sth_update_start_schedule_handle_DOWNTIMEDATA;

    $sth_update_stop_schedule_handle_DOWNTIMEDATA = $DB->prepare_cached(
        q{
            DELETE FROM nagios_scheduleddowntime 
            WHERE
                downtime_type=?
                    AND
                object_id=?
                    AND
                entry_time=FROM_UNIXTIME(?)
                    AND
                scheduled_start_time=FROM_UNIXTIME(?)
                    AND
                scheduled_end_time=FROM_UNIXTIME(?)
                    AND
                instance_id=1
        }
    ) unless defined $sth_update_stop_schedule_handle_DOWNTIMEDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );
        my $entry_time = int( $event->[ NDO_DATA_ENTRYTIME() ] );
        my $start_time = int( $event->[ NDO_DATA_STARTTIME() ] );
        my $end_time   = int( $event->[ NDO_DATA_ENDTIME() ] );

        my $type          = $event->[ NDO_DATA_TYPE() ];
        my $downtime_type = $event->[ NDO_DATA_DOWNTIMETYPE() ];

        my $object_id = 0;
        if ( $downtime_type == SERVICE_DOWNTIME() ) {
            $object_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_SERVICE(),
                $event->[ NDO_DATA_HOST() ],
                $event->[ NDO_DATA_SERVICE() ]
            );
        }
        elsif ( $downtime_type == HOST_DOWNTIME() ) {
            $object_id =
              get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
                $event->[ NDO_DATA_HOST() ]
              );
        }

        my $is_current = $state_time >= $LATEST_REALTIME_DATA_TIME;

        if (   $type == NEBTYPE_DOWNTIME_ADD()
            || $type == NEBTYPE_DOWNTIME_LOAD() )
        {

            my @data = (
                $downtime_type,

                @$event[
                  NDO_DATA_AUTHORNAME(), NDO_DATA_COMMENT(),
                NDO_DATA_TRIGGEREDBY(), NDO_DATA_FIXED(),
                NDO_DATA_DURATION(),
                ],
                $start_time,
                $end_time,

                $object_id,
                $entry_time,
                $event->[ NDO_DATA_DOWNTIMEID() ]
            );

            my $rv = $sth_insert_handle_DOWNTIMEDATA->execute(@data);

            unless ($rv) {
                $sth_update_handle_DOWNTIMEDATA->execute(@data);
            }

            if ($is_current) {

                my $rv =
                  $sth_insert_schedule_handle_DOWNTIMEDATA->execute(@data);

                unless ($rv) {
                    $sth_update_schedule_handle_DOWNTIMEDATA->execute(@data);
                }
            }

        }
        elsif ( $type == NEBTYPE_DOWNTIME_START() ) {
            my @data = (
                $state_time, $state_time_usec, $downtime_type, $object_id,
                $entry_time, $start_time, $end_time,
            );

            my $rv = $sth_update_start_handle_DOWNTIMEDATA->execute(@data);
            die "Update failed: ",
              $sth_update_start_handle_DOWNTIMEDATA->errstr, "\n"
              unless $rv;

            if ($is_current) {

                my $rv =
                  $sth_update_start_schedule_handle_DOWNTIMEDATA->execute(
                    @data);
                die "Update failed: ",
                  $sth_update_start_schedule_handle_DOWNTIMEDATA->errstr, "\n"
                  unless $rv;

            }
        }

        if ( $type == NEBTYPE_DOWNTIME_STOP() ) {
            my @data = (
                $state_time,
                $state_time_usec,
                $event->[ NDO_DATA_ATTRIBUTES() ]
                  == NEBATTR_DOWNTIME_STOP_CANCELLED ? 1 : 0,
                $downtime_type,
                $object_id,
                $entry_time,
                $start_time,
                $end_time,
            );

            my $rv = $sth_update_stop_handle_DOWNTIMEDATA->execute(@data);
            die "Update failed: ",
              $sth_update_stop_handle_DOWNTIMEDATA->errstr, "\n"
              unless $rv;

        }

        if (
            (
                   $type == NEBTYPE_DOWNTIME_STOP()
                || $type == NEBTYPE_DOWNTIME_DELETE()
            )
            && $is_current
          )
        {
            my @data = (
                $downtime_type, $object_id, $entry_time,
                $start_time,    $end_time,
            );

            my $rv =
              $sth_update_stop_schedule_handle_DOWNTIMEDATA->execute(@data);
            die "Update failed: ",
              $sth_update_stop_schedule_handle_DOWNTIMEDATA->errstr, "\n"
              unless $rv;

        }
    }

    return 1;
}

our $sth_update_handle_PROGRAMSTATUSDATA;
our $sth_insert_handle_PROGRAMSTATUSDATA;

sub handle_PROGRAMSTATUSDATA {

    $sth_update_handle_PROGRAMSTATUSDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_programstatus SET

    status_update_time=FROM_UNIXTIME(?),
    program_start_time=FROM_UNIXTIME(?),
    is_currently_running='1',
    process_id=?,
    daemon_mode=?,
    last_command_check=FROM_UNIXTIME(?),
    last_log_rotation=FROM_UNIXTIME(?),
    notifications_enabled=?,
    active_service_checks_enabled=?,
    passive_service_checks_enabled=?,
    active_host_checks_enabled=?,
    passive_host_checks_enabled=?,
    event_handlers_enabled=?,
    flap_detection_enabled=?,
    failure_prediction_enabled=0,
    process_performance_data=?,
    obsess_over_hosts=?,
    obsess_over_services=?,
    modified_host_attributes=?,
    modified_service_attributes=?,
    global_host_event_handler=?,
    global_service_event_handler=?


            WHERE
                instance_id=1
        }
    ) unless defined $sth_update_handle_PROGRAMSTATUSDATA;

    $sth_insert_handle_PROGRAMSTATUSDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_programstatus SET

    status_update_time=FROM_UNIXTIME(?),
    program_start_time=FROM_UNIXTIME(?),
    is_currently_running='1',
    process_id=?,
    daemon_mode=?,
    last_command_check=FROM_UNIXTIME(?),
    last_log_rotation=FROM_UNIXTIME(?),
    notifications_enabled=?,
    active_service_checks_enabled=?,
    passive_service_checks_enabled=?,
    active_host_checks_enabled=?,
    passive_host_checks_enabled=?,
    event_handlers_enabled=?,
    flap_detection_enabled=?,
    failure_prediction_enabled=0,
    process_performance_data=?,
    obsess_over_hosts=?,
    obsess_over_services=?,
    modified_host_attributes=?,
    modified_service_attributes=?,
    global_host_event_handler=?,
    global_service_event_handler=?


                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_PROGRAMSTATUSDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $program_start_time =
          int( $event->[ NDO_DATA_PROGRAMSTARTTIME() ] );
        my $last_command_check =
          int( $event->[ NDO_DATA_LASTCOMMANDCHECK() ] );
        my $last_log_rotation = int( $event->[ NDO_DATA_LASTLOGROTATION() ] );

        my @data = (
            $state_time,
            $program_start_time,

            @$event[ NDO_DATA_PROCESSID(), NDO_DATA_DAEMONMODE(), ],

            $last_command_check,
            $last_log_rotation,

            @$event[
              NDO_DATA_NOTIFICATIONSENABLED(),
            NDO_DATA_ACTIVESERVICECHECKSENABLED(),
            NDO_DATA_PASSIVESERVICECHECKSENABLED(),
            NDO_DATA_ACTIVEHOSTCHECKSENABLED(),
            NDO_DATA_PASSIVEHOSTCHECKSENABLED(),
            NDO_DATA_EVENTHANDLERSENABLED(),
            NDO_DATA_FLAPDETECTIONENABLED(),
            NDO_DATA_PROCESSPERFORMANCEDATA(),
            NDO_DATA_OBSESSOVERHOSTS(),
            NDO_DATA_OBSESSOVERSERVICES(),
            NDO_DATA_MODIFIEDHOSTATTRIBUTES(),
            NDO_DATA_MODIFIEDSERVICEATTRIBUTES(),
            NDO_DATA_GLOBALHOSTEVENTHANDLER(),
            NDO_DATA_GLOBALSERVICEEVENTHANDLER(),
            ]
        );

        my $rv = $sth_update_handle_PROGRAMSTATUSDATA->execute(@data);
        die "Update failed: ", $sth_update_handle_PROGRAMSTATUSDATA->errstr,
          "\n"
          unless $rv;

        if ( $rv eq '0E0' ) {
            $sth_insert_handle_PROGRAMSTATUSDATA->execute(@data);
        }
    }

    return 1;
}

our $sth_insert_handle_HOSTSTATUSDATA;
our $sth_update_handle_HOSTSTATUSDATA;
our $sth_insert_downtime_handle_HOSTSTATUSDATA;
our $sth_update_downtime_handle_HOSTSTATUSDATA;

sub handle_HOSTSTATUSDATA {

    $sth_update_handle_HOSTSTATUSDATA = $DB->prepare_cached(
        qq{
            UPDATE nagios_hoststatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_up=FROM_UNIXTIME(?),
        last_time_down=FROM_UNIXTIME(?),
        last_time_unreachable=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_host=?,
        modified_host_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

            WHERE
                host_object_id=?
        }
    ) unless defined $sth_update_handle_HOSTSTATUSDATA;

    $sth_update_downtime_handle_HOSTSTATUSDATA = $DB->prepare_cached(
        qq{
            UPDATE nagios_hoststatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_up=FROM_UNIXTIME(?),
        last_time_down=FROM_UNIXTIME(?),
        last_time_unreachable=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_host=?,
        modified_host_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

        , scheduled_downtime_depth = ?

            WHERE
                host_object_id=?
        }
    ) unless defined $sth_update_downtime_handle_HOSTSTATUSDATA;

    $sth_insert_handle_HOSTSTATUSDATA = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_hoststatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_up=FROM_UNIXTIME(?),
        last_time_down=FROM_UNIXTIME(?),
        last_time_unreachable=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_host=?,
        modified_host_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

                , host_object_id=?
        }
    ) unless defined $sth_insert_handle_HOSTSTATUSDATA;

    $sth_insert_downtime_handle_HOSTSTATUSDATA = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_hoststatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_up=FROM_UNIXTIME(?),
        last_time_down=FROM_UNIXTIME(?),
        last_time_unreachable=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_host=?,
        modified_host_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

        , scheduled_downtime_depth = ?

                , host_object_id=?
        }
    ) unless defined $sth_insert_downtime_handle_HOSTSTATUSDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my $state_time = $event->[ NDO_DATA_TIMESTAMP() ];
        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
            $event->[ NDO_DATA_HOST() ]
          );
        my $check_timeperiod_object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_HOSTCHECKPERIOD() ]
        );
        my $last_check_time = int( $event->[ NDO_DATA_LASTHOSTCHECK() ] );
        my $next_check_time = int( $event->[ NDO_DATA_NEXTHOSTCHECK() ] );
        my $last_state_change_time =
          int( $event->[ NDO_DATA_LASTSTATECHANGE() ] );
        my $last_hard_state_change_time =
          int( $event->[ NDO_DATA_LASTHARDSTATECHANGE() ] );
        my $last_time_up_time   = int( $event->[ NDO_DATA_LASTTIMEUP() ] );
        my $last_time_down_time = int( $event->[ NDO_DATA_LASTTIMEDOWN() ] );
        my $last_time_unreachable_time =
          int( $event->[ NDO_DATA_LASTTIMEUNREACHABLE() ] );
        my $last_notification_time =
          int( $event->[ NDO_DATA_LASTHOSTNOTIFICATION() ] );
        my $next_notification_time =
          int( $event->[ NDO_DATA_NEXTHOSTNOTIFICATION() ] );

        my @data = (
            $state_time,
            @$event[
              NDO_DATA_OUTPUT(), NDO_DATA_PERFDATA(),
            NDO_DATA_CURRENTSTATE(),      NDO_DATA_HASBEENCHECKED(),
            NDO_DATA_SHOULDBESCHEDULED(), NDO_DATA_CURRENTCHECKATTEMPT(),
            NDO_DATA_MAXCHECKATTEMPTS(),
            ],
            $last_check_time,
            $next_check_time,
            $event->[ NDO_DATA_CHECKTYPE() ],
            $last_state_change_time,
            $last_hard_state_change_time,
            $event->[ NDO_DATA_LASTHARDSTATE() ],
            $last_time_up_time,
            $last_time_down_time,
            $last_time_unreachable_time,
            $event->[ NDO_DATA_STATETYPE() ],
            $last_notification_time,
            $next_notification_time,
            @$event[
              NDO_DATA_NOMORENOTIFICATIONS(),
            NDO_DATA_NOTIFICATIONSENABLED(),
            NDO_DATA_PROBLEMHASBEENACKNOWLEDGED(),
            NDO_DATA_ACKNOWLEDGEMENTTYPE(),
            NDO_DATA_CURRENTNOTIFICATIONNUMBER(),
            NDO_DATA_PASSIVEHOSTCHECKSENABLED(),
            NDO_DATA_ACTIVEHOSTCHECKSENABLED(),
            NDO_DATA_EVENTHANDLERENABLED(),
            NDO_DATA_FLAPDETECTIONENABLED(),
            NDO_DATA_ISFLAPPING(),
            NDO_DATA_PERCENTSTATECHANGE(),
            NDO_DATA_LATENCY(),
            NDO_DATA_EXECUTIONTIME(),
            NDO_DATA_PROCESSPERFORMANCEDATA(),
            NDO_DATA_OBSESSOVERHOST(),
            NDO_DATA_MODIFIEDHOSTATTRIBUTES(),
            NDO_DATA_EVENTHANDLER(),
            NDO_DATA_CHECKCOMMAND(),
            NDO_DATA_NORMALCHECKINTERVAL(),
            NDO_DATA_RETRYCHECKINTERVAL(),
            ],
            $check_timeperiod_object_id,
        );

        my $rv;

        # Opsview patch: Only set the downtime flag if we are not in a retention data dump.
        # This is because when retention data is read, the scheduled_downtime_depth is reset to 0
        # and not changed until downtime is set later on. By missing this bit of data out from the SQL,
        # if the downtime is already set, then it will not get reset
        if ($LOADING_RETENTION_DATA_FLAG) {
            $rv =
              $sth_update_handle_HOSTSTATUSDATA->execute( @data, $object_id );

            if ( $rv eq '0E0' ) {
                $sth_insert_handle_HOSTSTATUSDATA->execute( @data, $object_id );
            }
        }
        else {
            $rv =
              $sth_update_downtime_handle_HOSTSTATUSDATA->execute( @data,
                $event->[ NDO_DATA_SCHEDULEDDOWNTIMEDEPTH() ], $object_id );

            if ( $rv eq '0E0' ) {
                $sth_insert_downtime_handle_HOSTSTATUSDATA->execute( @data,
                    $event->[ NDO_DATA_SCHEDULEDDOWNTIMEDEPTH() ], $object_id );
            }
        }

        if ( defined $event->[ NDO_DATA_CUSTOMVARIABLE() ] ) {
            handle_MULTI_CUSTOMVARIABLESTATUS(
                $event->[ NDO_DATA_CUSTOMVARIABLE() ],
                $object_id, $event->[ NDO_DATA_TIMESTAMP() ]
            );
        }
    }

    return 1;
}

our $sth_insert_handle_SERVICESTATUSDATA;
our $sth_update_handle_SERVICESTATUSDATA;
our $sth_insert_downtime_handle_SERVICESTATUSDATA;
our $sth_update_downtime_handle_SERVICESTATUSDATA;

sub handle_SERVICESTATUSDATA {

    $sth_update_handle_SERVICESTATUSDATA = $DB->prepare_cached(
        qq{
            UPDATE nagios_servicestatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_ok=FROM_UNIXTIME(?),
        last_time_warning=FROM_UNIXTIME(?),
        last_time_unknown=FROM_UNIXTIME(?),
        last_time_critical=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_service=?,
        modified_service_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

            WHERE
                service_object_id=?
        }
    ) unless defined $sth_update_handle_SERVICESTATUSDATA;

    $sth_update_downtime_handle_SERVICESTATUSDATA = $DB->prepare_cached(
        qq{
            UPDATE nagios_servicestatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_ok=FROM_UNIXTIME(?),
        last_time_warning=FROM_UNIXTIME(?),
        last_time_unknown=FROM_UNIXTIME(?),
        last_time_critical=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_service=?,
        modified_service_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

        , scheduled_downtime_depth = ?

            WHERE
                service_object_id=?
        }
    ) unless defined $sth_update_downtime_handle_SERVICESTATUSDATA;

    $sth_insert_handle_SERVICESTATUSDATA = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_servicestatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_ok=FROM_UNIXTIME(?),
        last_time_warning=FROM_UNIXTIME(?),
        last_time_unknown=FROM_UNIXTIME(?),
        last_time_critical=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_service=?,
        modified_service_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

                , service_object_id=?
        }
    ) unless defined $sth_insert_handle_SERVICESTATUSDATA;

    $sth_insert_downtime_handle_SERVICESTATUSDATA = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_servicestatus SET

        instance_id=1,
        status_update_time=FROM_UNIXTIME(?),
        output=?,
        perfdata=?,
        current_state=?,
        has_been_checked=?,
        should_be_scheduled=?,
        current_check_attempt=?,
        max_check_attempts=?,
        last_check=FROM_UNIXTIME(?),
        next_check=FROM_UNIXTIME(?),
        check_type=?,
        last_state_change=FROM_UNIXTIME(?),
        last_hard_state_change=FROM_UNIXTIME(?),
        last_hard_state=?,
        last_time_ok=FROM_UNIXTIME(?),
        last_time_warning=FROM_UNIXTIME(?),
        last_time_unknown=FROM_UNIXTIME(?),
        last_time_critical=FROM_UNIXTIME(?),
        state_type=?,
        last_notification=FROM_UNIXTIME(?),
        next_notification=FROM_UNIXTIME(?),
        no_more_notifications=?,
        notifications_enabled=?,
        problem_has_been_acknowledged=?,
        acknowledgement_type=?,
        current_notification_number=?,
        passive_checks_enabled=?,
        active_checks_enabled=?,
        event_handler_enabled=?,
        flap_detection_enabled=?,
        is_flapping=?,
        percent_state_change=?,
        latency=?,
        execution_time=?,
        failure_prediction_enabled=0,
        process_performance_data=?,
        obsess_over_service=?,
        modified_service_attributes=?,
        event_handler=?,
        check_command=?,
        normal_check_interval=?,
        retry_check_interval=?,
        check_timeperiod_object_id=?

        , scheduled_downtime_depth = ?

                , service_object_id=?
        }
    ) unless defined $sth_insert_downtime_handle_SERVICESTATUSDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_SERVICE(),
            $event->[ NDO_DATA_HOST() ],
            $event->[ NDO_DATA_SERVICE() ]
        );
        my $timeperiod_object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_SERVICECHECKPERIOD() ]
        );
        my $last_check_time = int( $event->[ NDO_DATA_LASTSERVICECHECK() ] );
        my $next_check_time = int( $event->[ NDO_DATA_NEXTSERVICECHECK() ] );
        my $last_state_change_time =
          int( $event->[ NDO_DATA_LASTSTATECHANGE() ] );
        my $last_hard_state_change_time =
          int( $event->[ NDO_DATA_LASTHARDSTATECHANGE() ] );
        my $last_time_ok_time = int( $event->[ NDO_DATA_LASTTIMEOK() ] );
        my $last_time_warning_time =
          int( $event->[ NDO_DATA_LASTTIMEWARNING() ] );
        my $last_time_unknown_time =
          int( $event->[ NDO_DATA_LASTTIMEUNKNOWN() ] );
        my $last_time_critical_time =
          int( $event->[ NDO_DATA_LASTTIMECRITICAL() ] );
        my $last_notification_time =
          int( $event->[ NDO_DATA_LASTSERVICENOTIFICATION() ] );
        my $next_notification_time =
          int( $event->[ NDO_DATA_NEXTSERVICENOTIFICATION() ] );

        my @data = (
            $state_time,
            @$event[
              NDO_DATA_OUTPUT(), NDO_DATA_PERFDATA(),
            NDO_DATA_CURRENTSTATE(),      NDO_DATA_HASBEENCHECKED(),
            NDO_DATA_SHOULDBESCHEDULED(), NDO_DATA_CURRENTCHECKATTEMPT(),
            NDO_DATA_MAXCHECKATTEMPTS(),
            ],
            $last_check_time,
            $next_check_time,
            $event->[ NDO_DATA_CHECKTYPE() ],
            $last_state_change_time,
            $last_hard_state_change_time,
            $event->[ NDO_DATA_LASTHARDSTATE() ],
            $last_time_ok_time,
            $last_time_warning_time,
            $last_time_unknown_time,
            $last_time_critical_time,
            $event->[ NDO_DATA_STATETYPE() ],
            $last_notification_time,
            $next_notification_time,
            @$event[
              NDO_DATA_NOMORENOTIFICATIONS(),
            NDO_DATA_NOTIFICATIONSENABLED(),
            NDO_DATA_PROBLEMHASBEENACKNOWLEDGED(),
            NDO_DATA_ACKNOWLEDGEMENTTYPE(),
            NDO_DATA_CURRENTNOTIFICATIONNUMBER(),
            NDO_DATA_PASSIVESERVICECHECKSENABLED(),
            NDO_DATA_ACTIVESERVICECHECKSENABLED(),
            NDO_DATA_EVENTHANDLERENABLED(),
            NDO_DATA_FLAPDETECTIONENABLED(),
            NDO_DATA_ISFLAPPING(),
            NDO_DATA_PERCENTSTATECHANGE(),
            NDO_DATA_LATENCY(),
            NDO_DATA_EXECUTIONTIME(),
            NDO_DATA_PROCESSPERFORMANCEDATA(),
            NDO_DATA_OBSESSOVERSERVICE(),
            NDO_DATA_MODIFIEDSERVICEATTRIBUTES(),
            NDO_DATA_EVENTHANDLER(),
            NDO_DATA_CHECKCOMMAND(),
            NDO_DATA_NORMALCHECKINTERVAL(),
            NDO_DATA_RETRYCHECKINTERVAL(),
            ],
            $timeperiod_object_id,
        );

        my $rv;

        # Opsview patch: Only set the downtime flag if we are not in a retention data dump.
        # This is because when retention data is read, the scheduled_downtime_depth is reset to 0
        # and not changed until downtime is set later on. By missing this bit of data out from the SQL,
        # if the downtime is already set, then it will not get reset
        if ($LOADING_RETENTION_DATA_FLAG) {
            $rv =
              $sth_update_handle_SERVICESTATUSDATA->execute( @data,
                $object_id );

            if ( $rv eq '0E0' ) {
                $sth_insert_handle_SERVICESTATUSDATA->execute( @data,
                    $object_id );
            }
        }
        else {
            $rv =
              $sth_update_downtime_handle_SERVICESTATUSDATA->execute( @data,
                $event->[ NDO_DATA_SCHEDULEDDOWNTIMEDEPTH() ], $object_id );

            if ( $rv eq '0E0' ) {
                $sth_insert_downtime_handle_SERVICESTATUSDATA->execute( @data,
                    $event->[ NDO_DATA_SCHEDULEDDOWNTIMEDEPTH() ], $object_id );
            }
        }

        if ( defined $event->[ NDO_DATA_CUSTOMVARIABLE() ] ) {
            handle_MULTI_CUSTOMVARIABLESTATUS(
                $event->[ NDO_DATA_CUSTOMVARIABLE() ],
                $object_id, $event->[ NDO_DATA_TIMESTAMP() ]
            );
        }
    }

    return 1;
}

sub handle_MULTI_GROUP_MEMBERS {

    my $sth_insert = $DB->prepare_cached(
        q[
            INSERT INTO nagios_] . $_[ ARG_PARENT() ] . q[group_members SET
                ] . $_[ ARG_PARENT() ] . q[group_id = ?,
                ] . $_[ ARG_PARENT() ] . q[_object_id = ?,
                instance_id=1
        ]
    );

    for my $var ( @{ $_[ ARG_MEMBERS() ] } ) {

        next unless length $var;

        my $member_id =
          get_object_id_with_insert( $_[ ARG_GROUP_TYPE() ], $var );

        $sth_insert->execute( $_[ ARG_OBJECT_ID() ], $member_id );
    }
}

sub handle_MULTI_CONTACT {

    my $sth_insert = $DB->prepare_cached(
        q[
            INSERT INTO nagios_] . $_[ ARG_PARENT() ] . q[_contacts SET
                ,] . $_[ ARG_PARENT() ] . q[_id = ?
                ,contact_object_id = ?
                ,instance_id=1
        ]
    );

    for my $var ( @{ $_[ ARG_CONTACTS() ] } ) {

        next unless length $var;

        my $member_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_CONTACT(), $var );

        $sth_insert->execute( $_[ ARG_OBJECT_ID3() ], $member_id );
    }
}

sub handle_MULTI_CONTACTGROUP {

    my $sth_insert = $DB->prepare_cached(
        q[
            INSERT INTO nagios_] . $_[ ARG_PARENT() ] . q[_contactgroups SET
                ] . $_[ ARG_PARENT() ] . q[_id = ?,
                contactgroup_object_id = ?,
                instance_id=1
        ]
    );

    for my $var ( @{ $_[ ARG_CONTACTGROUPS() ] } ) {

        next unless length $var;

        my $member_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_CONTACTGROUP(), $var );

        $sth_insert->execute( $_[ ARG_OBJECT_ID3() ], $member_id );
    }
}

our $sth_insert_handle_MULTI_PARENTHOST;

sub handle_MULTI_PARENTHOST {

    $sth_insert_handle_MULTI_PARENTHOST = $DB->prepare_cached(
        q{
            INSERT INTO nagios_host_parenthosts SET
                host_id = ?,
                parent_host_object_id = ?,
                instance_id=1
        }
    ) unless defined $sth_insert_handle_MULTI_PARENTHOST;

    for my $var ( @{ $_[ ARG_PARENTHOSTS() ] } ) {

        next unless length $var;

        my $member_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(), $var );

        $sth_insert_handle_MULTI_PARENTHOST->execute( $_[ ARG_OBJECT_ID2() ],
            $member_id );
    }
}

our $sth_insert_handle_MULTI_TIMERANGE;

sub handle_MULTI_TIMERANGE {

    $sth_insert_handle_MULTI_TIMERANGE = $DB->prepare_cached(
        q{
            INSERT INTO nagios_timeperiod_timeranges SET
                instance_id=1,
                timeperiod_id=?,
                day=?,
                start_sec=?,
                end_sec=?
        }
    ) unless defined $sth_insert_handle_MULTI_TIMERANGE;

    for my $var ( @{ $_[ ARG_TIMERANGES() ] } ) {
        my ( $day, $start, $end ) = $var =~ /(\d+):(\d+)\-(\d+)$/;
        next unless defined $start && defined $end;

        my $rv =
          $sth_insert_handle_MULTI_TIMERANGE->execute( $_[ ARG_OBJECT_ID2() ],
            $day, $start, $end );

        # ignore errors
        next unless $rv;
    }
}

our $sth_insert_handle_MULTI_CUSTOMVARIABLE;
our $sth_update_handle_MULTI_CUSTOMVARIABLE;

sub handle_MULTI_CUSTOMVARIABLE {

    $sth_insert_handle_MULTI_CUSTOMVARIABLE = $DB->prepare_cached(
        q{
            INSERT INTO nagios_customvariables SET
                instance_id=1,
                has_been_modified=?,
                varvalue=?,

                object_id=?,
                config_type=?,
                varname=?
        }
    ) unless defined $sth_insert_handle_MULTI_CUSTOMVARIABLE;

    $sth_update_handle_MULTI_CUSTOMVARIABLE = $DB->prepare_cached(
        q{
            UPDATE nagios_customvariables SET
                has_been_modified=?,
                varvalue=?
            WHERE
                object_id=?
                AND
                config_type=?
                AND
                varname=?
        }
    ) unless defined $sth_update_handle_MULTI_CUSTOMVARIABLE;

    for my $var ( @{ $_[ ARG_CUSTOMVARIABLES() ] } ) {
        my ( $n, $has_been_modified, $v ) = split( /:/, $var, 3 );
        my @data = (
            $has_been_modified, $v || '', $_[ ARG_OBJECT_ID2() ],
            $CURRENT_OBJECT_CONFIG_TYPE, $n || '',
        );
        my $rv = $sth_update_handle_MULTI_CUSTOMVARIABLE->execute(@data);
        die "Update failed: ", $sth_update_handle_MULTI_CUSTOMVARIABLE->errstr,
          "\n"
          unless $rv;
        if ( $rv eq '0E0' ) {
            $sth_insert_handle_MULTI_CUSTOMVARIABLE->execute(@data);
        }
    }
}

our $sth_insert_handle_MULTI_CUSTOMVARIABLESTATUS;
our $sth_update_handle_MULTI_CUSTOMVARIABLESTATUS;

sub handle_MULTI_CUSTOMVARIABLESTATUS {

    $sth_insert_handle_MULTI_CUSTOMVARIABLESTATUS = $DB->prepare_cached(
        q{
            INSERT INTO nagios_customvariablestatus SET
                instance_id=1,
                status_update_time=?,
                has_been_modified=?,
                varname=?,
                varvalue=?,
                object_id=?
        }
    ) unless defined $sth_insert_handle_MULTI_CUSTOMVARIABLESTATUS;

    $sth_update_handle_MULTI_CUSTOMVARIABLESTATUS = $DB->prepare_cached(
        q{
            UPDATE nagios_customvariablestatus SET
                instance_id=1,
                status_update_time=?,
                has_been_modified=?,
                varname=?,
                varvalue=?
            WHERE
                object_id=?
        }
    ) unless defined $sth_update_handle_MULTI_CUSTOMVARIABLESTATUS;

    for my $var ( @{ $_[ ARG_CUSTOMVARIABLES() ] } ) {
        my ( $n, $has_been_modified, $v ) = split( /:/, $var, 3 );
        my @data = (
            $_[ ARG_UPDATE_TIME() ],
            $has_been_modified, $n || '', $v || '', $_[ ARG_OBJECT_ID2() ]
        );
        my $rv = $sth_update_handle_MULTI_CUSTOMVARIABLESTATUS->execute(@data);
        die "Update failed: ",
          $sth_update_handle_MULTI_CUSTOMVARIABLESTATUS->errstr, "\n"
          unless $rv;
        if ( $rv eq '0E0' ) {
            $sth_insert_handle_MULTI_CUSTOMVARIABLESTATUS->execute(@data);
        }
    }
}

our $sth_update_handle_CONTACTSTATUSDATA;
our $sth_insert_handle_CONTACTSTATUSDATA;

sub handle_CONTACTSTATUSDATA {

    $sth_update_handle_CONTACTSTATUSDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_contactstatus SET

    instance_id=1,
    status_update_time=FROM_UNIXTIME(?),
    host_notifications_enabled=?,
    service_notifications_enabled=?,
    last_host_notification=FROM_UNIXTIME(?),
    last_service_notification=FROM_UNIXTIME(?),
    modified_attributes=?,
    modified_host_attributes=?,
    modified_service_attributes=?

            WHERE
                contact_object_id=?
        }
    ) unless defined $sth_update_handle_CONTACTSTATUSDATA;

    $sth_insert_handle_CONTACTSTATUSDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_contactstatus SET

    instance_id=1,
    status_update_time=FROM_UNIXTIME(?),
    host_notifications_enabled=?,
    service_notifications_enabled=?,
    last_host_notification=FROM_UNIXTIME(?),
    last_service_notification=FROM_UNIXTIME(?),
    modified_attributes=?,
    modified_host_attributes=?,
    modified_service_attributes=?

                ,contact_object_id=?
        }
    ) unless defined $sth_insert_handle_CONTACTSTATUSDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_CONTACT(),
            $event->[ NDO_DATA_CONTACTNAME() ]
        );

        my $last_host_notification_time =
          int( $event->[ NDO_DATA_LASTHOSTNOTIFICATION() ] );
        my $last_service_notification_time =
          int( $event->[ NDO_DATA_LASTSERVICENOTIFICATION() ] );

        my @data = (
            $state_time,
            @$event[
              NDO_DATA_HOSTNOTIFICATIONSENABLED(),
            NDO_DATA_SERVICENOTIFICATIONSENABLED(),
            ],
            $last_host_notification_time,
            $last_service_notification_time,
            @$event[
              NDO_DATA_MODIFIEDCONTACTATTRIBUTES(),
            NDO_DATA_MODIFIEDHOSTATTRIBUTES(),
            NDO_DATA_MODIFIEDSERVICEATTRIBUTES(),
            ],

            $object_id,
        );
        my $rv = $sth_update_handle_CONTACTSTATUSDATA->execute(@data);
        die "Update failed: ", $sth_update_handle_CONTACTSTATUSDATA->errstr,
          "\n"
          unless $rv;

        if ( $rv eq '0E0' ) {
            $sth_insert_handle_CONTACTSTATUSDATA->execute(@data);
        }

        if ( defined $event->[ NDO_DATA_CUSTOMVARIABLE() ] ) {
            handle_MULTI_CUSTOMVARIABLESTATUS(
                $event->[ NDO_DATA_CUSTOMVARIABLE() ],
                $object_id, $event->[ NDO_DATA_TIMESTAMP() ]
            );
        }
    }

    return 1;
}

sub handle_RETENTIONDATA {

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my $type = $event->[ NDO_DATA_TYPE() ];

        if ( $type == NEBTYPE_RETENTIONDATA_STARTLOAD() ) {
            $LOADING_RETENTION_DATA_FLAG = 1;
        }
        elsif ( $type == NEBTYPE_RETENTIONDATA_ENDLOAD() ) {
            $LOADING_RETENTION_DATA_FLAG = 0;
        }
    }

    return 1;
}

our $sth_insert_handle_ACKNOWLEDGEMENTDATA;

sub handle_ACKNOWLEDGEMENTDATA {

    $sth_insert_handle_ACKNOWLEDGEMENTDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_acknowledgements SET

    instance_id=1,
    entry_time=FROM_UNIXTIME(?),
    entry_time_usec=?,
    acknowledgement_type=?,
    object_id=?,
    state=?,
    author_name=?,
    comment_data=?,
    is_sticky=?,
    persistent_comment=?,
    notify_contacts=?

        }
    ) unless defined $sth_insert_handle_ACKNOWLEDGEMENTDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        my $acknowledgement_type = $event->[ NDO_DATA_ACKNOWLEDGEMENTTYPE() ];

        my $object_id = 0;

        if ( $acknowledgement_type == SERVICE_ACKNOWLEDGEMENT() ) {
            $object_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_SERVICE(),
                $event->[ NDO_DATA_HOST() ],
                $event->[ NDO_DATA_SERVICE() ]
            );
        }
        elsif ( $acknowledgement_type == HOST_ACKNOWLEDGEMENT() ) {
            $object_id =
              get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
                $event->[ NDO_DATA_HOST() ]
              );
        }

        my @data = (
            $state_time,
            $state_time_usec,
            $acknowledgement_type,
            $object_id,
            @$event[
              NDO_DATA_STATE(), NDO_DATA_AUTHORNAME(),
            NDO_DATA_COMMENT(),    NDO_DATA_STICKY(),
            NDO_DATA_PERSISTENT(), NDO_DATA_NOTIFYCONTACTS()
            ]
        );

        my $rv = $sth_insert_handle_ACKNOWLEDGEMENTDATA->execute(@data);
        die "Insert failed: ", $sth_insert_handle_ACKNOWLEDGEMENTDATA->errstr,
          "\n"
          unless $rv;

    }

    return 1;
}

our $sth_insert_handle_STATECHANGEDATA;
our $sth_select_downtimehist_handle_STATECHANGEDATA;
our $sth_update_downtimehist_handle_STATECHANGEDATA;

sub handle_STATECHANGEDATA {

    $sth_insert_handle_STATECHANGEDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_statehistory SET

    instance_id=1,
    state_time=FROM_UNIXTIME(?),
    state_time_usec=?,
    object_id=?,
    state_change=?,
    state=?,
    state_type=?,
    current_check_attempt=?,
    max_check_attempts=?,
    last_state=?,
    last_hard_state=?,
    output=?,
    scheduled_downtime_depth=?,
    downtimehistory_id=?,
    problem_has_been_acknowledged=?,
    eventtype=?,
    host_state=?,
    host_state_type=?

        }
    ) unless defined $sth_insert_handle_STATECHANGEDATA;

    $sth_select_downtimehist_handle_STATECHANGEDATA = $DB->prepare_cached(
        q{
            SELECT downtimehistory_id, was_logged
            FROM nagios_downtimehistory
            WHERE
                internal_downtime_id = ?
            ORDER BY downtimehistory_id DESC
            LIMIT 1
        }
    ) unless defined $sth_select_downtimehist_handle_STATECHANGEDATA;

    $sth_update_downtimehist_handle_STATECHANGEDATA = $DB->prepare_cached(
        q{
            UPDATE nagios_downtimehistory
            SET was_logged = 1
            WHERE
                downtimehistory_id = ?
        }
    ) unless defined $sth_update_downtimehist_handle_STATECHANGEDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        next if $event->[ NDO_DATA_TYPE() ] != NEBTYPE_STATECHANGE_END();

        my $eventtype   = $event->[ NDO_DATA_EVENTTYPE() ];
        my $downtime_id = $event->[ NDO_DATA_DOWNTIMEID() ];
        my $downtimehistory_id;
        my $was_logged = 0;

        if ( $downtime_id > 0 ) {
            $downtimehistory_id = 0;

            $sth_select_downtimehist_handle_STATECHANGEDATA->execute(
                $downtime_id);
            if ( my $row =
                $sth_select_downtimehist_handle_STATECHANGEDATA
                ->fetchrow_arrayref )
            {
                $downtimehistory_id = $row->[0];
                $was_logged         = $row->[1];
            }

            if (   $eventtype == NEBATTR_EVENTTYPE_DOWNTIME_STOP()
                && $was_logged == 0
                && $downtimehistory_id > 0 )
            {
                $sth_update_downtimehist_handle_STATECHANGEDATA->execute(
                    $downtimehistory_id);
            }
        }

        if (   $eventtype == NEBATTR_EVENTTYPE_DOWNTIME_STOP()
            && $was_logged == 1 )
        {
            next;
        }

        my $object_id;

        if ( $event->[ NDO_DATA_STATECHANGETYPE() ] == SERVICE_STATECHANGE() ) {
            $object_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_SERVICE(),
                $event->[ NDO_DATA_HOST() ],
                $event->[ NDO_DATA_SERVICE() ]
            );
        }
        else {
            $object_id =
              get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
                $event->[ NDO_DATA_HOST() ]
              );
        }

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        my @data = (
            $state_time,
            $state_time_usec,
            $object_id,

            @$event[
              NDO_DATA_STATECHANGE(),
            NDO_DATA_STATE(),
            NDO_DATA_STATETYPE(),
            NDO_DATA_CURRENTCHECKATTEMPT(),
            NDO_DATA_MAXCHECKATTEMPTS(),
            NDO_DATA_LASTSTATE(),
            NDO_DATA_LASTHARDSTATE(),
            NDO_DATA_OUTPUT(),
            NDO_DATA_SCHEDULEDDOWNTIMEDEPTH(),

            ],
            $downtimehistory_id,
            $event->[ NDO_DATA_PROBLEMHASBEENACKNOWLEDGED() ],
            $eventtype,
            @$event[ NDO_DATA_HOSTSTATE(), NDO_DATA_HOSTSTATETYPE(), ]
        );

        my $rv = $sth_insert_handle_STATECHANGEDATA->execute(@data);
        die "Insert failed: ", $sth_insert_handle_STATECHANGEDATA->errstr, "\n"
          unless $rv;

    }

    return 1;
}

sub handle_CONFIGDUMPSTART {

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {
        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        my $is_current = $state_time >= $LATEST_REALTIME_DATA_TIME;

        $DB->begin_work if $DB->{AutoCommit};

        if ($is_current) {

            my @tables = qw(
              nagios_programstatus
              nagios_contactstatus
              nagios_timedeventqueue
              nagios_comments
              nagios_runtimevariables
              nagios_customvariablestatus
              nagios_configfiles
              nagios_configfilevariables
              nagios_customvariables
              nagios_commands
              nagios_timeperiods
              nagios_timeperiod_timeranges
              nagios_contactgroups
              nagios_contactgroup_members
              nagios_hostgroups
              nagios_hostgroup_members
              nagios_servicegroups
              nagios_servicegroup_members
              nagios_hostescalations
              nagios_hostescalation_contacts
              nagios_serviceescalations
              nagios_serviceescalation_contacts
              nagios_hostdependencies
              nagios_servicedependencies
              nagios_contacts
              nagios_contact_addresses
              nagios_contact_notificationcommands
              nagios_hosts
              nagios_host_parenthosts
              nagios_host_contacts
              nagios_services
              nagios_service_contacts
              nagios_service_contactgroups
              nagios_host_contactgroups
              nagios_hostescalation_contactgroups
              nagios_serviceescalation_contactgroups
            );

            db_clear_table($_) for @tables;

            set_all_objects_as_inactive();
        }
    }

    return 1;
}

sub handle_CONFIGDUMPEND {

    $DB->commit unless $DB->{AutoCommit};

    my $file = sprintf( "/usr/local/nagios/var/ndoconfigend/%d", time() );
    system( "touch $file" );

    return 1;
}

our $sth_insert_handle_PROCESSDATA;
our $sth_update_endtime_handle_PROCESSDATA;

sub handle_PROCESSDATA {

    $sth_insert_handle_PROCESSDATA = $DB->prepare_cached(
        q{
            INSERT INTO nagios_processevents SET

    instance_id=1,
    event_type=?,
    event_time=FROM_UNIXTIME(?),
    event_time_usec=?,
    process_id=?,
    program_name=?,
    program_version=?,
    program_date=?


        }
    ) unless defined $sth_insert_handle_PROCESSDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );
        my $type = $event->[ NDO_DATA_TYPE() ];

        my @data = (
            $type,
            $state_time,
            $state_time_usec,

            @$event[
              NDO_DATA_PROCESSID(), NDO_DATA_PROGRAMNAME(),
            NDO_DATA_PROGRAMVERSION(), NDO_DATA_PROGRAMDATE(),
            ]
        );

        my $rv = $sth_insert_handle_PROCESSDATA->execute(@data);
        die "Insert failed: ", $sth_insert_handle_PROCESSDATA->errstr, "\n"
          unless $rv;

        my $is_current = $state_time >= $LATEST_REALTIME_DATA_TIME;

        if (
            (
                   $type == NEBTYPE_PROCESS_SHUTDOWN()
                || $type == NEBTYPE_PROCESS_RESTART()
            )
            && $is_current
          )
        {

            $sth_update_endtime_handle_PROCESSDATA = $DB->prepare_cached(
                q{
                    UPDATE nagios_programstatus SET
                        program_end_time=UNIX_TIMESTAMP(?),
                        is_currently_running='0'
                    WHERE
                        instance_id=1
                }
            ) unless defined $sth_update_endtime_handle_PROCESSDATA;

            $sth_update_endtime_handle_PROCESSDATA->execute();
        }
    }

    return 1;
}

our $sth_update_handle_HOSTDEFINITION;
our $sth_insert_handle_HOSTDEFINITION;
our $sth_fetch_ID_handle_HOSTDEFINITION;

sub handle_HOSTDEFINITION {

    $sth_fetch_ID_handle_HOSTDEFINITION = $DB->prepare_cached(
        qq[
            SELECT host_id
            FROM nagios_hosts
            WHERE
                host_object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        ]
    ) unless defined $sth_fetch_ID_handle_HOSTDEFINITION;

    $sth_update_handle_HOSTDEFINITION = $DB->prepare_cached(
        q{
            UPDATE nagios_hosts SET

    alias=?,
    display_name=?,
    address=?,
    check_command_object_id=?,
    check_command_args=?,
    eventhandler_command_object_id=?,
    eventhandler_command_args=?,
    check_timeperiod_object_id=?,
    notification_timeperiod_object_id=?,
    failure_prediction_options=?,
    check_interval=?,
    retry_interval=?,
    max_check_attempts=?,
    first_notification_delay=?,
    notification_interval=?,
    notify_on_down=?,
    notify_on_unreachable=?,
    notify_on_recovery=?,
    notify_on_flapping=?,
    notify_on_downtime=?,
    stalk_on_up=?,
    stalk_on_down=?,
    stalk_on_unreachable=?,
    flap_detection_enabled=?,
    flap_detection_on_up=?,
    flap_detection_on_down=?,
    flap_detection_on_unreachable=?,
    low_flap_threshold=?,
    high_flap_threshold=?,
    process_performance_data=?,
    freshness_checks_enabled=?,
    freshness_threshold=?,
    passive_checks_enabled=?,
    event_handler_enabled=?,
    active_checks_enabled=?,
    retain_status_information=?,
    retain_nonstatus_information=?,
    notifications_enabled=?,
    obsess_over_host=?,
    failure_prediction_enabled=0,
    notes=?,
    notes_url=?,
    action_url=?,
    icon_image=?,
    icon_image_alt=?,
    vrml_image=?,
    statusmap_image=?,
    have_2d_coords=?,
    x_2d=?,
    y_2d=?,
    have_3d_coords=?,
    x_3d=?,
    y_3d=?,
    z_3d=?


            WHERE
                host_object_id = ?
                AND
                config_type = ?
                AND
                instance_id = 1
        }
    ) unless defined $sth_update_handle_HOSTDEFINITION;

    $sth_insert_handle_HOSTDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_hosts SET


    alias=?,
    display_name=?,
    address=?,
    check_command_object_id=?,
    check_command_args=?,
    eventhandler_command_object_id=?,
    eventhandler_command_args=?,
    check_timeperiod_object_id=?,
    notification_timeperiod_object_id=?,
    failure_prediction_options=?,
    check_interval=?,
    retry_interval=?,
    max_check_attempts=?,
    first_notification_delay=?,
    notification_interval=?,
    notify_on_down=?,
    notify_on_unreachable=?,
    notify_on_recovery=?,
    notify_on_flapping=?,
    notify_on_downtime=?,
    stalk_on_up=?,
    stalk_on_down=?,
    stalk_on_unreachable=?,
    flap_detection_enabled=?,
    flap_detection_on_up=?,
    flap_detection_on_down=?,
    flap_detection_on_unreachable=?,
    low_flap_threshold=?,
    high_flap_threshold=?,
    process_performance_data=?,
    freshness_checks_enabled=?,
    freshness_threshold=?,
    passive_checks_enabled=?,
    event_handler_enabled=?,
    active_checks_enabled=?,
    retain_status_information=?,
    retain_nonstatus_information=?,
    notifications_enabled=?,
    obsess_over_host=?,
    failure_prediction_enabled=0,
    notes=?,
    notes_url=?,
    action_url=?,
    icon_image=?,
    icon_image_alt=?,
    vrml_image=?,
    statusmap_image=?,
    have_2d_coords=?,
    x_2d=?,
    y_2d=?,
    have_3d_coords=?,
    x_3d=?,
    y_3d=?,
    z_3d=?


                ,host_object_id=?
                ,config_type=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_HOSTDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $host_id;

        my ( $command, $check_command_args ) =
          split( /!/, $event->[ NDO_DATA_HOSTCHECKCOMMAND() ], 2 );
        my $check_command_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_COMMAND(), $command );

        my ( $eventhandler_command, $eventhandler_command_args ) =
          split( /!/, $event->[ NDO_DATA_HOSTEVENTHANDLER() ], 2 );
        my $eventhandler_command_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_COMMAND(),
            $eventhandler_command );

        my $object_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
            $event->[ NDO_DATA_HOSTNAME() ]
          );

        set_object_as_active( NDO2DB_OBJECTTYPE_HOST(), $object_id );

        my $check_timeperiod_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_HOSTCHECKPERIOD() ]
        );

        my $notification_timeperiod_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_HOSTNOTIFICATIONPERIOD() ]
        );

        my @data = (
            $event->[ NDO_DATA_HOSTALIAS() ]   || '',
            $event->[ NDO_DATA_DISPLAYNAME() ] || '',
            $event->[ NDO_DATA_HOSTADDRESS() ] || '',
            $check_command_id,
            $check_command_args || '',
            $eventhandler_command_id,
            $eventhandler_command_args || '',
            $check_timeperiod_id,
            $notification_timeperiod_id,
            @$event[
              NDO_DATA_HOSTFAILUREPREDICTIONOPTIONS(),
            NDO_DATA_HOSTCHECKINTERVAL(),
            NDO_DATA_HOSTRETRYINTERVAL(),
            NDO_DATA_HOSTMAXCHECKATTEMPTS(),
            NDO_DATA_FIRSTNOTIFICATIONDELAY(),
            NDO_DATA_HOSTNOTIFICATIONINTERVAL(),
            NDO_DATA_NOTIFYHOSTDOWN(),
            NDO_DATA_NOTIFYHOSTUNREACHABLE(),
            NDO_DATA_NOTIFYHOSTRECOVERY(),
            NDO_DATA_NOTIFYHOSTFLAPPING(),
            NDO_DATA_NOTIFYHOSTDOWNTIME(),
            NDO_DATA_STALKHOSTONUP(),
            NDO_DATA_STALKHOSTONDOWN(),
            NDO_DATA_STALKHOSTONUNREACHABLE(),
            NDO_DATA_HOSTFLAPDETECTIONENABLED(),
            NDO_DATA_FLAPDETECTIONONUP(),
            NDO_DATA_FLAPDETECTIONONDOWN(),
            NDO_DATA_FLAPDETECTIONONUNREACHABLE(),
            NDO_DATA_LOWHOSTFLAPTHRESHOLD(),
            NDO_DATA_HIGHHOSTFLAPTHRESHOLD(),
            NDO_DATA_PROCESSHOSTPERFORMANCEDATA(),
            NDO_DATA_HOSTFRESHNESSCHECKSENABLED(),
            NDO_DATA_HOSTFRESHNESSTHRESHOLD(),
            NDO_DATA_PASSIVEHOSTCHECKSENABLED(),
            NDO_DATA_HOSTEVENTHANDLERENABLED(),
            NDO_DATA_ACTIVEHOSTCHECKSENABLED(),
            NDO_DATA_RETAINHOSTSTATUSINFORMATION(),
            NDO_DATA_RETAINHOSTNONSTATUSINFORMATION(),
            NDO_DATA_HOSTNOTIFICATIONSENABLED(),
            NDO_DATA_OBSESSOVERHOST(),
            ],
            $event->[ NDO_DATA_NOTES() ]          || '',
            $event->[ NDO_DATA_NOTESURL() ]       || '',
            $event->[ NDO_DATA_ACTIONURL() ]      || '',
            $event->[ NDO_DATA_ICONIMAGE() ]      || '',
            $event->[ NDO_DATA_ICONIMAGEALT() ]   || '',
            $event->[ NDO_DATA_VRMLIMAGE() ]      || '',
            $event->[ NDO_DATA_STATUSMAPIMAGE() ] || '',

            # XXX first Y3D should really be Y2D
            @$event[
              NDO_DATA_HAVE2DCOORDS(), NDO_DATA_X2D(),
            NDO_DATA_Y3D(), NDO_DATA_HAVE3DCOORDS(),
            NDO_DATA_X3D(), NDO_DATA_Y3D(),
            NDO_DATA_Z3D(),
            ],

            $object_id,
            $CURRENT_OBJECT_CONFIG_TYPE,
        );

        my $rv = $sth_insert_handle_HOSTDEFINITION->execute(@data);

        unless ($rv) {
            $sth_update_handle_HOSTDEFINITION->execute(@data);

            # get primary key for existing entry
            $sth_fetch_ID_handle_HOSTDEFINITION->execute( $object_id,
                $CURRENT_OBJECT_CONFIG_TYPE, );

            ($host_id) = $sth_fetch_ID_handle_HOSTDEFINITION->fetchrow_array();
            $sth_fetch_ID_handle_HOSTDEFINITION->finish();

        }
        else {
            $host_id = $sth_insert_handle_HOSTDEFINITION->{mysql_insertid};
        }

        if ( defined $event->[ NDO_DATA_CUSTOMVARIABLE() ] ) {
            handle_MULTI_CUSTOMVARIABLE( $event->[ NDO_DATA_CUSTOMVARIABLE() ],
                $object_id );
        }

        next unless $host_id;

        if ( defined $event->[ NDO_DATA_PARENTHOST() ] ) {
            handle_MULTI_PARENTHOST( $event->[ NDO_DATA_PARENTHOST() ],
                $host_id );
        }

        if ( defined $event->[ NDO_DATA_CONTACTGROUP() ] ) {
            handle_MULTI_CONTACTGROUP( 'host',
                $event->[ NDO_DATA_CONTACTGROUP() ], $host_id );
        }

        if ( defined $event->[ NDO_DATA_CONTACT() ] ) {
            handle_MULTI_CONTACT( 'host', $event->[ NDO_DATA_CONTACT() ],
                $host_id );
        }

    }

    return 1;
}

our $sth_update_handle_SERVICEDEFINITION;
our $sth_insert_handle_SERVICEDEFINITION;
our $sth_fetch_ID_handle_SERVICEDEFINITION;

sub handle_SERVICEDEFINITION {

    $sth_fetch_ID_handle_SERVICEDEFINITION = $DB->prepare_cached(
        qq[
            SELECT service_id
            FROM nagios_services
            WHERE
                service_object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        ]
    ) unless defined $sth_fetch_ID_handle_SERVICEDEFINITION;

    $sth_update_handle_SERVICEDEFINITION = $DB->prepare_cached(
        q{
            UPDATE nagios_services SET


    host_object_id=?,
    display_name=?,
    check_command_object_id=?,
    check_command_args=?,
    eventhandler_command_object_id=?,
    eventhandler_command_args=?,
    check_timeperiod_object_id=?,
    notification_timeperiod_object_id=?,
    failure_prediction_options=?,
    check_interval=?,
    retry_interval=?,
    max_check_attempts=?,
    first_notification_delay=?,
    notification_interval=?,
    notify_on_warning=?,
    notify_on_unknown=?,
    notify_on_critical=?,
    notify_on_recovery=?,
    notify_on_flapping=?,
    notify_on_downtime=?,
    stalk_on_ok=?,
    stalk_on_warning=?,
    stalk_on_unknown=?,
    stalk_on_critical=?,
    is_volatile=?,
    flap_detection_enabled=?,
    flap_detection_on_ok=?,
    flap_detection_on_warning=?,
    flap_detection_on_unknown=?,
    flap_detection_on_critical=?,
    low_flap_threshold=?,
    high_flap_threshold=?,
    process_performance_data=?,
    freshness_checks_enabled=?,
    freshness_threshold=?,
    passive_checks_enabled=?,
    event_handler_enabled=?,
    active_checks_enabled=?,
    retain_status_information=?,
    retain_nonstatus_information=?,
    notifications_enabled=?,
    obsess_over_service=?,
    failure_prediction_enabled=0,
    notes=?,
    notes_url=?,
    action_url=?,
    icon_image=?,
    icon_image_alt=?


            WHERE
                service_object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        }
    ) unless defined $sth_update_handle_SERVICEDEFINITION;

    $sth_insert_handle_SERVICEDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_services SET


    host_object_id=?,
    display_name=?,
    check_command_object_id=?,
    check_command_args=?,
    eventhandler_command_object_id=?,
    eventhandler_command_args=?,
    check_timeperiod_object_id=?,
    notification_timeperiod_object_id=?,
    failure_prediction_options=?,
    check_interval=?,
    retry_interval=?,
    max_check_attempts=?,
    first_notification_delay=?,
    notification_interval=?,
    notify_on_warning=?,
    notify_on_unknown=?,
    notify_on_critical=?,
    notify_on_recovery=?,
    notify_on_flapping=?,
    notify_on_downtime=?,
    stalk_on_ok=?,
    stalk_on_warning=?,
    stalk_on_unknown=?,
    stalk_on_critical=?,
    is_volatile=?,
    flap_detection_enabled=?,
    flap_detection_on_ok=?,
    flap_detection_on_warning=?,
    flap_detection_on_unknown=?,
    flap_detection_on_critical=?,
    low_flap_threshold=?,
    high_flap_threshold=?,
    process_performance_data=?,
    freshness_checks_enabled=?,
    freshness_threshold=?,
    passive_checks_enabled=?,
    event_handler_enabled=?,
    active_checks_enabled=?,
    retain_status_information=?,
    retain_nonstatus_information=?,
    notifications_enabled=?,
    obsess_over_service=?,
    failure_prediction_enabled=0,
    notes=?,
    notes_url=?,
    action_url=?,
    icon_image=?,
    icon_image_alt=?


                ,service_object_id=?
                ,config_type=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_SERVICEDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my ( $command, $check_command_args ) =
          split( /!/, $event->[ NDO_DATA_SERVICECHECKCOMMAND() ], 2 );
        my $check_command_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_COMMAND(), $command );

        my ( $eventhandler_command, $eventhandler_command_args ) =
          split( /!/, $event->[ NDO_DATA_SERVICEEVENTHANDLER() ], 2 );
        my $eventhandler_command_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_COMMAND(),
            $eventhandler_command );

        my $service_id = 0;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_SERVICE(),
            $event->[ NDO_DATA_HOSTNAME() ],
            $event->[ NDO_DATA_SERVICEDESCRIPTION() ]
        );

        my $host_id =
          get_object_id_with_insert( NDO2DB_OBJECTTYPE_HOST(),
            $event->[ NDO_DATA_HOSTNAME() ]
          );

        set_object_as_active( NDO2DB_OBJECTTYPE_SERVICE(), $object_id );

        my $check_timeperiod_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_SERVICECHECKPERIOD() ]
        );

        my $notification_timeperiod_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_SERVICENOTIFICATIONPERIOD() ]
        );

        my @data = (
            $host_id,
            $event->[ NDO_DATA_DISPLAYNAME() ] || '',
            $check_command_id,
            $check_command_args || '',
            $eventhandler_command_id,
            $eventhandler_command_args || '',
            $check_timeperiod_id,
            $notification_timeperiod_id,
            @$event[
              NDO_DATA_SERVICEFAILUREPREDICTIONOPTIONS(),
            NDO_DATA_SERVICECHECKINTERVAL(),
            NDO_DATA_SERVICERETRYINTERVAL(),
            NDO_DATA_MAXSERVICECHECKATTEMPTS(),
            NDO_DATA_FIRSTNOTIFICATIONDELAY(),
            NDO_DATA_SERVICENOTIFICATIONINTERVAL(),
            NDO_DATA_NOTIFYSERVICEWARNING(),
            NDO_DATA_NOTIFYSERVICEUNKNOWN(),
            NDO_DATA_NOTIFYSERVICECRITICAL(),
            NDO_DATA_NOTIFYSERVICERECOVERY(),
            NDO_DATA_NOTIFYSERVICEFLAPPING(),
            NDO_DATA_NOTIFYSERVICEDOWNTIME(),
            NDO_DATA_STALKSERVICEONOK(),
            NDO_DATA_STALKSERVICEONWARNING(),
            NDO_DATA_STALKSERVICEONUNKNOWN(),
            NDO_DATA_STALKSERVICEONCRITICAL(),
            NDO_DATA_SERVICEISVOLATILE(),
            NDO_DATA_SERVICEFLAPDETECTIONENABLED(),
            NDO_DATA_FLAPDETECTIONONOK(),
            NDO_DATA_FLAPDETECTIONONWARNING(),
            NDO_DATA_FLAPDETECTIONONUNKNOWN(),
            NDO_DATA_FLAPDETECTIONONCRITICAL(),
            NDO_DATA_LOWSERVICEFLAPTHRESHOLD(),
            NDO_DATA_HIGHSERVICEFLAPTHRESHOLD(),
            NDO_DATA_PROCESSSERVICEPERFORMANCEDATA(),
            NDO_DATA_SERVICEFRESHNESSCHECKSENABLED(),
            NDO_DATA_SERVICEFRESHNESSTHRESHOLD(),
            NDO_DATA_PASSIVESERVICECHECKSENABLED(),
            NDO_DATA_SERVICEEVENTHANDLERENABLED(),
            NDO_DATA_ACTIVESERVICECHECKSENABLED(),
            NDO_DATA_RETAINSERVICESTATUSINFORMATION(),
            NDO_DATA_RETAINSERVICENONSTATUSINFORMATION(),
            NDO_DATA_SERVICENOTIFICATIONSENABLED(),
            NDO_DATA_OBSESSOVERSERVICE(),
            ],
            $event->[ NDO_DATA_NOTES() ]        || '',
            $event->[ NDO_DATA_NOTESURL() ]     || '',
            $event->[ NDO_DATA_ACTIONURL() ]    || '',
            $event->[ NDO_DATA_ICONIMAGE() ]    || '',
            $event->[ NDO_DATA_ICONIMAGEALT() ] || '',

            $object_id,
            $CURRENT_OBJECT_CONFIG_TYPE,
        );

        my $rv = $sth_insert_handle_SERVICEDEFINITION->execute(@data);

        unless ($rv) {
            $sth_update_handle_SERVICEDEFINITION->execute(@data);

            # get primary key for existing entry
            $sth_fetch_ID_handle_SERVICEDEFINITION->execute( $object_id,
                $CURRENT_OBJECT_CONFIG_TYPE, );

            ($service_id) =
              $sth_fetch_ID_handle_SERVICEDEFINITION->fetchrow_array();
            $sth_fetch_ID_handle_SERVICEDEFINITION->finish();

        }
        else {
            $service_id =
              $sth_insert_handle_SERVICEDEFINITION->{mysql_insertid};
        }

        if ( defined $event->[ NDO_DATA_CUSTOMVARIABLE() ] ) {
            handle_MULTI_CUSTOMVARIABLE( $event->[ NDO_DATA_CUSTOMVARIABLE() ],
                $object_id );
        }

        next unless $service_id;

        if ( defined $event->[ NDO_DATA_CONTACTGROUP() ] ) {
            handle_MULTI_CONTACTGROUP( 'service',
                $event->[ NDO_DATA_CONTACTGROUP() ], $service_id );
        }

        if ( defined $event->[ NDO_DATA_CONTACT() ] ) {
            handle_MULTI_CONTACT( 'service', $event->[ NDO_DATA_CONTACT() ],
                $service_id );
        }
    }

    return 1;
}

our $sth_update_handle_SERVICEDEPENDENCYDEFINITION;
our $sth_insert_handle_SERVICEDEPENDENCYDEFINITION;

sub handle_SERVICEDEPENDENCYDEFINITION {

    $sth_update_handle_SERVICEDEPENDENCYDEFINITION = $DB->prepare_cached(
        q{
            UPDATE nagios_servicedependencies SET
    timeperiod_object_id=?
            WHERE
                service_object_id=?
                    AND
                config_type = ?
                    AND
                instance_id = 1
                    AND
                dependent_service_object_id=?
                    AND
                dependency_type=?
                    AND
                inherits_parent=?
                    AND
                fail_on_ok=?
                    AND
                fail_on_warning=?
                    AND
                fail_on_unknown=?
                    AND
                fail_on_critical=?
        }
    ) unless defined $sth_update_handle_SERVICEDEPENDENCYDEFINITION;

    $sth_insert_handle_SERVICEDEPENDENCYDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_servicedependencies SET
    timeperiod_object_id=?
                ,service_object_id=?
                ,config_type=?
                ,instance_id=1
                ,dependent_service_object_id=?
                ,dependency_type=?
                ,inherits_parent=?
                ,fail_on_ok=?
                ,fail_on_warning=?
                ,fail_on_unknown=?
                ,fail_on_critical=?
        }
    ) unless defined $sth_insert_handle_SERVICEDEPENDENCYDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_SERVICE(),
            $event->[ NDO_DATA_HOSTNAME() ],
            $event->[ NDO_DATA_SERVICEDESCRIPTION() ]
        );

        my $dependent_object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_SERVICE(),
            $event->[ NDO_DATA_DEPENDENTHOSTNAME() ],
            $event->[ NDO_DATA_DEPENDENTSERVICEDESCRIPTION() ]
        );

        # XXX name1 = '', name2 = NULL
        my $timeperiod_object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_DEPENDENCYPERIOD() ]
        );

        my @data = (
            $timeperiod_object_id,

            $object_id,
            $CURRENT_OBJECT_CONFIG_TYPE,
            $dependent_object_id,
            @$event[
              NDO_DATA_DEPENDENCYTYPE(), NDO_DATA_INHERITSPARENT(),
            NDO_DATA_FAILONOK(),      NDO_DATA_FAILONWARNING(),
            NDO_DATA_FAILONUNKNOWN(), NDO_DATA_FAILONCRITICAL(),
            ]
        );

        my $rv = $sth_insert_handle_SERVICEDEPENDENCYDEFINITION->execute(@data);

        unless ($rv) {
            $sth_update_handle_SERVICEDEPENDENCYDEFINITION->execute(@data);
        }
    }

    return 1;
}

our $sth_update_handle_COMMANDDEFINITION;
our $sth_insert_handle_COMMANDDEFINITION;

sub handle_COMMANDDEFINITION {

    $sth_update_handle_COMMANDDEFINITION = $DB->prepare_cached(
        q{
            UPDATE nagios_commands SET
    command_line=?
            WHERE
                object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        }
    ) unless defined $sth_update_handle_COMMANDDEFINITION;

    $sth_insert_handle_COMMANDDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_commands SET
    command_line=?
                ,object_id=?
                ,config_type=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_COMMANDDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_COMMAND(),
            $event->[ NDO_DATA_COMMANDNAME() ]
        );

        set_object_as_active( NDO2DB_OBJECTTYPE_COMMAND(), $object_id );

        my @data = (
            @$event[ NDO_DATA_COMMANDLINE(), ],

            $object_id,
            $CURRENT_OBJECT_CONFIG_TYPE,
        );

        my $rv = $sth_insert_handle_COMMANDDEFINITION->execute(@data);

        unless ($rv) {
            $sth_update_handle_COMMANDDEFINITION->execute(@data);
        }
    }

    return 1;
}

our $sth_update_handle_TIMEPERIODDEFINITION;
our $sth_insert_handle_TIMEPERIODDEFINITION;
our $sth_fetch_ID_handle_TIMEPERIODDEFINITION;

sub handle_TIMEPERIODDEFINITION {

    $sth_fetch_ID_handle_TIMEPERIODDEFINITION = $DB->prepare_cached(
        qq[
            SELECT timeperiod_id
            FROM nagios_timeperiods
            WHERE
                timeperiod_object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        ]
    ) unless defined $sth_fetch_ID_handle_TIMEPERIODDEFINITION;

    $sth_update_handle_TIMEPERIODDEFINITION = $DB->prepare_cached(
        q{
            UPDATE nagios_timeperiods SET
    alias=?
            WHERE
                timeperiod_object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        }
    ) unless defined $sth_update_handle_TIMEPERIODDEFINITION;

    $sth_insert_handle_TIMEPERIODDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_timeperiods SET
    alias=?
                ,timeperiod_object_id=?
                ,config_type=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_TIMEPERIODDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $timeperiod_id = 0;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_TIMEPERIODNAME() ]
        );

        set_object_as_active( NDO2DB_OBJECTTYPE_TIMEPERIOD(), $object_id );

        my @data = (
            @$event[ NDO_DATA_TIMEPERIODALIAS(), ],

            $object_id,
            $CURRENT_OBJECT_CONFIG_TYPE,
        );

        my $rv = $sth_insert_handle_TIMEPERIODDEFINITION->execute(@data);

        unless ($rv) {
            $sth_update_handle_TIMEPERIODDEFINITION->execute(@data);

            # get primary key for existing entry
            $sth_fetch_ID_handle_TIMEPERIODDEFINITION->execute( $object_id,
                $CURRENT_OBJECT_CONFIG_TYPE, );

            ($timeperiod_id) =
              $sth_fetch_ID_handle_TIMEPERIODDEFINITION->fetchrow_array();
            $sth_fetch_ID_handle_TIMEPERIODDEFINITION->finish();

        }
        else {
            $timeperiod_id =
              $sth_insert_handle_TIMEPERIODDEFINITION->{mysql_insertid};
        }

        next unless $timeperiod_id;

        if ( defined $event->[ NDO_DATA_TIMERANGE() ] ) {
            handle_MULTI_TIMERANGE( $event->[ NDO_DATA_TIMERANGE() ],
                $timeperiod_id );
        }

    }

    return 1;
}

our $sth_update_handle_CONTACTDEFINITION;
our $sth_insert_handle_CONTACTDEFINITION;

#my $sth_fetch_ID_handle_CONTACTDEFINITION;

sub handle_CONTACTDEFINITION {

    #    $sth_fetch_ID_handle_CONTACTDEFINITION = $DB->prepare_cached(
    #        qq[
    #            SELECT contact_id
    #            FROM nagios_contacts
    #            WHERE
    #                contact_object_id=?
    #                AND
    #                config_type = ?
    #                AND
    #                instance_id = 1
    #        ]
    #    ) unless defined $sth_fetch_ID_handle_CONTACTDEFINITION;

    $sth_update_handle_CONTACTDEFINITION = $DB->prepare_cached(
        q{
            UPDATE nagios_contacts SET

    alias=?,
    email_address=?,
    pager_address=?,
    host_timeperiod_object_id=?,
    service_timeperiod_object_id=?,
    host_notifications_enabled=?,
    service_notifications_enabled=?,
    can_submit_commands=?,
    notify_service_recovery=?,
    notify_service_warning=?,
    notify_service_unknown=?,
    notify_service_critical=?,
    notify_service_flapping=?,
    notify_service_downtime=?,
    notify_host_recovery=?,
    notify_host_down=?,
    notify_host_unreachable=?,
    notify_host_flapping=?,
    notify_host_downtime=?


            WHERE
                contact_object_id=?
                AND
                config_type = ?
                AND
                instance_id = 1
        }
    ) unless defined $sth_update_handle_CONTACTDEFINITION;

    $sth_insert_handle_CONTACTDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_contacts SET


    alias=?,
    email_address=?,
    pager_address=?,
    host_timeperiod_object_id=?,
    service_timeperiod_object_id=?,
    host_notifications_enabled=?,
    service_notifications_enabled=?,
    can_submit_commands=?,
    notify_service_recovery=?,
    notify_service_warning=?,
    notify_service_unknown=?,
    notify_service_critical=?,
    notify_service_flapping=?,
    notify_service_downtime=?,
    notify_host_recovery=?,
    notify_host_down=?,
    notify_host_unreachable=?,
    notify_host_flapping=?,
    notify_host_downtime=?


                ,contact_object_id=?
                ,config_type=?
                ,instance_id=1
        }
    ) unless defined $sth_insert_handle_CONTACTDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $contact_id = 0;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_CONTACT(),
            $event->[ NDO_DATA_CONTACTNAME() ]
        );

        set_object_as_active( NDO2DB_OBJECTTYPE_CONTACT(), $object_id );

        my $host_timeperiod_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_HOSTNOTIFICATIONPERIOD() ]
        );

        my $service_timeperiod_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_TIMEPERIOD(),
            $event->[ NDO_DATA_SERVICENOTIFICATIONPERIOD() ]
        );

        my @data = (
            @$event[
              NDO_DATA_CONTACTALIAS(), NDO_DATA_EMAILADDRESS(),
            NDO_DATA_PAGERADDRESS(),
            ],
            $host_timeperiod_id,
            $service_timeperiod_id,
            @$event[
              NDO_DATA_HOSTNOTIFICATIONSENABLED(),
            NDO_DATA_SERVICENOTIFICATIONSENABLED(),
            NDO_DATA_CANSUBMITCOMMANDS(),
            NDO_DATA_NOTIFYSERVICERECOVERY(),
            NDO_DATA_NOTIFYSERVICEWARNING(),
            NDO_DATA_NOTIFYSERVICEUNKNOWN(),
            NDO_DATA_NOTIFYSERVICECRITICAL(),
            NDO_DATA_NOTIFYSERVICEFLAPPING(),
            NDO_DATA_NOTIFYSERVICEDOWNTIME(),
            NDO_DATA_NOTIFYHOSTRECOVERY(),
            NDO_DATA_NOTIFYHOSTDOWN(),
            NDO_DATA_NOTIFYHOSTUNREACHABLE(),
            NDO_DATA_NOTIFYHOSTFLAPPING(),
            NDO_DATA_NOTIFYHOSTDOWNTIME(),
            ],

            $object_id,
            $CURRENT_OBJECT_CONFIG_TYPE,
        );

        my $rv = $sth_insert_handle_CONTACTDEFINITION->execute(@data);

        unless ($rv) {
            $sth_update_handle_CONTACTDEFINITION->execute(@data);

            # get primary key for existing entry
            #            $sth_fetch_ID_handle_CONTACTDEFINITION->execute(
            #                $object_id,
            #                $CURRENT_OBJECT_CONFIG_TYPE,
            #            );
            #
            #            ($contact_id) = $sth_fetch_ID_handle_CONTACTDEFINITION->fetchrow_array();
            #            $sth_fetch_ID_handle_CONTACTDEFINITION->finish();
            #
            #
            #        } else {
            #            $contact_id =
            #              $sth_insert_handle_CONTACTDEFINITION->{mysql_insertid};
        }

        # ignore NDO_DATA_CONTACTADDRESS
        # ignore host NDO_DATA_CONTACTNOTIFICATIONCOMMANDS
        # ignore service NDO_DATA_CONTACTNOTIFICATIONCOMMANDS

        if ( defined $event->[ NDO_DATA_CUSTOMVARIABLE() ] ) {
            handle_MULTI_CUSTOMVARIABLE( $event->[ NDO_DATA_CUSTOMVARIABLE() ],
                $object_id );
        }

    }

    return 1;
}

our $sth_insert_handle_HOSTGROUPDEFINITION;

sub handle_HOSTGROUPDEFINITION {

    $sth_insert_handle_HOSTGROUPDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_hostgroups SET

    instance_id=1,
    config_type=?,
    hostgroup_object_id=?,
    alias=?
        }
    ) unless defined $sth_insert_handle_HOSTGROUPDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_HOSTGROUP(),
            $event->[ NDO_DATA_HOSTGROUPNAME() ]
        );

        set_object_as_active( NDO2DB_OBJECTTYPE_HOSTGROUP(), $object_id );

        my @data = (
            $CURRENT_OBJECT_CONFIG_TYPE, $object_id,
            $event->[ NDO_DATA_HOSTGROUPALIAS() ]
        );

        my $rv = $sth_insert_handle_HOSTGROUPDEFINITION->execute(@data);

        # ignore errors
        next unless $rv;

        my $group_id = $sth_insert_handle_HOSTGROUPDEFINITION->{mysql_insertid};

        if ( defined $event->[ NDO_DATA_HOSTGROUPMEMBER() ] ) {
            handle_MULTI_GROUP_MEMBERS( 'host', NDO2DB_OBJECTTYPE_HOST(),
                $event->[ NDO_DATA_HOSTGROUPMEMBER() ], $group_id );
        }
    }

    return 1;
}

our $sth_insert_handle_CONTACTGROUPDEFINITION;

sub handle_CONTACTGROUPDEFINITION {

    $sth_insert_handle_CONTACTGROUPDEFINITION = $DB->prepare_cached(
        q{
            INSERT INTO nagios_contactgroups SET

    instance_id=1,
    config_type=?,
    contactgroup_object_id=?,
    alias=?
        }
    ) unless defined $sth_insert_handle_CONTACTGROUPDEFINITION;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ( $state_time, $state_time_usec ) =
          timeval( $event->[ NDO_DATA_TIMESTAMP() ] );

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_CONTACTGROUP(),
            $event->[ NDO_DATA_CONTACTGROUPNAME() ]
        );

        set_object_as_active( NDO2DB_OBJECTTYPE_CONTACTGROUP(), $object_id );

        my @data = (
            $CURRENT_OBJECT_CONFIG_TYPE, $object_id,
            $event->[ NDO_DATA_CONTACTGROUPALIAS() ]
        );

        my $rv = $sth_insert_handle_CONTACTGROUPDEFINITION->execute(@data);

        # ignore errors
        next unless $rv;

        my $group_id =
          $sth_insert_handle_CONTACTGROUPDEFINITION->{mysql_insertid};

        if ( defined $event->[ NDO_DATA_CONTACTGROUPMEMBER() ] ) {
            handle_MULTI_GROUP_MEMBERS(
                'contact',
                NDO2DB_OBJECTTYPE_CONTACT(),
                $event->[ NDO_DATA_CONTACTGROUPMEMBER() ], $group_id
            );
        }
    }

    return 1;
}

our $sth_insert_handle_CONTACTNOTIFICATIONMETHODDATA;
our $sth_update_handle_CONTACTNOTIFICATIONMETHODDATA;

sub handle_CONTACTNOTIFICATIONMETHODDATA {

    $sth_update_handle_CONTACTNOTIFICATIONMETHODDATA = $DB->prepare_cached(
        qq{
            UPDATE nagios_contactnotificationmethods SET
    instance_id=1,
    end_time=FROM_UNIXTIME(?),
    end_time_usec=?,
    command_object_id=?,
    command_args=?
            WHERE
                contactnotification_id=?
                AND
                start_time=FROM_UNIXTIME(?)
                AND
                start_time_usec=?
        }
    ) unless defined $sth_update_handle_CONTACTNOTIFICATIONMETHODDATA;

    $sth_insert_handle_CONTACTNOTIFICATIONMETHODDATA = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_contactnotificationmethods SET
    instance_id=1,
    end_time=FROM_UNIXTIME(?),
    end_time_usec=?,
    command_object_id=?,
    command_args=?
                ,contactnotification_id=?
                ,start_time=FROM_UNIXTIME(?)
                ,start_time_usec=?
        }
    ) unless defined $sth_insert_handle_CONTACTNOTIFICATIONMETHODDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my $command_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_COMMAND(),
            $event->[ NDO_DATA_COMMANDNAME() ]
        );

        my ( $start_time, $start_time_usec ) =
          timeval( $event->[ NDO_DATA_STARTTIME() ] );
        my ( $end_time, $end_time_usec ) =
          timeval( $event->[ NDO_DATA_ENDTIME() ] );

        my @data = (
            $end_time,
            $end_time_usec,

            $command_id,
            $event->[ NDO_DATA_COMMANDARGS() ],

            $LAST_CONTACT_NOTIFICATION_ID,
            $start_time,
            $start_time_usec,
        );

        my $rv =
          $sth_insert_handle_CONTACTNOTIFICATIONMETHODDATA->execute(@data);
        unless ($rv) {
            $sth_update_handle_CONTACTNOTIFICATIONMETHODDATA->execute(@data);
        }
    }

    return 1;
}

our $sth_update_handle_CONTACTNOTIFICATIONDATA;
our $sth_insert_handle_CONTACTNOTIFICATIONDATA;
our $sth_fetch_ID_handle_CONTACTNOTIFICATIONDATA;

sub handle_CONTACTNOTIFICATIONDATA {

    $sth_fetch_ID_handle_CONTACTNOTIFICATIONDATA = $DB->prepare_cached(
        qq[
            SELECT contactnotification_id
            FROM nagios_contactnotifications
            WHERE
                contact_object_id=?
                AND
                start_time=FROM_UNIXTIME(?)
                AND
                start_time_usec=?
        ]
    ) unless defined $sth_fetch_ID_handle_CONTACTNOTIFICATIONDATA;

    $sth_update_handle_CONTACTNOTIFICATIONDATA = $DB->prepare_cached(
        qq{
            UPDATE nagios_contactnotifications SET
    instance_id=1,
    notification_id=?,
    end_time=FROM_UNIXTIME(?),
    end_time_usec=?
            WHERE
                contact_object_id=?
                AND
                start_time=FROM_UNIXTIME(?)
                AND
                start_time_usec=?
        }
    ) unless defined $sth_update_handle_CONTACTNOTIFICATIONDATA;

    $sth_insert_handle_CONTACTNOTIFICATIONDATA = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_contactnotifications SET
    instance_id=1,
    notification_id=?,
    end_time=FROM_UNIXTIME(?),
    end_time_usec=?
                ,contact_object_id=?
                ,start_time=FROM_UNIXTIME(?)
                ,start_time_usec=?
        }
    ) unless defined $sth_insert_handle_CONTACTNOTIFICATIONDATA;

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my $contact_object_id = get_object_id_with_insert(
            NDO2DB_OBJECTTYPE_CONTACT(),
            $event->[ NDO_DATA_CONTACTNAME() ]
        );

        my ( $start_time, $start_time_usec ) =
          timeval( $event->[ NDO_DATA_STARTTIME() ] );
        my ( $end_time, $end_time_usec ) =
          timeval( $event->[ NDO_DATA_ENDTIME() ] );

        my @data = (
            $LAST_NOTIFICATION_ID,

            $end_time,
            $end_time_usec,

            $contact_object_id,
            $start_time,
            $start_time_usec,
        );

        my $rv = $sth_insert_handle_CONTACTNOTIFICATIONDATA->execute(@data);
        if ($rv) {
            if ( $event->[ NDO_DATA_TYPE() ]
                == NEBTYPE_CONTACTNOTIFICATION_START() )
            {
                $LAST_CONTACT_NOTIFICATION_ID =
                  $sth_insert_handle_CONTACTNOTIFICATIONDATA->{mysql_insertid};
            }
        }
        else {
            $sth_update_handle_CONTACTNOTIFICATIONDATA->execute(@data);

            if ( $event->[ NDO_DATA_TYPE() ]
                == NEBTYPE_CONTACTNOTIFICATION_START() )
            {
                # get primary key for existing entry
                $sth_fetch_ID_handle_CONTACTNOTIFICATIONDATA->execute(
                    $contact_object_id,, $start_time, $start_time_usec );

                ($LAST_CONTACT_NOTIFICATION_ID) =
                  $sth_fetch_ID_handle_CONTACTNOTIFICATIONDATA->fetchrow_array(
                  );
                $sth_fetch_ID_handle_CONTACTNOTIFICATIONDATA->finish();
            }
        }
    }

    return 1;
}

sub db_reconnect {

    if ( defined $DB ) {
        for my $sth ( @{ $DB->{ChildHandles} } ) {
            next unless defined $sth;

            $sth->finish;

            # $sth is a tied hash
            $sth->DESTROY;
        }

        $DB->STORE( CachedKids => {} );

        $DB->disconnect;

        undef $DB;
    }

    DB_RECONNECT: while () {
        $DB_CONNECTED = 0;

        return 0 if ${ $_[ ARG_SELF() ]->{break} };

        $LOGGER->warn( "Reconnecting to database" );
        sleep 3;

        eval { $_[ ARG_SELF() ]->db_connect(); };
        if ($@) {
            $LOGGER->fatal( "..reconnecting failed" );
            next DB_RECONNECT;
        }

        reset_cached_statements();

        return 1;
    }

    return 0;
}

sub db_connected {
    return defined $DB && $DB_CONNECTED;
}

sub reset_cached_statements {

    # get package variables
    my %pv = %Opsview::Utils::NDOLogsImporter::;

    no strict 'refs';
    for my $sth ( grep {/^sth_/} keys %pv ) {
        my $v = \${ __PACKAGE__ . "::$sth" };
        next unless defined $$v;
        $$v->finish;
        $$v->DESTROY;
        undef $$v;
    }
}

1;

__END__

sub handle_HOSTESCALATIONDEFINITION {
}

sub handle_SERVICEESCALATIONDEFINITION {
}


sub handle_HOSTDEPENDENCYDEFINITION {
}

sub handle_FLAPPINGDATA {
}


sub handle_EVENTHANDLERDATA {
}

sub handle_HOSTEXTINFODEFINITION {
}

sub handle_SERVICEEXTINFODEFINITION {
}

sub handle_SYSTEMCOMMANDDATA {
}

# ignored handlers
sub handle_LOGENTRY {
}

sub handle_TIMEDEVENTDATA {
}

sub handle_LOGDATA {
}

sub handle_ADAPTIVEPROGRAMDATA {
}

sub handle_ADAPTIVEHOSTDATA {
}

sub handle_ADAPTIVESERVICEDATA {
}

sub handle_ADAPTIVECONTACTDATA {
}

sub handle_MAINCONFIGFILEVARIABLES {
}

sub handle_RESOURCECONFIGFILEVARIABLES {
}

sub handle_CONFIGVARIABLES {
}

sub handle_RUNTIMEVARIABLES {
}

sub handle_AGGREGATEDSTATUSDATA {
}

sub handle_SERVICEGROUPDEFINITION {

    my $columns =<<'EOC';
        instance_id=1,
        config_type=?,
        servicegroup_object_id=?,
        alias=?
EOC

    my $sth_insert = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_servicegroups SET
                $columns
        }
    );

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ($state_time, $state_time_usec) = timeval($event->[ NDO_DATA_TIMESTAMP() ]);

        next if $state_time < $LATEST_REALTIME_DATA_TIME;

        my $object_id = get_object_id_with_insert(
                NDO2DB_OBJECTTYPE_SERVICEGROUP(),
                $event->[ NDO_DATA_SERVICEGROUPNAME() ]
            );

        set_object_as_active( NDO2DB_OBJECTTYPE_SERVICEGROUP(), $object_id );

        my @data = (
            $CURRENT_OBJECT_CONFIG_TYPE,
            $object_id,
            $event->[ NDO_DATA_SERVICEGROUPALIAS() ]
        );


        my $rv = $sth_insert->execute( @data );

        # ignore errors
        next unless $rv;

        my $group_id = $sth_insert->{mysql_insertid};

        if ( defined $event->[ NDO_DATA_SERVICEGROUPMEMBER() ] ) {
            handle_MULTI_GROUP_MEMBERS('service', NDO2DB_OBJECTTYPE_SERVICE(), $event->[ NDO_DATA_SERVICEGROUPMEMBER() ], $group_id);
        }
    }

    return 1;
}

sub handle_EXTERNALCOMMANDDATA {

    my $columns =<<'EOC';
        instance_id=1,
	    command_type='%d',
        entry_time=FROM_UNIXTIME(?),
        command_name='%s',
        command_args='%s'
EOC

    my $sth_insert = $DB->prepare_cached(
        qq{
            INSERT INTO nagios_externalcommands SET
                $columns
        }
    );

    for my $event ( @{ $_[ ARG_EVENTS() ] } ) {

        my ($state_time, $state_time_usec) = timeval($event->[ NDO_DATA_TIMESTAMP() ]);
        my $entry_time = int($event->[ NDO_DATA_ENTRYTIME() ]);

        my @data = (
            $event->[ NDO_DATA_COMMANDTYPE() ],
            $entry_time,
            @$event[
                NDO_DATA_COMMANDSTRING(),
                NDO_DATA_COMMANDARGS(),
            ]
        );
        my $rv = $sth_insert->execute( @data );
        die "Update failed: ", $sth_insert->errstr, "\n" unless $rv;
    }

    return 1;
}




sub ARG_AGE() { 3 }
sub db_trim_table {

    my $sth = $DB->prepare_cached(
        q{ DELETE FROM }. $_[ ARG_TABLE() ] . q{ WHERE instance_id=1
            AND }. $_[ ARG_COLUMN() ] . q{ < FROM_UNIXTIME(?) }
    );

    $sth->execute( $_[ ARG_AGE() ] );
}

sub db_perform_maintenance {

    my $now = time();

    # run once an hour
    return if $now - $_[ ARG_SELF() ]->{last_table_trim_time} < 3600;

    $_[ ARG_SELF() ]->{last_table_trim_time} = $now;

    my %aging_tables = (
        nagios_timedevents => 'scheduled_time',
        nagios_systemcommands => 'start_time',
        nagios_servicechecks => 'start_time',
        nagios_hostchecks => 'start_time',
        nagios_eventhandlers => 'start_time',
        nagios_externalcommands => 'entry_time',
    );

    for my $table ( keys %aging_tables ) {
        my $max_age = $_[ ARG_SELF() ]->{ "max_${$table}_age" };
        next unless $max_age;

        $_[ ARG_SELF() ]->db_trim_table( $table,
            $aging_tables{$table},
            $max_age
        );
    }
}

