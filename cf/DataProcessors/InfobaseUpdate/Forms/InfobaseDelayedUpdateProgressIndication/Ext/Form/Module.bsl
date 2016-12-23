
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	InfobaseUpdateOverridable.WhenExplanationObtainingForApplicationUpdatingResults(ToolTipText);
	// Call of the outdated procedure for the backward compatibility.
	InfobaseUpdateOverridable.GetTextExplanationsForApplicationUpdateResults(ToolTipText);
	
	If Not IsBlankString(ToolTipText) Then
		Items.InformationToolTip.Title = ToolTipText;
		Items.WhereToFindThisFormToolTip.Title = ToolTipText;
		Items.InformationToolTipFormLocation.Title = ToolTipText;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		
		Items.GroupToolTipAboutPeriodOfLowestActivityUsers.Visible = False;
		Items.WhereToFindThisFormToolTip.Title = 
			NStr("en='Progress of the application versions data processing can be
		|also controlled from the section ""Information"" on the desktop, command ""Description of application changes"".';ru='Ход обработки данных версии программы можно
		|также проконтролировать из раздела ""Информация"" на рабочем столе, команда ""Описание изменений программы"".'");
		
	EndIf;
	
	// Read out the constant value.
	DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	UpdateEndTime = DataAboutUpdate.UpdateEndTime;
	
	BeginTimeOfPendingUpdate = DataAboutUpdate.BeginTimeOfPendingUpdate;
	EndTimeDeferredUpdate = DataAboutUpdate.EndTimeDeferredUpdate;
	
	FileInfobase = CommonUse.FileInfobase();
	
	If ValueIsFilled(UpdateEndTime) Then
		Items.InformationRefreshEnabledCompleted.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			Items.InformationRefreshEnabledCompleted.Title,
			Metadata.Version,
			Format(UpdateEndTime, "DLF=D"),
			Format(UpdateEndTime, "DLF=T"),
			DataAboutUpdate.DurationOfUpdate);
	Else
		TitleRefreshCompleted = NStr("en='Application version has been successfully updated to the %1 version';ru='Версия программы успешно обновлена на версию %1'");
		Items.InformationRefreshEnabledCompleted.Title = StringFunctionsClientServer.PlaceParametersIntoString(
			TitleRefreshCompleted,
			Metadata.Version);
	EndIf;
	
	If DataAboutUpdate.EndTimeDeferredUpdate = Undefined Then
		
		If Not Users.InfobaseUserWithFullAccess(, True) Then
			Items.StatusUpdate.CurrentPage = Items.StatusUpdateForUser;
		Else
			
			If Not FileInfobase AND DataAboutUpdate.DeferredUpdateIsCompletedSuccessfully = Undefined Then
				Items.StatusUpdate.CurrentPage = Items.RefreshInProgress;
			Else
				Items.StatusUpdate.CurrentPage = Items.RefreshInFileBase;
			EndIf;
			
		EndIf;
		
	Else
		MessageText = MessageAboutUpdateResult(DataAboutUpdate);
		Items.StatusUpdate.CurrentPage = Items.RefreshEnabledCompleted;
		
		DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
		CaptionPattern = NStr("en='Additional data processing procedures have been completed %1 in %2';ru='Дополнительные процедуры обработки данных завершены %1 в %2'");
		Items.InformationPostponedUpdateCompleted1.Title = 
		StringFunctionsClientServer.PlaceParametersIntoString(CaptionPattern, 
			Format(DataAboutUpdate.EndTimeDeferredUpdate, "DLF=D"),
			Format(DataAboutUpdate.EndTimeDeferredUpdate, "DLF=T"));
		
	EndIf;
	
	If Not FileInfobase Then
		RefreshEnabledCompleted = False;
		RefreshInformationAboutUpdate(DataAboutUpdate, RefreshEnabledCompleted);
		
		If RefreshEnabledCompleted Then
			RefreshPageRefreshCompleted(DataAboutUpdate);
			Items.StatusUpdate.CurrentPage = Items.RefreshEnabledCompleted;
			Return;
		EndIf;
		
	Else
		Items.InformationStateUpdate.Visible = False;
		Items.ChangeSchedule.Visible         = False;
	EndIf;
	
	If Users.InfobaseUserWithFullAccess(, True) Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			Items.ChangeSchedule.Visible     = False;
		Else
			Schedule = ScheduledJobs.FindPredefined(
				Metadata.ScheduledJobs.DeferredInfobaseUpdate).Schedule;
		EndIf;
		
	EndIf;
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Items.HyperlinkIsMainRefreshEnabled.Visible = False;
	EndIf;
	
	HideExtraGroupsOnForm(Parameters.OpenFromAdministrationPanel);
	
	Items.OpenListOfPendingHandlers.Title = MessageText;
	Items.InformationTitle.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Additional data processing procedures to the %1 version are being executed
		|The work with these files is temporarily limited';ru='Выполняются дополнительные процедуры обработки данных
		|на версию %1 Работа с этими данными временно ограничена'"), Metadata.Version);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not FileInfobase Then
		AttachIdleHandler("ValidateExecutionStatusHandlers", 15);
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "PostponedUpdate" Then
		
		If Not FileInfobase Then
			Items.StatusUpdate.CurrentPage = Items.RefreshInProgress;
		EndIf;
		
		AttachIdleHandler("RunPostponedUpdate", 0.5, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure InformationStateUpdateClick(Item)
	OpenForm("DataProcessor.InfobaseUpdate.Form.DelayedHandlers");
EndProcedure

&AtClient
Procedure HyperlinkMainRefreshClick(Item)
	
	FormParameters = New Structure;
	FormParameters.Insert("StartDate", BeginTimeOfPendingUpdate);
	If EndTimeDeferredUpdate <> Undefined Then
		FormParameters.Insert("EndDate", EndTimeDeferredUpdate);
	EndIf;
	
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", FormParameters);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure ExecuteUpdate(Command)
	
	If Not FileInfobase Then
		Items.StatusUpdate.CurrentPage = Items.RefreshInProgress;
	EndIf;
	
	AttachIdleHandler("RunPostponedUpdate", 0.5, True);
	
EndProcedure

&AtClient
Procedure OpenListOfPendingHandlers(Command)
	OpenForm("DataProcessor.InfobaseUpdate.Form.DelayedHandlers");
EndProcedure

&AtClient
Procedure ChangeSchedule(Command)
	
	Dialog = New ScheduledJobDialog(Schedule);
	
	NotifyDescription = New NotifyDescription("ChangeScheduleAfterScheduleSetup", ThisObject);
	Dialog.Show(NOTifyDescription);
	
EndProcedure

&AtClient
Procedure UnlockScheduledJobs(Command)
	If CommonUseClient.SubsystemExists("StandardSubsystems.UserSessions") Then
		// Not to be found by the dependencies check. Link is conditional, does not require documentation.
		FormNameUsersWorkLocks = "DataProcessor" + ".UserWorkBlocking.Form.Form";
		OpenForm(FormNameUsersWorkLocks);
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure HideExtraGroupsOnForm(OpenFromAdministrationPanel)
	
	InfobaseUserWithFullAccess = Users.InfobaseUserWithFullAccess(, True);
	
	If Not InfobaseUserWithFullAccess Or OpenFromAdministrationPanel Then
		WindowOptionsKey = "FormForNormalUser";
		
		Items.ToolTipGroupFormLocation.Visible = False;
		Items.ToolTipGroupFormLocationWhenUpdating.Visible = False;
		Items.InformationToolTipFormLocation.Visible = False;
		Items.IndentUpdateIsCompleted.Visible = False;
		
		If Not Users.RolesAvailable("ViewEventLogMonitor") Then
			Items.HyperlinkIsMainRefreshEnabled.Visible = False;
		EndIf;
		
	Else
		WindowOptionsKey = "FormForAdministrator";
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.UserSessions") Then
		Items.UnlockScheduledJobs.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure RunPostponedUpdate()
	
	RunUpdateAtServer();
	If Not FileInfobase Then
		AttachIdleHandler("ValidateExecutionStatusHandlers", 15);
		Return;
	EndIf;
	
	Items.StatusUpdate.CurrentPage = Items.RefreshEnabledCompleted;
	
EndProcedure

&AtClient
Procedure ValidateExecutionStatusHandlers()
	
	RefreshEnabledCompleted = False;
	ValidateExecutionStatusHandlersAtServer(RefreshEnabledCompleted);
	If RefreshEnabledCompleted Then
		Items.StatusUpdate.CurrentPage = Items.RefreshEnabledCompleted;
		DetachIdleHandler("ValidateExecutionStatusHandlers")
	EndIf;
	
EndProcedure

&AtServer
Procedure ValidateExecutionStatusHandlersAtServer(RefreshEnabledCompleted)
	
	DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	If DataAboutUpdate.EndTimeDeferredUpdate <> Undefined Then
		RefreshEnabledCompleted = True;
	Else
		RefreshInformationAboutUpdate(DataAboutUpdate, RefreshEnabledCompleted);
	EndIf;
	
	If RefreshEnabledCompleted = True Then
		RefreshPageRefreshCompleted(DataAboutUpdate);
	EndIf;
	
EndProcedure

&AtServer
Procedure RunUpdateAtServer()
	
	DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	
	DataAboutUpdate.DeferredUpdateIsCompletedSuccessfully = Undefined;
	DataAboutUpdate.EndTimeDeferredUpdate = Undefined;
	For Each TreeRowLibrary IN DataAboutUpdate.HandlerTree.Rows Do
		For Each TreeRowVersion IN TreeRowLibrary.Rows Do
			For Each Handler IN TreeRowVersion.Rows Do
				Handler.NumberAttempts = 0;
			EndDo;
		EndDo;
	EndDo;
	InfobaseUpdateService.WriteDataOnUpdatingInformationBase(DataAboutUpdate);
	
	If Not FileInfobase Then
		
		If CommonUseReUse.DataSeparationEnabled() Then
			InfobaseUpdateService.OnEnablePostponedUpdating(True);
		Else
			ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DeferredInfobaseUpdate);
			ScheduledJob.Use = True;
			ScheduledJob.Write();
		EndIf;
		Return;
		
	EndIf;
	
	InfobaseUpdateService.PerformPostponedUpdateNow();
	
	DataAboutUpdate = InfobaseUpdateService.DataOnUpdatingInformationBase();
	RefreshPageRefreshCompleted(DataAboutUpdate);
	
EndProcedure

&AtServer
Procedure RefreshPageRefreshCompleted(DataAboutUpdate)
	
	CaptionPattern = NStr("en='Additional data processing procedures have been completed %1 in %2';ru='Дополнительные процедуры обработки данных завершены %1 в %2'");
	MessageText = MessageAboutUpdateResult(DataAboutUpdate);
	
	Items.InformationPostponedUpdateCompleted1.Title = 
		StringFunctionsClientServer.PlaceParametersIntoString(CaptionPattern, 
			Format(DataAboutUpdate.EndTimeDeferredUpdate, "DLF=D"),
			Format(DataAboutUpdate.EndTimeDeferredUpdate, "DLF=T"));
	
	Items.OpenListOfPendingHandlers.Title = MessageText;
	
	EndTimeDeferredUpdate = DataAboutUpdate.EndTimeDeferredUpdate;
	
EndProcedure

&AtServer
Function MessageAboutUpdateResult(DataAboutUpdate)
	
	HandlersList = DataAboutUpdate.HandlerTree;
	SuccessfullyCompletedHandlers = 0;
	TotalHandlers            = 0;
	For Each TreeRowLibrary IN DataAboutUpdate.HandlerTree.Rows Do
		For Each TreeRowVersion IN TreeRowLibrary.Rows Do
			TotalHandlers = TotalHandlers + TreeRowVersion.Rows.Count();
			For Each Handler IN TreeRowVersion.Rows Do
				
				If Handler.Status = "Completed" Then
					SuccessfullyCompletedHandlers = SuccessfullyCompletedHandlers + 1;
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	If TotalHandlers = SuccessfullyCompletedHandlers Then
		
		If TotalHandlers = 0 Then
			Items.InformationPendingHandlersAbsent.Visible = True;
			Items.GroupTransitionToListOfPendingHandlers.Visible = False;
		Else
			MessageText = NStr("en='All update procedures have been successfully completed (%1)';ru='Все процедуры обновления выполнены успешно (%1)'");
		EndIf;
		Items.PictureInformation1.Picture = PictureLib.Successfully32;
	Else
		MessageText = NStr("en='Not all the procedures were completed (completed %1 of %2)';ru='Не все процедуры удалось выполнить (выполнено %1 из %2)'");
		Items.PictureInformation1.Picture = PictureLib.Error32;
	EndIf;
	Return StringFunctionsClientServer.PlaceParametersIntoString(
		MessageText, SuccessfullyCompletedHandlers, TotalHandlers);
	
EndFunction

&AtServer
Procedure RefreshInformationAboutUpdate(DataAboutUpdate, RefreshEnabledCompleted = False)
	
	CompletedHandlers = 0;
	TotalHandlers     = 0;
	For Each TreeRowLibrary IN DataAboutUpdate.HandlerTree.Rows Do
		For Each TreeRowVersion IN TreeRowLibrary.Rows Do
			TotalHandlers = TotalHandlers + TreeRowVersion.Rows.Count();
			For Each Handler IN TreeRowVersion.Rows Do
				
				If Handler.Status = "Completed" Then
					CompletedHandlers = CompletedHandlers + 1;
				EndIf;
				
			EndDo;
		EndDo;
	EndDo;
	
	If TotalHandlers = 0 Then
		RefreshEnabledCompleted = True;
	EndIf;
	
	Items.InformationStateUpdate.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Completed: %1 of %2';ru='Выполнено: %1 из %2'"),
		CompletedHandlers,
		TotalHandlers);
	
EndProcedure

&AtServer
Procedure SetScheduleOfPostponedUpdate(Schedule)
	
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.DeferredInfobaseUpdate);
	ScheduledJob.Schedule = Schedule;
	ScheduledJob.Write();
	
EndProcedure

&AtClient
Procedure ChangeScheduleAfterScheduleSetup(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		If Schedule.RepeatPeriodInDay = 0 Then
			Notification = New NotifyDescription("ChangeScheduleAfterQuestion", ThisObject, Schedule);
			
			QuestionButtons = New ValueList;
			QuestionButtons.Add("ConfigureSchedule", NStr("en='Setup schedule';ru='Настроить расписание'"));
			QuestionButtons.Add("RecommendedSettings", NStr("en='Set recommended settings';ru='Установить рекомендуемые настройки'"));
			
			MessageText = NStr("en='Data processing additional procedures are executed
		|in the small portions, therefore for their correct work it is required to specify the retry interval after completion.
		|
		|For this in the schedule setting window it is required
		|to go to the tab ""Daytime"" and fill in the ""Repeating through"" filed.';ru='Дополнительные процедуры обработки данных выполняются небольшими порциями,
		|поэтому для их корректной работы необходимо обязательно задать интервал повтора после завершения.
		|
		|Для этого в окне настройки расписания необходимо перейти на вкладку """"Дневное""""
		|и заполнить поле """"Повторять через"""".'");
			ShowQueryBox(Notification, MessageText, QuestionButtons,, "ConfigureSchedule");
		Else
			SetScheduleOfPostponedUpdate(Schedule);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeScheduleAfterQuestion(Result, Schedule) Export
	
	If Result = "RecommendedSettings" Then
		Schedule.RepeatPeriodInDay = 60;
		Schedule.RepeatPause = 60;
		SetScheduleOfPostponedUpdate(Schedule);
	Else
		NotifyDescription = New NotifyDescription("ChangeScheduleAfterScheduleSetup", ThisObject);
		Dialog = New ScheduledJobDialog(Schedule);
		Dialog.Show(NOTifyDescription);
	EndIf;
	
EndProcedure

#EndRegion














