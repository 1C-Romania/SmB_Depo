#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ThisIsGlobalDataProcessor;

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	If IsFolder Then
		Return;
	EndIf;
	
	ItemCheck = True;
	If AdditionalProperties.Property("ListCheck") Then
		ItemCheck = False;
	EndIf;
	
	If Not AdditionalReportsAndDataProcessors.CheckGlobalProcessing(Type) Then
		If Not UseForObjectForm AND Not UseForListForm 
			AND Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled Then
			CommonUseClientServer.MessageToUser(
				NStr("en='Disable publication or select at least one form for using';ru='Необходимо отключить публикацию или выбрать для использования как минимум одну из форм'")
				,
				,
				,
				"Object.UseForObjectForm",
				Cancel);
		EndIf;
	EndIf;
	
	// If the report is published, it is necessary to control the uniqueness of the object name under which the additional report is registered in the system.
	If Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used Then
		
		// Check name
		QueryText =
		"SELECT TOP 1
		|	1
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors AS AddReports
		|WHERE
		|	AddReports.ObjectName = &ObjectName
		|	AND &AdditReportCondition
		|	AND AddReports.Publication = VALUE(Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used)
		|	AND AddReports.DeletionMark = FALSE
		|	AND AddReports.Ref <> &Ref";
		
		AdditionalReportTypes = New Array;
		AdditionalReportTypes.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
		AdditionalReportTypes.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
		
		If AdditionalReportTypes.Find(Type) <> Undefined Then
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "AddReports.Type IN (&AdditionalReportsTypes)");
		Else
			QueryText = StrReplace(QueryText, "&AdditReportCondition", "Not AddReports.Type IN (&AdditionalReportsTypes)");
		EndIf;
		
		Query = New Query;
		Query.SetParameter("ObjectName",     ObjectName);
		Query.SetParameter("AdditionalReportsTypes", AdditionalReportTypes);
		Query.SetParameter("Ref",         Ref);
		Query.Text = QueryText;
		
		SetPrivilegedMode(True);
		Conflicting = Query.Execute().Unload();
		SetPrivilegedMode(False);
		
		If Conflicting.Count() > 0 Then
			Cancel = True;
			If ItemCheck Then
				ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Name ""%1"" used by this report (data processor) is already used by another additional published report (data processor). 
		|
		|To continue it is necessary to change Publication kind from ""%2"" to ""%3"" or ""%4"".';ru='Имя ""%1"", используемое данным отчетом (обработкой), уже занято другим опубликованным дополнительным отчетом (обработкой). 
		|
		|Для продолжения необходимо изменить вид Публикации с ""%2"" на ""%3"" или ""%4"".'"),
					ObjectName,
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used),
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode),
					String(Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled)
				);
			Else
				ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Name ""%1"" used by report (data processor) ""% 2"" already occupied by another published additional report (data processor).';ru='Имя ""%1"", используемое отчетом (обработкой) ""%2"", уже занято другим опубликованным дополнительным отчетом (обработкой).'"),
					ObjectName,
					CommonUse.ObjectAttributeValue(ThisObject.Ref, "Description")
				);
			EndIf;
			CommonUseClientServer.MessageToUser(ErrorText, , "Object.Publication");
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	// It is called right before the object is written to the data base.
	AdditionalReportsAndDataProcessors.AdditionalProcessingBeforeWrite(ThisObject, Cancel);
	
	If IsNew() AND Not AdditionalReportsAndDataProcessors.AddRight(ThisObject) Then
		Raise NStr("en='Insufficient rights for adding the additional reports and processings.';ru='Недостаточно прав для добавления дополнительных отчетов или обработок.'");
	EndIf;
	
	// Preliminary checks
	If Not IsNew() AND Type <> CommonUse.ObjectAttributeValue(Ref, "Type") Then
		CommonUseClientServer.MessageToUser(
			NStr("en='Impossible to change the existing additional report or processing type.';ru='Невозможно сменить вид существующего дополнительного отчета или обработки.'"),,,,
			Cancel);
		Return;
	EndIf;
	
	// Link of attributes marked for deletion.
	If DeletionMark Then
		Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	EndIf;
	
	// Cache of standard checks
	AdditionalProperties.Insert("PublicationIsUsed", Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used);
	
	If ThisIsGlobalDataProcessor() Then
		If RightClickScheduleSettings() Then
			BeforeWritingOfGlobalProcessing(Cancel);
		EndIf;
		Purpose.Clear();
	Else
		BeforeWriteAppointedDataProcessor(Cancel);
		Sections.Clear();
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	// It is called right after the object is written in the data base.
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	QuickAccess = Undefined;
	If AdditionalProperties.Property("QuickAccess", QuickAccess) Then
		InformationRegisters.UserSettingsOfAccessToDataProcessors.RefreshDataOnAdditionalWriteObject(Ref, QuickAccess);
	EndIf;
	
	If ThisIsGlobalDataProcessor() Then
		If RightClickScheduleSettings() Then
			OnWriteOfGlobalDataProcessor(Cancel);
		EndIf;
	Else
		OnWriteNominatedDataProcessors(Cancel);
	EndIf;
	
	If Type = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport Then
		OnWriteGlobalReport(Cancel);
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	// It is called right before deleting the object from the data base.
	AdditionalReportsAndDataProcessors.BeforeAdditionalInformationProcessorDeletion(ThisObject, Cancel);
	
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	If AdditionalReportsAndDataProcessors.CheckGlobalProcessing(Type) Then
		BeforeDeleteOfGlobalProcessing(Cancel);
	EndIf;
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function ThisIsGlobalDataProcessor()
	
	If ThisIsGlobalDataProcessor = Undefined Then
		ThisIsGlobalDataProcessor = AdditionalReportsAndDataProcessors.CheckGlobalProcessing(Type);
	EndIf;
	
	Return ThisIsGlobalDataProcessor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Global data processors

Procedure BeforeWritingOfGlobalProcessing(Cancel)
	If Cancel OR Not AdditionalProperties.Property("ActualCommands") Then
		Return;
	EndIf;
	
	CommandTable = AdditionalProperties.ActualCommands;
	
	TasksForUpdating = New Map;
	
	PublicationIsIncluded = (Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	
	// Scheduled job is required to be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	// Clearing jobs on commands that were removed from the table.
	If Not IsNew() Then
		For Each OldCommand IN Ref.Commands Do
			If ValueIsFilled(OldCommand.ScheduledJobGUID)
				AND CommandTable.Find(OldCommand.ScheduledJobGUID, "ScheduledJobGUID") = Undefined Then
				
				Task = AdditionalReportsAndDataProcessorsScheduledJobs.FindJob(OldCommand.ScheduledJobGUID);
				If Task <> Undefined Then
					AdditionalReportsAndDataProcessorsScheduledJobs.DeleteJob(Task);
				EndIf;
				
			EndIf;
		EndDo;
	EndIf;
	
	// Update of scheduled jobs set for recording their IDs in tabular section.
	For Each ActualCommand IN CommandTable Do
		
		Command = Commands.Find(ActualCommand.ID, "ID");
		
		If PublicationIsIncluded AND ActualCommand.ScheduledJobSchedule.Count() > 0 Then
			Schedule    = ActualCommand.ScheduledJobSchedule[0].Value;
			Use = ActualCommand.ScheduledJobUse AND ScheduleWasSet(Schedule);
		Else
			Schedule = Undefined;
			Use = False;
		EndIf;
		
		Task = AdditionalReportsAndDataProcessorsScheduledJobs.FindJob(ActualCommand.ScheduledJobGUID);
		
		If Task = Undefined Then // Not found
			
			If Use Then
				
				Task = AdditionalReportsAndDataProcessorsScheduledJobs.CreateNewJob(
					TaskPresentation(ActualCommand));
				
				TasksForUpdating.Insert(ActualCommand, Task);
				
				// Create and register
				Command.ScheduledJobGUID = 
					AdditionalReportsAndDataProcessorsScheduledJobs.GetIDTasks(
						Task);
				
			Else
				// Action is not required
			EndIf;
			
		Else // Found
			
			If Use Then
				// Register
				TasksForUpdating.Insert(ActualCommand, Task);
			Else
				// Delete
				AdditionalReportsAndDataProcessorsScheduledJobs.DeleteJob(Task);
				Command.ScheduledJobGUID = New UUID("00000000-0000-0000-0000-000000000000");
			EndIf;
			
		EndIf;
		
	EndDo;
	
	AdditionalProperties.Insert("TasksForUpdating", TasksForUpdating);
	
EndProcedure

Procedure OnWriteOfGlobalDataProcessor(Cancel)
	
	If Cancel OR Not AdditionalProperties.Property("ActualCommands") Then
		Return;
	EndIf;
	
	PublicationIsIncluded = (Publication <> Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	
	// Scheduled job is required to be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	For Each KeyAndValue IN AdditionalProperties.TasksForUpdating Do
		
		Command = KeyAndValue.Key;
		Task = KeyAndValue.Value;
		
		If PublicationIsIncluded AND Command.ScheduledJobSchedule.Count() > 0 Then
			Schedule    = Command.ScheduledJobSchedule[0].Value;
			Use = Command.ScheduledJobUse AND ScheduleWasSet(Schedule);
		Else
			Schedule    = Undefined;
			Use = False;
		EndIf;
		
		JobParameters = New Array;
		JobParameters.Add(Ref);
		JobParameters.Add(Command.ID);
		
		AdditionalReportsAndDataProcessorsScheduledJobs.SetJobParameters(
			Task,
			Use,
			Left(TaskPresentation(Command), 120),
			JobParameters,
			Schedule);
		
	EndDo;
	
EndProcedure

Procedure BeforeDeleteOfGlobalProcessing(Cancel)
	
	// Scheduled job is required to be changed in the privileged mode.
	SetPrivilegedMode(True);
	
	For Each Command IN Commands Do
		
		Task = AdditionalReportsAndDataProcessorsScheduledJobs.FindJob(
			Command.ScheduledJobGUID);
			
		If Task <> Undefined Then
			AdditionalReportsAndDataProcessorsScheduledJobs.DeleteJob(Task);
		EndIf;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Work with scheduled jobs.

Function RightClickScheduleSettings()
	// Checks the existence of the right to set a schedule for additional reports and data processors.
	Return Users.RolesAvailable("AddChangeAdditionalReportsAndDataProcessors");
EndFunction

Function TaskPresentation(Command)
	// '%1: %2 / Command: %3'
	Return (
		TrimAll(Type)
		+ ": "
		+ TrimAll(Description)
		+ " / "
		+ NStr("en='Command';ru='команда'")
		+ ": "
		+ TrimAll(Command.Presentation));
EndFunction

Function ScheduleWasSet(Schedule)
	
	Return String(Schedule) <> String(New JobSchedule);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Assigned data processors

Procedure BeforeWriteAppointedDataProcessor(Cancel)
	TablePurpose = Purpose.Unload();
	TablePurpose.GroupBy("ObjectDestination");
	Purpose.Load(TablePurpose);
	
	RefreshEnabledRegisterPurpose = New Structure("RefArray");
	
	RefOfMetadataObjects = TablePurpose.UnloadColumn("ObjectDestination");
	
	If Not IsNew() Then
		For Each TableRow IN Ref.Purpose Do
			If RefOfMetadataObjects.Find(TableRow.ObjectDestination) = Undefined Then
				RefOfMetadataObjects.Add(TableRow.ObjectDestination);
			EndIf;
		EndDo;
	EndIf;
	
	AdditionalProperties.Insert("RefOfMetadataObjects", RefOfMetadataObjects);
EndProcedure

Procedure OnWriteNominatedDataProcessors(Cancel)
	If Cancel OR Not AdditionalProperties.Property("RefOfMetadataObjects") Then
		Return;
	EndIf;
	
	InformationRegisters.AdditionalInformationProcessorsFunctions.RefreshDataOnLinksOfMetadataObjects(AdditionalProperties.RefOfMetadataObjects);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Global reports

Procedure OnWriteGlobalReport(Cancel)
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportsVariants") Then
		
		Try
			If IsNew() Then
				ExternalObject = ExternalReports.Create(ObjectName);
			Else
				ExternalObject = AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(Ref);
			EndIf;
		Except
			ErrorText = NStr("en='Connection error:';ru='Ошибка подключения:'") + Chars.LF + DetailErrorDescription(ErrorInfo());
			AdditionalReportsAndDataProcessors.WriteError(Ref, ErrorText);
			AdditionalProperties.Insert("ErrorConnection", ErrorText);
			Return;
		EndTry;
		
		ModuleReportsVariants = CommonUse.CommonModule("ReportsVariants");
		ModuleReportsVariants.OnWriteAdditionalReport(ThisObject, Cancel, ExternalObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
