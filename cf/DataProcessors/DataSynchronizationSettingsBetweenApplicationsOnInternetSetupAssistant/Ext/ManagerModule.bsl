#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// For internal use
//
Procedure SetExchangeStep1(Parameters, TemporaryStorageAddress) Export
	
	ExchangePlanName = Parameters.ExchangePlanName;
	CorrespondentCode = Parameters.CorrespondentCode;
	CorrespondentDescription = Parameters.CorrespondentDescription;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	CorrespondentEndPoint = Parameters.CorrespondentEndPoint;
	FilterSsettingsAtNode = Parameters.FilterSsettingsAtNode;
	Prefix = Parameters.Prefix;
	CorrespondentPrefix = Parameters.CorrespondentPrefix;
	
	SetPrivilegedMode(True);
	
	ThisApplicationCode = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	ThisApplicationName = DataExchangeSaaS.GeneratePredefinedNodeDescription();
	
	BeginTransaction();
	Try
		
		Correspondent = Undefined;
		
		// Create exchange setting in this base
		DataExchangeSaaS.CreateExchangeSetting(
			ExchangePlanName,
			CorrespondentCode,
			CorrespondentDescription,
			CorrespondentEndPoint,
			FilterSsettingsAtNode.FilterSsettingsAtNode,
			Correspondent,
			,
			,
			Prefix);
		
		// Record the catalogs to be exported in this base
		DataExchangeServer.RegisterOnlyCatalogsForInitialLandings(Correspondent);
		
		// {Handler: OnSendingSenderData} Start
		ExchangePlans[ExchangePlanName].OnDataSendingSender(FilterSsettingsAtNode.FilterSsettingsAtNode, False);
		// {Handler: OnSendingSenderData} End
		
		// Send a message to the correspondent
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeManagementInterface.MessageSetExchangeStep1());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		Message.Body.CorrespondentCode = ThisApplicationCode;
		Message.Body.CorrespondentName = ThisApplicationName;
		Message.Body.FilterSettings = XDTOSerializer.WriteXDTO(FilterSsettingsAtNode.CorrespondentInfobaseNodeFilterSetup);
		Message.Body.Code = CommonUse.ObjectAttributeValue(Correspondent, "Code");
		Message.Body.EndPoint = MessageExchangeInternal.ThisNodeCode();
		Message.AdditionalInfo = XDTOSerializer.WriteXDTO(New Structure("Prefix", CorrespondentPrefix));
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
	Output_Parameters = New Structure("Correspondent, Session", Correspondent, Session);
	PutToTempStorage(Output_Parameters, TemporaryStorageAddress);
	
EndProcedure

// For internal use
//
Procedure SetExchangeStep2(Parameters, TemporaryStorageAddress) Export
	
	Correspondent = Parameters.Correspondent;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	DefaultValuesAtNode = Parameters.DefaultValuesAtNode;
	CorrespondentInfobaseNodeDefaultValues = Parameters.CorrespondentInfobaseNodeDefaultValues;
	
	SetPrivilegedMode(True);
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Correspondent);
	ThisApplicationCode = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	BeginTransaction();
	Try
		
		// Save the settings specified by the user
		DataExchangeSaaS.RefreshYourExchangeConfiguration(Correspondent, DefaultValuesAtNode);
		
		// Record all data to be exported, except catalogs
		DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExporting(Correspondent);
		
		// Send a message to the correspondent
		Message = MessagesSaaS.NewMessage(
			MessagesDataExchangeManagementInterface.MessageSetExchangeStep2());
		Message.Body.CorrespondentZone = CorrespondentDataArea;
		
		Message.Body.ExchangePlan = ExchangePlanName;
		Message.Body.CorrespondentCode = ThisApplicationCode;
		Message.Body.AdditionalSettings = XDTOSerializer.WriteXDTO(CorrespondentInfobaseNodeDefaultValues);
		
		Session = DataExchangeSaaS.SendMessage(Message);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	MessagesSaaS.DeliverQuickMessages();
	
	Output_Parameters = New Structure("Session", Session);
	PutToTempStorage(Output_Parameters, TemporaryStorageAddress);
	
EndProcedure

// For internal use
//
Procedure RunAutomaticDataMapping(Parameters, TemporaryStorageAddress) Export
	
	// Execute automatic data mapping, received from
	// the correspondent Get mapping statistics
	
	Correspondent = Parameters.Correspondent;
	
	SetPrivilegedMode(True);
	
	// Receive an exchange message in the temporary directory.
	Cancel = False;
	MessageParameters = DataExchangeServer.GetExchangeMessageToTemporaryDirectory(
		Cancel, Correspondent, Undefined);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Errors occurred while receiving an exchange message from the external resource for the ""%1"" correspondent.';ru='Возникли ошибки при получении сообщения обмена из внешнего ресурса для корреспондента ""%1"".'"),
			String(Correspondent));
	EndIf;
	
	InteractiveDataExchangeAssistant = DataProcessors.InteractiveDataExchangeAssistant.Create();
	InteractiveDataExchangeAssistant.InfobaseNode = Correspondent;
	InteractiveDataExchangeAssistant.ExchangeMessageFileName = MessageParameters.ExchangeMessageFileName;
	InteractiveDataExchangeAssistant.TemporaryExchangeMessagesDirectoryName = MessageParameters.TemporaryExchangeMessagesDirectoryName;
	InteractiveDataExchangeAssistant.ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Correspondent);
	InteractiveDataExchangeAssistant.ExchangeMessageTransportKind = Undefined;
	
	// Execute exchange message analysis.
	Cancel = False;
	InteractiveDataExchangeAssistant.RunExchangeMessageAnalysis(Cancel);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Errors occurred while analyzing exchange message for the ""%1"" correspondent.';ru='Возникли ошибки при анализе сообщения обмена для корреспондента ""%1"".'"),
			String(Correspondent));
	EndIf;
	
	// Execute automatic mapping and receive mapping statistics.
	Cancel = False;
	InteractiveDataExchangeAssistant.RunAutomaticMappingByDefaultAndGetMappingStats(Cancel);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Errors occurred while automatically mapping data received from the ""%1"" correspondent.';ru='Возникли ошибки при выполнении автоматического сопоставления данных, полученных от корреспондента ""%1"".'"),
			String(Correspondent));
	EndIf;
	
	TableOfInformationStatistics = InteractiveDataExchangeAssistant.TableOfInformationStatistics();
	
	// Delete from the string statistics table for which there is no data in this base or in the base-correspondent.
	// And also strings for which data synchronization by references ID is not provided.
	DeleteEmptyDataFromStatistics(TableOfInformationStatistics);
	
	AllDataMapped = (TableOfInformationStatistics.FindRows(New Structure("PictureIndex", 1)).Count() = 0);
	
	Output_Parameters = New Structure("StatisticsInformation, AllDataMapped, ExchangeMessageFileName, StatisticsIsEmpty",
		TableOfInformationStatistics, AllDataMapped, MessageParameters.ExchangeMessageFileName, TableOfInformationStatistics.Count() = 0);
	PutToTempStorage(Output_Parameters, TemporaryStorageAddress);
	
EndProcedure

// For internal use
//
Procedure SynchronizeCatalogs(Parameters, TemporaryStorageAddress) Export
	
	Correspondent = Parameters.Correspondent;
	CorrespondentDataArea = Parameters.CorrespondentDataArea;
	
	SetPrivilegedMode(True);
	
	ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Correspondent);
	ThisApplicationCode = DataExchangeReUse.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	
	// Execute importing of the exchange message, received from the correspondent
	Cancel = False;
	DataExchangeSaaS.ExecuteDataImport(Cancel, Correspondent);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Errors occurred while importing catalogs from the correspondent %1.';ru='Возникли ошибки в процессе загрузки справочников от корреспондента %1.'"),
			String(Correspondent));
	EndIf;
	
	// Execute exporting of the exchange message for the correspondent (catalogs only)
	Cancel = False;
	DataExchangeSaaS.ExecuteDataExport(Cancel, Correspondent);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Errors occurred while exporting catalogs for the correspondent %1.';ru='Возникли ошибки в процессе выгрузки справочников для корреспондента %1.'"),
			String(Correspondent));
	EndIf;
	
	// Send a message to the correspondent
	Message = MessagesSaaS.NewMessage(
		MessagesDataExchangeManagementInterface.MessageImportExchangeMessage());
	Message.Body.CorrespondentZone = CorrespondentDataArea;
	
	Message.Body.ExchangePlan = ExchangePlanName;
	Message.Body.CorrespondentCode = ThisApplicationCode;
	
	BeginTransaction();
	Session = DataExchangeSaaS.SendMessage(Message);
	CommitTransaction();
	
	MessagesSaaS.DeliverQuickMessages();
	
	Output_Parameters = New Structure("Session", Session);
	PutToTempStorage(Output_Parameters, TemporaryStorageAddress);
	
EndProcedure

// For internal use
//
Procedure GetStatsComparison(Parameters, TemporaryStorageAddress) Export
	
	// Parameters.Correspondent
	// Parameters.ExchangeMessageFileName
	// Parameters.StatisticsInformation
	// Parameters.RowIndexes
	
	// Get the mapping statistics for the specified data types
	SetPrivilegedMode(True);
	
	InteractiveDataExchangeAssistant = DataProcessors.InteractiveDataExchangeAssistant.Create();
	InteractiveDataExchangeAssistant.InfobaseNode = Parameters.Correspondent;
	InteractiveDataExchangeAssistant.ExchangeMessageFileName = Parameters.ExchangeMessageFileName;
	InteractiveDataExchangeAssistant.TemporaryExchangeMessagesDirectoryName = "";
	InteractiveDataExchangeAssistant.ExchangePlanName = DataExchangeReUse.GetExchangePlanName(Parameters.Correspondent);
	InteractiveDataExchangeAssistant.ExchangeMessageTransportKind = Undefined;
	
	InteractiveDataExchangeAssistant.StatisticsInformation.Load(Parameters.StatisticsInformation);
	
	Cancel = False;
	InteractiveDataExchangeAssistant.GetObjectMappingStatsByString(Cancel, Parameters.RowIndexes);
	If Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Errors occurred while receiving statistics information for the ""%1"" correspondent.';ru='Возникли ошибки при получении информации статистики для корреспондента ""%1"".'"),
			String(Parameters.Correspondent));
	EndIf;
	
	AllDataMapped = (InteractiveDataExchangeAssistant.TableOfInformationStatistics().FindRows(New Structure("PictureIndex", 1)).Count() = 0);
	
	Output_Parameters = New Structure("StatisticsInformation, AllDataMapped",
		InteractiveDataExchangeAssistant.TableOfInformationStatistics(), AllDataMapped);
	PutToTempStorage(Output_Parameters, TemporaryStorageAddress);
	
EndProcedure

// For internal use
//
Procedure DeleteEmptyDataFromStatistics(TableOfInformationStatistics)
	
	ReverseIndex = TableOfInformationStatistics.Count() - 1;
	
	While ReverseIndex >= 0 Do
		
		Statistics = TableOfInformationStatistics[ReverseIndex];
		
		If Statistics.ObjectsCountInSource = 0
			OR Statistics.ObjectsCountInReceiver = 0
			OR Not Statistics.SynchronizeByID Then
			
			TableOfInformationStatistics.Delete(Statistics);
			
		EndIf;
		
		ReverseIndex = ReverseIndex - 1;
	EndDo;
	
EndProcedure

#EndIf
