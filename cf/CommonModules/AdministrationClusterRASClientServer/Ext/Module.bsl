////////////////////////////////////////////////////////////////////////////////
// The subsystem "Basic functionality".
// Client and server procedures and functions of common purpose:
// - Implement the application administration of the
//   servers cluster via the administer server.
//
////////////////////////////////////////////////////////////////////////////////

#If Not WebClient Then

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
	
	Result = InfobaseProperties(ClusterAdministrationParameters, InfobaseAdministrationParameters, SessionsAndScheduledJobsLockingPropertiesDictionary());
	
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
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters(),
//  SessionsAndJobsBlockProperties - Structure describing the state sessions
//    and scheduled jobs locking, Description - see ClusterAdministrationClientServer.SessionsAndScheduledJobsBlockProperties().
//
Procedure SetInfobaseSessionsAndJobsLocking(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val SessionsAndJobsLockingProperties) Export
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		SessionsAndScheduledJobsLockingPropertiesDictionary(),
		SessionsAndJobsLockingProperties);
	
EndProcedure

// Verify the correctness of the administration parameters.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//    Parameter can be omitted when similar fields were specified in
//    the structure passed as the
//  ClusterAdministrationParameters, VerifyClusterAdministrationParameters parameter value - Boolean, flag showing the
//                                                necessity
//  to verify the parameters of the cluster administration,
// VerifyInfobaseAdministrationParameters - Boolean, flag showing
//                                                          the necessity to verify the parameters of the cluster administration.
//
Procedure CheckAdministrationParameters(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters = Undefined,
	VerifyInfobaseAdministrationParameters = True,
	VerifyClusterAdministrationParameters = True) Export
	
	
	If VerifyClusterAdministrationParameters Or VerifyInfobaseAdministrationParameters Then
		
		ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
		WorkingProcesses = GetWorkflows(ClusterIdentifier, ClusterAdministrationParameters);
		
	EndIf;
	
	If VerifyInfobaseAdministrationParameters Then
		
		Dictionary = New Structure();
		Dictionary.Insert("SessionsLock", "sessions-deny");
		
		IBProperties = InfobaseProperties(ClusterAdministrationParameters, InfobaseAdministrationParameters, Dictionary);
		
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
	
	Dictionary = New Structure("JobsLock", "scheduled-jobs-deny");
	
	IBProperties = InfobaseProperties(ClusterAdministrationParameters, InfobaseAdministrationParameters, Dictionary);
	Return IBProperties.JobsLock;
	
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
	
	Dictionary = New Structure("JobsLock", "scheduled-jobs-deny");
	Properties = New Structure("JobsLock", ScheduledJobsLocking);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Dictionary,
		Properties);
	
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
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	InfobaseIdentifier = GetInfobase(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	Return GetSessions(ClusterIdentifier, ClusterAdministrationParameters, InfobaseIdentifier, Filter);
	
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
	
	Pattern = "%rac session --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% terminate";
	
	Parameters = New Map();
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	InfobaseIdentifier = GetInfobase(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	
	Sessions = GetSessions(ClusterIdentifier, ClusterAdministrationParameters, InfobaseIdentifier, Filter, False);
	For Each Session IN Sessions Do
		
		Try
			
			Parameters.Insert("session", Session.Get("session"));
			RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
			
		Except
			
			// Session may have already been terminated by the time of rac session terminate call.
			
			FilterSessions = New Structure();
			FilterSessions.Insert("Number", Session.Get("session-id"));
			
			If GetSessions(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters, FilterSessions, True).Count() > 0 Then
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
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	InfobaseIdentifier = GetInfobase(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	Return GetConnections(ClusterIdentifier, ClusterAdministrationParameters, InfobaseIdentifier, InfobaseAdministrationParameters, Filter, True);
	
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
	
	Pattern = "%rac connection --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% disconnect";
	
	Parameters = New Structure;
	
	Parameters = New Map();
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	InfobaseIdentifier = GetInfobase(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	Parameters.Insert("infobase", InfobaseIdentifier);
	FillAuthenticationParametersToIB(InfobaseAdministrationParameters, Parameters);
	
	connection = GetConnections(ClusterIdentifier, ClusterAdministrationParameters, InfobaseIdentifier, InfobaseAdministrationParameters, Filter, False);
	For Each Join IN connection Do
		
		Try
			
			Parameters.Insert("process", Join.Get("process"));
			Parameters.Insert("connection", Join.Get("connection"));
			RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
			
		Except
			
			// Connection may have already been terminated by the time of rac connection disconnect call.
			
			ConnectionsFilter = New Structure();
			ConnectionsFilter.Insert("Number", Join.Get("conn-id"));
			
			ConnectionsDescriptions = GetConnections(
				ClusterIdentifier,
				ClusterAdministrationParameters,
				InfobaseIdentifier,
				InfobaseAdministrationParameters,
				ConnectionsFilter,
				True);
			
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
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "security-profile-name");
	
	Result = InfobaseProperties(ClusterAdministrationParameters, InfobaseAdministrationParameters, Dictionary).ProfileName;
	If ValueIsFilled(Result) Then
		Return Result;
	Else
		Return "";
	EndIf;
	
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
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "safe-mode-security-profile-name");
	
	Result = InfobaseProperties(ClusterAdministrationParameters, InfobaseAdministrationParameters, Dictionary).ProfileName;
	If ValueIsFilled(Result) Then
		Return Result;
	Else
		Return "";
	EndIf;
	
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
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "security-profile-name");
	
	Values = New Structure();
	Values.Insert("ProfileName", ProfileName);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Dictionary,
		Values);
	
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
	
	Dictionary = New Structure();
	Dictionary.Insert("ProfileName", "safe-mode-security-profile-name");
	
	Values = New Structure();
	Values.Insert("ProfileName", ProfileName);
	
	SetInfobaseProperties(
		ClusterAdministrationParameters,
		InfobaseAdministrationParameters,
		Dictionary,
		Values);
	
EndProcedure

// Verifies the existence of the security profile in the cluster of servers.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile the existence of which is verified.
//
Function SecurityProfileExists(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterIdentifier, ClusterAdministrationParameters, Filter);
	
	Return (SecurityProfiles.Count() = 1);
	
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
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterIdentifier, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Security profile %2 is not registered in server cluster %1 .';ru='В кластере серверов %1 не зарегистрирован профиль безопасности %2!'"), ClusterIdentifier, ProfileName);
	EndIf;
	
	Result = SecurityProfiles[0];
	Result = ConvertAccessListsUsagePropertiesValues(Result);
	
	// Virtual directories
	Result.Insert("VirtualDirectories",
		GetVirtualDirectories(ClusterIdentifier, ClusterAdministrationParameters, ProfileName));
	
	// Allowed COM classes
	Result.Insert("COMClasses",
		GetAllowedCOMClasses(ClusterIdentifier, ClusterAdministrationParameters, ProfileName));
	
	// External components
	Result.Insert("ExternalComponents",
		GetAllowedExternalComponents(ClusterIdentifier, ClusterAdministrationParameters, ProfileName));
	
	// External modules
	Result.Insert("ExternalModules",
		GetAllowedExternalModules(ClusterIdentifier, ClusterAdministrationParameters, ProfileName));
	
	// OS applications
	Result.Insert("OSApplications",
		GetAllowedOSApplications(ClusterIdentifier, ClusterAdministrationParameters, ProfileName));
	
	// Internet resources
	Result.Insert("InternetResources",
		GetAllowedInternetResources(ClusterIdentifier, ClusterAdministrationParameters, ProfileName));
	
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
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterIdentifier, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() = 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Security profile %2 is already registered in server cluster %1.';ru='В кластере серверов %1 уже зарегистрирован профиль безопасности %2!'"), ClusterIdentifier, ProfileName);
	EndIf;
	
	UpdateSecurityProfilesProperties(ClusterAdministrationParameters, SecurityProfileProperties, False);
	
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
	
	ProfileName = SecurityProfileProperties.Name;
	
	Filter = New Structure("Name", ProfileName);
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	
	SecurityProfiles = GetSecurityProfiles(ClusterIdentifier, ClusterAdministrationParameters, Filter);
	
	If SecurityProfiles.Count() <> 1 Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Security profile %2 is not registered in server cluster %1 .';ru='В кластере серверов %1 не зарегистрирован профиль безопасности %2!'"), ClusterIdentifier, ProfileName);
	EndIf;
	
	UpdateSecurityProfilesProperties(ClusterAdministrationParameters, SecurityProfileProperties, True);
	
EndProcedure

// Delete the security profile.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, the name of the security profile.
//
Procedure DeleteSecurityProfile(Val ClusterAdministrationParameters, Val ProfileName) Export
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% remove --name=%name%";
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	
	RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns descriptions of servers clusters.
//
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  Filter - Structure, parameters of servers clusters filtering.
//
// Return value: Array(Structure).
//
Function GetClusters(Val ClusterAdministrationParameters, Val Filter = Undefined)
	
	Pattern = "%rac cluster list";
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters);
	Result = OutputParser(OutputFlow, Undefined, Filter);
	Return Result;
	
EndFunction

// Returns an internal identifier of the servers cluster.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters().
//
// Returns - String, internal identifier of servers cluster.
//
Function GetCluster(Val ClusterAdministrationParameters)
	
	Filter = New Structure("port", ClusterAdministrationParameters.ClusterPort);
	
	Clusters = GetClusters(ClusterAdministrationParameters, Filter);
	
	If Clusters.Count() = 1 Then
		Return Clusters[0].Get("cluster");
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Servers cluster with %1 port is not found';ru='Не обнаружен кластер серверов с портом %1'"), ClusterAdministrationParameters.ClusterPort);
	EndIf;
	
EndFunction

// Returns the description of production servers.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  Filter - Structure, parameters of the production servers filtering.
//
// Return value: Array(Structure).
//
Function GetProductionServers(Val ClusterIdentifier, Val ClusterAdministrationParameters, Filter = Undefined)
	
	Pattern = "%rac server --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputFlow, Undefined, Filter);
	Return Result;
	
EndFunction

// Returns descriptions of the infobases.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  Filter - Structure, parameters of the infobases filtering.
//
// Return value: Array(Structure).
//
Function GetInfobases(Val ClusterIdentifier, Val ClusterAdministrationParameters, Filter = Undefined)
	
	Pattern = "%rac infobase summary --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputFlow, Undefined, Filter);
	Return Result;
	
EndFunction

// Returns an internal identifier of the infobase.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//
// Return value: String, internal identifier of the servers cluster.
//
Function GetInfobase(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val InformationBaseAdministrationParameters)
	
	Filter = New Structure("name", InformationBaseAdministrationParameters.NameInCluster);
	
	Infobases = GetInfobases(ClusterIdentifier, ClusterAdministrationParameters, Filter);
	
	If Infobases.Count() = 1 Then
		Return Infobases[0].Get("infobase");
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Infobase %2 is not registered in server cluster %1.';ru='В кластере серверов %1 не зарегистрирована информационная база %2!'"), ClusterIdentifier, InformationBaseAdministrationParameters.NameInCluster);
	EndIf;
	
EndFunction

// Returns the descriptions of workflows.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  Filter - Structure, parameters of the workflow filtering.
//
// Return value: Array(Structure).
//
Function GetWorkflows(Val ClusterIdentifier, Val ClusterAdministrationParameters, Filter = Undefined)
	
	Pattern = "%rac process --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list --server=%server%";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	Result = New Array();
	WorkingServers = GetProductionServers(ClusterIdentifier, ClusterAdministrationParameters);
	For Each ServerName IN WorkingServers Do
		Parameters.Insert("server", ServerName.Get("server"));
		OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
		ServerWorkflows = OutputParser(OutputFlow, Undefined, Filter);
		For Each WorkingProcess IN ServerWorkflows Do
			If WorkingProcess.Get("running") = "yes" AND WorkingProcess.Get("is-enable") = "yes" Then
				Result.Add(WorkingProcess);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the descriptions of infobase sessions.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseIdentifier - String, internal identifier of
//  the infobase, InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
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
//    value with which the comparison is executed. When this variant of the filter description is used,
//    the
//  comparison is always executed on the equality, UseDictionary - Boolean if True - return result will be filled in using the dictionary, otherwise, - without
//    usage.
//
// Return value: Array(Structure), Array(Map) - array of structures describing
// sessions properties (description of structures - see ClusterAdministrationClientServer.SessionProperties())
// or an array of matches that describe session properties in the rac utility notation (when UseDictionary = False).
//
Function GetSessions(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val InfobaseIdentifier, Filter = Undefined, Val UseDictionary = True) Export
	
	Pattern = "%rac session --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";	
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("infobase", InfobaseIdentifier);
	
	If UseDictionary Then
		Dictionary = SessionsPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, SessionsPropertiesDictionary());
	EndIf;
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputFlow, Dictionary, Filter);
	Return Result;
	
EndFunction

// Returns the descriptions of the infobase connections.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseIdentifier - String, internal identifier of
//  the infobase, InfobaseAdministrationParameters - Structure that describes the parameters of
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
//    value with which the comparison is executed. When this variant of the filter description is used,
//    the
//  comparison is always executed on the equality, UseDictionary - Boolean if True - return result will be filled in using the dictionary, otherwise, - without
//    usage.
//
// Return value: Array(Structure), Array(Map) - array of structures describing
// the connection properties (description of structures - see ClusterAdministrationClientServer.ConnectionProperties())
// or an array of matches that describe connection properties in the rac utility notation (when UseDictionary = False).
//
Function GetConnections(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val InfobaseIdentifier, Val InformationBaseAdministrationParameters, Val Filter = Undefined, Val UseDictionary = False) Export
	
	Pattern = "%rac connection --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("infobase", InfobaseIdentifier);
	FillAuthenticationParametersToIB(InformationBaseAdministrationParameters, Parameters);
	
	If UseDictionary Then
		Dictionary = ConnectionsPropertiesDictionary();
	Else
		Dictionary = Undefined;
		Filter = FilterToRacNotation(Filter, ConnectionsPropertiesDictionary());
	EndIf;
	
	Result = New Array();
	WorkingProcesses = GetWorkflows(ClusterIdentifier, ClusterAdministrationParameters);
	
	For Each WorkingProcess IN WorkingProcesses Do
		
		Parameters.Insert("process", WorkingProcess.Get("process"));
		OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
		ProductionProcessConnections = OutputParser(OutputFlow, Dictionary, Filter);
		For Each Join IN ProductionProcessConnections Do
			If Not UseDictionary Then
				Join.Insert("process", WorkingProcess.Get("process"));
			EndIf;
			Result.Add(Join);
		EndDo;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the properties values of the infobase.
//
// Parameters:
//  ClusterAdministrationParameters - Structure - describes parameters of connection to
//    the servers cluster, description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure - describes parameters of connection to
//    the infobase, description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//  Dictionary - Structure - match of properties names for API and flow of the rac utility output.
//
// Returns: 
//   Structure - description of the infobase made according to the passed dictionary.
//
Function InfobaseProperties(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val Dictionary)
	
	Pattern = "%rac infobase --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% info";
	
	Parameters = New Map();
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	InfobaseIdentifier = GetInfobase(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	Parameters.Insert("infobase", InfobaseIdentifier);
	FillAuthenticationParametersToIB(InfobaseAdministrationParameters, Parameters);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputFlow, Dictionary);
	Return Result[0];
	
EndFunction

// Sets values of the infobase properties
//
// Parameters:
//  ClusterAdministrationParameters - Structure - describes parameters of connection to
//    the servers cluster, description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  InfobaseAdministrationParameters - Structure - describes parameters of connection to
//    the infobase, description - see ClusterAdministrationClientServer.ClusterInfobaseAdministrationParameters(),
//  Dictionary - Structure - match of properties names for API and flow of the rac utility output.
//  PropertyValues - Structure - set values of the infobase properties:
//    * Key - name of property in
//    API notation, * Value - set value for the property.
//
Procedure SetInfobaseProperties(Val ClusterAdministrationParameters, Val InfobaseAdministrationParameters, Val Dictionary, Val PropertyValues)
	
	Pattern = "%rac infobase --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% update";
	
	Parameters = New Map();
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	InfobaseIdentifier = GetInfobase(ClusterIdentifier, ClusterAdministrationParameters, InfobaseAdministrationParameters);
	Parameters.Insert("infobase", InfobaseIdentifier);
	FillAuthenticationParametersToIB(InfobaseAdministrationParameters, Parameters);
	
	FillParametersByDictionary(Dictionary, PropertyValues, Parameters, Pattern);
	
	RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Returns descriptions of the security profiles.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  Filter - Structure, parameters of the security profiles filtering.
//
// Return value: Array(Structure).
//
Function GetSecurityProfiles(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val Filter = Undefined)
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% list";
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputFlow, SecurityProfilePropertiesDictionary(), Filter);
	Return Result;
	
EndFunction

// Returns descriptions of the virtual directories.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, Filter - Structure, parameters of virtual directory filtering.
//
// Return value: Array(Structure).
//
Function GetVirtualDirectories(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return GetAccessControlList(
		ClusterIdentifier,
		ClusterAdministrationParameters,
		ProfileName,
		"directory", // Not localized
		VirtualDirectoryPropertiesDictionary());
	
EndFunction

// Returns descriptions of COM classes.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, Filter - Structure, parameters of the COM classes filtering.
//
// Return value: Array(Structure).
//
Function GetAllowedCOMClasses(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return GetAccessControlList(
		ClusterIdentifier,
		ClusterAdministrationParameters,
		ProfileName,
		"com", // Not localized
		COMClassPropertiesDictionary());
	
EndFunction

// Returns the descriptions of external components.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, Filter - Structure, parameters of external components filtering.
//
// Return value: Array(Structure).
//
Function GetAllowedExternalComponents(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return GetAccessControlList(
		ClusterIdentifier,
		ClusterAdministrationParameters,
		ProfileName,
		"addin", // Not localized
		ExternalComponentPropertiesDictionary());
	
EndFunction

// Returns descriptions of external modules.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, Filter - Structure, parameters of the external modules filtering.
//
// Return value: Array(Structure).
//
Function GetAllowedExternalModules(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return GetAccessControlList(
		ClusterIdentifier,
		ClusterAdministrationParameters,
		ProfileName,
		"module", // Not localized
		ExternalModulePropertiesDictionary());
	
EndFunction

// Returns descriptions of OS applications.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, Filter - Structure, parameters of the OS applications filtering.
//
// Return value: Array(Structure).
//
Function GetAllowedOSApplications(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return GetAccessControlList(
		ClusterIdentifier,
		ClusterAdministrationParameters,
		ProfileName,
		"app", // Not localized
		OSApplicationPropertiesDictionary());
	
EndFunction

// Returns the descriptions of the Internet resources.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, Filter - Structure, parameters of the Internet resources filtering.
//
// Return value: Array(Structure).
//
Function GetAllowedInternetResources(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val Filter = Undefined)
	
	Return GetAccessControlList(
		ClusterIdentifier,
		ClusterAdministrationParameters,
		ProfileName,
		"inet", // Not localized
		InternetResourcePropertiesDictionary());
	
EndFunction

// Returns description of items of access control list.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, ListName - String, name of the list of access control (acl)
//  in the rac utility notation, Dictionary - Structure, map of properties names in flow of the rac utility output
//  and the required description, Filter - Structure, filter parameters of access control list items.
//
// Return value: Array(Structure).
//
Function GetAccessControlList(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val Filter = Undefined)
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name%";
	Pattern = StrReplace(Pattern, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	
	Parameters.Insert("name", ProfileName);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	Result = OutputParser(OutputFlow, Dictionary, Filter);
	Return Result;
	
EndFunction

// Updates the properties of the security profile (including the update of use and acls content).
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  SecurityProfileProperties - Structure describing the properties installed for
//    the security profile, Description - see ClusterAdministrationClientServer.SecurityProfileProperties().
//  ClearAccessControlLists - Boolean, check box of the preliminary clearance of the acls current content
//
Procedure UpdateSecurityProfilesProperties(Val ClusterAdministrationParameters, Val SecurityProfileProperties, Val ClearAccessControlLists)
	
	ProfileName = SecurityProfileProperties.Name;
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% update ";
	
	Parameters = New Map();
	
	ClusterIdentifier = GetCluster(ClusterAdministrationParameters);
	Parameters.Insert("cluster", ClusterIdentifier);
	
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	FillParametersByDictionary(SecurityProfilePropertiesDictionary(False), SecurityProfileProperties, Parameters, Pattern);
	
	RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	
	DictionaryPropertiesUsingAccessControlLists = UsagePropertiesDictionaryAccessControlList();
	For Each DictionaryFragment IN DictionaryPropertiesUsingAccessControlLists Do
		SetAccessControlListUsage(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, DictionaryFragment.Value, Not SecurityProfileProperties[DictionaryFragment.Key]);
	EndDo;
	
	// Virtual directories
	ListName = "directory";
	CurrentDictionary = VirtualDirectoryPropertiesDictionary();
	If ClearAccessControlLists Then
		DeletedVirtualDirectories = GetAccessControlList(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each DeletedVirtualDirectory IN DeletedVirtualDirectories Do
			DeleteAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, DeletedVirtualDirectory.LogicalURL);
		EndDo;
	EndIf;
	GeneratedVirtualDirectories = SecurityProfileProperties.VirtualDirectories;
	For Each GeneratedVirtualDirectory IN GeneratedVirtualDirectories Do
		CreateAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, GeneratedVirtualDirectory);
	EndDo;
	
	// Allowed COM classes
	ListName = "com";
	CurrentDictionary = COMClassPropertiesDictionary();
	If ClearAccessControlLists Then
		DeletedCOMClasses = GetAccessControlList(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each DeletedCOMClass IN DeletedCOMClasses Do
			DeleteAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, DeletedCOMClass.Name);
		EndDo;
	EndIf;
	GeneratedCOMClasses = SecurityProfileProperties.COMClasses;
	For Each GeneratedCOMClass IN GeneratedCOMClasses Do
		CreateAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, GeneratedCOMClass);
	EndDo;
	
	// External components
	ListName = "addin";
	CurrentDictionary = ExternalComponentPropertiesDictionary();
	If ClearAccessControlLists Then
		DeletedExternalComponents = GetAccessControlList(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each DeletedExternalComponent IN DeletedExternalComponents Do
			DeleteAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, DeletedExternalComponent.Name);
		EndDo;
	EndIf;
	GeneratedExternalComponents = SecurityProfileProperties.ExternalComponents;
	For Each GeneratedExternalComponent IN GeneratedExternalComponents Do
		CreateAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, GeneratedExternalComponent);
	EndDo;
	
	// External modules
	ListName = "module";
	CurrentDictionary = ExternalModulePropertiesDictionary();
	If ClearAccessControlLists Then
		DeletedExternalModules = GetAccessControlList(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each DeletedExternalModule IN DeletedExternalModules Do
			DeleteAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, DeletedExternalModule.Name);
		EndDo;
	EndIf;
	GeneratedExternalModules = SecurityProfileProperties.ExternalModules;
	For Each GeneratedExternalModule IN GeneratedExternalModules Do
		CreateAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, GeneratedExternalModule);
	EndDo;
	
	// OS applications
	ListName = "app";
	CurrentDictionary = OSApplicationPropertiesDictionary();
	If ClearAccessControlLists Then
		DeletedOSApplications = GetAccessControlList(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each DeletedOSApplication IN DeletedOSApplications Do
			DeleteAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, DeletedOSApplication.Name);
		EndDo;
	EndIf;
	GeneratedOSApplications = SecurityProfileProperties.OSApplications;
	For Each GeneratedOSApplication IN GeneratedOSApplications Do
		CreateAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, GeneratedOSApplication);
	EndDo;
	
	// Internet resources
	ListName = "inet";
	CurrentDictionary = InternetResourcePropertiesDictionary();
	If ClearAccessControlLists Then
		DeletedInternetResources = GetAccessControlList(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary);
		For Each DeletedInternetResource IN DeletedInternetResources Do
			DeleteAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, DeletedInternetResource.Name);
		EndDo;
	EndIf;
	GeneratedInternetResources = SecurityProfileProperties.InternetResources;
	For Each GeneratedInternetResource IN GeneratedInternetResources Do
		CreateAccessControlListItem(ClusterIdentifier, ClusterAdministrationParameters, ProfileName, ListName, CurrentDictionary, GeneratedInternetResource);
	EndDo;
	
EndProcedure

// Sets the usage of acl for the security profile.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, ListName - String, name of the access control list (acl)
//  in the rac utility notation, Usage - Boolean, check box of using acl.
//
Procedure SetAccessControlListUsage(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Use)
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name%";
	Pattern = StrReplace(Pattern, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	If Use Then
		Parameters.Insert("access", "list");
	Else
		Parameters.Insert("access", "full");
	EndIf;
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Deletes the acl item for the security profile.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, ListName - String, name of the access control list (acl) in
//  notation of the rac utility, ItemKey = String, value of the key property of the acl item.
//
Procedure DeleteAccessControlListItem(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val ItemKey)
	
	ListKey = AccessControlListsKeys()[ListName];
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl --name=%name%";
	Pattern = StrReplace(Pattern, "directory", ListName);
	Pattern = StrReplace(Pattern, "key", ListKey);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("name", ProfileName);
	Parameters.Insert(ListKey, ItemKey);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Creates the acl item for the security profile.
//
// Parameters:
//  ClusterIdentifier - String, internal identifier of
//  the servers cluster, ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ProfileName - String, security
//  proattachment file name, ListName - String, name of the list of access control (acl)
//  in the rac utility notation, Dictionary - Structure, maping of properties names in the output flow of the rac
//  utility and in the required description, ItemProperties - Structure, properties values of the item of the access control list.
//
Procedure CreateAccessControlListItem(Val ClusterIdentifier, Val ClusterAdministrationParameters, Val ProfileName, Val ListName, Val Dictionary, Val ItemProperties)
	
	Pattern = "%rac profile --cluster=%cluster% --cluster-user=%?cluster-user% --cluster-pwd=%?cluster-pwd% acl";
	Pattern = StrReplace(Pattern, "directory", ListName);
	
	Parameters = New Map();
	
	Parameters.Insert("cluster", ClusterIdentifier);
	FillAuthenticationParametersInCluster(ClusterAdministrationParameters, Parameters);
	Parameters.Insert("profile_name", ProfileName);
	
	FillParametersByDictionary(Dictionary, ItemProperties, Parameters, Pattern);
	
	OutputFlow = RunCommand(Pattern, ClusterAdministrationParameters, Parameters);
	
EndProcedure

// Converts properties values of using lists of access
// control (used nonstandard formatting of values during passing the values to rac utility - True="full", False="list").
//
// Parameters:
//  DescriptionStructure - Structure, containing object description received from
//    the flow of the rac utility output.
//
// Return value: Structure where the full and list values are converted to True and False.
//
Function ConvertAccessListsUsagePropertiesValues(Val DescriptionStructure)
	
	Dictionary = UsagePropertiesDictionaryAccessControlList();
	
	Result = New Structure;
	
	For Each KeyAndValue IN DescriptionStructure Do
		
		If Dictionary.Property(KeyAndValue.Key) Then
			
			If KeyAndValue.Value = "list" Then
				
				Value = False;
				
			ElsIf KeyAndValue.Value = "full" Then
				
				Value = True;
				
			EndIf;
			
			Result.Insert(KeyAndValue.Key, Value);
			
		Else
			
			Result.Insert(KeyAndValue.Key, KeyAndValue.Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Converts the value of the ultimate fallback language
//  to the console client notation of the administer server.
//
// Parameters:
//  Value - custom, value to which it is required to be converted.
//
// Returns:
//  String, value converted to notation of the console client of the administer server.
//
Function AdjustValue(Val Value, Val ParameterName = "")
	
	If TypeOf(Value) = Type("Date") Then
		Return XMLString(Value);
	EndIf;
	
	If TypeOf(Value) = Type("Boolean") Then
		
		If IsBlankString(ParameterName) Then
			FormatString = "BF=off; BT=on";
		Else
			FormatString = BooleanPropertiesFormattingDictionary()[ParameterName];
		EndIf;
		
		Return Format(Value, FormatString);
		
	EndIf;
	
	If TypeOf(Value) = Type("Number") Then
		Return Format(Value, "NDS=,;NZ=0; NG=0; NN=1");
	EndIf;
	
	If TypeOf(Value) = Type("String") Then
		If Find(Value, """") > 0 Or Find(Value, " ") > 0 Or Find(Value, "-") > 0 Or Find(Value, "!") > 0 Then
			Return """" + StrReplace(Value, """", """""") + """";
		EndIf;
	EndIf;
	
	Return String(Value);
	
EndFunction

// Converts an item of the output flow containing a
//  value to notation of a console client of the administer server to a value of the ultimate fallback language.
//
// Parameters:
//  OutputItem - String, item of the output flow containing the value
//    to the notation of administer server console client.
//
// Returns:
//  Custom, value of the ultimate fallback language.
//
Function CastOutputItem(OutputItem)
	
	If IsBlankString(OutputItem) Then
		Return Undefined;
	EndIf;
	
	OutputItem = StrReplace(OutputItem, """""", """");
	
	If OutputItem = "on" Or OutputItem = "yes" Then
		Return True;
	EndIf;
	
	If OutputItem = "off" Or OutputItem = "no" Then
		Return False;
	EndIf;
	
	If StringFunctionsClientServer.OnlyNumbersInString(OutputItem) Then
		Return Number(OutputItem);
	EndIf;
	
	Try
		Return XMLValue(Type("Date"), OutputItem);
	Except
		// Processing of the exception is not required. Expected exception - error
		// occurred during converting to the Date type.
	EndTry;
	
	Return OutputItem;
	
EndFunction

// Launches the console client of administer server for a command run.
//
// Parameters:
//  Pattern - String, template of the command row (unique for each command).
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  ParametersValues - structure containing parameters values
//    that should be input to the template.
//
// Returns:
//  String, result of redirection of the standard output flow during the rac utility launch.
//
Function RunCommand(Val Pattern, Val ClusterAdministrationParameters, Val ParameterValues = Undefined)
	
	#If Server Then
		
		If SafeMode() Then
			Raise NStr("en='Cluster administration is not available in safe mode!';ru='Администрирование кластера невозможно в безопасном режиме!'");
		EndIf;
		
		If CommonUseReUse.DataSeparationEnabled() Then
			Raise NStr("en='In the model of service, the execution of the cluster administration functions by the applied infobase is not allowed!';ru='В модели сервиса недопустимо выполнение прикладной информационной базой функций администрирования кластера!'");
		EndIf;
		
	#EndIf
	
	SystemInfo = New SystemInfo();
	
	// Insert a path to rac utility and ras server address to the command row.
	Client = GetAdministerServerClient();
	ClientFile = New File(Client);
	If Not ClientFile.Exist() Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Unable to run operation of the servers cluster administration as: file %1 is not found.
		|
		|To administer cluster via administer server (ras), you need to
		|install a client of administer server (ras) on this computer.
		|
		|To install it: 
		|- for computers with Windows OS you need to reinstall the platform by installing the component 1C:Enterprise server administer"";
		|- for computers with Linux OS you need to install the 1c-enterprise83-server* pack.';
		|ru='Невозможно выполнить операцию администрирования кластера серверов по причине: файл %1 не найден!
		|
		|Для администрирования кластера через сервер администрирования (ras) требуется  		
		|установить на данном компьютере клиент сервера администрирования (ras).
		|
		|Для его установки:
		|- для компьютеров с ОС Windows требуется перестановить платформу, установив компонент ""Администрирование сервера 1С:Предприятия"";
		|- для компьютеров с ОС Linux требуется установить пакет 1c-enterprise83-server*.'"),
			ClientFile.DescriptionFull);
		
	EndIf;
	
	If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerAddress) Then
		Server = TrimAll(ClusterAdministrationParameters.AdministrationServerAddress);
		If ValueIsFilled(ClusterAdministrationParameters.AdministrationServerPort) Then
			Server = Server + ":" + AdjustValue(ClusterAdministrationParameters.AdministrationServerPort);
		Else
			Server = Server + ":1545";
		EndIf;
	Else
		Server = "";
	EndIf;
	
	CommandLine = """" + Client + """ " + StrReplace(Pattern, "%rac", Server);
	
	// Insert a row of parameters value to the command bar.
	If ValueIsFilled(ParameterValues) Then
		For Each Parameter IN ParameterValues Do
			// Fill in parameter value.
			CommandLine = StrReplace(CommandLine, "%" + Parameter.Key + "%", AdjustValue(Parameter.Value, Parameter.Key));
			If ValueIsFilled(Parameter.Value) Then
				// It could be an optional parameter.
				CommandLine = StrReplace(CommandLine, "%?" + Parameter.Key + "%", AdjustValue(Parameter.Value, Parameter.Key));
			Else
				// If an optional parameter is not set - cut it out from the command bar.
				CommandLine = StrReplace(CommandLine, "--" + Parameter.Key + "=%?" + Parameter.Key + "%", "");
			EndIf;
		EndDo;
	EndIf;
	
	// Redirection stdout and stderr.
	OutputFlowFile = GetTempFileName("out");
	ErrorsFlowFile = GetTempFileName("err");
	CommandLine = CommandLine + " > """ + OutputFlowFile + """ 2>""" + ErrorsFlowFile + """";
	
	If (SystemInfo.PlatformType = PlatformType.Windows_x86) Or (SystemInfo.PlatformType = PlatformType.Windows_x86_64) Then
		
		// For Windows you need to launch it via cmd.exe (for redirecting stdout and stderr).
		CommandLine = "cmd /c " +  " """ + CommandLine + """";
		
		#If Server Then
			
			RunApp(CommandLine, PlatformExecutableFilesDirectory(), True);
			
		#Else
			
			// For Windows-client you need to use Wscript.Shell, to prevent windows with cmd from appearing.
			
			Shell = New COMObject("Wscript.Shell");
			Shell.Run(CommandLine, 0, True);
			
		#EndIf
		
	Else
		
		// For Linux OS you just need to launch the application.
		
		RunApp(CommandLine, PlatformExecutableFilesDirectory(), True);
		
	EndIf;
	
	ErrorsFlowReading = New TextReader(ErrorsFlowFile, GetStandardFlowsEncoding());
	ErrorsFlow = ErrorsFlowReading.Read();
	
	If ValueIsFilled(ErrorsFlow) Then
		
		Raise ErrorsFlow;
		
	Else
		
		OutputFlowReading = New TextReader(OutputFlowFile, GetStandardFlowsEncoding()); 
		OutputFlow = OutputFlowReading.Read();
		If OutputFlow = Undefined Then
			OutputFlow = "";
		EndIf;
		
		Return OutputFlow;
		
	EndIf;
	
EndFunction

// Returns the directory of the executed files of the platform.
//
// Returns:
//  String, directory of the executable platform files.
//
Function PlatformExecutableFilesDirectory() Export
	
	Result = BinDir();
	SeparatorChar = GetPathSeparator();
	
	If Not Right(Result, 1) = SeparatorChar Then
		Result = Result + SeparatorChar;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a path to the administer server console client
//
// Returns:
//  String, path to the console client of the administer server.
//
Function GetAdministerServerClient() Export
	
	LaunchDirectory = PlatformExecutableFilesDirectory();
	Client = LaunchDirectory + "rac";
	
	SysInfo = New SystemInfo();
	If (SysInfo.PlatformType = PlatformType.Windows_x86) Or (SysInfo.PlatformType = PlatformType.Windows_x86_64) Then
		Client = Client + ".exe";
	EndIf;
	
	Return Client;
	
EndFunction

// Returns the coding of standard flow of output and errors used in the current OS.
//
// Returns:
//  TextEncoding, encoding of standard flows of output and errors.
//
Function GetStandardFlowsEncoding() Export
	
	SysInfo = New SystemInfo();
	If (SysInfo.PlatformType = PlatformType.Windows_x86) Or (SysInfo.PlatformType = PlatformType.Windows_x86_64) Then
		Encoding = TextEncoding.OEM;
	Else
		Encoding = TextEncoding.System;
	EndIf;
	
	Return Encoding;
	
EndFunction

// Converts a redirected output flow of
// the console client of administer server to an array of matches (items of array - objects,
// match keys - names of the properties, map values - properties values).
//
// Parameters:
//  OutputFlow - String, redirected output
//  flow, Dictionary - Structure acting as a dictionary of names of objects properties match.
//    IN the rac utility notation and in
//  the API notation, Filter - Structure, conditions of objects filtering (only for flows
//    of the commands output returning collections of objects).
//
// Returns:
//  Array(Map)
//
Function OutputParser(Val OutputFlow, Val Dictionary, Val Filter = Undefined)
	
	Result = New Array();
	ResultItem = New Map();
	
	OutputSize = StrLineCount(OutputFlow);
	For Step = 1 To OutputSize Do
		FlowItem = StrGetLine(OutputFlow, Step);
		FlowItem = TrimAll(FlowItem);
		SeparatorPosition = Find(FlowItem, ":");
		If SeparatorPosition > 0 Then
			
			PropertyName = TrimAll(Left(FlowItem, SeparatorPosition - 1));
			PropertyValue = CastOutputItem(TrimAll(Right(FlowItem, StrLen(FlowItem) - SeparatorPosition)));
			
			If PropertiesShieledWithQuotations().Find(PropertyName) <> Undefined Then
				If Left(PropertyValue, 1) = """" AND Right(PropertyValue, 1) = """" Then
					PropertyValue = Left(PropertyValue, StrLen(PropertyValue) - 1);
					PropertyValue = Right(PropertyValue, StrLen(PropertyValue) - 1)
				EndIf;
			EndIf;
			
			ResultItem.Insert(PropertyName, PropertyValue);
			
		Else
			
			If ResultItem.Count() > 0 Then
				
				OutputItemParser(ResultItem, Result, Dictionary, Filter);
				
				ResultItem = New Map();
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If ResultItem.Count() > 0 Then
		OutputItemParser(ResultItem, Result, Dictionary, Filter);
	EndIf;
	
	Return Result;
	
EndFunction

// Converts the item of the redirected output
//  flow of the administer server console client to matching. Match keys - names of the properties, map values - properties values.
//
// Parameters:
//  ResultItem - String - item of
//  the output flow, Result - Array - array to which the reparsed object
//  should be added, Dictionary - Structure - structure acting as a dictionary of names of objects properties match.
//    IN the rac utility notation and in
//  the API notation, Filter - Structure - conditions of objects filtering (only for commands output
//    flows that return collections of objects).
//
Procedure OutputItemParser(ResultItem, Result, Dictionary, Filter)
	
	If Dictionary <> Undefined Then
		Object = CollateOutputItem(ResultItem, Dictionary);
	Else
		Object = ResultItem;
	EndIf;
	
	If Filter <> Undefined AND Not ClusterAdministrationClientServer.VerifyFilterConditions(Object, Filter) Then
		Return;
	EndIf;
	
	Result.Add(Object);
	
EndProcedure

// Breaks the item of redirected output flow of administer server console client.
//
// Parameters:
//  OutputItem - String, item of redirected flow of the
//  administer server client output, Dictionary - Structure acting as a dictionary of names of objects properties match.
//    IN the rac utility notation and in the API notation
//
// Return value: Structure, keys - names of properties in API notation, values - properties
//  values from the redirected output flow.
//
Function CollateOutputItem(Val OutputItem, Val Dictionary)
	
	Result = New Structure();
	
	For Each DictionaryFragment IN Dictionary Do
		
		Result.Insert(DictionaryFragment.Key, OutputItem[DictionaryFragment.Value]);
		
	EndDo;
	
	Return Result;
	
EndFunction

// Adds authentication parameters of the cluster administrator to the rac launch parameters.
//
// Parameters:
//  ClusterAdministrationParameters - Structure that describes the connection parameters
//    to the server cluster, Description - see ClusterAdministrationClientServer.ClusterAdministrationParameters(),
//  Parameters - Map, generated match of rac launch parameters.
//
Procedure FillAuthenticationParametersInCluster(Val ClusterAdministrationParameters, Parameters)
	
	Parameters.Insert("cluster-user", ClusterAdministrationParameters.ClusterAdministratorName);
	Parameters.Insert("cluster-pwd", ClusterAdministrationParameters.ClusterAdministratorPassword);
	
EndProcedure

// Adds authentication parameters of the infobase administrator to the rac launch parameters.
//
// Parameters:
//  InfobaseAdministrationParameters - Structure that describes the parameters of
//    connection to the infobase, Description - see ClusterAdministrationClientServer.ClusterInformationBaseAdministrationParameters().
//  Parameters - Map, generated match of rac launch parameters.
//
Procedure FillAuthenticationParametersToIB(Val InfobaseAdministrationParameters, Parameters)
	
	Parameters.Insert("infobase-user", InfobaseAdministrationParameters.NameAdministratorInfobase);
	Parameters.Insert("infobase-pwd", InfobaseAdministrationParameters.PasswordAdministratorInfobase);
	
EndProcedure

// Expands parameters of the rac launch by dictionary.
//
// Parameters:
//  Dictionary - Structure acting as a dictionary of matching properties
//    of objects names in the rac notation and in the API notation.
//  Source - Structure, key - name of the property in API notation, value - property
//  value, Parameters - Map, collected parameters of
//  the rac launch, Template - String, command template for the rac launch.
//
Procedure FillParametersByDictionary(Val Dictionary, Val Source, Parameters, Pattern)
	
	For Each DictionaryFragment IN Dictionary Do
		
		Pattern = Pattern + " --" + DictionaryFragment.Value + "=%" + DictionaryFragment.Value + "%";
		Parameters.Insert(DictionaryFragment.Value, Source[DictionaryFragment.Key]);
		
	EndDo;
	
EndProcedure

// Converts filter to the rac utility notation.
//
// Parameters:
//  Filter - Structure, Array (Structure), filter in
//  API notation, Dictionary - Structure, description of the properties names match in the API notation and the rac utility notation.
//
// Return value: Structure, Array(Structure) - filter in the rac utility notation.
//
Function FilterToRacNotation(Val Filter, Val Dictionary)
	
	If Filter = Undefined Then
		Return Undefined;
	EndIf;
	
	If Dictionary = Undefined Then
		Return Filter;
	EndIf;
	
	Result = New Array();
	
	For Each Condition IN Filter Do
		
		If TypeOf(Condition) = Type("KeyAndValue") Then
			
			Result.Add(New Structure("Property, ComparisonType, Value", Dictionary[Condition.Key], ComparisonType.Equal, Condition.Value));
			
		ElsIf TypeOf(Condition) = Type("Structure") Then
			
			Result.Add(New Structure("Property, ComparisonType, Value", Dictionary[Condition.Property], Condition.ComparisonType, Condition.Value));
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a match of infobase properties names
//  describing the lock state of sessions and scheduled jobs for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name
//         in
//  API (see ClusterAdministrationClientServer.SessionsAndScheduledJobsLockingProperties()), Value - String, the name of the object property.
//
Function SessionsAndScheduledJobsLockingPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("SessionsLock", "sessions-deny");
	Result.Insert("DateFrom", "denied-from");
	Result.Insert("DateTo", "denied-to");
	Result.Insert("Message", "denied-message");
	Result.Insert("KeyCode", "permission-code");
	Result.Insert("LockParameter", "denied-parameter");
	Result.Insert("ScheduledJobsLocking", "scheduled-jobs-deny");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of infobase sessions for structures used
//  in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.SessionProperties()), Value - String, the name of the object property.
//
Function SessionsPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "session-id");
	Result.Insert("UserName", "user-name");
	Result.Insert("ClientComputerName", "host");
	Result.Insert("ClientApplicationIdentifier", "app-id");
	Result.Insert("LanguageIdentifier", "locale");
	Result.Insert("SessionCreationTime", "started-at");
	Result.Insert("LastSessionActivityMoment", "last-active-at");
	Result.Insert("DBMSLocking", "blocked-by-dbms");
	Result.Insert("Block", "blocked-by-ls");
	Result.Insert("Transferred", "bytes-all");
	Result.Insert("PassedFor5Minutes", "bytes-last-5min");
	Result.Insert("ServerCalls", "calls-all");
	Result.Insert("ServerCallsFor5Minutes", "calls-last-5min");
	Result.Insert("ServerCallsDuration", "duration-all");
	Result.Insert("CurrentServerCallDuration", "duration-current");
	Result.Insert("ServerCallsDurationFor5Minutes", "duration-last-5min");
	Result.Insert("PassedDBMS", "dbms-bytes-all");
	Result.Insert("DBMSPassedIn5Minutes", "dbms-bytes-last-5min");
	Result.Insert("DBMSCallsDuration", "duration-all-dbms");
	Result.Insert("CurrentDBMSCallDuration", "duration-current-dbms");
	Result.Insert("DBMSCallsDurationFor5Minutes", "duration-last-3min-dbms");
	Result.Insert("ConnectionDBMS", "db-proc-info");
	Result.Insert("ConnectionTimeDBMS", "db-proc-took");
	Result.Insert("CaptureDBMSConnectionMoment", "db-proc-took-at");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of connections to the infobase for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.ConnectionProperties()), Value - String, the name of the object property.
//
Function ConnectionsPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Number", "conn-id");
	Result.Insert("UserName", "user-name");
	Result.Insert("ClientComputerName", "host");
	Result.Insert("ClientApplicationIdentifier", "app-id");
	Result.Insert("ConnectionMoment", "connected-at");
	Result.Insert("InfobaseConnectionMode", "ib-conn-mode");
	Result.Insert("DatabaseConnectionMode", "db-conn-mode");
	Result.Insert("DBMSLocking", "blocked-by-dbms");
	Result.Insert("Transferred", "bytes-all");
	Result.Insert("PassedFor5Minutes", "bytes-last-5min");
	Result.Insert("ServerCalls", "calls-all");
	Result.Insert("ServerCallsFor5Minutes", "calls-last-5min");
	Result.Insert("PassedDBMS", "dbms-bytes-all");
	Result.Insert("DBMSPassedIn5Minutes", "dbms-bytes-last-5min");
	Result.Insert("ConnectionDBMS", "db-proc-info");
	Result.Insert("TimeDBMS", "db-proc-took");
	Result.Insert("CaptureDBMSConnectionMoment", "db-proc-took-at");
	Result.Insert("ServerCallsDuration", "duration-all");
	Result.Insert("DBMSCallsDuration", "duration-all-dbms");
	Result.Insert("CurrentServerCallDuration", "duration-current");
	Result.Insert("CurrentDBMSCallDuration", "duration-current-dbms");
	Result.Insert("ServerCallsDurationFor5Minutes", "duration-last-5min");
	Result.Insert("DBMSCallsDurationFor5Minutes", "duration-last-5min-dbms");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of security profile for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.SecurityProfileProperties()), Value - String, the name of the object property.
//
Function SecurityProfilePropertiesDictionary(Val IncludingAccessControlListsUsageProperties = True)
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Description", "descr");
	Result.Insert("ProfileOfSafeMode", "config");
	Result.Insert("FullAccessToPrivilegedMode", "priv");
	
	If IncludingAccessControlListsUsageProperties Then
		
		DictionaryPropertiesUsingAccessControlLists = UsagePropertiesDictionaryAccessControlList();
		
		For Each DictionaryFragment IN DictionaryPropertiesUsingAccessControlLists Do
			Result.Insert(DictionaryFragment.Key, DictionaryFragment.Value);
		EndDo;
		
	EndIf;
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of security profile for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.SecurityProfileProperties()), Value - String, the name of the object property.
//
Function UsagePropertiesDictionaryAccessControlList()
	
	Result = New Structure();
	
	Result.Insert("FullAccessToFileSystem", "directory");
	Result.Insert("COMObjectsFullAccess", "com");
	Result.Insert("FullAccessToExternalComponents", "addin");
	Result.Insert("FullAccessToExternalModules", "module");
	Result.Insert("FullAccessToOperatingSystemApplications", "app");
	Result.Insert("FullAccessToInternetResources", "inet");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of virtual directory for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.VirtualDirectoryProperties()), Value - String, the name of the object property.
//
Function VirtualDirectoryPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("LogicalURL", "alias");
	Result.Insert("PhysicalURL", "physicalPath");
	
	Result.Insert("Description", "descr");
	
	Result.Insert("DataReading", "allowedRead");
	Result.Insert("DataRecording", "allowedWrite");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of COM-class for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.COMClassProperties()), Value - String, the name of the object property.
//
Function COMClassPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Description", "descr");
	
	Result.Insert("FileMoniker", "fileName");
	Result.Insert("CLSID", "id");
	Result.Insert("Computer", "host");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of external component for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.ExternalComponentProperties()), Value - String, the name of the object property.
//
Function ExternalComponentPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Description", "descr");
	
	Result.Insert("HashSum", "hash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of an external module for
//  structures used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.ExternalModuleProperties()), Value - String, the name of the object property.
//
Function ExternalModulePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Description", "descr");
	
	Result.Insert("HashSum", "hash");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of operating system application for structures
//  used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.OSApplicationProperties()), Value - String, the name of the object property.
//
Function OSApplicationPropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Description", "descr");
	
	Result.Insert("TemplateLaunchRows", "wild");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns a match of properties names of the Internet resource
//  for structures used in API and descriptions of objects in rac output.
//
// Return value: FixedStructure:
//  Key - String, property name in
//  API (see ClusterAdministrationClientServer.InternetResourceProperties()), Value - String, the name of the object property.
//
Function InternetResourcePropertiesDictionary()
	
	Result = New Structure();
	
	Result.Insert("Name", "name");
	Result.Insert("Description", "descr");
	
	Result.Insert("Protocol", "protocol");
	Result.Insert("Address", "url");
	Result.Insert("Port", "port");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the names of the acls key properties (in the rac utility notation).
//
// Return value: FixedStructure:
//  Key - String,
//  acl name, Value - String, name of the key property.
//
Function AccessControlListsKeys()
	
	Result = New Structure();
	
	Result.Insert("directory", "alias");
	Result.Insert("com", "name");
	Result.Insert("addin", "name");
	Result.Insert("module", "name");
	Result.Insert("inet", "name");
	
	Return New FixedStructure(Result);
	
EndFunction

// Returns the formatting rules of the Boolean according
//  to the rac utility notation.
//
// Return value: FixedMatch:
//  Key - String,
//  property name, Value - String, format row for property values.
//
Function BooleanPropertiesFormattingDictionary()
	
	OnOffFormat = "BF=off; BT=on";
	YesNoFormat = "BF=no; BT=yes";
	
	Result = New Map();
	
	// Locking properties of sessions and jobs.
	Dictionary = SessionsAndScheduledJobsLockingPropertiesDictionary();
	Result.Insert(Dictionary.SessionsLock, OnOffFormat);
	Result.Insert(Dictionary.ScheduledJobsLocking, OnOffFormat);
	
	// Properties of the security profile.
	Dictionary = SecurityProfilePropertiesDictionary(False);
	Result.Insert(Dictionary.ProfileOfSafeMode, YesNoFormat);
	Result.Insert(Dictionary.FullAccessToPrivilegedMode, YesNoFormat);
	
	// Properties of the virtual directory.
	Dictionary = VirtualDirectoryPropertiesDictionary();
	Result.Insert(Dictionary.DataReading, YesNoFormat);
	Result.Insert(Dictionary.DataRecording, YesNoFormat);
	
	Return New FixedMap(Result);
	
EndFunction

// Returns the properties listing, values of
// which are shielded with quotations in the flow of the rac utility output.
//
// Return value: Array(Row) - list of properties names.
//
Function PropertiesShieledWithQuotations()
	
	Result = New Array();
	
	Result.Add("denied-message");
	Result.Add("permission-code");
	Result.Add("denied-parameter");
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#EndIf