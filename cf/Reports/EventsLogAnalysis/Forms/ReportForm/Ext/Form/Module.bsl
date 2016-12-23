
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ArrayRoutineMaintenanceJobs = ListAllScheduledJobs();
	HideSceduledJobs = Report.SettingsComposer.Settings.DataParameters.AvailableParameters.FindParameter(New DataCompositionParameter("HideSceduledJobs"));
	HideSceduledJobs.AvailableValues.Clear();
	For Each Item IN ArrayRoutineMaintenanceJobs Do
		HideSceduledJobs.AvailableValues.Add(Item.UID, Item.Description);
	EndDo;
	HideSceduledJobs.AvailableValues.SortByPresentation();
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If JobID <> New UUID("00000000-0000-0000-0000-000000000000") Then
		OnCloseAtServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ResultDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Item.CurrentArea) = Type("SpreadsheetDocumentDrawing") Then
		
		If TypeOf(Item.CurrentArea.Object) = Type("Chart") Then
			StandardProcessing = False;
			Return;
		EndIf;
		
	EndIf;
	
	If Not CurrentVariantDescription = NStr("en='Duration of the scheduled jobs work';ru='Продолжительность работы регламентных заданий'") Then
		StandardProcessing = True;
		Return;
	EndIf;
	
	StandardProcessing = False;
	TypeDetails = Details.Get(0);
	If TypeDetails = "DecryptionScheduledJobs" Then
		
		VariantDetails = New ValueList;
		VariantDetails.Add("InfoAboutScheduledJob", NStr("en='Information on the scheduled job';ru='Сведения о регламентном задании'"));
		VariantDetails.Add("OpenEventLogMonitor", NStr("en='Proceed to the event log';ru='Перейти к журналу регистрации'"));
		
		NotifyDescription = New NotifyDescription("ResultDetailDataProcessorEnd", ThisObject, Details);
		ShowChooseFromMenu(NOTifyDescription, VariantDetails);
		
	Else
		InfoAboutScheduledJob(Details);
	EndIf;
	
EndProcedure

&AtClient
Procedure ResultAdditionalDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Item.CurrentArea) = Type("SpreadsheetDocumentDrawing") Then
		If TypeOf(Item.CurrentArea.Object) = Type("Chart") Then
			StandardProcessing = False;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GenerateReport(Command)
	ClearMessages();
	ReportParameters = ReportParameters();	
	ExecutionResult = GenerateReportServer(ReportParameters);
	IdleHandlerParameters = New Structure();
	
	If Not ExecutionResult.JobCompleted Then		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "ReportCreation");
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ResultDetailDataProcessorEnd(SelectedVariant, Details) Export
	
	If SelectedVariant = Undefined Then
		Return;
	EndIf;
	
	Action = SelectedVariant.Value;
	If Action = "InfoAboutScheduledJob" Then
		
		ListPoints = Result.Areas.GanttChart.Object.Points;
		For Each GanttChartPoint IN ListPoints Do
			
			DetailsDots = GanttChartPoint.Details;
			If GanttChartPoint.Value = NStr("en='Background jobs';ru='Фоновые задания'") Then
				Continue;
			EndIf;
			
			If DetailsDots.Find(Details.Get(2)) <> Undefined Then
				InfoAboutScheduledJob(DetailsDots);
				Break;
			EndIf;
			
		EndDo;
		
	ElsIf Action = "OpenEventLogMonitor" Then
		
		SessionScheduledJobs.Clear();
		SessionScheduledJobs.Add(Details.Get(1));
		StartDate = Details.Get(3);
		EndDate = Details.Get(4);
		EventLogMonitorFilter = New Structure("Session, StartDate, EndDate", 
			SessionScheduledJobs, StartDate, EndDate);
		OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", EventLogMonitorFilter);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCloseAtServer()
	
	LongActions.CancelJobExecution(JobID);
	
EndProcedure

&AtServer
Function ListAllScheduledJobs()
	SetPrivilegedMode(True);
	ScheduledJobList = ScheduledJobs.GetScheduledJobs();
	ArrayRoutineMaintenanceJobs = New Array;
	For Each Item IN ScheduledJobList Do
		If Item.Description <> "" Then
			ArrayRoutineMaintenanceJobs.Add(New Structure("UID, Description", Item.UUID, 
																			Item.Description));
		ElsIf Item.Metadata.Synonym <> "" Then
			ArrayRoutineMaintenanceJobs.Add(New Structure("UID, Description", Item.UUID,
																			Item.Metadata.Synonym));
		EndIf;
	EndDo;
	
	Return ArrayRoutineMaintenanceJobs;
EndFunction

&AtServer
Function ReportParameters()
	ReportParameters = New Structure;
	ReportParameters.Insert("Settings", Report.SettingsComposer.Settings);
	ReportParameters.Insert("UserSettings", Report.SettingsComposer.UserSettings);
	ReportParameters.Insert("FixedSettings", Report.SettingsComposer.FixedSettings);
	ReportParameters.Insert("FormID", UUID);
	
	Return ReportParameters;
EndFunction

&AtServer
Procedure GetScheduledTaskID(NameEvents, DescriptionEvents)
	SetPrivilegedMode(True);
	FilterOnScheduledJobs = New Structure; 	
	ScheduledJobMetadata = Metadata.ScheduledJobs.Find(NameEvents);
	If ScheduledJobMetadata <> Undefined Then
		FilterOnScheduledJobs.Insert("Metadata", ScheduledJobMetadata);
		If DescriptionEvents <> Undefined Then
			FilterOnScheduledJobs.Insert("Description", DescriptionEvents);
		EndIf;
		SchedTask = ScheduledJobs.GetScheduledJobs(FilterOnScheduledJobs);
		If ValueIsFilled(SchedTask) Then
			ScheduledJobID = SchedTask[0].UUID;
		EndIf;
	EndIf;	
EndProcedure 					   

&AtClient
Procedure InfoAboutScheduledJob(Details)
	ScheduledJobID = Undefined;
	ResultDetails = ReportOnScheduledTask(Details);
	NameScheduledJobs = Details.Get(1);
	DescriptionEvents = Details.Get(2);
	If NameScheduledJobs <> "" Then
		NameEvents = StrReplace(NameScheduledJobs, "ScheduledJob." , "");
		GetScheduledTaskID(NameEvents, DescriptionEvents);
	EndIf;
	FormParameters = New Structure("Report, ScheduledJobID, Title", 
		ResultDetails.Report,	ScheduledJobID, Details.Get(2));
	OpenForm("Report.EventsLogAnalysis.Form.InfoAboutScheduledJob", FormParameters);
EndProcedure

&AtServer
Function ReportOnScheduledTask(Details)
	FormingResultReport = Reports.EventsLogAnalysis.DecryptionScheduledJobs(Details);
	Return FormingResultReport;
EndFunction		

&AtServer
Function GenerateReportServer(ReportParameters)
	If Not CheckFilling() Then 
		Return New Structure("JobCompleted", True);
	EndIf;
	
	LongActions.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
	
	AddressDecoding = PutToTempStorage(Undefined, UUID);
	ReportParameters.Insert("AddressDecoding", AddressDecoding);
	
	ExecutionResult = LongActions.ExecuteInBackground(
		UUID,
		"Reports.EventsLogAnalysis.Generate",
		ReportParameters,
		NStr("en='Report execution: Events log monitor analysis';ru='Выполнение отчета: Анализ журнала регистрации'"));
	
	StorageAddress       = ExecutionResult.StorageAddress;
	JobID = ExecutionResult.JobID;
	
	If ExecutionResult.JobCompleted Then
		ImportPreparedData();
	EndIf;
	
	Return ExecutionResult;

EndFunction

&AtServer
Procedure ImportPreparedData()
	ExecutionResult = GetFromTempStorage(StorageAddress);
	Result         = ExecutionResult.Result;
	DetailsData = ExecutionResult.DetailsData;
	
	JobID = Undefined;
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	Try
		If JobCompleted(JobID) Then 
			ImportPreparedData();
			CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
		Else
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
		EndIf;
	Except
		CommonUseClientServer.SetSpreadsheetDocumentFieldState(Items.Result, "DontUse");
		Raise;
	EndTry;	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

#EndRegion














