////////////////////////////////////////////////////////////////////////////////
// Subsystem
// "Data exchange" Module is designed to work with external connection.
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// Exports data for the infobase node to a temporary file.
// (For internal use only).
//
Procedure ExportForInfobaseNode(Cancel,
												ExchangePlanName,
												CodeOfInfobaseNode,
												ExchangeMessageFullFileName,
												ErrorMessageString = ""
	) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
	If CommonUse.FileInfobase() Then
		
		Try
			DataExchangeServer.ExportDataForInfobaseNodeViaFile(ExchangePlanName, CodeOfInfobaseNode, ExchangeMessageFullFileName);
		Except
			Cancel = True;
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
		EndTry;
		
	Else
		
		Address = "";
		
		Try
			
			DataExchangeServer.ExportToTempStorageForInfobaseNode(ExchangePlanName, CodeOfInfobaseNode, Address);
			
			GetFromTempStorage(Address).Write(ExchangeMessageFullFileName);
			
			DeleteFromTempStorage(Address);
			
		Except
			Cancel = True;
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
		EndTry;
		
	EndIf;
	
EndProcedure

// Put into the event log the record about the data exchange beginning.
// (For internal use only).
//
Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	DataExchangeServer.WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
EndProcedure

// Registers the completion of data exchange via external connection.
// (For internal use only).
//
Procedure FixEndExchange(ExchangeSettingsStructureExternalConnection) Export
	
	ExchangeSettingsStructureExternalConnection.ExchangeProcessResult = Enums.ExchangeExecutionResult[ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString];
	
	DataExchangeServer.AddExchangeOverExternalConnectionFinishEventLogMonitorMessage(ExchangeSettingsStructureExternalConnection);
	
EndProcedure

// Receives the read rules of the objects conversion by the exchange plan name.
// (For internal use only).
//
//  Returns:
//  Read rules of the objects conversion.
//
Function GetObjectConversionRules(ExchangePlanName) Export
	
	Return DataExchangeServer.GetObjectConversionRulesViaExternalConnection(ExchangePlanName);
	
EndFunction

// Gets the structure of the exchange settings.
// (For internal use only).
//
Function ExchangeSettingsStructure(Structure) Export
	
	Return DataExchangeServer.ExchangeOverExternalConnectionSettingsStructure(DataExchangeEvents.CopyStructure(Structure));
	
EndFunction

// Check the existence of a exchange plan with the specified name.
// (For internal use only).
//
Function ExchangePlanExists(ExchangePlanName) Export
	
	Return Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined;
	
EndFunction

// Receives default infobase prefix via external connection.
// Wrapper of the same function in the overridable module.
// (For internal use only).
//
Function InfobasePrefixByDefault() Export
	
	InfobasePrefix = Undefined;
	InfobasePrefix = DataExchangeOverridable.InfobasePrefixByDefault();
	DataExchangeOverridable.OnDefineDefaultInfobasePrefix(InfobasePrefix);
	
	Return InfobasePrefix;
	
EndFunction

// Checks the necessity to verify the differences of the versions in the conversion rules.
//
Function WarnAboutExchangeRulesVersionsMismatch(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	Return DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRulesVersionsMismatch");
	
EndFunction

// Returns the flag of the FullRights role accessibility.
// (For internal use only).
//
Function IsInRoleFullAccess() Export
	
	Return Users.InfobaseUserWithFullAccess(, True);
	
EndFunction

// Returns the table of the objects list of the specified metadata object.
// (For internal use only).
// 
Function GetTableObjects(FullTableName) Export
	
	Return ValueToStringInternal(CommonUse.ValueFromXMLString(DataExchangeServer.GetTableObjects(FullTableName)));
	
EndFunction

// Returns the table of the objects list of the specified metadata object.
// (For internal use only).
// 
Function GetTableObjects_2_0_1_6(FullTableName) Export
	
	Return DataExchangeServer.GetTableObjects(FullTableName);
	
EndFunction

// Receives the specified properties (Synonym, Hierarchic) of the metadata object.
// (For internal use only).
//
Function MetadataObjectProperties(FullTableName) Export
	
	Return DataExchangeServer.MetadataObjectProperties(FullTableName);
	
EndFunction

// Returns the name of the exchange plan predefined node.
// (For internal use only).
//
Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	Return DataExchangeServer.PredefinedExchangePlanNodeDescription(ExchangePlanName);
	
EndFunction

// For internal use.
//
Function GetCommonNodeData(Val ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return ValueToStringInternal(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// For internal use.
//
Function GetCommonNodeData_2_0_1_6(Val ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return CommonUse.ValueToXMLString(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// For internal use.
//
Function GetInfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorInfo) Export
	
	Return DataExchangeServer.GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorInfo);
	
EndFunction

// For internal use.
//
Function GetInfobaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorInfo) Export
	
	Return DataExchangeServer.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, ErrorInfo);
	
EndFunction

#EndRegion
