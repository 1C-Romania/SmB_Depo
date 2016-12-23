#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en='Insufficient access rights.
		|
		|Work with scheduled and
		|background jobs is executed only by administrators.';ru='Недостаточно прав доступа.
		|
		|Работа с
		|регламентными и фоновыми заданиями выполняется только администраторами.'");
	EndIf;
	
	EmptyID = String(New UUID("00000000-0000-0000-0000-000000000000"));
	TextUndefined = ScheduledJobsService.TextUndefined();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not SettingsImported Then
		FillFormSettings(New Map);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ScheduledJobs" Then
		
		If ValueIsFilled(Parameter) Then
			RefreshScheduledJobsTable(Parameter);
		Else
			AttachIdleHandler("ScheduledJobsPostponedUpdate", 0.1, True);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FillFormSettings(Settings);
	
	SettingsImported = True;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure TasksOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.BackgroundJobs
	   AND Not BackgroundJobPageOpened Then
		
		BackgroundJobPageOpened = True;
		RefreshBackgroundJobsTable();
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterKindByPeriodOnChange(Item)
	
	CurrentSessionDate = CurrentSessionDateAtServer();
	
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodTill.ReadOnly = Not (FilterKindByPeriod = 4);
	
	If FilterKindByPeriod = 0 Then
		FilterPeriodFrom  = '00010101';
		FilterPeriodTill = '00010101';
		Items.SettingArbitraryPeriod.Visible = False;
	ElsIf FilterKindByPeriod = 4 Then
		FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		FilterPeriodTill = FilterPeriodFrom;
		Items.SettingArbitraryPeriod.Visible = True;
	Else
		RefreshAutomaticPeriod(ThisObject, CurrentSessionDate);
		Items.SettingArbitraryPeriod.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterByScheduledJobOnChange(Item)

	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
EndProcedure

&AtClient
Procedure ScheduledJobToBeFilteredClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	ScheduledJobForFilterID = EmptyID;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersBackgroundJobTable

&AtClient
Procedure TableBackgroundJobsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenBackgroundJob();
	
EndProcedure

#EndRegion

#Region FormTableEventsHandlersJobScheduledItemsTable

&AtClient
Procedure TableScheduledJobsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field = "Predefined"
	 OR Field = "Use" Then
		
		AddCopyChangeScheduledJob("Change");
	EndIf;
	
EndProcedure

&AtClient
Procedure TableScheduledJobsBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
	AddCopyChangeScheduledJob(?(Copy, "Copy", "Add"));
	
EndProcedure

&AtClient
Procedure TableScheduledJobsBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
	AddCopyChangeScheduledJob("Change");
	
EndProcedure

&AtClient
Procedure TableScheduledJobsBeforeDelete(Item, Cancel)
	
	Cancel = True;
	
	If Items.ScheduledJobTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en='Select one scheduled job.';ru='Выберите одно регламентное задание.'"));
		
	ElsIf Item.CurrentData.Predefined Then
		ShowMessageBox(, NStr("en='Impossible to delete the predefined scheduled job.';ru='Невозможно удалить предопределенное регламентное задание.'") );
	Else
		ShowQueryBox(
			New NotifyDescription("TableScheduledJobsBeforeDeleteEnd", ThisObject),
			NStr("en='Delete scheduled job?';ru='Удалить регламентное задание?'"), QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UpdateScheduledJobs(Command)
	
	RefreshScheduledJobsTable();
	
EndProcedure

&AtClient
Procedure ExecuteScheduledJobManually(Command)

	If Items.ScheduledJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Select the scheduled job.';ru='Выберите регламентное задание.'"));
		Return;
	EndIf;
	
	SelectedRows = New Array;
	For Each SelectedRow IN Items.ScheduledJobTable.SelectedRows Do
		SelectedRows.Add(SelectedRow);
	EndDo;
	IndexOf = 0;
	
	EventsAboutErrorsArray = New Array;
	
	For Each SelectedRow IN SelectedRows Do
		UpdateAll = (IndexOf = SelectedRows.Count() - 1);
		CurrentData = ScheduledJobTable.FindByID(SelectedRow);
		
		ExecuteParameters = ExecuteScheduledJobManuallyAtServer(CurrentData.ID, UpdateAll);
		If ExecuteParameters.Started Then
			
			ShowUserNotification(
				NStr("en='Scheduled job procedure is running';ru='Запущена процедура регламентного задания'"), ,
				StringFunctionsClientServer.PlaceParametersIntoString(NStr("en='%1.
		|Procedure is launched in the background job %2';ru='%1.
		|Процедура запущена в фоновом задании %2'"),
					CurrentData.Description,
					String(ExecuteParameters.StartedAt)),
				PictureLib.ExecuteScheduledJobManually);
			
			BackgroundJobIDsOnManualChange.Add(
				ExecuteParameters.BackgroundJobID,
				CurrentData.Description);
			
			AttachIdleHandler(
				"ShowMessageAboutScheduledJobManualProcessingCompletion", 0.1, True);
		ElsIf ExecuteParameters.ProcedureAlreadyExecuting Then
			EventsAboutErrorsArray.Add(
				StringFunctionsClientServer.PlaceParametersIntoString(
					NStr("en='Scheduled job procedure
		|  ""%1"" is already in progress in %2 session, opened %3.';ru='Процедура
		|  регламентного задания ""%1"" уже выполняется в сеансе %2, открытом %3.'"),
					CurrentData.Description,
					ExecuteParameters.BackgroundJobPresentation,
					String(ExecuteParameters.StartedAt)));
		Else
			Items.ScheduledJobTable.SelectedRows.Delete(
				Items.ScheduledJobTable.SelectedRows.Find(SelectedRow));
		EndIf;
		
		IndexOf = IndexOf + 1;
	EndDo;
	
	ErrorsCount = EventsAboutErrorsArray.Count();
	If ErrorsCount > 0 Then
		TextAboutErrorsTitle = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='Jobs have been performed with errors (%1 of %2)';ru='Задания выполнены с ошибками (%1 из %2)'"),
			Format(ErrorsCount, "NG="),
			Format(SelectedRows.Count(), "NG="));
		
		AllErrorsText = New TextDocument;
		AllErrorsText.AddLine(TextAboutErrorsTitle + ":");
		For Each ThisErrorText IN EventsAboutErrorsArray Do
			AllErrorsText.AddLine("");
			AllErrorsText.AddLine(ThisErrorText);
		EndDo;
		
		If ErrorsCount > 5 Then
			Buttons = New ValueList;
			Buttons.Add(1, NStr("en='Show errors';ru='Показать ошибки'"));
			Buttons.Add(DialogReturnCode.Cancel);
			
			ShowQueryBox(
				New NotifyDescription(
					"ExecuteScheduledJobManuallyEnd", ThisObject, AllErrorsText),
				TextAboutErrorsTitle, Buttons);
		Else
			ShowMessageBox(, TrimAll(AllErrorsText.GetText()));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateBackgroundJobs(Command)
	
	RefreshBackgroundJobsTable();
	
EndProcedure

&AtClient
Procedure ConfigureSchedule(Command)
	
	CurrentData = Items.ScheduledJobTable.CurrentData;
	
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Select the scheduled job.';ru='Выберите регламентное задание.'"));
	
	ElsIf Items.ScheduledJobTable.SelectedRows.Count() > 1 Then
		ShowMessageBox(, NStr("en='Select one scheduled job.';ru='Выберите одно регламентное задание.'"));
	Else
		Dialog = New ScheduledJobDialog(
			GetSchedule(CurrentData.ID));
		
		Dialog.Show(New NotifyDescription(
			"OpenScheduleEnd", ThisObject, CurrentData));
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableScheduledJob(Command)
	
	SetUseScheduledJob(True);
	
EndProcedure

&AtClient
Procedure DisableScheduledJob(Command)
	
	SetUseScheduledJob(False);
	
EndProcedure

&AtClient
Procedure OpenBackgroundJobOnClient(Command)
	
	OpenBackgroundJob();
	
EndProcedure

&AtClient
Procedure CancelBackgroundJob(Command)
	
	If Items.BackgroundJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Choose a background job.';ru='Выберите фоновое задание.'"));
	Else
		CancelBackgroundJobAtServer(Items.BackgroundJobTable.CurrentData.ID);
		
		ShowMessageBox(,
			NStr("en='Job was cancelled, but the
		|cancellation state will be set
		|by server only in seconds, you might need to update data manually.';ru='Задание отменено, но
		|состояние отмены будет установлено
		|сервером только через секунды, возможно потребуется обновить данные вручную.'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.End.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("BackgroundJobTable.End");
	FilterElement.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Text", NStr("en='<>';ru='<>'"));
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExecutionState.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ScheduledJobTable.ExecutionState");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='<not defined>';ru='<не определено>'");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.EndDate.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ScheduledJobTable.EndDate");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = NStr("en='<not defined>';ru='<не определено>'");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleDataColor);


EndProcedure

&AtClient
Procedure TableScheduledJobsBeforeDeleteEnd(Response, NotSpecified) Export
	
	If Response = DialogReturnCode.Yes Then
		DeleteScheduledJobExecuteAtServer(
			Items.ScheduledJobTable.CurrentData.ID);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteScheduledJobManuallyEnd(Response, AllErrorsText) Export
	
	If Response = 1 Then
		AllErrorsText.Show();
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, CurrentData) Export

	If NewSchedule <> Undefined Then
		SetSchedule(CurrentData.ID, NewSchedule);
		RefreshScheduledJobsTable(CurrentData.ID);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSchedule(Val ScheduledJobID)
	
	SetPrivilegedMode(True);
	
	Return ScheduledJobsServer.GetJobSchedule(
		ScheduledJobID);
	
EndFunction

&AtServerNoContext
Procedure SetSchedule(Val ScheduledJobID, Val Schedule)
	
	SetPrivilegedMode(True);
	
	ScheduledJobsServer.SetJobSchedule(
		ScheduledJobID,
		Schedule);
	
EndProcedure

&AtServer
Procedure FillFormSettings(Val Settings)
	
	RefreshScheduledJobsTable();
	
	DefaultSettings = New Structure;
	
	// Filter setting of the background jobs.
	If Settings.Get("FilterByActiveState") = Undefined Then
		Settings.Insert("FilterByActiveState", True);
	EndIf;
	
	If Settings.Get("FilterByCompletedState") = Undefined Then
		Settings.Insert("FilterByCompletedState", True);
	EndIf;
	
	If Settings.Get("FilterByFailedState") = Undefined Then
		Settings.Insert("FilterByFailedState", True);
	EndIf;

	If Settings.Get("FilterByCanceledState") = Undefined Then
		Settings.Insert("FilterByCanceledState", True);
	EndIf;
	
	If Settings.Get("FilterByScheduledJob") = Undefined
	 OR Settings.Get("ScheduledJobForFilterID")   = Undefined Then
		Settings.Insert("FilterByScheduledJob", False);
		Settings.Insert("ScheduledJobForFilterID", EmptyID);
	EndIf;
	
	// Setting filter by period "For all time".See
	// also event handler FilterKindByPeriodOnChange switch.
	If Settings.Get("FilterKindByPeriod") = Undefined
	 OR Settings.Get("FilterPeriodFrom")       = Undefined
	 OR Settings.Get("FilterPeriodTill")      = Undefined Then
		
		Settings.Insert("FilterKindByPeriod", 0);
		CurrentSessionDate = CurrentSessionDate();
		Settings.Insert("FilterPeriodFrom",  BegOfDay(CurrentSessionDate) - 3*3600);
		Settings.Insert("FilterPeriodTill", BegOfDay(CurrentSessionDate) + 9*3600);
	EndIf;
	
	For Each Setting IN Settings Do
		DefaultSettings.Insert(Setting.Key, Setting.Value);
	EndDo;
	
	FillPropertyValues(ThisObject, DefaultSettings);
	
	// Visible and accessibility settings.
	Items.FilterPeriodFrom.ReadOnly  = Not (FilterKindByPeriod = 4);
	Items.FilterPeriodTill.ReadOnly = Not (FilterKindByPeriod = 4);
	Items.ScheduledJobForFilter.Enabled = FilterByScheduledJob;
	
	RefreshAutomaticPeriod(ThisObject, CurrentSessionDate());
	
	RefreshBackgroundJobsTable();
	
EndProcedure

&AtClient
Procedure OpenBackgroundJob()
	
	If Items.BackgroundJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Choose a background job.';ru='Выберите фоновое задание.'"));
		Return;
	EndIf;
	
	PassedPropertyList =
	"ID,
	|Key,
	|Description,
	|MethodName,
	|Status,
	|Begin,
	|End,
	|Location,
	|UserMessagesAndErrorDetails,
	|ScheduledJobID,
	|ScheduledJobDescription";
	CurrentDataValues = New Structure(PassedPropertyList);
	FillPropertyValues(CurrentDataValues, Items.BackgroundJobTable.CurrentData);
	
	FormParameters = New Structure;
	FormParameters.Insert("ID", Items.BackgroundJobTable.CurrentData.ID);
	FormParameters.Insert("BackgroundJobProperties", CurrentDataValues);
	
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.BackgroundJob", FormParameters, ThisObject);
	
EndProcedure

&AtServerNoContext
Function CurrentSessionDateAtServer()
	
	Return CurrentSessionDate();
	
EndFunction

&AtServer
Function NotificationsAboutScheduledJobCompletion()
	
	CompletionNotifications = New Array;
	
	If BackgroundJobIDsOnManualChange.Count() > 0 Then
		IndexOf = BackgroundJobIDsOnManualChange.Count() - 1;
		
		SetPrivilegedMode(True);
		While IndexOf >= 0 Do
			
			Filter = New Structure("UUID", New UUID(
				BackgroundJobIDsOnManualChange[IndexOf].Value));
			
			BackgroundJobArray = BackgroundJobs.GetBackgroundJobs(Filter);
			
			If BackgroundJobArray.Count() = 1 Then
				FinishedAt = BackgroundJobArray[0].End;
				
				If ValueIsFilled(FinishedAt) Then
					
					CompletionNotifications.Add(
						New Structure(
							"ScheduledJobPresentation,
							|FinishedAt",
							BackgroundJobIDsOnManualChange[IndexOf].Presentation,
							FinishedAt));
					
					BackgroundJobIDsOnManualChange.Delete(IndexOf);
				EndIf;
			Else
				BackgroundJobIDsOnManualChange.Delete(IndexOf);
			EndIf;
			IndexOf = IndexOf - 1;
		EndDo;
		SetPrivilegedMode(False);
	EndIf;
	
	RefreshScheduledJobsTable();
	
	Return CompletionNotifications;
	
EndFunction

&AtClient
Procedure ShowMessageAboutScheduledJobManualProcessingCompletion()
	
	CompletionNotifications = NotificationsAboutScheduledJobCompletion();
	
	For Each Notification IN CompletionNotifications Do
		
		ShowUserNotification(
			NStr("en='Scheduled job procedure has been completed';ru='Выполнена процедура регламентного задания'"),
			,
			StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='%1.
		|The procedure has been completed at the background job %2';ru='%1.
		|Процедура завершена в фоновом задании %2'"),
				Notification.ScheduledJobPresentation,
				String(Notification.FinishedAt)),
			PictureLib.ExecuteScheduledJobManually);
	EndDo;
	
	If BackgroundJobIDsOnManualChange.Count() > 0 Then
		
		AttachIdleHandler(
			"ShowMessageAboutScheduledJobManualProcessingCompletion", 2, True);
	EndIf;

EndProcedure

&AtServer
Procedure RefreshScheduledJobChoiceList()
	
	Table = ScheduledJobTable;
	List  = Items.ScheduledJobForFilter.ChoiceList;
	
	// Adding the predefined item.
	If List.Count() = 0 Then
		List.Add(EmptyID, TextUndefined);
	EndIf;
	
	IndexOf = 1;
	For Each Task IN Table Do
		If IndexOf >= List.Count()
		 OR List[IndexOf].Value <> Task.ID Then
			// Insertion of new job.
			List.Insert(IndexOf, Task.ID, Task.Description);
		Else
			List[IndexOf].Presentation = Task.Description;
		EndIf;
		IndexOf = IndexOf + 1;
	EndDo;
	
	// Extra rows deletion.
	While IndexOf < List.Count() Do
		List.Delete(IndexOf);
	EndDo;
	
	ItemOfList = List.FindByValue(ScheduledJobForFilterID);
	If ItemOfList = Undefined Then
		ScheduledJobForFilterID = EmptyID;
	EndIf;
	
EndProcedure

&AtServer
Function ExecuteScheduledJobManuallyAtServer(Val ScheduledJobID, UpdateAll = False)
													 
	Result = ScheduledJobsService.ExecuteScheduledJobManually(ScheduledJobID);
	If UpdateAll Then
		RefreshScheduledJobsTable();
	Else
		RefreshScheduledJobsTable(ScheduledJobID);
	EndIf;
	Return Result;
	
EndFunction

&AtServer
Procedure CancelBackgroundJobAtServer(Val ID)
	
	ScheduledJobsService.CancelBackgroundJob(ID);
	
	RefreshScheduledJobsTable();
	RefreshBackgroundJobsTable();
	
EndProcedure

&AtServer
Procedure DeleteScheduledJobExecuteAtServer(Val ID)
	
	Task = ScheduledJobsServer.GetScheduledJob(ID);
	String = ScheduledJobTable.FindRows(New Structure("ID", ID))[0];
	Task.Delete();
	ScheduledJobTable.Delete(ScheduledJobTable.IndexOf(String));
	
EndProcedure

&AtClient
Procedure AddCopyChangeScheduledJob(Val Action)
	
	If Items.ScheduledJobTable.CurrentData = Undefined Then
		ShowMessageBox(, NStr("en='Select the scheduled job.';ru='Выберите регламентное задание.'"));
	Else
		FormParameters = New Structure;
		FormParameters.Insert("ID", Items.ScheduledJobTable.CurrentData.ID);
		FormParameters.Insert("Action",      Action);
		
		OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJob", FormParameters, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ScheduledJobsPostponedUpdate()
	
	RefreshScheduledJobsTable();
	
EndProcedure

&AtServer
Procedure RefreshScheduledJobsTable(ScheduledJobID = Undefined)

	// Updating the ScheduledJobs table and ChoiceList list of the scheduled job for selection.
	CurrentJobs = ScheduledJobs.GetScheduledJobs();
	Table = ScheduledJobTable;
	
	Tasks1SaaS = New Map;
	SubsystemSaaS = Metadata.Subsystems.StandardSubsystems.Subsystems.Find("SaaS");
	If Not CommonUseReUse.DataSeparationEnabled() AND SubsystemSaaS <> Undefined Then
		For Each MetadataObject IN Metadata.ScheduledJobs Do
			If SubsystemSaaS.Content.Contains(MetadataObject) Then
				Tasks1SaaS.Insert(MetadataObject.Name, True);
				Continue;
			EndIf;
			For Each Subsystem IN SubsystemSaaS.Subsystems Do
				If Subsystem.Content.Contains(MetadataObject) Then
					Tasks1SaaS.Insert(MetadataObject.Name, True);
					Continue;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	If ScheduledJobID = Undefined Then
		
		IndexOf = 0;
		For Each Task IN CurrentJobs Do
			If Not CommonUseReUse.DataSeparationEnabled()
			   AND Tasks1SaaS[Task.Metadata.Name] <> Undefined Then
				
				Continue;
			EndIf;
			
			ID = String(Task.UUID);
			
			If IndexOf >= Table.Count()
			 OR Table[IndexOf].ID <> ID Then
				
				// Insertion of new job.
				Update = Table.Insert(IndexOf);
				
				// Setting the unique ID.
				Update.ID = ID;
			Else
				Update = Table[IndexOf];
			EndIf;
			UpdateScheduledJobsTableRow(Update, Task);
			IndexOf = IndexOf + 1;
		EndDo;
	
		// Extra rows deletion.
		While IndexOf < Table.Count() Do
			Table.Delete(IndexOf);
		EndDo;
	Else
		Task = ScheduledJobs.FindByUUID(
			New UUID(ScheduledJobID));
		
		Rows = Table.FindRows(
			New Structure("ID", ScheduledJobID));
		
		If Task <> Undefined
		   AND Rows.Count() > 0 Then
			
			UpdateScheduledJobsTableRow(Rows[0], Task);
		EndIf;
	EndIf;
	
	Items.ScheduledJobTable.Refresh();
	
	BracketPosition = Find(Items.ScheduledJobs.Title, " (");
	If BracketPosition > 0 Then
		Items.ScheduledJobs.Title = Left(Items.ScheduledJobs.Title, BracketPosition - 1);
	EndIf;
	ItemsInList = ScheduledJobTable.Count();
	If ItemsInList > 0 Then
		Items.ScheduledJobs.Title = Items.ScheduledJobs.Title + " (" + Format(ItemsInList, "NG=") + ")";
	EndIf;
	
	RefreshScheduledJobChoiceList();
	
EndProcedure

&AtServer
Procedure UpdateScheduledJobsTableRow(String, Task);
	
	FillPropertyValues(String, Task);
	
	// Adjusting the name
	String.Description = ScheduledJobsService.ScheduledJobPresentation(Task);
	
	// Setting End date and Completion state by the latest background procedure.
	LastBackgroundJobProperties = ScheduledJobsService
		.GetScheduledJobExecutionLastBackgroundJobProperties(Task);
	
	If LastBackgroundJobProperties = Undefined Then
		
		String.EndDate       = TextUndefined;
		String.ExecutionState = TextUndefined;
	Else
		String.EndDate       = ?(ValueIsFilled(LastBackgroundJobProperties.End),
		                               LastBackgroundJobProperties.End,
		                               "<>");
		String.ExecutionState = LastBackgroundJobProperties.State;
	EndIf;
		
EndProcedure

&AtServer
Procedure RefreshBackgroundJobsTable()
	
	If Not BackgroundJobPageOpened Then
		Return;
	EndIf;
	
	// 1. Filter preparation.
	Filter = New Structure;
	
	// 1.1. Adding filter by states.
	StateArray = New Array;
	
	If FilterByActiveState Then 
		StateArray.Add(BackgroundJobState.Active);
	EndIf;
	
	If FilterByCompletedState Then 
		StateArray.Add(BackgroundJobState.Completed);
	EndIf;
	
	If FilterByFailedState Then 
		StateArray.Add(BackgroundJobState.Failed);
	EndIf;
	
	If FilterByCanceledState Then 
		StateArray.Add(BackgroundJobState.Canceled);
	EndIf;
	
	If StateArray.Count() <> 4 Then
		If StateArray.Count() = 1 Then
			Filter.Insert("State", StateArray[0]);
		Else
			Filter.Insert("State", StateArray);
		EndIf;
	EndIf;
	
	// 1.2. Adding filter by scheduled job.
	If FilterByScheduledJob Then
		Filter.Insert(
				"ScheduledJobID",
				?(ScheduledJobForFilterID = EmptyID,
				"",
				ScheduledJobForFilterID));
	EndIf;
	
	// 1.3. Adding filter by period.
	If FilterKindByPeriod <> 0 Then
		RefreshAutomaticPeriod(ThisObject, CurrentSessionDate());
		Filter.Insert("Begin", FilterPeriodFrom);
		Filter.Insert("End",  FilterPeriodTill);
	EndIf;
	
	// 2. Update the list of background jobs.
	Table = BackgroundJobTable;
	
	CurrentTable = ScheduledJobsService.GetBackgroundJobsPropertiesTable(Filter);
	
	IndexOf = 0;
	For Each Task IN CurrentTable Do
		
		If IndexOf >= Table.Count()
		 OR Table[IndexOf].ID <> Task.ID Then
			// Insertion of new job.
			Update = Table.Insert(IndexOf);
			// Setting the unique ID.
			Update.ID = Task.ID;
		Else
			Update = Table[IndexOf];
		EndIf;
		
		FillPropertyValues(Update, Task);
		
		// Setting the name of scheduled job from the ScheduledJobTable collection.
		If ValueIsFilled(Update.ScheduledJobID) Then
			
			Update.ScheduledJobID
				= Update.ScheduledJobID;
			
			Rows = ScheduledJobTable.FindRows(
				New Structure("ID", Update.ScheduledJobID));
			
			Update.ScheduledJobDescription
				= ?(Rows.Count() = 0, NStr("en='<not found>';ru='<не найден>'"), Rows[0].Description);
		Else
			Update.ScheduledJobDescription  = TextUndefined;
			Update.ScheduledJobID = TextUndefined;
		EndIf;
		
		// Getting information about errors.
		Update.UserMessagesAndErrorDetails 
			= ScheduledJobsService.MessagesAndDescriptionsOfBackgroundJobErrors(
				Update.ID, Task);
		
		// Index increase
		IndexOf = IndexOf + 1;
	EndDo;
	
	// Extra rows deletion.
	While IndexOf < Table.Count() Do
		Table.Delete(Table.Count()-1);
	EndDo;
	
	Items.BackgroundJobTable.Refresh();
	
	BracketPosition = Find(Items.BackgroundJobs.Title, " (");
	If BracketPosition > 0 Then
		Items.BackgroundJobs.Title = Left(Items.BackgroundJobs.Title, BracketPosition - 1);
	EndIf;
	ItemsInList = BackgroundJobTable.Count();
	If ItemsInList > 0 Then
		Items.BackgroundJobs.Title = Items.BackgroundJobs.Title + " (" + Format(ItemsInList, "NG=") + ")";
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure RefreshAutomaticPeriod(Form, CurrentSessionDate)
	
	If Form.FilterKindByPeriod = 1 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 3*3600;
		Form.FilterPeriodTill = BegOfDay(CurrentSessionDate) + 9*3600;
		
	ElsIf Form.FilterKindByPeriod = 2 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate) - 24*3600;
		Form.FilterPeriodTill = EndOfDay(Form.FilterPeriodFrom);
		
	ElsIf Form.FilterKindByPeriod = 3 Then
		Form.FilterPeriodFrom  = BegOfDay(CurrentSessionDate);
		Form.FilterPeriodTill = EndOfDay(Form.FilterPeriodFrom);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUseScheduledJob(Enabled)
	
	For Each SelectedRow IN Items.ScheduledJobTable.SelectedRows Do
		CurrentData = ScheduledJobTable.FindByID(SelectedRow);
		Task = ScheduledJobsServer.GetScheduledJob(CurrentData.ID);
		If Task.Use <> Enabled Then
			Task.Use = Enabled;
			Task.Write();
			CurrentData.Use = Enabled;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion














