////////////////////////////////////////////////////////////////////////////////
// Subsystem "Logging off users".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Deletes all infobase sessions except current.
//
Procedure DeleteAllSessionsExceptCurrent(AdministrationParameters) Export
	
	CurrentSessionNumber = InfobaseConnectionsServerCallReUse.SessionTerminationParameters().InfobaseSessionNumber;
	
	AllExceptCurrent = New Structure;
	AllExceptCurrent.Insert("Property", "Number");
	AllExceptCurrent.Insert("ComparisonType", ComparisonType.NotEqual);
	AllExceptCurrent.Insert("Value", CurrentSessionNumber);
	
	Filter = New Array;
	Filter.Add(AllExceptCurrent);

	ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

// Get IB connection string if nonstandard port of server cluster is set.
//
// Parameters:
//  ServerClusterPort  - Number - nonstandard port of server cluster.
//
// Returns:
//   String   - IB connection string.
//
Function GetInformationBaseConnectionString(Val ServerClusterPort = 0) Export

	Result = InfobaseConnectionString();
	If FileInfobase() Or (ServerClusterPort = 0) Then
		Return Result;
	EndIf;
	
#If AtClient Then
	If CommonUseClient.ClientConnectedViaWebServer() Then
		Return Result;
	EndIf;
#EndIf
	
	ConnectionStringSubstrings  = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Result, ";");
	ServerName = StringFunctionsClientServer.ContractDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	InfobaseName      = StringFunctionsClientServer.ContractDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	Result  = "Srvr=" + """" + ServerName + 
		?(Find(ServerName, ":") > 0, "", ":" + Format(ServerClusterPort, "NG=0")) + """;" + 
		"Ref=" + """" + InfobaseName + """;";
	Return Result;

EndFunction

// Returns the full path to the infobase (connection string).
//
// Parameters:
//  FileModeFlag         - Boolean - output parameter. Takes value.
//                                     True if current IB - file;
//                                     False - if client server.
//  ServerClusterPort    - Number  - input parameter. It is
//                                     set in case if server cluster uses the nonstandard port number.
//                                     Value by default - 0 means that
//                                     the server cluster takes the default port number.
//
// Returns:
//   String   - IB connection string.
//
Function InformationBasePath(FileModeFlag = Undefined, Val ServerClusterPort = 0) Export
	
	ConnectionString = GetInformationBaseConnectionString(ServerClusterPort);
	
	SearchPosition = Find(Upper(ConnectionString), "FILE=");
	
	If SearchPosition = 1 Then // file IB
		
		PathToInfobase = Mid(ConnectionString, 6, StrLen(ConnectionString) - 6);
		FileModeFlag = True;
		
	Else
		FileModeFlag = False;
		
		SearchPosition = Find(Upper(ConnectionString), "SRVR=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = Find(ConnectionString, ";");
		CopyStartPosition = 6 + 1;
		CopyingEndPosition = SemicolonPosition - 2;
		
		ServerName = Mid(ConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		ConnectionString = Mid(ConnectionString, SemicolonPosition + 1);
		
		// server name position
		SearchPosition = Find(Upper(ConnectionString), "REF=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		CopyStartPosition = 6;
		SemicolonPosition = Find(ConnectionString, ";");
		CopyingEndPosition = SemicolonPosition - 2;
		
		InfobaseNameAtServer = Mid(ConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		PathToInfobase = """" + ServerName + "\" + InfobaseNameAtServer + """";
	EndIf;
	
	Return PathToInfobase;
	
EndFunction

// Returns the text constant for message formation.
// Used for localization purposes.
//
// Returns:
//  String - text for administrator.
//
Function TextForAdministrator() Export
	
	Return NStr("en='For the administrator:';ru='Для администратора:'");
	
EndFunction

// Returns user message text of session lock.
// 
// Parameters:
//   Message - String - full message.
// 
// Returns:
//  String - lock message.
//
Function ExtractLockMessage(Val Message) Export
	
	MarkerIndex = Find(Message, TextForAdministrator());
	If MarkerIndex = 0  Then
		Return Message;
	ElsIf MarkerIndex >= 3 Then
		Return Mid(Message, 1, MarkerIndex - 3);
	Else
		Return "";
	EndIf;
		
EndFunction

// Returns a string constant to form the events log messages.
//
// Returns:
//   String - event description for events log monitor.
//
Function EventLogMonitorEvent() Export
	
	Return NStr("en='User work completion';ru='Завершение работы пользователей'", CommonUseClientServer.MainLanguageCode());
	
EndFunction

// Returns whether infobase is file.
//
// Returns:
//  Boolean - True if the infobase is file.
//
Function FileInfobase()
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Result = CommonUse.FileInfobase();
#Else
	Result = StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase;
#EndIf
	Return Result;
EndFunction

#EndRegion
