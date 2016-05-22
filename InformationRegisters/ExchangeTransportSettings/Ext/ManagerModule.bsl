#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure adds record in the register by passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		DataExchangeServer.AddRecordToInformationRegister(New Structure("Correspondent", RecordStructure.Node), "DataAreaTransportExchangeSettings");
	Else
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "ExchangeTransportSettings");
	EndIf;
	
EndProcedure

// Procedure updates record in the register by the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateRecordToInformationRegister(RecordStructure, "ExchangeTransportSettings");
	
EndProcedure

Procedure WhenFillingOutPermitsForAccessToExternalResources(PermissionsQueries) Export
	
	TransportSettings = SavedTransportSettings();
	
	While TransportSettings.Next() Do
		
		QueryOnExternalResourcesUse(PermissionsQueries, TransportSettings);
		
	EndDo;
	
EndProcedure

Function SavedTransportSettings()
	
	Query = New Query;
	Query.Text = "SELECT
	|	ExchangeTransportSettings.Node,
	|	ExchangeTransportSettings.FTPConnectionPath,
	|	ExchangeTransportSettings.FILEInformationExchangeDirectory,
	|	ExchangeTransportSettings.WSURLWebService,
	|	ExchangeTransportSettings.COMInfobaseDirectory,
	|	ExchangeTransportSettings.COMInfobaseNameAtServer1CEnterprise,
	|	ExchangeTransportSettings.FTPConnectionPath AS FTPConnectionPath,
	|	ExchangeTransportSettings.FTPConnectionPort AS FTPConnectionPort,
	|	ExchangeTransportSettings.WSURLWebService AS WSURLWebService,
	|	ExchangeTransportSettings.FILEInformationExchangeDirectory AS FILEInformationExchangeDirectory
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings";
	
	QueryResult = Query.Execute();
	Return QueryResult.Select();
	
EndFunction

Procedure QueryOnExternalResourcesUse(PermissionsQueries, Record, AskCOM = True,
	AskFILE = True, AskWS = True, AskFTP = True) Export
	
	permissions = New Array;
	
	If AskFTP AND Not IsBlankString(Record.FTPConnectionPath) Then
		
		StructureOfAddress = CommonUseClientServer.URLStructure(Record.FTPConnectionPath);
		permissions.Add(WorkInSafeMode.PermissionForWebsiteUse(
			StructureOfAddress.Schema, StructureOfAddress.Host, Record.FTPConnectionPort));
		
	EndIf;
	
	If AskFILE AND Not IsBlankString(Record.FILEInformationExchangeDirectory) Then
		
		permissions.Add(WorkInSafeMode.PermissionToUseFileSystemDirectory(
			Record.FILEInformationExchangeDirectory, True, True));
		
	EndIf;
	
	If AskWS AND Not IsBlankString(Record.WSURLWebService) Then
		
		StructureOfAddress = CommonUseClientServer.URLStructure(Record.WSURLWebService);
		permissions.Add(WorkInSafeMode.PermissionForWebsiteUse(
			StructureOfAddress.Schema, StructureOfAddress.Host, StructureOfAddress.Port));
		
	EndIf;
	
	If AskCOM AND (NOT IsBlankString(Record.COMInfobaseDirectory)
		Or Not IsBlankString(Record.COMInfobaseNameAtServer1CEnterprise)) Then
		
		COMConnectorName = CommonUseClientServer.COMConnectorName();
		permissions.Add(WorkInSafeMode.PermissionForCOMClassCreation(
			COMConnectorName, CommonUse.COMConnectorIdentifier(COMConnectorName)));
		
	EndIf;
	
	// Permissions for exchange through mail are requested in the subsystem Work with email messages.
	
	If permissions.Count() > 0 Then
		
		PermissionsQueries.Add(
			WorkInSafeMode.QueryOnExternalResourcesUse(permissions, Record.Node));
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for getting the settings values for the exchange plan node.

// Receives setting values of a specific transport kind.
// If transport kind isn't specified (ExchangeTransportKind
// = Undefined) that receives settings of all transport kinds registered in the system.
//  
// Parameters:
//  No.
//  
// Returns:
//  
//
Function TransportSettings(Val Node, Val ExchangeTransportKind = Undefined) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		
		Return InformationRegisters["DataAreaTransportExchangeSettings"].TransportSettings(Node);
	Else
		
		Return ExchangeTransportSettings(Node, ExchangeTransportKind);
	EndIf;
	
EndFunction

Function TransportSettingsWS(Node, AuthenticationParameters = Undefined) Export
	
	SettingsStructure = GetSettingsStructure("WS");
	
	Result = GetRegisterDataByStructure(Node, SettingsStructure);
	
	If TypeOf(AuthenticationParameters) = Type("Structure") Then // Initiate user exchange from client.
		
		If AuthenticationParameters.UseCurrentUser Then
			
			Result.WSUserName = InfobaseUsers.CurrentUser().Name;
			
		EndIf;
		
		Password = Undefined;
		
		If AuthenticationParameters.Property("Password", Password)
			AND Password <> Undefined Then // Password is entered on client
			
			Result.WSPassword = Password;
			
		Else // Password isn't entered on client.
			
			Password = DataExchangeServer.PasswordSynchronizationData(Node);
			
			Result.WSPassword = ?(Password = Undefined, "", Password);
			
		EndIf;
		
	ElsIf TypeOf(AuthenticationParameters) = Type("String") Then
		
		Result.WSPassword = AuthenticationParameters;
		
	EndIf;
	
	Return Result;
EndFunction

Function ExchangeMessageTransportKindByDefault(InfobaseNode) Export
	
	// Return value of the function.
	ExchangeMessageTransportKind = Undefined;
	
	QueryText = "
	|SELECT
	|	ExchangeTransportSettings.ExchangeMessageTransportKindByDefault AS ExchangeMessageTransportKindByDefault
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &InfobaseNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		ExchangeMessageTransportKind = Selection.ExchangeMessageTransportKindByDefault;
		
	EndIf;
	
	Return ExchangeMessageTransportKind;
EndFunction

Function InformationExchangeDirectoryName(ExchangeMessageTransportKind, InfobaseNode) Export
	
	// Return value of the function.
	Result = "";
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FILE Then
		
		TransportSettings = TransportSettings(InfobaseNode);
		
		Result = TransportSettings["FILEInformationExchangeDirectory"];
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessagesTransportKinds.FTP Then
		
		TransportSettings = TransportSettings(InfobaseNode);
		
		Result = TransportSettings["FTPConnectionPath"];
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportSettingsPresentations(TransportKind) Export
	
	Result = New Structure;
	
	If TransportKind = Enums.ExchangeMessagesTransportKinds.COM Then
		
		AddSettingPresentationItem(Result, "COMInfobaseOperationMode");
		AddSettingPresentationItem(Result, "COMServerName1CEnterprise");
		AddSettingPresentationItem(Result, "COMInfobaseNameAtServer1CEnterprise");
		AddSettingPresentationItem(Result, "COMInfobaseDirectory");
		AddSettingPresentationItem(Result, "COMAuthenticationOS");
		AddSettingPresentationItem(Result, "COMUserName");
		AddSettingPresentationItem(Result, "COMUserPassword");
		
	ElsIf TransportKind = Enums.ExchangeMessagesTransportKinds.FILE Then
		
		AddSettingPresentationItem(Result, "FILEInformationExchangeDirectory");
		AddSettingPresentationItem(Result, "FILECompressOutgoingMessageFile");
		
	ElsIf TransportKind = Enums.ExchangeMessagesTransportKinds.FTP Then
		
		AddSettingPresentationItem(Result, "FTPConnectionPath");
		AddSettingPresentationItem(Result, "FTPConnectionPort");
		AddSettingPresentationItem(Result, "FTPConnectionUser");
		AddSettingPresentationItem(Result, "FTPConnectionPassword");
		AddSettingPresentationItem(Result, "FTPConnectionMaximumValidMessageSize");
		AddSettingPresentationItem(Result, "FTPConnectionPassiveConnection");
		AddSettingPresentationItem(Result, "FTPCompressOutgoingMessageFile");
		
	ElsIf TransportKind = Enums.ExchangeMessagesTransportKinds.EMAIL Then
		
		AddSettingPresentationItem(Result, "EMAILAccount");
		AddSettingPresentationItem(Result, "EMAILMaximumValidMessageSize");
		AddSettingPresentationItem(Result, "EMAILCompressOutgoingMessageFile");
		
	ElsIf TransportKind = Enums.ExchangeMessagesTransportKinds.WS Then
		
		AddSettingPresentationItem(Result, "WSURLWebService");
		AddSettingPresentationItem(Result, "WSUserName");
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportForNodeSettingsAreSetted(Node) Export
	
	QueryText = "
	|SELECT 1 FROM InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node
	|";
	
	Query = New Query;
	Query.SetParameter("Node", Node);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Function ConfiguredTransportTypes(InfobaseNode) Export
	
	Result = New Array;
	
	TransportSettings = TransportSettings(InfobaseNode);
	
	If ValueIsFilled(TransportSettings.COMInfobaseDirectory) 
		OR ValueIsFilled(TransportSettings.COMInfobaseNameAtServer1CEnterprise) Then
		
		Result.Add(Enums.ExchangeMessagesTransportKinds.COM);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.EMAILAccount) Then
		
		Result.Add(Enums.ExchangeMessagesTransportKinds.EMAIL);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.FILEInformationExchangeDirectory) Then
		
		Result.Add(Enums.ExchangeMessagesTransportKinds.FILE);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.FTPConnectionPath) Then
		
		Result.Add(Enums.ExchangeMessagesTransportKinds.FTP);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.WSURLWebService) Then
		
		Result.Add(Enums.ExchangeMessagesTransportKinds.WS);
		
	EndIf;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local service procedures and functions.

// Receives setting values of a specific transport kind.
// If transport kind isn't specified (ExchangeTransportKind
// = Undefined) that receives settings of all transport kinds registered in the system.
//  
// Parameters:
//  No.
//  
// Returns:
//  
//
Function ExchangeTransportSettings(Node, ExchangeTransportKind)
	
	SettingsStructure = New Structure;
	
	// General settings for all transport kinds.
	SettingsStructure.Insert("ExchangeMessageTransportKindByDefault");
	SettingsStructure.Insert("ExchangeMessageArchivePassword");
	
	If ExchangeTransportKind = Undefined Then
		
		For Each TransportKind IN Enums.ExchangeMessagesTransportKinds Do
			
			TransportSettingsStructure = GetSettingsStructure(CommonUse.NameOfEnumValue(TransportKind));
			
			SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
			
		EndDo;
		
	Else
		
		TransportSettingsStructure = GetSettingsStructure(CommonUse.NameOfEnumValue(ExchangeTransportKind));
		
		SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
		
	EndIf;
	
	Result = GetRegisterDataByStructure(Node, SettingsStructure);
	Result.Insert("UseTempDirectoryForSendingAndReceivingMessages", True);
	DataExchangeServer.AddTransactionItemCountToTransportSettings(Result);
	
	Return Result;
EndFunction

Function GetRegisterDataByStructure(Node, SettingsStructure)
	
	If Not ValueIsFilled(Node) Then
		Return SettingsStructure;
	EndIf;
	
	If SettingsStructure.Count() = 0 Then
		Return SettingsStructure;
	EndIf;
	
	// Form query text only by the necessary fields -
	// parameters for the specified transport kind.
	QueryText = "SELECT ";
	
	For Each SettingItem IN SettingsStructure Do
		
		QueryText = QueryText + SettingItem.Key + ", ";
		
	EndDo;
	
	// Delete last char ", ".
	StringFunctionsClientServer.DeleteLatestCharInRow(QueryText, 2);
	
	QueryText = QueryText + "
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Node", Node);
	
	Selection = Query.Execute().Select();
	
	// If there is data for node then fill structure.
	If Selection.Next() Then
		
		For Each SettingItem IN SettingsStructure Do
			
			SettingsStructure[SettingItem.Key] = Selection[SettingItem.Key];
			
		EndDo;
		
	EndIf;
	
	Return SettingsStructure;
	
EndFunction

Function GetSettingsStructure(SearchSubstring)
	
	TransportSettingsStructure = New Structure();
	
	RegisterMetadata = Metadata.InformationRegisters.ExchangeTransportSettings;
	
	For Each Resource IN RegisterMetadata.Resources Do
		
		If Find(Resource.Name, SearchSubstring) <> 0 Then
			
			TransportSettingsStructure.Insert(Resource.Name, Resource.Synonym);
			
		EndIf;
		
	EndDo;
	
	Return TransportSettingsStructure;
EndFunction

Function MergeCollections(Structure1, Structure2)
	
	ResultStructure = New Structure;
	
	SupplementCollection(Structure1, ResultStructure);
	SupplementCollection(Structure2, ResultStructure);
	
	Return ResultStructure;
EndFunction

Procedure SupplementCollection(Source, Receiver)
	
	For Each Item IN Source Do
		
		Receiver.Insert(Item.Key, Item.Value);
		
	EndDo;
	
EndProcedure

Procedure AddSettingPresentationItem(Structure, SettingName)
	
	Structure.Insert(SettingName, Metadata.InformationRegisters.ExchangeTransportSettings.Resources[SettingName].Presentation());
	
EndProcedure

#EndRegion

#EndIf