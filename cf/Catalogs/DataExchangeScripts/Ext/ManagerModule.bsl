#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

Procedure CreateScenario(InfobaseNode, Schedule = Undefined) Export
	
	Cancel = False;
	
	Description = NStr("en='Automatic data synchronization with %1';ru='Автоматическая синхронизация данных с %1'");
	Description = StringFunctionsClientServer.SubstituteParametersInString(Description,
			CommonUse.ObjectAttributeValue(InfobaseNode, "Description"));
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
	
	DataExchangeScenario = Catalogs.DataExchangeScripts.CreateItem();
	
	// Fill in header attributes.
	DataExchangeScenario.Description = Description;
	DataExchangeScenario.UseScheduledJob = True;
	
	// Create scheduled job.
	RefreshScheduledJobData(Cancel, Schedule, DataExchangeScenario);
	
	// Tabular section
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.RunningAction = Enums.ActionsAtExchange.DataImport;
	TableRow.InfobaseNode = InfobaseNode;
	
	TableRow = DataExchangeScenario.ExchangeSettings.Add();
	TableRow.ExchangeTransportKind = ExchangeTransportKind;
	TableRow.RunningAction = Enums.ActionsAtExchange.DataExport;
	TableRow.InfobaseNode = InfobaseNode;
	
	DataExchangeScenario.Write();
	
EndProcedure

Function ScheduledJobDefaultSchedule() Export
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 900; // 15 minutes
	Schedule.DaysRepeatPeriod        = 1; // every day
	Schedule.Months                   = Months;
	
	Return Schedule;
EndFunction

// Returns reference to exchange plan node that is specified in the first string of exchange execution setting.
//  
// Parameters:
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScripts - exchange setting from
//                                                                        which it is required to receive exchange plan node.
//  
// Returns:
//  
// ExchangePlanRef - ref to exchange plan node that is specified in the first string of exchange execution setting;
// if there are no srtings, Undefined is returned.
//
Function GetInfobaseNodeFromFirstSettingsLine(ExchangeExecutionSettings) Export
	
	// Return value of the function.
	InfobaseNode = Undefined;
	
	If ExchangeExecutionSettings.IsEmpty() Then
		Return InfobaseNode;
	EndIf;
	
	QueryText = "
	|SELECT TOP 1
	|	ExchangeExecutionSettingsExchangeSettings.InfobaseNode AS InfobaseNode
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS ExchangeExecutionSettingsExchangeSettings
	|WHERE
	|	ExchangeExecutionSettingsExchangeSettings.Ref = &Ref
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", ExchangeExecutionSettings);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		InfobaseNode = Selection.InfobaseNode;
		
	EndIf;
	
	Return InfobaseNode;
EndFunction

// Receives scheduled job schedule.
// If scheduled job is not specified, then it returns an empty schedule (by default).
//
Function GetDataExchangeSchedule(ExchangeExecutionSettings) Export
	
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(ExchangeExecutionSettings.ScheduledJobGUID);
	
	If ScheduledJobObject <> Undefined Then
		
		JobSchedule = ScheduledJobObject.Schedule;
		
	Else
		
		JobSchedule = New JobSchedule;
		
	EndIf;
	
	Return JobSchedule;
	
EndFunction

Procedure RefreshScheduledJobData(Cancel, JobSchedule, CurrentObject) Export
	
	// Receive scheduled job by identifier if you did not find object, then create the new one.
	ScheduledJobObject = CreateScheduledJobIfNeeded(Cancel, CurrentObject);
	
	If Cancel Then
		Return;
	EndIf;
	
	// update P3 properties
	SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject);
	
	// Write changed job.
	WriteScheduledJob(Cancel, ScheduledJobObject);
	
	// Remember GUID scheduled job in object attribute.
	CurrentObject.ScheduledJobGUID = String(ScheduledJobObject.UUID);
	
EndProcedure

Function CreateScheduledJobIfNeeded(Cancel, CurrentObject)
	
	ScheduledJobObject = DataExchangeServerCall.FindScheduledJobByParameter(CurrentObject.ScheduledJobGUID);
	
	// Create scheduled job if needed.
	If ScheduledJobObject = Undefined Then
		
		ScheduledJobObject = ScheduledJobs.CreateScheduledJob("DataSynchronization");
		
	EndIf;
	
	Return ScheduledJobObject;
	
EndFunction

Procedure SetScheduledJobParameters(ScheduledJobObject, JobSchedule, CurrentObject)
	
	If IsBlankString(CurrentObject.Code) Then
		
		CurrentObject.SetNewCode();
		
	EndIf;
	
	ScheduledJobParameters = New Array;
	ScheduledJobParameters.Add(CurrentObject.Code);
	
	ScheduledJobDescription = NStr("en='Exchanging using scenario: %1';ru='Выполнение обмена по сценарию: %1'");
	ScheduledJobDescription = StringFunctionsClientServer.SubstituteParametersInString(ScheduledJobDescription, TrimAll(CurrentObject.Description));
	
	ScheduledJobObject.Description  = Left(ScheduledJobDescription, 120);
	ScheduledJobObject.Use = CurrentObject.UseScheduledJob;
	ScheduledJobObject.Parameters     = ScheduledJobParameters;
	
	// Update schedule if it is changed.
	If JobSchedule <> Undefined Then
		ScheduledJobObject.Schedule = JobSchedule;
	EndIf;
	
EndProcedure

// Writes scheduled job.
//
// Parameters:
//  Cancel                     - Boolean - Failure flag. If errors occur while executing the
//                                       procedure, check box of denial is set to the True value.
//  ScheduledJobObject - scheduled job object that should be written.
// 
Procedure WriteScheduledJob(Cancel, ScheduledJobObject)
	
	SetPrivilegedMode(True);
	
	Try
		
		// write job
		ScheduledJobObject.Write();
		
	Except
		
		MessageString = NStr("en='An error occurred when saving the exchange schedule. Error description: %1';ru='Произошла ошибка при сохранении расписания выполнения обменов. Подробное описание ошибки: %1'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, BriefErrorDescription(ErrorInfo()));
		DataExchangeServer.ShowMessageAboutError(MessageString, Cancel);
		
	EndTry;
	
EndProcedure

//

// Deletes node from all scripts of data exchange.
// If after this the script is empty, then this script is deleted.
//
Procedure ClearInfobaseNodeReferences(Val InfobaseNode) Export
	
	If CommonUseReUse.DataSeparationEnabled()
		AND CommonUseReUse.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	QueryText = "
	|SELECT DISTINCT
	|	DataExchangeScenarioExchangeSettings.Ref AS DataExchangeScenario
	|FROM
	|	Catalog.DataExchangeScripts.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.InfobaseNode = &InfobaseNode
	|";
	
	Query = New Query;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DataExchangeScenario = Selection.DataExchangeScenario.GetObject();
		
		DeleteDumpInDataExchangeScript(DataExchangeScenario, InfobaseNode);
		DeleteImportInDataExchangeScript(DataExchangeScenario, InfobaseNode);
		
		DataExchangeScenario.Write();
		
		If DataExchangeScenario.ExchangeSettings.Count() = 0 Then
			DataExchangeScenario.Delete();
		EndIf;
		
	EndDo;
	
EndProcedure

//

Procedure DeleteDumpInDataExchangeScript(DataExchangeScenario, InfobaseNode) Export
	
	DeleteLineInDataExchangeScript(DataExchangeScenario, InfobaseNode, Enums.ActionsAtExchange.DataExport);
	
EndProcedure

Procedure DeleteImportInDataExchangeScript(DataExchangeScenario, InfobaseNode) Export
	
	DeleteLineInDataExchangeScript(DataExchangeScenario, InfobaseNode, Enums.ActionsAtExchange.DataImport);
	
EndProcedure

Procedure AddDumpToDataExchangeScripts(DataExchangeScenario, InfobaseNode) Export
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScripts") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Add data export in cycle.
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For IndexOf = 0 To MaxIndex Do
		
		ReverseIndex = MaxIndex - IndexOf;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		// export last string
		If TableRow.RunningAction = Enums.ActionsAtExchange.DataExport Then
			
			NewRow = ExchangeSettings.Insert(ReverseIndex + 1);
			
			NewRow.InfobaseNode = InfobaseNode;
			NewRow.ExchangeTransportKind    = ExchangeTransportKind;
			NewRow.RunningAction    = Enums.ActionsAtExchange.DataExport;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If in the cycle export string is not added, then insert string to the table end.
	Filter = New Structure("InfobaseNode, ExecutedAction", InfobaseNode, Enums.ActionsAtExchange.DataExport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Add();
		
		NewRow.InfobaseNode = InfobaseNode;
		NewRow.ExchangeTransportKind    = ExchangeTransportKind;
		NewRow.RunningAction    = Enums.ActionsAtExchange.DataExport;
		
	EndIf;
	
	If MustWriteObject Then
		
		// Write changes in object.
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure AddImportingToDataExchangeScripts(DataExchangeScenario, InfobaseNode) Export
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScripts") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeTransportKind = InformationRegisters.ExchangeTransportSettings.ExchangeMessageTransportKindByDefault(InfobaseNode);
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	// Add data import in cycle.
	For Each TableRow IN ExchangeSettings Do
		
		If TableRow.RunningAction = Enums.ActionsAtExchange.DataImport Then // import last string
			
			NewRow = ExchangeSettings.Insert(ExchangeSettings.IndexOf(TableRow));
			
			NewRow.InfobaseNode = InfobaseNode;
			NewRow.ExchangeTransportKind    = ExchangeTransportKind;
			NewRow.RunningAction    = Enums.ActionsAtExchange.DataImport;
			
			Break;
		EndIf;
		
	EndDo;
	
	// If in the cycle import string is not added, then insert string to the table beginning.
	Filter = New Structure("InfobaseNode, ExecutedAction", InfobaseNode, Enums.ActionsAtExchange.DataImport);
	If ExchangeSettings.FindRows(Filter).Count() = 0 Then
		
		NewRow = ExchangeSettings.Insert(0);
		
		NewRow.InfobaseNode = InfobaseNode;
		NewRow.ExchangeTransportKind    = ExchangeTransportKind;
		NewRow.RunningAction    = Enums.ActionsAtExchange.DataImport;
		
	EndIf;
	
	If MustWriteObject Then
		
		// Write changes in object.
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

Procedure DeleteLineInDataExchangeScript(DataExchangeScenario, InfobaseNode, ActionOnExchange)
	
	MustWriteObject = False;
	
	If TypeOf(DataExchangeScenario) = Type("CatalogRef.DataExchangeScripts") Then
		
		DataExchangeScenario = DataExchangeScenario.GetObject();
		
		MustWriteObject = True;
		
	EndIf;
	
	ExchangeSettings = DataExchangeScenario.ExchangeSettings;
	
	MaxIndex = ExchangeSettings.Count() - 1;
	
	For IndexOf = 0 To MaxIndex Do
		
		ReverseIndex = MaxIndex - IndexOf;
		
		TableRow = ExchangeSettings[ReverseIndex];
		
		If  TableRow.InfobaseNode = InfobaseNode
			AND TableRow.RunningAction = ActionOnExchange Then
			
			ExchangeSettings.Delete(ReverseIndex);
			
		EndIf;
		
	EndDo;
	
	If MustWriteObject Then
		
		// Write changes in object.
		DataExchangeScenario.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Objects bulk edit.

// Returns the list of attributes
// excluded from the scope of the batch object modification.
//
Function NotEditableInGroupProcessingAttributes() Export
	
	Result = New Array;
	Result.Add("ScheduledJobGUID");
	Return Result;
	
EndFunction

#EndRegion

#EndIf
