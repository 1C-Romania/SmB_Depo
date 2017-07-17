
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en='Insufficient access rights.
		|
		|Change properties of
		|scheduled job is executed only by administrators.';ru='Недостаточно прав доступа.
		|
		|Изменение свойств регламентного задания
		|выполняется только администраторами.'");
	EndIf;
	
	Action = Parameters.Action;
	
	If Find(", Add, Copy, Change,", ", " + Action + ",") = 0 Then
		
		Raise NStr("en='Incorrect parameters of opening form ""Scheduled job"".';ru='Неверные параметры открытия формы ""Регламентное задание"".'");
	EndIf;
	
	If Action = "Add" Then
		
		Schedule = New JobSchedule;
		
		For Each ScheduledJobMetadata IN Metadata.ScheduledJobs Do
			ScheduledJobMetadataDetails.Add(
				ScheduledJobMetadata.Name
					+ Chars.LF
					+ ScheduledJobMetadata.Synonym
					+ Chars.LF
					+ ScheduledJobMetadata.MethodName,
				?(IsBlankString(ScheduledJobMetadata.Synonym),
				  ScheduledJobMetadata.Name,
				  ScheduledJobMetadata.Synonym) );
		EndDo;
	Else
		Task = ScheduledJobsServer.GetScheduledJob(Parameters.ID);
		FillPropertyValues(
			ThisObject,
			Task,
			"Key,
			|Predefined,
			|Use,
			|Description,
			|UserName,
			|RestartIntervalOnFailure,
			|RestartCountOnFailure");
		
		ID = String(Task.UUID);
		If Task.Metadata = Undefined Then
			MetadataName        = NStr("en='<no metadata>';ru='<нет метаданных>'");
			MetadataSynonym     = NStr("en='<no metadata>';ru='<нет метаданных>'");
			MetadataMethodName  = NStr("en='<no metadata>';ru='<нет метаданных>'");
		Else
			MetadataName        = Task.Metadata.Name;
			MetadataSynonym     = Task.Metadata.Synonym;
			MetadataMethodName  = Task.Metadata.MethodName;
		EndIf;
		Schedule = Task.Schedule;
		
		UserMessagesAndErrorDetails = ScheduledJobsService
			.MessagesAndDescriptionsOfScheduledJobErrors(Task);
	EndIf;
	
	If Action <> "Change" Then
		ID = NStr("en='<will be created when writing>';ru='<будет создан при записи>'");
		Use = False;
		
		Description = ?(
			Action = "Add",
			"",
			ScheduledJobsService.ScheduledJobPresentation(Task));
	EndIf;
	
	// Filling choice list of user name.
	UserArray = InfobaseUsers.GetUsers();
	
	For Each User IN UserArray Do
		Items.UserName.ChoiceList.Add(User.Name);
	EndDo;
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
EndProcedure 

&AtClient
Procedure OnOpen(Cancel)
	
	If Action = "Add" Then
		AttachIdleHandler("TemplateSelectionForNewScheduledJob", 0.1, True);
	Else
		RefreshFormTitle();
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseEnd", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	
	RefreshFormTitle();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Write(Command)
	
	WriteScheduledJob();
	
EndProcedure

&AtClient
Procedure WriteAndCloseExecute()
	
	WriteAndCloseEnd();
	
EndProcedure

&AtClient
Procedure ConfigureScheduleExecute()

	Dialog = New ScheduledJobDialog(Schedule);
	Dialog.Show(New NotifyDescription("OpenScheduleEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure WriteAndCloseEnd(Result = Undefined, AdditionalParameters = Undefined) Export
	
	WriteScheduledJob();
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure TemplateSelectionForNewScheduledJob()
	
	// Template selection for scheduled job (metadata).
	ScheduledJobMetadataDetails.ShowChooseItem(
		New NotifyDescription("TemplateSelectionForNewScheduledJobEnd", ThisObject),
		NStr("en='Select a scheduled job template';ru='Выберите шаблон регламентного задания'"));
	
EndProcedure

&AtClient
Procedure TemplateSelectionForNewScheduledJobEnd(ItemOfList, NotSpecified) Export
	
	If ItemOfList = Undefined Then
		Close();
		Return;
	EndIf;
	
	MetadataName       = StrGetLine(ItemOfList.Value, 1);
	MetadataSynonym    = StrGetLine(ItemOfList.Value, 2);
	MetadataMethodName = StrGetLine(ItemOfList.Value, 3);
	Description        = ItemOfList.Presentation;
	
	RefreshFormTitle();
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, NotSpecified) Export

	If NewSchedule <> Undefined Then
		Schedule = NewSchedule;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteScheduledJob()
	
	If Not ValueIsFilled(MetadataName) Then
		Return;
	EndIf;
	
	CurrentIdentifier = ?(Action = "Change", ID, Undefined);
	
	WriteScheduledJobAtServer();
	RefreshFormTitle();
	
	Notify("Write_ScheduledJobs", CurrentIdentifier);
	
EndProcedure

&AtServer
Procedure WriteScheduledJobAtServer()
	
	If Action = "Change" Then
		Task = ScheduledJobsServer.GetScheduledJob(ID);
	Else
		Task = ScheduledJobs.CreateScheduledJob(
			Metadata.ScheduledJobs[MetadataName]);
		
		ID = String(Task.UUID);
		Action = "Change";
	EndIf;
	
	FillPropertyValues(
		Task,
		ThisObject,
		"Key, 
		|Description,
		|Use,
		|UserName,
		|RestartIntervalOnFailure,
		|RestartCountOnFailure");
	
	Task.Schedule = Schedule;
	Task.Write();
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure RefreshFormTitle()
	
	If Not IsBlankString(Description) Then
		Presentation = Description;
		
	ElsIf Not IsBlankString(MetadataSynonym) Then
		Presentation = MetadataSynonym;
	Else
		Presentation = MetadataName;
	EndIf;
	
	If Action = "Change" Then
		Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='%1 (Scheduled job)';ru='%1 (Регламентное задание)'"), Presentation);
	Else
		Title = NStr("en='Scheduled job (creation)';ru='Регламентное задание (создание)'");
	EndIf;
	
EndProcedure

#EndRegion
