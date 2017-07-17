////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Server procedures and functions of common use:
// - Implementation of the application administration of the servers cluster with using.
//     COM object V8*.ComConnector
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

#Region SessionsAndJobsLocking

// Returns the current state of sessions and scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//
// Return value: Structure describing the state sessions
//  and scheduled jobs locking, Description - see ClusterAdministrationClientServer.SessionsAndScheduledJobsBlockProperties().
//
Function InfobaseSessionsAndJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	Result = COMAdministratorObjectModelObjectDescription(
		Infobase,
		SessionsAndScheduledJobsLockingPropertiesDictionary());
	
	If Result.DateFrom = ClusterAdministrationClientServer.BlankDate() Then
		Result.DateFrom = Undefined;
	EndIf;
	
	If Result.DateTo = ClusterAdministrationClientServer.BlankDate() Then
		Result.DateTo = Undefined;
	EndIf;
	
	If Not ValueIsFilled(Result.KeyCode) Then
		Result.KeyCode = "";
	EndIf;
	
	If Not ValueIsFilled(Result.Message) Then
		Result.Message = "";
	EndIf;
	
	If Not ValueIsFilled(Result.LockParameter) Then
		Result.LockParameter = "";
	EndIf;
	
	Return Result;
	
EndFunction

// Sets new state sessions and scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster,
//     Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase,
//     Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  SessionsAndJobsBlockProperties - Structure describing the state sessions and scheduled jobs locking,
//     Description - see ClusterAdministrationClientServer.SessionsAndScheduledJobsBlockProperties().
//
Procedure SetInfobaseSessionsAndJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val SessionsAndJobsLockingProperties) Export
	
	EstablishedLocking = New Structure();
	For Each KeyAndValue IN SessionsAndJobsLockingProperties Do
		EstablishedLocking.Insert(KeyAndValue.Key, KeyAndValue.Value);
	EndDo;
	
	If Not ValueIsFilled(EstablishedLocking.DateFrom) Then
		EstablishedLocking.DateFrom = ClusterAdministrationClientServer.BlankDate();
	EndIf;
	
	If Not ValueIsFilled(EstablishedLocking.DateTo) Then
		EstablishedLocking.DateTo = ClusterAdministrationClientServer.BlankDate();
	EndIf;
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	SessionsAreProhibited = Infobase.SessionsDenied;
	
	FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
		Infobase,
		EstablishedLocking,
		SessionsAndScheduledJobsLockingPropertiesDictionary());
	
	WorkingProcessConnection.UpdateInfobase(Infobase);
	
EndProcedure

// Verify the correctness of the administration parameters.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters to the server cluster,
//     Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of connection to the infobase,
//     Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted when similar fields were specified in
//    the structure passed as the ClusterAdministrationParameters,
// VerifyClusterAdministrationParameters parameter value - Boolean, flag showing the
//                                                         necessity to verify the parameters of the cluster administration,
// VerifyInfobaseAdministrationParameters - Boolean, flag showing the necessity to verify the parameters of the cluster administration.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined,
	VerifyInfobaseAdministrationParameters = True,
	VerifyClusterAdministrationParameters = True) Export
	
	If VerifyClusterAdministrationParameters OR VerifyInfobaseAdministrationParameters Then
		
		COMConnector = COMConnector();
	
		ConnectionToServerAgent = ConnectionToServerAgent(
			COMConnector,
			ClusterAdministrationParameters.ServerAgentAddress,
			ClusterAdministrationParameters.ServerAgentPort);
		
		Cluster = GetCluster(
			ConnectionToServerAgent,
			ClusterAdministrationParameters.ClusterPort,
			ClusterAdministrationParameters.ClusterAdministratorName,
			ClusterAdministrationParameters.ClusterAdministratorPassword);
		
	EndIf;
	
	If VerifyInfobaseAdministrationParameters Then
		
		WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
		
		Infobase = GetIB(
			WorkingProcessConnection,
			Cluster,
			InfobaseAdministrationParameters.NameInCluster,
			InfobaseAdministrationParameters.NameAdministratorInfobase,
			InfobaseAdministrationParameters.PasswordAdministratorInfobase);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ScheduledJobsLocking

// Returns the current state scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//
// Return value: Boolean.
//
Function InfobaseScheduledJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	Return Infobase.ScheduledJobsDenied;
	
EndFunction

// Set new state scheduled jobs locking for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  ScheduledJobsLocking - Boolean, the flag for setting the locking of infobase scheduled jobs.
//
Procedure LockInfobaseSheduledJobs(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val ScheduledJobsLocking) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	Infobase.ScheduledJobsDenied = ScheduledJobsLocking;
	WorkingProcessConnection.UpdateInfobase(Infobase);
	
EndProcedure

#EndRegion

#Region InfobaseSessions

// Returns the descriptions of infobase sessions.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  Filter - Description of the session filtering conditions which descriptions must be received.
//    Variants:
//      1. Array of structures that describe conditions of the sessions filtering. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of
//        the function ClusterAdministrationClientServer.SessionProperties(), ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          sessions values with the specified in the filter condition. Possible values:
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
//          with which the value of corresponding session property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array values that contains
//          the set of values with which the comparison will be done. When ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be
//          passed as the structures with the From and To fields the values of which form
//          the period
//    that will be used for the comparison to be done, 2. Structure (simplified version), key - Name of the session's property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison is always executed on equality.
//
// Return value: Array (Structure), array of structures that describe the sessions properties. Description of structures -
// see ClusterAdministrationClientServer.SessionProperties().
//
Function InfobaseSessions(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	InfobaseDescription = GetIBDescription(
		ConnectionToServerAgent,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster);
	
	Return GetSessions(ConnectionToServerAgent, Cluster, InfobaseDescription, Filter, True);
	
EndFunction

// Delete sessions with infobase by the filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  Filter - Description of filtering conditions of sessions to be deleted.
//    Variants:
//      1. Array of structures that describe conditions of the sessions filtering. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of
//        the function ClusterAdministrationClientServer.SessionProperties(), ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          sessions values with the specified in the filter condition. Possible values:
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
//          with which the value of corresponding session property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array values that contains
//          the set of values with which the comparison will be done. When ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be
//          passed as the structures with the From and To fields the values of which form
//          the period
//    that will be used for the comparison to be done, 2. Structure (simplified version), key - Name of the session's property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison is always executed on equality.
//
Procedure DeleteInfobaseSessions(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	InfobaseDescription = GetIBDescription(
		ConnectionToServerAgent,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster);
	
	Sessions = GetSessions(ConnectionToServerAgent, Cluster, InfobaseDescription, Filter, False);
	
	For Each Session IN Sessions Do
		
		Try
			
			ConnectionToServerAgent.TerminateSession(Cluster, Session);
			
		Except
			
			// The session could be completed by the time of calling the TerminateSession.
			
			FilterSessions = New Structure("Number", Session.Number);
			
			If GetSessions(ConnectionToServerAgent, Cluster, InfobaseDescription, FilterSessions, False).Count() > 0 Then
				Raise;
			Else
				Continue;
			EndIf;
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region InfobaseConnection

// Returns the descriptions of the infobase connections.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
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
Function InfobaseConnection(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	Return GetConnections(
		COMConnector,
		ConnectionToServerAgent,
		Cluster,
		InfobaseAdministrationParameters,
		Filter,
		True);
	
EndFunction

// Terminates the infobase connection by filter.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
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
Procedure TerminateConnectionWithInfobase(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val Filter = Undefined) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	ProcessesAndConnections = GetConnections(
		COMConnector,
		ConnectionToServerAgent,
		Cluster,
		InfobaseAdministrationParameters,
		Filter,
		False);
	
	For Each ProcessAndConnection IN ProcessesAndConnections Do
		
		Try
			
			ProcessAndConnection.WorkingProcessConnection.Disconnect(ProcessAndConnection.Join);
			
		Except
			
			// Connection could be already terminated by the time of calling the Disconnect.
			
			ConnectionsFilter = New Structure("Number", ProcessAndConnection.Join.Number);
			
			ConnectionsDescriptions = GetConnections(
				COMConnector,
				ConnectionToServerAgent,
				Cluster,
				InfobaseAdministrationParameters,
				ConnectionsFilter);
			
			If ConnectionsDescriptions.Count() > 0 Then
				Raise;
			Else
				Continue;
			EndIf;
			
		EndTry;
		
	EndDo;
	
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
//
// Return value: String, the name of the security profile that is assigned for the infobase. If
//  the security profile is not assigned for the infobase - an empty string is returned.
//
Function InfobaseSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	If ValueIsFilled(Infobase.SecurityProfileName) Then
		Result = Infobase.SecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ConnectionToServerAgent = Undefined;
	COMConnector = Undefined;
	
	Return Result;
	
EndFunction

// Returns the name of the security profile that is assigned
//  as the security profile of the safe mode for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//
// Return value: String, the name of the security profile that is assigned
//  as the security profile of the safe mode for the infobase. If the security profile is not assigned for the infobase - an
//  empty string is returned.
//
Function InfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	If ValueIsFilled(Infobase.SafeModeSecurityProfileName) Then
		Result = Infobase.SafeModeSecurityProfileName;
	Else
		Result = "";
	EndIf;
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ConnectionToServerAgent = Undefined;
	COMConnector = Undefined;
	
	Return Result;
	
EndFunction

// Assigns the usage of security profile for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  ProfileName - String, the name of the security profile. If an empty string is passed - for the infobase
//    the using of the security profile will be disabled.
//
Procedure SetInformationBaseSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val ProfileName = "") Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	Infobase.SecurityProfileName = ProfileName;
	
	WorkingProcessConnection.UpdateInfobase(Infobase);
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ConnectionToServerAgent = Undefined;
	COMConnector = Undefined
	
EndProcedure

// Assign to use security profile of the safe mode for the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  ProfileName - String, the name of the security profile. If an empty string is passed - for the infobase
//    the using of the security profile of the safe mode will be disabled.
//
Procedure SetInfobaseSafeModeSecurityProfile(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val ProfileName = "") Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	Infobase = GetIB(
		WorkingProcessConnection,
		Cluster,
		InfobaseAdministrationParameters.NameInCluster,
		InfobaseAdministrationParameters.NameAdministratorInfobase,
		InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
	Infobase.SafeModeSecurityProfileName = ProfileName;
	
	WorkingProcessConnection.UpdateInfobase(Infobase);
	
	Infobase = Undefined;
	WorkingProcessConnection = Undefined;
	Cluster = Undefined;
	ConnectionToServerAgent = Undefined;
	COMConnector = Undefined
	
EndProcedure

// Verifies the existence of the security profile in the cluster of servers.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile the existence of which is verified.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	For Each SecurityProfile IN ConnectionToServerAgent.GetSecurityProfiles(Cluster) Do
		
		If SecurityProfile.Name = ProfileName Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
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
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(ConnectionToServerAgent, Cluster, ProfileName);
	
	Result = COMAdministratorObjectModelObjectDescription(
		SecurityProfile,
		SecurityProfilePropertiesDictionary());
	
	// Virtual directories
	Result.Insert("VirtualDirectories",
		COMAdministratorObjectModelObjectDescriptions(
			GetVirtualDirectories(ConnectionToServerAgent, Cluster, ProfileName),
			VirtualDirectoryPropertiesDictionary()));
	
	// Allowed COM classes
	Result.Insert("COMClasses",
		COMAdministratorObjectModelObjectDescriptions(
			GetCOMClasses(ConnectionToServerAgent, Cluster, ProfileName),
			COMClassPropertiesDictionary()));
	
	// External components
	Result.Insert("ExternalComponents",
		COMAdministratorObjectModelObjectDescriptions(
			GetExternalComponents(ConnectionToServerAgent, Cluster, ProfileName),
			ExternalComponentPropertiesDictionary()));
	
	// External modules
	Result.Insert("ExternalModules",
		COMAdministratorObjectModelObjectDescriptions(
			GetExternalModules(ConnectionToServerAgent, Cluster, ProfileName),
			ExternalModulePropertiesDictionary()));
	
	// OS applications
	Result.Insert("OSApplications",
		COMAdministratorObjectModelObjectDescriptions(
			GetOSApplications(ConnectionToServerAgent, Cluster, ProfileName),
			OSApplicationPropertiesDictionary()));
	
	// Internet resources
	Result.Insert("InternetResources",
		COMAdministratorObjectModelObjectDescriptions(
			GetInternetResources(ConnectionToServerAgent, Cluster, ProfileName),
			InternetResourcePropertiesDictionary()));
	
	Return Result;
	
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
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = ConnectionToServerAgent.CreateSecurityProfile();
	ApplySecurityProfilePropertiesChanges(ConnectionToServerAgent, Cluster, SecurityProfile, SecurityProfileProperties);
	
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
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(
		ConnectionToServerAgent,
		Cluster,
		SecurityProfileProperties.Name);
	
	ApplySecurityProfilePropertiesChanges(ConnectionToServerAgent, Cluster, SecurityProfile, SecurityProfileProperties);
	
EndProcedure

// Deletes the security profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	COMConnector = COMConnector();
	
	ConnectionToServerAgent = ConnectionToServerAgent(
		COMConnector,
		ClusterAdministrationParameters.ServerAgentAddress,
		ClusterAdministrationParameters.ServerAgentPort);
	
	Cluster = GetCluster(
		ConnectionToServerAgent,
		ClusterAdministrationParameters.ClusterPort,
		ClusterAdministrationParameters.ClusterAdministratorName,
		ClusterAdministrationParameters.ClusterAdministratorPassword);
	
	SecurityProfile = GetSecurityProfile(
		ConnectionToServerAgent,
		Cluster,
		ProfileName);
	
	ConnectionToServerAgent.UnregSecurityProfile(Cluster, ProfileName);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Create a COM object V8*.ComConnector.
//
// Return value: COMObject.
//
Function COMConnector()
	
	#If Client Then
		Return New COMObject(StandardSubsystemsClientReUse.ClientWorkParameters().COMConnectorName);
	#Else
		
		If SafeMode() Then
			Raise NStr("en='Cluster administration is unavailable in the safe mode.';ru='Администрирование кластера невозможно в безопасном режиме!'");
		EndIf;
		
		If CommonUseReUse.DataSeparationEnabled() Then
			Raise NStr("en='Applied infobase cannot administer cluster in SaaS.';ru='В модели сервиса недопустимо выполнение прикладной информационной базой функций администрирования кластера!'");
		EndIf;
		
		Return New COMObject(CommonUseClientServer.COMConnectorName());
		
	#EndIf
	
EndFunction

// Establishes a connection to the server agent.
//
// Parameters:
//  COMConnector - COMObject
//  V8*.ComConnector, ServerAgentAddress - String, the network address
//  of the server agent, ServerAgentPort - Number, the network port of the server agent (typical value 1540).
//
// Return value: COMObject that implements the interface IV8AgentConnection.
//
Function ConnectionToServerAgent(COMConnector, Val ServerAgentAddress, Val ServerAgentPort)
	
	StringConnectionToServerAgent = "tcp://" + ServerAgentAddress + ":" + Format(ServerAgentPort, "NG=0");
	ConnectionToServerAgent = COMConnector.ConnectAgent(StringConnectionToServerAgent);
	Return ConnectionToServerAgent;
	
EndFunction

// Returns the cluster of servers.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the IV8AgentConnection interface, ClusterPort - Number, the network port of the cluster
//  manager (typical value 1541), ClusterAdministratorName - String, the name of the
//  cluster administrator's account, ClusterAdministratorPassword - String, the password of the cluster administrator's account.
//
// Return value: COMObject that implements the IClusterInfo interface.
//
Function GetCluster(ConnectionToServerAgent, Val ClusterPort, Val ClusterAdministratorName, Val ClusterAdministratorPassword)
	
	For Each Cluster IN ConnectionToServerAgent.GetClusters() Do
		
		If Cluster.MainPort = ClusterPort Then
			
			ConnectionToServerAgent.Authenticate(Cluster, ClusterAdministratorName, ClusterAdministratorPassword);
			
			Return Cluster;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Cluster %2 is not found on server %1';ru='На рабочем сервере %1 не найден кластер %2'"),
		ConnectionToServerAgent.ConnectionString,
		ClusterPort);
	
EndFunction

// Establishes a connection to the working process.
//
// Parameters:
//  COMConnector - COMObject
//  V8*.ComConnector, ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COM Object that implements the interface IClusterInfo.
//
// Return value: COMObject that implements the interface IV8ServerConnection.
//
Function WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster)
	
	For Each WorkingProcess IN ConnectionToServerAgent.GetWorkingProcesses(Cluster) Do
		If WorkingProcess.Running AND WorkingProcess.IsEnable  Then
			ConnectionStringWithWorkingProcess = WorkingProcess.HostName + ":" + Format(WorkingProcess.MainPort, "NG=");
			Return COMConnector.ConnectWorkingProcess(ConnectionStringWithWorkingProcess);
		EndIf;
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Active processes are not found in server cluster %1:%2.';ru='В кластере серверов %1:%2 не найдено активных рабочих процессов.'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"));
	
EndFunction

// Returns infobase description.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, NameInCluster - String, the name of the infobase in the cluster of servers.
//
// Return value: COMObject that implements the interface IInfobaseShort.
//
Function GetIBDescription(ConnectionToServerAgent, Cluster, Val NameInCluster)
	
	For Each InfobaseDescription IN ConnectionToServerAgent.GetInfobases(Cluster) Do
		
		If InfobaseDescription.Name = NameInCluster Then
			
			Return InfobaseDescription;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Infobase ""%3"" was not found in server cluster %1:%2.';ru='В кластере серверов %1:%2 не найдена информационная база ""%3""!'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		NameInCluster
	);
	
EndFunction

// Return an infobase.
//
// Parameters:
//  WorkingProcessConnection - COMObject that implements
//  the interface IV8ServerConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, NameInCluster - String, the name of the
//  infobase in the cluster of servers, IBAdministratorName - String, the name
//  of the infobase administrator, IBAdministratorPassword - String, the password of the infobase administrator.
//
// Return value: COMObject that implements the interface IInfobaseInfo.
//
Function GetIB(WorkingProcessConnection, Cluster, Val NameInCluster, Val IBAdministratorName, Val IBAdministratorPassword)
	
	WorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
	
	For Each Infobase IN WorkingProcessConnection.GetInfobases() Do
		
		If Infobase.Name = NameInCluster Then
			
			If Not ValueIsFilled(Infobase.DBMS) Then
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='The administrator user name or password is incorrect in the cluster of servers %2:%3 in infobase %1 (name: ""%4"").';ru='Неправильные имя и пароль администратора информационной базы %1 в кластере серверов %2:%3 (имя: ""%4"").'"),
					NameInCluster,
					Cluster.HostName, Cluster.MainPort,
					IBAdministratorName);
				
			EndIf;
			
			Return Infobase;
			
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Infobase ""%3"" was not found in server cluster %1:%2.';ru='В кластере серверов %1:%2 не найдена информационная база ""%3""!'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		NameInCluster
	);
	
EndFunction

// Returns infobase sessions.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the IClusterInfo interface, Infobase - COMObject that implements
//  the interface IInfobaseInfo, Filter - Description of the session filtering conditions which descriptions must be received.
//    Variants:
//      1. Array of structures that describe conditions of the sessions filtering. Fields of structures included in the array:
//        Property - String, the name of the property used for filtering. Possible values - see
//          Return value of
//        the function ClusterAdministrationClientServer.SessionProperties(), ComparisonType - value of the systematic enum ComparisonType, kind of comparing
//          sessions values with the specified in the filter condition. Possible values:
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
//          with which the value of corresponding session property is compared. When ComparisonType.InList
//          and ComparisonType.NotInList shall be passed as the ValueList or Array values that contains
//          the set of values with which the comparison will be done. When ComparisonType.Period,
//          ComparisonType.PeriodIncludingBorders, ComparisonType.IntervalIncludingLowerBound and ComparisonType.IntervalIncludingUpperBound shall be
//          passed as the structures with the From and To fields the values of which form
//          the period
//    that will be used for the comparison to be done, 2. Structure (simplified version), key - Name of the session's property (see above), value - the
//    value with which the comparison is executed. When using this option of the filter description, the
//    comparison
//  is always done by equality, Descriptions - Boolean if value is False, the function returns the array
//    of COMObjects that implement the ISessionInfo interface, else - array of structures that describe the properties of the sessions (fields of structures - see return value of the function.
//    ClusterAdministrationClientServer.SessionProperties()).
//
// Return value: Array(COMObject), Array(Structure).
//
Function GetSessions(ConnectionToServerAgent, Cluster, Infobase, Val Filter = Undefined, Val description = False)
	
	Sessions = New Array;
	
	Dictionary = SessionsPropertiesDictionary();
	
	For Each Session IN ConnectionToServerAgent.GetInfobaseSessions(Cluster, Infobase) Do
		
		SessionDescription = COMAdministratorObjectModelObjectDescription(Session, Dictionary);
		
		If ClusterAdministrationClientServer.VerifyFilterConditions(SessionDescription, Filter) Then
			
			If description Then
				Sessions.Add(SessionDescription);
			Else
				Sessions.Add(Session);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Sessions;
	
EndFunction

// Returns connections to the infobase.
//
// Parameters:
//  COMConnector - COMObject
//  V8*.ComConnector, ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, NameInCluster - String, the name of the
//  infobase in the cluster of servers, IBAdministratorName - String, the name
//  of the infobase administrator, IBAdministratorPassword - String, the password of
//  the infobase administrator, Filter - Description of the connection filtering conditions, descriptions of which must be received.
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
//    comparison
//  is always done by equality, Descriptions - Boolean if value is False, the function returns the
//             array of COMObjects that implement the IConnectionShort interface, else - array of structures that describe the connections properties (fields of structures - see
//             return value of the function.
//    ClusterAdministrationClientServer.ConnectionProperties()).
//
// Return value: Array(COMObject), Array(Structure).
//
Function GetConnections(COMConnector, ConnectionToServerAgent, Cluster, InfobaseAdministrationParameters, Val Filter = Undefined, Val description = False)
	
	NameInCluster = InfobaseAdministrationParameters.NameInCluster;
	IBAdministratorName = InfobaseAdministrationParameters.NameAdministratorInfobase;
	IBAdministratorPassword = InfobaseAdministrationParameters.PasswordAdministratorInfobase;
	
	connection = New Array();
	Dictionary = ConnectionsPropertiesDictionary();
	
	WorkingProcessConnection = WorkingProcessConnection(COMConnector, ConnectionToServerAgent, Cluster);
	
	WorkingProcessConnection.AddAuthentication(IBAdministratorName, IBAdministratorPassword);
	
	For Each Infobase IN WorkingProcessConnection.GetInfobases() Do
		
		If Infobase.Name = NameInCluster Then
			
			For Each Join IN WorkingProcessConnection.GetInfobaseConnections(Infobase) Do
				
				ConnectionDescription = COMAdministratorObjectModelObjectDescription(Join, Dictionary);
				
				If ClusterAdministrationClientServer.VerifyFilterConditions(ConnectionDescription, Filter) Then
					
					If description Then
						connection.Add(ConnectionDescription);
					Else
						connection.Add(New Structure("ConnectionWithWorkingProcess, Connection", WorkingProcessConnection, Join));
					EndIf;
					
				EndIf;
			
			EndDo;
			
			
		EndIf;
		
	EndDo;
	
	Return connection;
	
EndFunction

// Returns a security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: COMObject that implements the interface ISecurityProfile.
//
Function GetSecurityProfile(ConnectionToServerAgent, Cluster, ProfileName)
	
	For Each SecurityProfile IN ConnectionToServerAgent.GetSecurityProfiles(Cluster) Do
		
		If SecurityProfile.Name = ProfileName Then
			Return SecurityProfile;
		EndIf;
		
	EndDo;
	
	Raise StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en='Security profile ""%3"" is not found in server cluster %1:%2.';ru='В кластере серверов %1:%2 не найден профиль безопасности ""%3""!'"),
		Cluster.HostName,
		Format(Cluster.MainPort, "NG=0"),
		ProfileName
	);
	
EndFunction

// Returns the virtual directories that are allowed in the security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: Array(COMObject) - array of COM
// objects that implement the interface ISecurityProfileVirtualDirectory.
//
Function GetVirtualDirectories(ConnectionToServerAgent, Cluster, ProfileName)
	
	VirtualDirectories = New Array();
	
	For Each VirtualDirectory IN ConnectionToServerAgent.GetSecurityProfileVirtualDirectories(Cluster, ProfileName) Do
		
		VirtualDirectories.Add(VirtualDirectory);
		
	EndDo;
	
	Return VirtualDirectories;
	
EndFunction

// Returns COM classes that are allowed in the security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: Array(COMObject) - array of COM objects that implements the interface ISecurityProfileCOMClass.
//
Function GetCOMClasses(ConnectionToServerAgent, Cluster, ProfileName)
	
	COMClasses = New Array();
	
	For Each COMClass IN ConnectionToServerAgent.GetSecurityProfileCOMClasses(Cluster, ProfileName) Do
		
		COMClasses.Add(COMClass);
		
	EndDo;
	
	Return COMClasses;
	
EndFunction

// Returns external components that are allowed in the security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: Array(COMObject) - array of COM objects that implements the interface ISecurityProfileAddIn.
//
Function GetExternalComponents(ConnectionToServerAgent, Cluster, ProfileName)
	
	ExternalComponents = New Array();
	
	For Each ExternalComponent IN ConnectionToServerAgent.GetSecurityProfileAddIns(Cluster, ProfileName) Do
		
		ExternalComponents.Add(ExternalComponent);
		
	EndDo;
	
	Return ExternalComponents;
	
EndFunction

// Returns the external modules that are allowed in the security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: Array(COMObject) - array of COM objects that implement the interface ISecurityProfileExternalModule.
//
Function GetExternalModules(ConnectionToServerAgent, Cluster, ProfileName)
	
	ExternalModules = New Array();
	
	For Each ExternalModule IN ConnectionToServerAgent.GetSecurityProfileUnSafeExternalModules(Cluster, ProfileName) Do
		
		ExternalModules.Add(ExternalModule);
		
	EndDo;
	
	Return ExternalModules;
	
EndFunction

// Returns the OS applications allowed in the security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: Array(COMObject) - array of COM objects that implement the interface ISecurityProfileApplication.
//
Function GetOSApplications(ConnectionToServerAgent, Cluster, ProfileName)
	
	OSApplications = New Array();
	
	For Each OSApplication IN ConnectionToServerAgent.GetSecurityProfileApplications(Cluster, ProfileName) Do
		
		OSApplications.Add(OSApplication);
		
	EndDo;
	
	Return OSApplications;
	
EndFunction

// Returns the OS applications allowed in the security profile.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the interface IClusterInfo, ProfileName - String, the name of the security profile.
//
// Return value: Array(COMObject) - array of COM
// objects that implement the interface ISecurityProfileInternetResource.
//
Function GetInternetResources(ConnectionToServerAgent, Cluster, ProfileName)
	
	InternetResources = New Array();
	
	For Each InternetResource IN ConnectionToServerAgent.GetSecurityProfileInternetResources(Cluster, ProfileName) Do
		
		InternetResources.Add(InternetResource);
		
	EndDo;
	
	Return InternetResources;
	
EndFunction

// Overwrites the properties of the security profile passed.
//
// Parameters:
//  ConnectionToServerAgent - COMObject that implements
//  the interface IV8AgentConnection, Cluster - COMObject that implements
//  the Interface IClusterInfo, SecurityProfile - COMObject that implements
//  the interface ISecurityProfile, SecurityProfileProperties - Structure that describes the security profile. Content - see
//    ClusterAdministrationClientServer.SecurityProfileProperties().
//
Procedure ApplySecurityProfilePropertiesChanges(ConnectionToServerAgent, Cluster, SecurityProfile, SecurityProfileProperties)
	
	FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
		SecurityProfile,
		SecurityProfileProperties,
		SecurityProfilePropertiesDictionary());
	
	ProfileName = SecurityProfileProperties.Name;
	
	ConnectionToServerAgent.RegSecurityProfile(Cluster, SecurityProfile);
	
	// Virtual directories
	DeletedVirtualDirectories = GetVirtualDirectories(ConnectionToServerAgent, Cluster, ProfileName);
	For Each DeletedVirtualDirectory IN DeletedVirtualDirectories Do
		ConnectionToServerAgent.UnregSecurityProfileVirtualDirectory(
			Cluster,
			ProfileName,
			DeletedVirtualDirectory.Alias
		);
	EndDo;
	GeneratedVirtualDirectories = SecurityProfileProperties.VirtualDirectories;
	For Each GeneratedVirtualDirectory IN GeneratedVirtualDirectories Do
		VirtualDirectory = ConnectionToServerAgent.CreateSecurityProfileVirtualDirectory();
		FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
			VirtualDirectory,
			GeneratedVirtualDirectory,
			VirtualDirectoryPropertiesDictionary()
		);
		ConnectionToServerAgent.RegSecurityProfileVirtualDirectory(Cluster, ProfileName, VirtualDirectory);
	EndDo;
	
	// Allowed COM classes
	DeletedCOMClasses = GetCOMClasses(ConnectionToServerAgent, Cluster, ProfileName);
	For Each DeletedCOMClass IN DeletedCOMClasses Do
		ConnectionToServerAgent.UnregSecurityProfileCOMClass(
			Cluster,
			ProfileName,
			DeletedCOMClass.Name
		);
	EndDo;
	GeneratedCOMClasses = SecurityProfileProperties.COMClasses;
	For Each GeneratedCOMClass IN GeneratedCOMClasses Do
		COMClass = ConnectionToServerAgent.CreateSecurityProfileCOMClass();
		FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
			COMClass,
			GeneratedCOMClass,
			COMClassPropertiesDictionary()
		);
		ConnectionToServerAgent.RegSecurityProfileCOMClass(Cluster, ProfileName, COMClass);
	EndDo;
	
	// External components
	DeletedExternalComponents = GetExternalComponents(ConnectionToServerAgent, Cluster, ProfileName);
	For Each DeletedExternalComponent IN DeletedExternalComponents Do
		ConnectionToServerAgent.UnregSecurityProfileAddIn(
			Cluster,
			ProfileName,
			DeletedExternalComponent.Name
		);
	EndDo;
	GeneratedExternalComponents = SecurityProfileProperties.ExternalComponents;
	For Each GeneratedExternalComponent IN GeneratedExternalComponents Do
		ExternalComponent = ConnectionToServerAgent.CreateSecurityProfileAddIn();
		FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
			ExternalComponent,
			GeneratedExternalComponent,
			ExternalComponentPropertiesDictionary()
		);
		ConnectionToServerAgent.RegSecurityProfileAddIn(Cluster, ProfileName, ExternalComponent);
	EndDo;
	
	// External modules
	DeletedExternalModules = GetExternalModules(ConnectionToServerAgent, Cluster, ProfileName);
	For Each DeletedExternalModule IN DeletedExternalModules Do
		ConnectionToServerAgent.UnregSecurityProfileUnSafeExternalModule(
			Cluster,
			ProfileName,
			DeletedExternalModule.Name
		);
	EndDo;
	GeneratedExternalModules = SecurityProfileProperties.ExternalModules;
	For Each GeneratedExternalModule IN GeneratedExternalModules Do
		ExternalModule = ConnectionToServerAgent.CreateSecurityProfileUnSafeExternalModule();
		FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
			ExternalModule,
			GeneratedExternalModule,
			ExternalModulePropertiesDictionary()
		);
		ConnectionToServerAgent.RegSecurityProfileUnSafeExternalModule(Cluster, ProfileName, ExternalModule);
	EndDo;
	
	// OS applications
	DeletedOSApplications = GetOSApplications(ConnectionToServerAgent, Cluster, ProfileName);
	For Each DeletedOSApplication IN DeletedOSApplications Do
		ConnectionToServerAgent.UnregSecurityProfileApplication(
			Cluster,
			ProfileName,
			DeletedOSApplication.Name
		);
	EndDo;
	GeneratedOSApplications = SecurityProfileProperties.OSApplications;
	For Each GeneratedOSApplication IN GeneratedOSApplications Do
		OSApplication = ConnectionToServerAgent.CreateSecurityProfileApplication();
		FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
			OSApplication,
			GeneratedOSApplication,
			OSApplicationPropertiesDictionary()
		);
		ConnectionToServerAgent.RegSecurityProfileApplication(Cluster, ProfileName, OSApplication);
	EndDo;
	
	// Internet resources
	DeletedInternetResources = GetInternetResources(ConnectionToServerAgent, Cluster, ProfileName);
	For Each DeletedInternetResource IN DeletedInternetResources Do
		ConnectionToServerAgent.UnregSecurityProfileInternetResource(
			Cluster,
			ProfileName,
			DeletedInternetResource.Name
		);
	EndDo;
	GeneratedInternetResources = SecurityProfileProperties.InternetResources;
	For Each GeneratedInternetResource IN GeneratedInternetResources Do
		InternetResource = ConnectionToServerAgent.CreateSecurityProfileInternetResource();
		FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(
			InternetResource,
			GeneratedInternetResource,
			InternetResourcePropertiesDictionary()
		);
		ConnectionToServerAgent.RegSecurityProfileInternetResource(Cluster, ProfileName, InternetResource);
	EndDo;
	
EndProcedure

// Forms the description of the object of the COM administrator object model.
//
// Parameters:
//  Object - COMObject,
//  Dictionary - Maping contains correspondence of the object properties and in the description:
//    Key - Property name in
//    the description, Value - The name of the object property.
//
// Return value: Structure, the object's description of
//  the COM administrator object model based on the provided dictionary.
//
Function COMAdministratorObjectModelObjectDescription(Val Object, Val Dictionary)
	
	Description = New Structure();
	For Each DictionaryFragment IN Dictionary Do
		If ValueIsFilled(Object[DictionaryFragment.Value]) Then
			Description.Insert(DictionaryFragment.Key, Object[DictionaryFragment.Value]);
		Else
			Description.Insert(DictionaryFragment.Key, Undefined);
		EndIf;
	EndDo;
	
	Return Description;
	
EndFunction

// Form objects descriptions of the object model COM administrator.
//
// Parameters:
//  Objects - Array(COMObject),
//  Dictionary - Maping contains correspondence of the object properties and in the description:
//    Key - Property name in
//    the description, Value - The name of the object property.
//
// Return value: Array(Structure), the object's descriptions of
//  the COM administrator object model based on the provided dictionary.
//
Function COMAdministratorObjectModelObjectDescriptions(Val Objects, Val Dictionary)
	
	description = New Array();
	
	For Each Object IN Objects Do
		description.Add(COMAdministratorObjectModelObjectDescription(Object, Dictionary));
	EndDo;
	
	Return description;
	
EndFunction

// Fill the object's properties of the COM administrator
//  object model based on the properties from the passed description.
//
// Parameters:
//  Object - COMObject,
//  Description - Structure, description that is used for
//  filling the properties of the object, Dictionary - Maping contains correspondence of the object properties and in the description:
//    Key - Property name in
//    the description, Value - The name of the object property.
//
Procedure FillObjectPropertiesObjectModelOfCOMAdministratorByDescription(Object, Val Description, Val Dictionary)
	
	For Each DictionaryFragment IN Dictionary Do
		
		PropertyName = DictionaryFragment.Value;
		PropertyValue = Description[DictionaryFragment.Key];
		
		Object[PropertyName] = PropertyValue;
		
	EndDo;
	
EndProcedure

// Returns the compliance of the infobase properties
//  names describing the state sessions and scheduled jobs locking
//  for the structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name
//         in
//  API (see ClusterAdministrationClientServer.SessionsAndScheduledJobsLockingProperties()), Value - String, the name of the object property.
//
Function SessionsAndScheduledJobsLockingPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("SessionsLock", "SessionsDenied");
	Result.Insert("DateFrom", "DeniedFrom");
	Result.Insert("DateTo", "DeniedTo");
	Result.Insert("Message", "DeniedMessage");
	Result.Insert("KeyCode", "KeyCode");
	Result.Insert("LockParameter", "DeniedParameter");
	Result.Insert("ScheduledJobsLocking", "ScheduledJobsDenied");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the infobase sessions properties names for the structures
//  that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.SessionProperties()), Value - String, the name of the object property.
//
Function SessionsPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "SessionID");
	Result.Insert("UserName", "UserName");
	Result.Insert("ClientComputerName", "Host");
	Result.Insert("ClientApplicationIdentifier", "AppID");
	Result.Insert("LanguageIdentifier", "Locale");
	Result.Insert("SessionCreationTime", "StartedAt");
	Result.Insert("LastSessionActivityMoment", "LastActiveAt");
	Result.Insert("DBMSLocking", "blockedByDBMS");
	Result.Insert("Block", "blockedByLS");
	Result.Insert("Transferred", "bytesAll");
	Result.Insert("PassedFor5Minutes", "bytesLast5Min");
	Result.Insert("ServerCalls", "callsAll");
	Result.Insert("ServerCallsFor5Minutes", "callsLast5Min");
	Result.Insert("ServerCallsDuration", "durationAll");
	Result.Insert("CurrentServerCallDuration", "durationCurrent");
	Result.Insert("ServerCallsDurationFor5Minutes", "durationLast5Min");
	Result.Insert("PassedDBMS", "dbmsBytesAll");
	Result.Insert("DBMSPassedIn5Minutes", "dbmsBytesLast5Min");
	Result.Insert("DBMSCallsDuration", "durationAllDBMS");
	Result.Insert("CurrentDBMSCallDuration", "durationCurrentDBMS");
	Result.Insert("DBMSCallsDurationFor5Minutes", "durationLast5MinDBMS");
	Result.Insert("ConnectionDBMS", "dbProcInfo");
	Result.Insert("ConnectionTimeDBMS", "dbProcTook");
	Result.Insert("CaptureDBMSConnectionMoment", "dbProcTookAt");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the infobase connections properties names for the structures that
//  are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.ConnectionProperties()), Value - String, the name of the object property.
//
Function ConnectionsPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "ConnID");
	Result.Insert("UserName", "UserName");
	Result.Insert("ClientComputerName", "HostName");
	Result.Insert("ClientApplicationIdentifier", "AppID");
	Result.Insert("ConnectionMoment", "ConnectedAt");
	Result.Insert("InfobaseConnectionMode", "IBConnMode");
	Result.Insert("DatabaseConnectionMode", "dbConnMode");
	Result.Insert("DBMSLocking", "blockedByDBMS");
	Result.Insert("Transferred", "bytesAll");
	Result.Insert("PassedFor5Minutes", "bytesLast5Min");
	Result.Insert("ServerCalls", "callsAll");
	Result.Insert("ServerCallsFor5Minutes", "callsLast5Min");
	Result.Insert("PassedDBMS", "dbmsBytesAll");
	Result.Insert("DBMSPassedIn5Minutes", "dbmsBytesLast5Min");
	Result.Insert("ConnectionDBMS", "dbProcInfo");
	Result.Insert("TimeDBMS", "dbProcTook");
	Result.Insert("CaptureDBMSConnectionMoment", "dbProcTookAt");
	Result.Insert("ServerCallsDuration", "durationAll");
	Result.Insert("DBMSCallsDuration", "durationAllDBMS");
	Result.Insert("CurrentServerCallDuration", "durationCurrent");
	Result.Insert("CurrentDBMSCallDuration", "durationCurrentDBMS");
	Result.Insert("ServerCallsDurationFor5Minutes", "durationLast5Min");
	Result.Insert("DBMSCallsDurationFor5Minutes", "durationLast5MinDBMS");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the security profile properties names for the
//  structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.SecurityProfileProperties()), Value - String, the name of the object property.
//
Function SecurityProfilePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Description", "Descr");
	Result.Insert("ProfileOfSafeMode", "SafeModeProfile");
	Result.Insert("FullAccessToPrivilegedMode", "PrivilegedModeInSafeModeAllowed");
	
	Result.Insert("FullAccessToFileSystem", "FileSystemFullAccess");
	Result.Insert("COMObjectsFullAccess", "COMFullAccess");
	Result.Insert("FullAccessToExternalComponents", "AddInFullAccess");
	Result.Insert("FullAccessToExternalModules", "UnSafeExternalModuleFullAccess");
	Result.Insert("FullAccessToOperatingSystemApplications", "ExternalAppFullAccess");
	Result.Insert("FullAccessToInternetResources", "InternetFullAccess");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the virtual directory properties names for the
//  structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.VirtualDirectoryProperties()), Value - String, the name of the object property.
//
Function VirtualDirectoryPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("LogicalURL", "Alias");
	Result.Insert("PhysicalURL", "PhysicalPath");
	
	Result.Insert("Description", "Descr");
	
	Result.Insert("DataReading", "AllowedRead");
	Result.Insert("DataRecording", "AllowedWrite");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the COM class properties names for
//  the structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.COMClassProperties()), Value - String, the name of the object property.
//
Function COMClassPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Description", "Descr");
	
	Result.Insert("FileMoniker", "FileName");
	Result.Insert("CLSID", "ObjectUUID");
	Result.Insert("Computer", "ComputerName");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the external component properties names for the
//  structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.ExternalComponentProperties()), Value - String, the name of the object property.
//
Function ExternalComponentPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Description", "Descr");
	
	Result.Insert("HashSum", "AddInHash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the external module properties names for the
//  structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.ExternalModuleProperties()), Value - String, the name of the object property.
//
Function ExternalModulePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Description", "Descr");
	
	Result.Insert("HashSum", "ExternalModuleHash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the operating system application properties names for the
//  structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.OSApplicationProperties()), Value - String, the name of the object property.
//
Function OSApplicationPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Description", "Descr");
	
	Result.Insert("TemplateLaunchRows", "MaskCommand");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the compliance of the internet resource properties names for
//  the structures that are used in API and objects of the COM administrator object models.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.InternetResourceProperties()), Value - String, the name of the object property.
//
Function InternetResourcePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "Name");
	Result.Insert("Description", "Descr");
	
	Result.Insert("Protocol", "Protocol");
	Result.Insert("Address", "Address");
	Result.Insert("Port", "Port");
	
	Return New FixedStructure(Result);
	
EndFunction

#EndRegion