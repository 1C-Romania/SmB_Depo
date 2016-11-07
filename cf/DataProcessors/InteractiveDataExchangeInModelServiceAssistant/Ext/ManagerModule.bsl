#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProgramInterface

// Handler of the background job for registration of additional data and exchange
//
// Parameters:
//     ImportingHandling - DataProcessorObject.InteractiveExportChange - the
//     StorageAddress initialized object    - String, UUID - Address in storage for getting a result
// 
Procedure ExchangeOnDemand(Val ImportingHandling, Val StorageAddress = Undefined) Export
	
	RegisterExportAdditionData(ImportingHandling);
	
	Session = LaunchExchangeOnDemand(ImportingHandling.InfobaseNode);
	
	If StorageAddress <> Undefined Then
		PutToTempStorage(New Structure("Session", Session), StorageAddress);
	EndIf;
	
EndProcedure

// Registers additional data by settings
//
// Parameters:
//     ImportingHandling - Structure, DataProcessorObject.InteraractiveExportChange - initialized object
//
Procedure RegisterExportAdditionData(Val ImportingHandling)
	
	If TypeOf(ImportingHandling) = Type("Structure") Then
		DataProcessor = DataProcessors.InteractiveExportChange.Create();
		FillPropertyValues(DataProcessor, ImportingHandling, , "AdditionalRegistration, AdditionalRegistrationNodeScript");
		DataExchangeServer.FillValueTable(DataProcessor.AdditionalRegistration, ImportingHandling.AdditionalRegistration);
		DataExchangeServer.FillValueTable(DataProcessor.AdditionalRegistrationScriptSite, ImportingHandling.AdditionalRegistrationScriptSite);
	Else
		DataProcessor = ImportingHandling;
	EndIf;
	
	If DataProcessor.ExportVariant <= 0 Then
		// Do not add
		Return;
		
	ElsIf DataProcessor.ExportVariant = 1 Then
		// For a period with filter, clear additionally
		DataProcessor.AdditionalRegistration.Clear();
		
	ElsIf DataProcessor.ExportVariant = 2 Then
		// Set in details, clear general
		DataProcessor.ComposerAllDocumentsFilter = Undefined;
		DataProcessor.AllDocumentsFilterPeriod      = Undefined;
		
	EndIf;
	
	DataProcessor.RegisterAdditionalModifications();
EndProcedure

// Launches exchange on demand
//
// Parameters:
//     InfobaseNode - ExchangePlanRef - Ref to correspondent
//
Function LaunchExchangeOnDemand(Val InfobaseNode) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeAdministrationManagementInterface.MessagePushSynchronization()
		);
		
		Session = InformationRegisters.SystemMessagesExchangeSessions.NewSession();
		
		Message.Body.Zone      = CommonUse.SessionSeparatorValue();
		Message.Body.SessionId = Session;
		
		MessagesSaaS.SendMessage(Message, SaaSReUse.ServiceManagerEndPoint(), True);
		CommitTransaction();
	Except
		RollbackTransaction();
		
		WriteLogEvent(DataExchangeSaaS.EventLogMonitorEventDataSynchronization(), EventLogLevel.Error, , ,
			DetailErrorDescription(ErrorInfo()) 
		);
			
		Session = Undefined;
	EndTry;
	
	If Session<>Undefined Then
		MessagesSaaS.DeliverQuickMessages();
	EndIf;
	
	Return Session;
EndFunction

#EndRegion

#EndIf