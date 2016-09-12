#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Parameters.Property("Title") Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	If Parameters.Property("Representation") Then
		Items.List.Representation = TableRepresentation[Parameters.Representation];
	EndIf;
	
	ChoiceList = Items.PublicationFilter.ChoiceList;
	
	TypeIsUsed = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
	KindDisconnected = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	ViewModeDebugging = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	
	PublicationsAvailableTypes = AdditionalReportsAndDataProcessorsReUse.PublicationsAvailableTypes();
	
	AllPublicationsBesidesUnused = New Array;
	AllPublicationsBesidesUnused.Add(TypeIsUsed);
	If PublicationsAvailableTypes.Find(ViewModeDebugging) <> Undefined Then
		AllPublicationsBesidesUnused.Add(ViewModeDebugging);
	EndIf;
	
	If AllPublicationsBesidesUnused.Count() > 1 Then
		
		ArrayPresentation = StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en='%1 or %2';ru='%1 или %2'"),
			String(AllPublicationsBesidesUnused[0]),
			String(AllPublicationsBesidesUnused[1]));
		
		ChoiceList.Add(1, ArrayPresentation);
		
	EndIf;
	
	For Each EnumValue IN Enums.AdditionalReportsAndDataProcessorsPublicationOptions Do
		If PublicationsAvailableTypes.Find(EnumValue) <> Undefined Then
			ChoiceList.Add(EnumValue, String(EnumValue));
		EndIf;
	EndDo;
	
	ChoiceList = Items.TypeFilter.ChoiceList;
	ChoiceList.Add(1, NStr("en='Only reports';ru='Только отчеты'"));
	ChoiceList.Add(2, NStr("en='Only data processors';ru='Только обработки'"));
	For Each EnumValue IN Enums.AdditionalReportsAndDataProcessorsKinds Do
		ChoiceList.Add(EnumValue, String(EnumValue));
	EndDo;
	
	AdditionalReportTypes = New Array;
	AdditionalReportTypes.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	AdditionalReportTypes.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	
	List.Parameters.SetParameterValue("PublicationFilter", PublicationFilter);
	List.Parameters.SetParameterValue("TypeFilter",        TypeFilter);
	List.Parameters.SetParameterValue("AdditionalReportTypes",  AdditionalReportTypes);
	List.Parameters.SetParameterValue("AllPublicationsBesidesUnused", AllPublicationsBesidesUnused);
	
	AddRight = AdditionalReportsAndDataProcessors.AddRight();
	CommonUseClientServer.SetFormItemProperty(Items, "Create",              "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "CreateMenu",          "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "CreateFolder",        "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "CreateMenuGroup",    "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "Copy",          "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "CopyMenu",      "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "LoadFromFile",     "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "LoadFromFileMenu", "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "ExportToFile",       "Visible", AddRight);
	CommonUseClientServer.SetFormItemProperty(Items, "ExportToFileMenu",   "Visible", AddRight);
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.GroupObjectsChange") Then
		Items.ChangeSelected.Visible = False;
		Items.ChangeSelectedMenu.Visible = False;
	EndIf;
	
	If Parameters.Property("CheckAdditionalReportsAndDataProcessors") Then
		Items.Create.Visible = False;
		Items.CreateFolder.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	PublicationFilter = Settings.Get("PublicationFilter");
	TypeFilter        = Settings.Get("TypeFilter");
	List.Parameters.SetParameterValue("PublicationFilter", PublicationFilter);
	List.Parameters.SetParameterValue("TypeFilter",        TypeFilter);
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure PublicationFilterOnChange(Item)
	DCParameterValue = List.Parameters.Items.Find("PublicationFilter");
	If DCParameterValue.Value <> PublicationFilter Then
		DCParameterValue.Value = PublicationFilter;
	EndIf;
EndProcedure

&AtClient
Procedure TypeFilterOnChange(Item)
	DCParameterValue = List.Parameters.Items.Find("TypeFilter");
	If DCParameterValue.Value <> TypeFilter Then
		DCParameterValue.Value = TypeFilter;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ExportToFile(Command)
	RowData = Items.List.CurrentData;
	If RowData = Undefined Or Not ItemSelected(RowData) Then
		Return;
	EndIf;
	
	ExportParameters = New Structure;
	ExportParameters.Insert("Ref",   RowData.Ref);
	ExportParameters.Insert("IsReport", RowData.IsReport);
	ExportParameters.Insert("FileName", RowData.FileName);
	AdditionalReportsAndDataProcessorsClient.ExportToFile(ExportParameters);
EndProcedure

&AtClient
Procedure ImportReportProcessingFile(Command)
	RowData = Items.List.CurrentData;
	If RowData = Undefined Or Not ItemSelected(RowData) Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", RowData.Ref);
	FormParameters.Insert("ShowDialogLoadFromFileOnOpen", True);
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.ObjectForm", FormParameters);
EndProcedure

&AtClient
Procedure ChangeSelected(Command)
	ModuleBatchObjectChangingClient = CommonUseClient.CommonModule("GroupObjectsChangeClient");
	ModuleBatchObjectChangingClient.ChangeSelected(Items.List);
EndProcedure

&AtClient
Procedure PublicationIsUsed(Command)
	ChengePublication("Used");
EndProcedure

&AtClient
Procedure PublicationDisabled(Command)
	ChengePublication("Disabled");
EndProcedure

&AtClient
Procedure PublicationDebugMode(Command)
	ChengePublication("DebugMode");
EndProcedure

&AtClient
Procedure ChangeDeletionMarkWithProfiles(Command)
	ListChangeMarkToDelete();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function ItemSelected(RowData)
	If TypeOf(RowData.Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		ShowMessageBox(, NStr("en='The command can not be run for the specified object."
"Select additional report or data processor.';ru='Команда не может быть выполнена для указанного объекта."
"Выберите дополнительный отчет или обработку.'"));
		Return False;
	EndIf;
	If RowData.IsFolder Then
		ShowMessageBox(, NStr("en='The command can not be run for the group."
"Select additional report or data processor.';ru='Команда не может быть выполнена для группы."
"Выберите дополнительный отчет или обработку.'"));
		Return False;
	EndIf;
	Return True;
EndFunction

&AtClient
Procedure ImportReportDataProcessorFileEnd(Result, AdditionalParameters) Export
	
	If Result = "FileImported" Then
		ShowValue(,Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure	

&AtServer
Procedure SetConditionalAppearance()
	Instruction = AdditionalReportsAndDataProcessors.ConditionalDesignInstruction();
	Instruction.Fields = "List";
	Instruction.Filters.Insert("List.Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode);
	Instruction.Appearance.Insert("TextColor", StyleColors.OverdueDataColor);
	AdditionalReportsAndDataProcessors.AddConditionalAppearanceItem(ThisObject, Instruction);
	
	Instruction = AdditionalReportsAndDataProcessors.ConditionalDesignInstruction();
	Instruction.Fields = "List";
	Instruction.Filters.Insert("List.Publication", Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled);
	Instruction.Appearance.Insert("TextColor", StyleColors.InaccessibleDataColor);
	AdditionalReportsAndDataProcessors.AddConditionalAppearanceItem(ThisObject, Instruction);
EndProcedure

&AtClient
Procedure ChengePublication(PublicationVariant)
	
	ClearMessages();
	Result = PublicationChange(PublicationVariant);
	
	If TypeOf(Result) = Type("Structure") Then
		StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	EndIf;
	
EndProcedure

&AtServer
Function PublicationChange(PublicationVariant)
	
	NewExecutionResult = StandardSubsystemsClientServer.NewExecutionResult();
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		MessageText = NStr("en='No additional reports (data processors) selected';ru='Не выбран ни один дополнительный отчет (обработка)'");
		OutputWarning = NewExecutionResult.OutputWarning;
		OutputWarning.Use = True;
		OutputWarning.Text = MessageText;
		Return NewExecutionResult;
	EndIf;
	
	For Each SelectedRow IN SelectedRows Do
		
		Try
			LockDataForEdit(SelectedRow);
		Except
			ErrorInfo = ErrorInfo();
			OutputWarning = NewExecutionResult.OutputWarning;
			OutputWarning.Use = True;
			OutputWarning.Text = BriefErrorDescription(ErrorInfo);
			
			Items.List.Refresh();
			Return NewExecutionResult;
		EndTry;
		
		BeginTransaction();
		
		Object = SelectedRow.GetObject();
		If PublicationVariant = "Used" Then
			Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
		ElsIf PublicationVariant = "DebugMode" Then
			Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
		Else
			Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
		EndIf;
		
		Object.AdditionalProperties.Insert("ListCheck");
		If Not Object.CheckFilling() Then
			RollbackTransaction();
			Items.List.Refresh();
			
			ErrorPresentation = "";
			MessagesArray = GetUserMessages(True);
			For Each UserMessage IN MessagesArray Do
				ErrorPresentation = ErrorPresentation + UserMessage.Text + Chars.LF;
			EndDo;
			
			UnlockDataForEdit(SelectedRow);
			
			OutputWarning = NewExecutionResult.OutputWarning;
			OutputWarning.Use = True;
			OutputWarning.Text = ErrorPresentation;
			Return NewExecutionResult;
		EndIf;
		
		Object.Write();
		
		CommitTransaction();
		UnlockDataForEdit(SelectedRow);
		
	EndDo;
	
	Items.List.Refresh();
	
	If SelectedRows.Count() = 1 Then
		ObjectName = CommonUse.ObjectAttributeValue(SelectedRows[0], "Description");
		MessageText = NStr("en='Additional report (data processor)  ""%1"" publication is changed';ru='Изменена публикация дополнительного отчета (обработки) ""%1""'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, ObjectName);
	Else
		MessageText = NStr("en='Additional reports (data processors) %1 publication is changed';ru='Изменена публикация у %1 дополнительных отчетов (обработок)'");
		MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, SelectedRows.Count());
	EndIf;
	
	OutputNotification = NewExecutionResult.OutputNotification;
	OutputNotification.Use = True;
	OutputNotification.Text = MessageText;
	OutputNotification.Title = NStr("en='Publication is changed';ru='Изменена публикация'");
	
	Return NewExecutionResult;
	
EndFunction

&AtClient
Procedure ListChangeMarkToDelete()
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure("Ref, DeletionMark");
	FillPropertyValues(Context, TableRow);
	
	If Context.DeletionMark Then
		QuestionText = NStr("en='Unmark ""%1"" for deletion?';ru='Снять с ""%1"" пометку на удаление?'");
	Else
		QuestionText = NStr("en='Mark ""%1"" for deletion?';ru='Пометить ""%1"" на удаление?'");
	EndIf;
	QuestionText = StringFunctionsClientServer.PlaceParametersIntoString(QuestionText, TableRow.Description);
	
	Handler = New NotifyDescription("ListChangeMarkToDeleteAfterConfirmation", ThisObject, Context);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure ListChangeMarkToDeleteAfterConfirmation(Response, Context) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Context.Insert("Queries", Undefined);
	Context.Insert("FormID", UUID);
	LockObjectsAndGenerateResolutionsPermissions(Context);
	
	Handler = New NotifyDescription("ListChangeMarkToDeleteAfterRequestsConfirmation", ThisObject, Context);
	WorkInSafeModeClient.ApplyQueriesOnExternalResourcesUse(Context.Queries, ThisObject, Handler);
EndProcedure

&AtServerNoContext
Procedure LockObjectsAndGenerateResolutionsPermissions(Context)
	LockDataForEdit(Context.Ref, , Context.FormID);
	
	Object = Context.Ref.GetObject();
	
	Context.Queries = AdditionalReportsAndDataProcessorsInSafeModeService.QueriesOnPermissionsForAdditionalDataProcessor(
		Object,
		Object.permissions.Unload(),
		,
		Not Context.DeletionMark);
EndProcedure

&AtClient
Procedure ListChangeMarkToDeleteAfterRequestsConfirmation(Response, Context) Export
	ChangeMark = (Response = DialogReturnCode.OK);
	UnlockAndChangeObjectsDeletionMark(Context, ChangeMark);
	Items.List.Refresh();
EndProcedure

&AtServerNoContext
Procedure UnlockAndChangeObjectsDeletionMark(Context, ChangeMark)
	If ChangeMark Then
		Object = Context.Ref.GetObject();
		Object.SetDeletionMark(NOT Context.DeletionMark);
		Object.Write();
	EndIf;
	UnlockDataForEdit(Context.Ref, Context.FormID);
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
