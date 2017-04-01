////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Client and server procedures and functions of common purpose:
// - Application interface for administering the cluster of the servers.
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

#Region ApplicationInterfaceParametersConstructors

// Structure designer that describes the connection
//  parameters to the administered cluster of the servers.
//
// Return value: Structure, fields:
//  ConnectionType - String, possible values:
//    "COM" - when connecting to the server agent using the COM object V8*.ComConnector, 
//    "RAS" - when connecting to the administration server (ras)
//     with using console client of the administration server (rac),
//  ServerAgentAddress - String, the network address of the server agent (only when ConnectionType = "COM"), 
//  ServerAgentPort - Number, the network port of the server agent (only when ConnectionType = "COM"),
//    a typical value - 1540,
//  AdministrationServerAddress - String, the network address of the ras administration server (only
//    When ConnectionType = "RAS")
//  AdministrationServerPort - Number, the network port of the ras administration server (only when
//    ConnectionType = "RAS"), a typical value - 1545,
//  ClusterPort - Number, the network port of the administered cluster manager, typical value is 1541,
//  ClusterAdministratorName - String, the account name of the cluster
//    administrator (if the list of administrators is not specified for the cluster) - an empty row is used), 
//  ClusterAdministratorPassword - String, the password of the cluster
//    administrator's account (if the list of administrators is not specified for the cluster or if the password is not set for the account) -
//    an empty row is used),
//
Function ClusterAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("ConnectionType", "COM"); // "COM" or "RAS"
	
	// Only for "COM"
	Result.Insert("ServerAgentAddress", "");
	Result.Insert("ServerAgentPort", 1540);
	
	// Only for "RAS"
	Result.Insert("AdministrationServerAddress", "");
	Result.Insert("AdministrationServerPort", 1545);
	
	Result.Insert("ClusterPort", 1541);
	Result.Insert("ClusterAdministratorName", "");
	Result.Insert("ClusterAdministratorPassword", "");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes the
//  connection parameters to the administered infobase of the cluster.
//
// Return value: Structure, fields:
//  NameInCluster - String, the name of the administered infobase in the servers cluster, 
//  NameAdministratorInfobase - String, the user name of
//    the infobase with administrator rights (if the list of IB users is not specified for the infobase) - an
//    empty row is used), 
//  PasswordAdministratorInfobase - String, the password
//    of the infobase user with administrator rights (if the list of IB users
//    is not specified for the infobase or for the infobase user the password is not set) - an empty row is used).
//
Function ClusterInfobaseAdministrationParameters() Export
	
	Result = New Structure();
	
	Result.Insert("NameInCluster", "");
	Result.Insert("NameAdministratorInfobase", "");
	Result.Insert("PasswordAdministratorInfobase", "");
	
	Return Result;
	
EndFunction

// Verify the correctness of the administration parameters.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster, 
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase, 
//    Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted when similar fields were specified in
//    the structure passed as the
//  ClusterAdministrationParameters, VerifyClusterAdministrationParameters parameter value - Boolean, flag showing the
//                                                necessity
//  to verify the parameters of the cluster administration,
// VerifyInfobaseAdministrationParameters - Boolean, flag showing
//                                                          the necessity to verify the parameters of the cluster administration.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined,
	VerifyClusterAdministrationParameters = True,
	VerifyInfobaseAdministrationParameters = True) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	AdministrationManager.CheckAdministrationParameters(ClusterAdministrationParameters, InfobaseAdministrationParameters, VerifyInfobaseAdministrationParameters, VerifyClusterAdministrationParameters);
	
EndProcedure

#EndRegion

#Region SessionsAndScheduledJobsLocking

// Constructor of the structure that describes the properties
//  of locking the sessions and scheduled jobs of the infobase.
//
// Return value: Structure, fields:
//  SessionsLock - Boolean, the flag of locking the new sessions with the infobase, 
//  DateFrom - Date(Date and time) - start time of locking the new sessions with infobase, 
//  DateTo - Date(Date and time) - the end of locking new sessions with the infobase, 
//  Message - String, the message displayed to the user when
//    an attempt is made to set new session with the infobase with installed blocking of new sessions, 
//  KeyCode - String, the code of the block bypass of the new sessions with the infobase,
//  BlockScheduledJobs - Boolean, the flag of
//    locking the execution of infobase scheduled jobs.
//
Function SessionsAndScheduledJobsLockingProperties() Export
	
	Result = New Structure();
	
	Result.Insert("SessionsLock");
	Result.Insert("DateFrom");
	Result.Insert("DateTo");
	Result.Insert("Message");
	Result.Insert("KeyCode");
	Result.Insert("LockParameter");
	Result.Insert("ScheduledJobsLocking");
	
	Return Result;
	
EndFunction

// Returns the current state of sessions and scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster,
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase,
//    Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted in case if similar fields were specified in
//    the structure passed as the parameter value ClusterAdministrationParameters.
//
// Return value: Structure describing the state of the sessions and scheduled jobs locking, 
//  Description - see ClusterAdministrationClientServer.SessionsAndScheduledJobsBlockProperties().
//
Function InfobaseSessionsAndJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Result = AdministrationManager.InfobaseSessionsAndJobsLocking(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
	Return Result;
	
EndFunction

// Sets new state of the sessions and scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster,
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase, 
//    Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter can be omitted in that case, 
//    if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  SessionsAndJobsLockingProperties - Structure describing the state of the sessions and scheduled jobs locking, 
//    Description - see ClusterAdministrationClientServer.SessionsAndScheduledJobsBlockProperties().
//
Procedure SetInfobaseSessionsAndJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val SessionsAndJobsLockingProperties) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSessionsAndJobsLocking(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		SessionsAndJobsLockingProperties);
	
EndProcedure

// Unlocks the sessions and scheduled jobs for infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster, 
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase,
//    Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter can be omitted in that case, 
//    if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//
Procedure UnlockInfobaseSessionsAndJobs(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	BlockProperties = SessionsAndScheduledJobsLockingProperties();
	BlockProperties.SessionsLock = False;
	BlockProperties.DateFrom = Undefined;
	BlockProperties.DateTo = Undefined;
	BlockProperties.Message = "";
	BlockProperties.KeyCode = "";
	BlockProperties.ScheduledJobsLocking = False;
	
	SetInfobaseSessionsAndJobsLocking(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		BlockProperties);
	
EndProcedure

#EndRegion

#Region ScheduledJobsLocking

// Returns the current state of the scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster, 
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase, 
//    Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted in case if similar fields were specified in
//    the structure passed as the parameter value ClusterAdministrationParameters.
//
// Return value: Boolean.
//
Function InfobaseScheduledJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Result = AdministrationManager.InfobaseScheduledJobsLocking(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
	Return Result;
	
EndFunction

// Sets new state of the scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster, 
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase, 
//    Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter can be omitted in that case, 
//    if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  ScheduledJobsLocking - Boolean, the flag for setting the locking of infobase scheduled jobs.
//
Procedure LockInfobaseSheduledJobs(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val ScheduledJobsLocking) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.LockInfobaseSheduledJobs(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		ScheduledJobsLocking);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Constructor of the structure that describes the properties of the infobase session.
//
// Return value: Structure, fields:
//  Number - Number, session number. Unique among all the infobase sessions,
//  UserName - String, the name of the authenticated infobase user, 
//  ClientComputerName - String, name or network address
//    of the computer that created the session with the infobase,
//  ClientApplicationIdentifier - String, the application identifier that created the session.
//    Possible values - see Description of the global context function ApplicationPresentation(),
//  LanguageIdentifier - String, the identifier of the interface language,
//  SessionCreationTime - Date(Date and time) - setting of the session start, 
//  LastSessionActivityMoment - Date(Date and time) - moment of the last session activity, 
//  Block - Number, the session number that is the
//    reason for the waiting of managed transactional block in that case,
//    if the session executes an installing of managed transactional blocks and waits for removal of blocks established by another session (otherwise - value is 0),
//  BlockDBMS - Number, the number of session that
//    is the reason for the waiting of a transactional block, in that case,
//    if a session executes a request to DBMS and waits a transactional block established by another session (otherwise - value is 0,
//  Passed - Number, the data amount passed between 1C:Enterprise server
//    and the client application of this session since the start of the session (in bytes),
//  PassedFor5Minutes - Number, the data amount passed between 1C:Enterprise
//    server and the client application of this session for the last 5 minutes (in bytes), 
//  ServerCalls - Number, the amount of 1C:Enterprise server calls on behalf
//    of this session since the start of the session, 
//  ServerCallsFor5Minutes - Number, the amount of 1C:Enterprise server calls on
//    behalf of this session for the last 5 minutes,
//  ServerCallsDuration - Number, the execution time of the
//    1C:Enterprise server calls on behalf of this session since the start of the session (in seconds), 
//  CurrentServerCallDuration - Number, the time interval in milliseconds that passed
//    since the beginning of the call, in case the call of the 1C:Enterprise server is executed in the session (else - value is 0),
//  ServerCallsDurationFor5Minutes - Number, execution time of the 1C:Enterprise
//    server calls on behalf of this session for the last 5 minutes (in milliseconds)
//  PassedDBMS - Number, the data amount, sent and received from the DBMS on behalf
//    of this session since the start of the session (in bytes), 
//  DBMSPassedFor5Minutes - Number, the data amount, sent and received from the DBMS on
//    behalf of this session for the last 5 minutes (in bytes),
//  DBMSCallsDuration - Number, the execution time of the queries to DBMS on behalf
//    of this session since the start of the session (in milliseconds),
//  CurrentDBMSCallDuration - Number, the time interval in milliseconds that passed
//    since the start of the query execution, in case if the session executes the query to DBMS (else - value  is 0),
//  DBMSCallsDurationFor5Minutes - Number, the total time of executing queries to the DBMS
//    on behalf of this session for the last 5 minutes (in milliseconds).
//  ConnectionDBMS - String, the connection number with DBMS in terms of DBMS in that case, if
//    at the time of getting sessions list a request to DBMS is executing,
//    a transaction is opened or temporary tables are defined (i.e. the connection with DBMS is captured). If the connection with the DBMS is not captured - value is an empty row,
//  DBMSConnectionTime - Number, time of the connection to the DBMS from the moment of capture (in milliseconds). If the
//    connection with the DBMS is not captured - value is 0, 
//  CaptureDBMSConnectionMoment - Date(Date and time), the moment of time when the connection
//    with DBMS was captured by another session for the last time.
//
Function SessionProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Number");
	Result.Insert("UserName");
	Result.Insert("ClientComputerName");
	Result.Insert("ClientApplicationIdentifier");
	Result.Insert("LanguageIdentifier");
	Result.Insert("SessionCreationTime");
	Result.Insert("LastSessionActivityMoment");
	Result.Insert("Block");
	Result.Insert("DBMSLocking");
	Result.Insert("Transferred");
	Result.Insert("PassedFor5Minutes");
	Result.Insert("ServerCalls");
	Result.Insert("ServerCallsFor5Minutes");
	Result.Insert("ServerCallsDuration");
	Result.Insert("CurrentServerCallDuration");
	Result.Insert("ServerCallsDurationFor5Minutes");
	Result.Insert("PassedDBMS");
	Result.Insert("DBMSPassedIn5Minutes");
	Result.Insert("DBMSCallsDuration");
	Result.Insert("CurrentDBMSCallDuration");
	Result.Insert("DBMSCallsDurationFor5Minutes");
	Result.Insert("ConnectionDBMS");
	Result.Insert("ConnectionTimeDBMS");
	Result.Insert("CaptureDBMSConnectionMoment");
	
	Return Result;
	
EndFunction

// Returns the descriptions of infobase sessions.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster, 
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase,
//    Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter can be omitted in that case,
//    if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  Filter - Description of the session filtering conditions which descriptions must be received.
//    Variants:
//      1. Array of structures that describe conditions of the sessions filtering. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of  the function ClusterAdministrationClientServer.SessionProperties(), 
//        ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          sessions values with the specified in the filter condition. Possible values:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.More (only for numeric values), 
//            ComparisonType.GreaterOrEqual ComparisonType.More (only for numeric values), 
//            ComparisonType.Less (only for numeric values), 
//            ComparisonType.LessOrEqual (only for numeric values),
//            
//            
//            ComparisonType.InList, ComparisonType.NotInList, ComparisonType.Period (only for numeric values), 
//            ComparisonType.PeriodIncludingBorders (only for numeric values), 
//            ComparisonType.IntervalIncludingLowerBound (only for numeric values),
//            ComparisonType.IntervalIncludingUpperBound (only for numeric values), 
//         Value - Number, String, Date, Boolean, ValueList, Array, Structure - value
//          with which the value of corresponding session property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array values that contains
//          the set of values with which the comparison will be done. When ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be
//          passed as the structures with the From and To fields the values of which form
//          the period that will be used for the comparison to be done, 
//    2. Structure (simplified version), key - Name of the session's property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison is always executed on equality.
//
// Return value: Array (Structure), array of structures that describe the sessions properties. Description of structures -
// see ClusterAdministrationClientServer.SessionProperties().
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSessions(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Filter);
	
EndFunction

// Delete sessions with infobase by the filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters  to the server cluster,
//    Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase,
//    Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter can be omitted in that case,
//    if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  Filter - Description of filtering conditions of sessions to be deleted.
//    Variants:
//      1. Array of structures that describe conditions of the sessions filtering. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of the function ClusterAdministrationClientServer.SessionProperties(), 
//        ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          sessions values with the specified in the filter condition. Possible values:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.More (only for numeric values),
//            ComparisonType.GreaterOrEqual ComparisonType.More (only for numeric values), 
//            ComparisonType.Less (only for numeric values), 
//            ComparisonType.LessOrEqual (only for numeric values),
//            
//            
//            ComparisonType.InList, ComparisonType.NotInList, ComparisonType.Period (only for numeric values), 
//            ComparisonType.PeriodIncludingBorders (only for numeric values), 
//            ComparisonType.IntervalIncludingLowerBound (only for numeric values), 
//            ComparisonType.IntervalIncludingUpperBound (only for numeric values), 
//        Value - Number, String, Date, Boolean, ValueList, Array, Structure - value
//          with which the value of corresponding session property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array values that contains
//          the set of values with which the comparison will be done. When ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be
//          passed as the structures with the From and To fields the values of which form
//          the period that will be used for the comparison to be done, 
//    2. Structure (simplified version), key - Name of the session's property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison is always executed on equality.
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteInfobaseSessions(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Filter);
	
EndProcedure

#EndRegion

#Region InfobaseConnection

// Constructor of the structure that describes the properties of the connection with the infobase.
//
// Return value: Structure, fields:
//  Number - Number, the infobase connection number, 
//  UserName - String, the user name of the 1C:Enterprise, connected to infobase, 
//  ClientComputerName - String, the name of the computer from which the connection is established,
//  ClientApplicationIdentifier - String, the application identifier that created the connection.
//    Possible values - see Description of the global context function, 
//  ApplicationPresentation(), ConnectionMoment - Date(Date and time), time of setting connection, 
//  InfobaseConnectionMode - Number, connection mode with the infobase (0 - separated, 1 - Exclusive),
//    
//  DatabaseConnectionMode - Number, connection mode with the database (0 - Connection is not found, 1 - separated, 2 - Exclusive),
//    
//  BlockDBMS - Number, the connection identifier that locks the work of this connection in DBMS, 
//  Passed - Number, the amount of data, received and sent by the connection,  
//  PassedFor5Minutes - Number, the data amount received and sent by the connection for the last 5 minutes, 
//  ServerCalls - Number, quantity of the server calls, 
//  ServerCallsFor5Minutes - Number, the amount of the connection server calls for the last 5 minutes, 
//  PassedDBMS - Number, the data amount passed between 1C:Enterprise server and
//    data bases server since the start of this connection, 
//  DBMSPassedFor5Minutes - Number, the data amount passed between 1C:Enterprise server
//    and data bases server for the last 5 minutes, 
//  ConnectionDBMS - String, the identifier of the connection process with DBMS (if
//    at the time of getting the connections list this connection executed request to the server DBMS, otherwise - value is an empty row).
//    Identifier returns in terms of DBMS server.
//  TimeDBMS - Number, time in seconds, during which the request to DBMS server is executed
//    (if at the time of getting the connections list this connection executed the request to DBMS server, otherwise - value is 0), 
//    
//  CaptureDBMSConnectionMoment - Date(Date and time) - time of the last capture connection with the DBMS server, 
//  ServerCallsDuration - Number, the duration of the all connection server calls,
//  DBMSCallsDuration - Number, the DBMS time calls initiated by the connection, 
//  CurrentServerCallDuration - Number, the duration of the current server call, 
//  CurrentDBMSCallDuration - Number, the duration of the current DBMS server call, 
//  ServerCallsDurationFor5Minutes - Number, the duration of the connection server calls for the last 5 minutes,
//  DBMSCallsDurationFor5Minutes - Number, the duration of the DBMS connection calls for the last 5 minutes.
//
Function ConnectionProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Number");
	Result.Insert("UserName");
	Result.Insert("ClientComputerName");
	Result.Insert("ClientApplicationIdentifier");
	Result.Insert("ConnectionMoment");
	Result.Insert("InfobaseConnectionMode");
	Result.Insert("DatabaseConnectionMode");
	Result.Insert("DBMSLocking");
	Result.Insert("Transferred");
	Result.Insert("PassedFor5Minutes");
	Result.Insert("ServerCalls");
	Result.Insert("ServerCallsFor5Minutes");
	Result.Insert("PassedDBMS");
	Result.Insert("DBMSPassedIn5Minutes");
	Result.Insert("ConnectionDBMS");
	Result.Insert("TimeDBMS");
	Result.Insert("CaptureDBMSConnectionMoment");
	Result.Insert("ServerCallsDuration");
	Result.Insert("DBMSCallsDuration");
	Result.Insert("CurrentServerCallDuration");
	Result.Insert("CurrentDBMSCallDuration");
	Result.Insert("ServerCallsDurationFor5Minutes");
	Result.Insert("DBMSCallsDurationFor5Minutes");
	
	Return Result;
	
EndFunction

// Returns the descriptions of the infobase connections.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter
//    can be omitted in that case if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  Filter - Description of the connection filtering conditions, descriptions of which must be received.
//    Variants:
//      1. Array of structures that describe conditions of the connections filtering. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of
//        the function ClusterAdministrationClientServer.ConnectionProperties(), ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          connections values with the specified in the filter condition. Possible values:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.More (only for numeric
//            values), ComparisonType.GreaterOrEqual ComparisonType.More (only for
//            numeric values), ComparisonType.Less (only for
//            numeric values), ComparisonType.LessOrEqual (only for
//            numeric
//            values),
//            ComparisonType.InList, ComparisonType.NotInList, ComparisonType.Period (only for
//            numeric values), ComparisonType.PeriodIncludingBorders (only for
//            numeric values), ComparisonType.IntervalIncludingLowerBound (only for
//            numeric values), ComparisonType.IntervalIncludingUpperBound (only for
//        numeric values), Value - Number, String, Date, Boolean, ValueList, Array, Structure - value
//          with which the value of corresponding connection property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array
//          values that contains the set of values with which the comparison will be done. When
//          ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be passed
//          as the structures with the From and To fields the values of which form the
//          period that
//    will be used for the comparison to be done, 2. Structure (simplified version), key - Name of the connection property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison is always executed on equality.
//
// Return value: Array (Structure) array of structures that describe the connections properties. Description of structures -
// see ClusterAdministrationClientServer.ConnectionProperties().
//
Function InfobaseConnection(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseConnection(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Filter);
	
EndFunction

// Terminates the infobase connection by filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter
//    can be omitted in that case if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  Filter - Description of the filtering connections conditions that are required to be completed.
//    Variants:
//      1. Array of structures that describe the filtering conditions of the terminated connections. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of
//        the function ClusterAdministrationClientServer.ConnectionProperties(), ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          connections values with the specified in the filter condition. Possible values:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.More (only for numeric
//            values), ComparisonType.GreaterOrEqual ComparisonType.More (only for
//            numeric values), ComparisonType.Less (only for
//            numeric values), ComparisonType.LessOrEqual (only for
//            numeric
//            values),
//            ComparisonType.InList, ComparisonType.NotInList, ComparisonType.Period (only for
//            numeric values), ComparisonType.PeriodIncludingBorders (only for
//            numeric values), ComparisonType.IntervalIncludingLowerBound (only for
//            numeric values), ComparisonType.IntervalIncludingUpperBound (only for
//        numeric values), Value - Number, String, Date, Boolean, ValueList, Array, Structure - value
//          with which the value of corresponding connection property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array
//          values that contains the set of values with which the comparison will be done. When
//          ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be passed
//          as the structures with the From and To fields the values of which form the
//          period that
//    will be used for the comparison to be done, 2. Structure (simplified version), key - Name of the connection property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison is always executed on equality.
//
Procedure TerminateConnectionWithInfobase(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined, Val Filter = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.TerminateConnectionWithInfobase(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Filter);
	
EndProcedure

#EndRegion

#Region SecurityProfiles

// Returns the name of the security profile, assigned to the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted in case if similar fields were specified in
//    the structure passed as the parameter value ClusterAdministrationParameters.
//
// Return value: String, the name of the security profile that is assigned for the infobase. If
//  the security profile is not assigned for the infobase - an empty string is returned.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSecurityProfile(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
EndFunction

// Returns the name of the security profile that is assigned
//  as the security profile of the safe mode for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted in case if similar fields were specified in
//    the structure passed as the parameter value ClusterAdministrationParameters.
//
// Return value: String, the name of the security profile that is
//  assigned as the security profile of the safe mode for the infobase. If the security profile is not assigned for the infobase - an
//  empty string is returned.
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined) Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.InfobaseSafeModeSecurityProfile(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters);
	
EndFunction

// Assigns the usage of security profile for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter
//    can be omitted in that case if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  ProfileName - String, the name of the security profile. If an empty string is passed - for the infobase
//    the using of the security profile will be disabled.
//
Procedure SetInformationBaseSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined, Val ProfileName = "") Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInformationBaseSecurityProfile(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		ProfileName);
	
EndProcedure

// Assign to use security profile of the safe mode for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//    Parameter
//    can be omitted in that case if similar fields were specified in the structure passed as the parameter value ClusterAdministrationParameters.
//  ProfileName - String, the name of the security profile. If an empty string is passed - for the infobase
//    the using of the security profile of the safe mode will be disabled.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined, Val ProfileName = "") Export
	
	If InfobaseAdministrationParameters = Undefined Then
		InfobaseAdministrationParameters = ClusterAdministrationParameters;
	EndIf;
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetInfobaseSafeModeSecurityProfile(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		ProfileName);
	
EndProcedure

// Verifies the existence of the security profile in the cluster of servers.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile the existence of which is verified.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfileExists(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Constructor of the structure that describes the properties of the security profile.
//
// Return value: Structure, fields:
//  Name - String, the
//  name of the security profile, Description - String, the description
//  of the security profile, SafeModeProfile - Boolean, defines the option to
//    use the security profile as the security profile of the safe mode
//    (either when you specify it as the safe mode profile for the infobase or during the call).
//    SetSafeMode (<ProfileName>)
//  from the configuration code, FullAccessToPrivilegedMode - Boolean, defines the
//    option to set the privileged mode from the
//  safe mode of this security profile, FullAccessToFileSystem - Boolean determines the existence of restrictions on
//    access to the file system. When you set the value as False the access will be
//    given only to the directories
//  of the file system, listed in the property of VirtualDirectories, COMObjectsFullAccess - Boolean determines the existence of restrictions on access to use.
//    COMObjects. When you set the value as False the access will
//    be given only to
//  the COM classes, listed in the property of COMClasses, FullAccessToExternalComponents - Boolean, defines the access restrictions
//    to the usage of external components. When you set the value as False the access will
//    be given only to the
//  external components, listed in the property of ExternalComponents, FullAccessToExternalModules - Boolean, defines the access estrictions
//    to use the external modules (external reports and processors, Execute() and Calculate() calls) in unsafe mode.
//    When you set the value as False, the option to
//    use only external modules in an unsafe mode
//  will be given that are listed in the property of ExternalModules, FullAccessToOperatingSystemApplications - Boolean, defines the access restrictions
//    to the use the applications of operating system. When you set the value as
//    False, there will be the option to use only the
//  operating system applications that are listed in the property of OSApplications, FullAccessToInternetResources - Boolean determines the existence of restrictions on access to use.
//    Internet resources. When you set the value as False, the
//    option to use only internet resources
//  listed in a property will be given, VirtualDirectories - Array(Structure), array of structures that
//    describes the virtual directories that give access when installing FullAccessToFileSystem = False. Descriptions of the structures fields -
//   see ClusterAdministrationClientServer.VirtualDirectoryProperties(),
//  COMClasses - Array(Structure), array of structures that
//    describe COM classes that give access when installing COMObjectsFullAccess = False. Descriptions of the structures fields - see
//    ClusterAdministrationClientServer.COMClassProperties(),
//  ExternalComponents - Array(Structure), array of structures that describe
//    external components that give access when installing FullAccessToExternalComponents = False. Descriptions of the structures fields - see
//    ClusterAdministrationClientServer.ExternalComponentProperties(),
//  ExternalModules - Array(Structure), array of structures that describe
//    the external modules permitted to access in the unsafe mode when setting the FullAccessToExternalModules = False. Descriptions of the structures fields - see
//    ClusterAdministrationClientServer.ExternalModuleProperties(),
//  OSApplications - Array(Structure), array of structures that describe
//    the applications of the operating system that give access when you installing FullAccessToOperatingSystemApplications = False. Descriptions
//    of the structures fields - see ClusterAdministrationClientServer.OSApplicationsProperties(),
//  InternetResources - Array (Structure), array of structures that
//    describe internet resources that give access when installing FullAccessToInternetResources = false. Descriptions of the structures fields - see
//    ClusterAdministrationClientServer.InternetResourceProperties().
//
Function SecurityProfileProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name", "");
	Result.Insert("Definition", "");
	Result.Insert("ProfileOfSafeMode", False);
	Result.Insert("FullAccessToPrivilegedMode", False);
	
	Result.Insert("FullAccessToFileSystem", False);
	Result.Insert("COMObjectsFullAccess", False);
	Result.Insert("FullAccessToExternalComponents", False);
	Result.Insert("FullAccessToExternalModules", False);
	Result.Insert("FullAccessToOperatingSystemApplications", False);
	Result.Insert("FullAccessToInternetResources", False);
	
	Result.Insert("VirtualDirectories", New Array());
	Result.Insert("COMClasses", New Array());
	Result.Insert("ExternalComponents", New Array());
	Result.Insert("ExternalModules", New Array());
	Result.Insert("OSApplications", New Array());
	Result.Insert("InternetResources", New Array());
	
	Return Result;
	
EndFunction

// Structure designer that describes the properties of the virtual directory.
//
// Return value: Structure, fields:
//  LogicalURL - String, logical
//  directory URL, PhysicalURL - String, the physical URL of the directory on
//    the server for data placement of the virtual catalog.
//  Definition - String, description of
//  the virtual directory, DataReading - Boolean, permission flag of data reading
//  from a virtual directory, DataRecording - Boolean, the permission flag to write data in the virtual directory.
//
Function VirtualDirectoryProperties() Export
	
	Result = New Structure();
	
	Result.Insert("LogicalURL");
	Result.Insert("PhysicalURL");
	
	Result.Insert("Definition");
	
	Result.Insert("DataReading");
	Result.Insert("DataRecording");
	
	Return Result;
	
EndFunction

// Constructor of the structure describing the properties of a COM class.
//
// Return value: Structure, fields:
//  Name - String, the name of the COM class
//  is used as a key when searching, Description - String, description
//  of a COM class, FileMoniker - String, the name of the file on which the object is created by the global context method.
//    GetCOMObject() with a
//  null value of the second parameter, CLSID - String, the presentation of the COM class identifier in
//    the format of Microsoft Windows system registry without curved brackets, and
//  which can be created in the operating system, Computer - String, name of the computer on which the COM object can be created.
//
Function COMClassProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Definition");
	
	Result.Insert("FileMoniker");
	Result.Insert("CLSID");
	Result.Insert("Computer");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes the properties of the external component.
//
// Return value: Structure, fields:
//  Name - String, the name of the external component that
//  is used as the key for searching, Description - String, description of
//  the external component, HashSum - String, the checksum of the permitted external component, calculated by the algorithm.
//    SHA-1 and base64 converted to row.
//
Function ExternalComponentProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Definition");
	
	Result.Insert("HashSum");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes the properties of the external module.
//
// Return value: Structure, fields:
//  Name - String, the name of the external module is
//  used as the key for searching, Description - String, description of
//  the external module, HashSum - String, the checksum of the permitted external module, calculated by the algorithm.
//    SHA-1 and base64 converted to row.
//
Function ExternalModuleProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Definition");
	
	Result.Insert("HashSum");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes the application properties of the operating system.
//
// Return value: Structure, fields:
//  Name - String, the application name of the operating system that
//  is used as the key for searching, Description - String, the description of
//  the operating system application, TemplateLaunchRows - String, the template of the application launch
//    row (consists of a template words sequence separated by spaces).
//
Function OSApplicationsProperties() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Definition");
	
	Result.Insert("TemplateLaunchRows");
	
	Return Result;
	
EndFunction

// Constructor of the structure that describes the internet resource.
//
// Return value: Structure, fields:
//  Name - String, the name of the internet resource
//  that is used as the key for searching, Description - String, the
//  description of the internet resource, Protocol - String, allowed network protocol. Possible values:
//    HTTP,
//    HTTPS,
//    FTP,
//    FTPS,
//    POP3,
//    SMTP,
//    IMAP,
//  Address - String, the network address of the Internet resource
//  without specifying the protocol and the port, Port - Number, the network port of internet resource.
//
Function PropertiesInternetResource() Export
	
	Result = New Structure();
	
	Result.Insert("Name");
	Result.Insert("Definition");
	
	Result.Insert("Protocol");
	Result.Insert("Address");
	Result.Insert("Port");
	
	Return Result;
	
EndFunction

// Returns properties of the security profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile.
//
// Return value: structure describing the security profile, Description - see
//  ClusterAdministrationClientServer.SecurityProfileProperties().
//
Function SecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	Return AdministrationManager.SecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndFunction

// Creates a security profile based on the provided description.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  SecurityProfileProperties - Structure that describes the properties
//    of the newly created security profile, Description - see ClusterAdministrationClientServer.SecurityProfileProperties().
//
Procedure CreateSecurityProfile(Val ClusterAdministrationParameters, Val SecurityProfileProperties) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.CreateSecurityProfile(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Set properties for an existing security profile based on the provided description.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  SecurityProfileProperties - Structure describing the properties installed for
//    the security profile, Description - see ClusterAdministrationClientServer.SecurityProfileProperties().
//
Procedure SetSecurityProfileProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties)  Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.SetSecurityProfileProperties(
		ClusterAdministrationParameters,
		SecurityProfileProperties);
	
EndProcedure

// Delete the security profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	AdministrationManager = AdministrationManager(ClusterAdministrationParameters);
	
	AdministrationManager.DeleteSecurityProfile(
		ClusterAdministrationParameters,
		ProfileName);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Verify the values of the object properties for compliance with the conditions, specified in the filter.
//
// Parameters:
//  VerifiedObject - Structure:
//    Key - Name of the property which
//    value is compared with the filter, Value - Value of the property that
//  is to be compared with filter, Filter - Description of the filtering objects condition.
//    Variants:
//      1. Array of structures describing the conditions of the filter. Fields of structures included in the array:
//        Property - String, the name of the
//        property on which is being filtered, ComparisonType - value of the systematic enum ComparisonType, kind of
//          comparing values with the specified in the filter condition. Possible values:
//            ComparisonType.Equal,
//            ComparisonType.NotEqual,
//            ComparisonType.More (only for numeric
//            values), ComparisonType.GreaterOrEqual ComparisonType.More (only for
//            numeric values), ComparisonType.Less (only for
//            numeric values), ComparisonType.LessOrEqual (only for
//            numeric
//            values),
//            ComparisonType.InList, ComparisonType.NotInList, ComparisonType.Period (only for
//            numeric values), ComparisonType.PeriodIncludingBorders (only for
//            numeric values), ComparisonType.IntervalIncludingLowerBound (only for
//            numeric values), ComparisonType.IntervalIncludingUpperBound (only for
//        numeric values), Value - Number, String, Date, Boolean, ValueList, Array, Structure - value
//          with which the value of corresponding property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array values that contains
//          the set of values with which the comparison will be done. When ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be
//          passed as the structures with the From and To fields the values of which form
//          the period
//    that will be used for the comparison to be done, 2. Structure (simplified version), key - Property name (see above), value - the value
//      with which the comparison is executed. When using this option of the filter description, the comparison is always executed on equality.
//
// Return value: Boolean, it is True if the values of the object
//  properties satisfy the conditions specified in the filter, False - if they do not satisfy.
//
Function VerifyFilterConditions(Val VerifiedObject, Val Filter = Undefined) Export
	
	If Filter = Undefined Or Filter.Count() = 0 Then
		Return True;
	EndIf;
	
	ExecutedConditions = 0;
	
	For Each Condition IN Filter Do
		
		If TypeOf(Condition) = Type("Structure") Then
			
			Field = Condition.Property;
			RequiredValue = Condition.Value;
			ValuesComparisonType = Condition.ComparisonType;
			
		ElsIf TypeOf(Condition) = Type("KeyAndValue") Then
			
			Field = Condition.Key;
			RequiredValue = Condition.Value;
			ValuesComparisonType = ComparisonType.Equal;
			
		Else
			
			Raise NStr("en='The filter is incorrectly set!';ru='Некорректно задан фильтр!'");
			
		EndIf;
		
		VerifiedValue = VerifiedObject[Field];
		ConditionExecuted = VerifyFilterCondition(VerifiedValue, ValuesComparisonType, RequiredValue);
		
		If ConditionExecuted Then
			ExecutedConditions = ExecutedConditions + 1;
		Else
			Break;
		EndIf;
		
	EndDo;
	
	Return ExecutedConditions = Filter.Count();
	
EndFunction

// Verifies the values for compliance to the conditions specified in the filter.
//
// Parameters:
//  VerifiedValue - Number, String, Date, Boolean - value that is compared
//  with the condition ValuesComparisonType - value of the systematic enum ComparisonType, kind of
//    comparing values with the specified in the filter condition. Possible values:
//      ComparisonType.Equal,
//      ComparisonType.NotEqual,
//      ComparisonType.More (only
//      for numeric values), ComparisonType.GreaterOrEqual ComparisonType.More
//      (only for numeric values), ComparisonType.Less
//      (only for numeric values), ComparisonType.LessOrEqual
//      (only
//      for
//      numeric values), ComparisonType.InList, ComparisonType.NotInList, ComparisonType.Period
//      (only for numeric values), ComparisonType.PeriodIncludingBorders
//      (only for numeric values), ComparisonType.IntervalIncludingLowerBound
//      (only for numeric values), ComparisonType.IntervalIncludingUpperBound
//  (only for numeric values), Value - Number, String, Date, Boolean, ValueList, Array, Structure - value
//    with which the value being verified is compared. When ComparisonType.InList and ComparisonType.NotInList
//    values should be passed as ValueList or Array containing the set
//    of values with which the comparison will be executed. When ComparisonType.Period, ComparisonType.IntervalIncludingBounds,
//    ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound as
//    a value structures with the From and To fields must be passed, values of which
//    form the period with which the corresponding comparison will be done.
//
// Return value: Boolean, True if a value satisfies the conditions, False - if it does not satisfy.
//
Function VerifyFilterCondition(Val VerifiedValue, Val ValuesComparisonType, Val Value)
	
	If ValuesComparisonType = ComparisonType.Equal Then
		
		Return VerifiedValue = Value;
		
	ElsIf ValuesComparisonType = ComparisonType.NotEqual Then
		
		Return VerifiedValue <> Value;
		
	ElsIf ValuesComparisonType = ComparisonType.Greater Then
		
		Return VerifiedValue > Value;
		
	ElsIf ValuesComparisonType = ComparisonType.GreaterOrEqual Then
		
		Return VerifiedValue >= Value;
		
	ElsIf ValuesComparisonType = ComparisonType.Less Then
		
		Return VerifiedValue < Value;
		
	ElsIf ValuesComparisonType = ComparisonType.LessOrEqual Then
		
		Return VerifiedValue <= Value;
		
	ElsIf ValuesComparisonType = ComparisonType.InList Then
		
		If TypeOf(Value) = Type("ValueList") Then
			
			Return Value.FindByValue(VerifiedValue) <> Undefined;
			
		ElsIf TypeOf(Value) = Type("Array") Then
			
			Return Value.Find(VerifiedValue) <> Undefined;
			
		EndIf;
		
	ElsIf ValuesComparisonType = ComparisonType.NotInList Then
		
		If TypeOf(Value) = Type("ValueList") Then
			
			Return Value.FindByValue(VerifiedValue) = Undefined;
			
		ElsIf TypeOf(Value) = Type("Array") Then
			
			Return Value.Find(VerifiedValue) = Undefined;
			
		EndIf;
		
	ElsIf ValuesComparisonType = ComparisonType.Interval Then
		
		Return VerifiedValue > Value.From AND VerifiedValue < Value.To;
		
	ElsIf ValuesComparisonType = ComparisonType.IntervalIncludingBounds Then
		
		Return VerifiedValue >= Value.From AND VerifiedValue <= Value.To;
		
	ElsIf ValuesComparisonType = ComparisonType.IntervalIncludingLowerBound Then
		
		Return VerifiedValue >= Value.From AND VerifiedValue < Value.To;
		
	ElsIf ValuesComparisonType = ComparisonType.IntervalIncludingUpperBound Then
		
		Return VerifiedValue > Value.From AND VerifiedValue <= Value.To;
		
	EndIf;
	
EndFunction

// Returns the general module that implements the
// application interface for the administration of the servers cluster that corresponds to the type of connection to administered servers cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters().
//
// Return value: CommonModule.
//
Function AdministrationManager(Val AdministrationParameters)
	
	If AdministrationParameters.ConnectionType = "COM" Then
		
		Return ClusterAdministrationCOMClientServer;
		
	ElsIf AdministrationParameters.ConnectionType = "RAS" Then
		
		Return AdministrationClusterRASClientServer;
		
	Else
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unknown type of connection: %1!';ru='Неизвестный тип подключения: %1!'"), AdministrationParameters.ConnectionType);
		
	EndIf;
	
EndFunction

// Returns the date that corresponds to the empty date in the registry of the cluster servers.
//
// Return value: Date(Date and time).
//
Function BlankDate() Export
	
	Return Date(1, 1, 1, 0, 0, 0);
	
EndFunction

#EndRegion


