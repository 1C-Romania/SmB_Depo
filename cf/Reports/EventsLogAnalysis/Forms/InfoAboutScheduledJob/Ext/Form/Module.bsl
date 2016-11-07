
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Report = Parameters.Report;
	ScheduledJobID = Parameters.ScheduledJobID;
	Title = Parameters.Title;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		SubsystemScheduledJobsExist = True;
		Items.ChangeSchedule.Visible = True;
	Else
		Items.ChangeSchedule.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ReportDetailsProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	StartDate = Details.Get(0);
	EndDate = Details.Get(1);
	SessionScheduledJobs.Clear();
	SessionScheduledJobs.Add(Details.Get(2)); 
	EventLogMonitorFilter = New Structure("Session, StartDate, EndDate", SessionScheduledJobs, StartDate, EndDate);
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", EventLogMonitorFilter);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ConfigureScheduleJobSchedule(Command)
	
	If ValueIsFilled(ScheduledJobID) Then
		
		Dialog = New ScheduledJobDialog(GetSchedule());
		
		NotifyDescription = New NotifyDescription("ConfigureScheduledJobScheduleEnd", ThisObject);
		Dialog.Show(NOTifyDescription);
		
	Else
		ShowMessageBox(,NStr("en='It is impossible to get the scheduled job schedule: scheduled job was deleted or its description was not specified.';ru='Невозможно получить расписание регламентного задания: регламентное задание было удалено или не указано его наименование.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Command)
	
	For Each Area IN Report.SelectedAreas Do
		Details = Area.Details;
		If Details = Undefined
			OR Area.Top <> Area.Bottom Then
			ShowMessageBox(,NStr("en='Select row or cell of the job session you need';ru='Выберите строку или ячейку нужного сеанса задания'"));
			Return;
		EndIf;
		StartDate = Details.Get(0);
		EndDate = Details.Get(1);
		SessionScheduledJobs.Clear();
		SessionScheduledJobs.Add(Details.Get(2));
		EventLogMonitorFilter = New Structure("Session, StartDate, EndDate", SessionScheduledJobs, StartDate, EndDate);
		OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", EventLogMonitorFilter);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	ModuleScheduledJobsServer = CommonUse.CommonModule("ScheduledJobsServer");
	Return ModuleScheduledJobsServer.GetJobSchedule(
		ScheduledJobID);
	
EndFunction

&AtClient
Procedure ConfigureScheduledJobScheduleEnd(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetJobSchedule(Schedule);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetJobSchedule(Schedule)
	
	SetPrivilegedMode(True);
	
	ModuleScheduledJobsServer = CommonUse.CommonModule("ScheduledJobsServer");
	ModuleScheduledJobsServer.SetJobSchedule(
		ScheduledJobID,
		Schedule);
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
