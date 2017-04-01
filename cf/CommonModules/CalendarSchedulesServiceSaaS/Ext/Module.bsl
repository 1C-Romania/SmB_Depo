////////////////////////////////////////////////////////////////////////////////
// Subsystem "Calendar schedules in service model".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.SuppliedData\OnDefenitionHandlersProvidedData"].Add(
				"CalendarSchedulesServiceSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\WhenYouDefineAliasesHandlers"].Add(
				"CalendarSchedulesServiceSaaS");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// HANDLERS OF SUPPLIED DATA RECEIPT

// Registers the handlers of supplied data during the day and since ever.
//
Procedure RegisterProvidedDataHandlers(Val Handlers) Export
	
	Handler = Handlers.Add();
	Handler.DataKind = "ProductCalendars";
	Handler.ProcessorCode = "BusinessCalendarsData";
	Handler.Handler = CalendarSchedulesServiceSaaS;
	
EndProcedure

// It is called when a notification of new data received.
// IN the body you should check whether these data is necessary for the application, and if so, - select the Import check box.
// 
// Parameters:
//   Descriptor - XDTOObject Descriptor.
//   Import     - Boolean, return.
//
Procedure AvailableNewData(Val Handle, Import) Export
	
 	If Handle.DataType = "ProductCalendars" Then
		Import = True;
	EndIf;
	
EndProcedure

// It is called after the call of AvailableNewData, allows you to parse data.
//
// Parameters:
//   Descriptor  - XDTOObject Descriptor.
//   PathToFile  - String. The full name of the extracted file. File will be deleted automatically after completion of the procedure.
//
Procedure ProcessNewData(Val Handle, Val PathToFile) Export
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	XMLReader.MoveToContent();
	If Not StartElement(XMLReader, "CalendarSuppliedData") Then
		Return;
	EndIf;
	XMLReader.Read();
	If Not StartElement(XMLReader, "Calendars") Then
		Return;
	EndIf;
	
	// Update a list of production calendars.
	TableCalendars = CommonUse.ReadXMLToTable(XMLReader).Data;
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(TableCalendars);
	
	XMLReader.Read();
	If Not EndElement(XMLReader, "Calendars") Then
		Return;
	EndIf;
	XMLReader.Read();
	If Not StartElement(XMLReader, "CalendarData") Then
		Return;
	EndIf;
	
	// Update data of production calendars.
	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromXML(XMLReader);
	
	Catalogs.BusinessCalendars.RefreshDataBusinessCalendars(DataTable);
	
EndProcedure

// It is called on cancellation of data processing in case of failure.
//
Procedure DataProcessingCanceled(Val Handle) Export 
	
	SuppliedData.AreaProcessed(Handle.FileGUID, "BusinessCalendarsData", Undefined);
	
EndProcedure	

#EndRegion

#Region ServiceProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the SSL subsystems.

// Register the handlers of supplied data.
//
// When getting notification of new common data accessibility the procedure is called.
// AvailableNewData modules registered through GetSuppliedDataHandlers.
// Descriptor is passed to the procedure - XDTOObject Descriptor.
// 
// IN case the AvailableNewData sets the Import argument to true, the data is imported, the descriptor and path to the data file are passed to the procedure.
// ProcessNewData. File will be deleted automatically after completion of the procedure.
// If the file was not specified in the service manager - The argument value is Undefined.
//
// Parameters: 
//   Handlers, ValueTable - The table for adding handlers. 
//       Columns:
//        DataKind, string - the code of data kind processed by the handler.
//        HandlersCode, row(20) - it will be used during restoring data processing after the failure.
//        Handler,  CommonModule - the module that contains the following procedures:
//          AvailableNewData(Handle, Import) Export 
//          ProcessNewData(Handle,  PathToFile) Export 
//          DataProcessingCanceled(Handle) Export
//
Procedure OnDefenitionHandlersProvidedData(Handlers) Export
	
	RegisterProvidedDataHandlers(Handlers);
	
EndProcedure

// Fills in the match of methods names and their aliases for call from the jobs queue.
//
// Parameters:
//  AccordanceNamespaceAliases - Correspondence
//   Key - Method alias, for example, ClearDataArea.
//   Value - Method name for call, for example, SaaSOperations.ClearDataArea.
//    You can specify Undefined as a value, in this case, it is
// considered that name matches the alias.
//
Procedure WhenYouDefineAliasesHandlers(AccordanceNamespaceAliases) Export
	
	AccordanceNamespaceAliases.Insert("CalendarSchedulesServiceSaaS.UpdateWorkSchedules");
	
EndProcedure

// It is called when production calendars are changed.
//
Procedure ScheduleRefreshGraphsWork(Val UpdateConditions) Export
	
	MethodParameters = New Array;
	MethodParameters.Add(UpdateConditions);
	MethodParameters.Add(New UUID);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "CalendarSchedulesServiceSaaS.UpdateWorkSchedules");
	JobParameters.Insert("Parameters"    , MethodParameters);
	JobParameters.Insert("RestartCountOnFailure", 3);
	JobParameters.Insert("DataArea", -1);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// Procedure for calling from the job queue, it is placed in PlanWorkSchedulesUpdates.
// 
// Parameters:
//  UpdateConditions - ValuesTable with conditions of schedule updates.
//  FileID - UUID of processed exchange rate file.
//
Procedure UpdateWorkSchedules(Val UpdateConditions, Val UpdateId) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		
		// Receiving data areas for processing.
		AreasForUpdating = SuppliedData.AreasRequiredProcessing(
			UpdateId, "BusinessCalendarsData");
			
		// Update work schedules by data areas.
		DistributeDataProductionOnCalendarsWorkSchedule(UpdateConditions, AreasForUpdating, 
			UpdateId, "BusinessCalendarsData", WorkSchedulesModule);
			
	EndIf;

EndProcedure

// Fills out schedule data with the production calendar data by all ODs.
//
// Parameters:
//  CurrencyRatesDate - Date or Undefined. Exchange rates are added for the specified date or since ever.
//  UpdateConditions - ValuesTable with conditions of schedule updates.
//  AreasForUpdating - Array with a list of area codes.
//  FileID - UUID of processed exchange rate file.
//  ProcessorCode - String, handler code.
//
Procedure DistributeDataProductionOnCalendarsWorkSchedule(Val UpdateConditions, 
	Val AreasForUpdating, Val FileID, Val ProcessorCode, Val WorkSchedulesModule)
	
	UpdateConditions.GroupBy("BusinessCalendarCode, Year");
	
	For Each DataArea IN AreasForUpdating Do
	
		SetPrivilegedMode(True);
		CommonUse.SetSessionSeparation(True, DataArea);
		SetPrivilegedMode(False);
		
		BeginTransaction();
		WorkSchedulesModule.UpdateWorkSchedulesByFactoryCalendarData(UpdateConditions);
		SuppliedData.AreaProcessed(FileID, ProcessorCode, DataArea);
		CommitTransaction();
		
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Other service procedures and functions.

Function StartElement(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Or XMLReader.Name <> Name Then
		WriteLogEvent(NStr("en='Supplied data. Calendar schedules';ru='Поставляемые данные.Календарные графики'", 
			Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,
			,, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Incorrect data file format. Waiting for the start of %1 item';ru='Неверный формат файла данных. Ожидается начало элемента %1'"), Name));
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function EndElement(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.EndElement Or XMLReader.Name <> Name Then
		WriteLogEvent(NStr("en='Supplied data. Calendar schedules';ru='Поставляемые данные.Календарные графики'", 
			Metadata.DefaultLanguage.LanguageCode), EventLogLevel.Error,
			,, StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Incorrect data file format. Waiting for the end of %1 item';ru='Неверный формат файла данных. Ожидается конец элемента %1'"), Name));
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion
