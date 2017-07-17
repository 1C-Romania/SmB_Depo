
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	WarnOnCloseForm = True;
	
	// Check that the form is opened applicationmatically.
	If Not Parameters.Property("ExchangeMessageFileName") Then
		
		NString = NStr("en='The form cannot be opened interactively.';ru='Форма не может быть открыта интерактивно.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
		
	EndIf;
	
	// Initialize the processing by passed parameters.
	FillPropertyValues(Object, Parameters,, "ListOfUsedFields, TableFieldList");
	
	MaximumQuantityOfCustomFields         = Parameters.MaximumQuantityOfCustomFields;
	UnapprovedRelationTableTempStorageAddress = Parameters.UnapprovedRelationTableTempStorageAddress;
	ListOfUsedFields  = Parameters.ListOfUsedFields;
	TableFieldList       = Parameters.TableFieldList;
	MappingFieldList = Parameters.MappingFieldList;
	
	// form title setting
	Title = Parameters.Title;
	
	ScriptAutoMappingObjects();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GoToNumber = 0;
	
	// Position to the assistant's second step.
	SetGoToNumber(2);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If  Object.TableOfAutomaticallyMappedObjects.Count() > 0
		AND WarnOnCloseForm = True Then
			
		ShowMessageBox(, NStr("en='The form contains automatic mapping data. The action is canceled.';ru='Форма содержит данные автоматического сопоставления. Действие отменено.'"));
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Apply(Command)
	
	WarnOnCloseForm = False;
	
	// Context server call
	NotifyChoice(IntoTableOfAutomaticallyMappedObjectsToTemporaryStorage());
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	WarnOnCloseForm = False;
	
	NotifyChoice(Undefined);
	
EndProcedure

&AtClient
Procedure UncheckMarks(Command)
	
	SetMarksAtServer(False);
	
EndProcedure

&AtClient
Procedure SetMarks(Command)
	
	SetMarksAtServer(True);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	
	WarnOnCloseForm = False;
	
	NotifyChoice(Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE  PROCEDURES AND FUNCTIONS (Supplied part).

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Execute the transition event handlers.
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Set the display of pages.
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage = Items[GoToRowCurrent.MainPageName];
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongOperation AND Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// handler OnOpen
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongOperationHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying is not defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// Handler LongOperationProcessing.
	If Not IsBlankString(GoToRowCurrent.LongOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									OnOpenHandlerName = "",
									LongOperation = False,
									LongOperationHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber = GoToNumber;
	NewRow.MainPageName = MainPageName;
	
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongOperation = LongOperation;
	NewRow.LongOperationHandlerName = LongOperationHandlerName;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function IntoTableOfAutomaticallyMappedObjectsToTemporaryStorage()
	
	Return PutToTempStorage(Object.TableOfAutomaticallyMappedObjects.Unload(New Structure("Check", True), "UniqueReceiverHandle, UniqueSourceHandle, SourceType, ReceiverType"));
	
EndFunction

&AtServer
Procedure SetVisibleOfTableFields(Val FormTableName, Val MaxCountOfCustomFields)
	
	SourceFieldName = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#ReceiverFieldNN","#FormTableName#", FormTableName);
	
	// Remove the visible of all fields of the mapping table.
	For FieldNumber = 1 To MaxCountOfCustomFields Do
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		Items[SourceField].Visible = False;
		Items[TargetField].Visible = False;
		
	EndDo;
	
	// Set the visible of the mapping table fields selected by a user.
	For Each Item IN Object.ListOfUsedFields Do
		
		FieldNumber = Object.ListOfUsedFields.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		// Set the visible of the fields.
		Items[SourceField].Visible = Item.Check;
		Items[TargetField].Visible = Item.Check;
		
		// Set the fields headers.
		Items[SourceField].Title = Item.Presentation;
		Items[TargetField].Title = Item.Presentation;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetMarksAtServer(Check)
	
	ValueTable = Object.TableOfAutomaticallyMappedObjects.Unload();
	
	ValueTable.FillValues(Check, "Check");
	
	Object.TableOfAutomaticallyMappedObjects.Load(ValueTable);
	
EndProcedure

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure SkipBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Wait handlers

&AtClient
Procedure BackgroundJobTimeoutHandler()
	
	LongOperationFinished = False;
	
	State = DataExchangeServerCall.JobState(JobID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	ElsIf State = "Completed" Then
		
		LongOperation = False;
		LongOperationFinished = True;
		
		GoToNext();
		
	Else // Failed
		
		LongOperation = False;
		
		SkipBack();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Go to event handlers.

// Page 0: Error of the automatic mapping.
//
&AtClient
Function Attachable_ObjectsMappingError_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.Close1.DefaultButton = True;
	
EndFunction

// Page 1 (waiting): Mapping the objects.
//
&AtClient
Function Attachable_WaitObjectsMapping_LongOperationProcessing(Cancel, GoToNext)
	
	PerformMappingOfObjects(Cancel);
	
EndFunction

// Page 1 (waiting): Mapping the objects.
//
&AtClient
Function Attachable_WaitObjectsMappingLongOperation_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperation Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobTimeoutHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 1 (waiting): Mapping the objects.
//
&AtClient
Function Attachable_WaitObjectsMappingLongOperationEnd_LongOperationProcessing(Cancel, GoToNext)
	
	If LongOperationFinished Then
		
		ExecuteMappingObjectsEnd(Cancel);
		
	EndIf;
	
EndFunction

// Page 1: Mapping objects.
//
&AtServer
Procedure PerformMappingOfObjects(Cancel)
	
	LongOperation = False;
	LongOperationFinished = False;
	JobID = Undefined;
	TemporaryStorageAddress = "";
	
	Try
		
		FormAttributes = New Structure;
		FormAttributes.Insert("ListOfUsedFields",  ListOfUsedFields);
		FormAttributes.Insert("TableFieldList",       TableFieldList);
		FormAttributes.Insert("MappingFieldList", MappingFieldList);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("ObjectContext", DataExchangeServer.GetObjectContext(FormAttributeToValue("Object")));
		MethodParameters.Insert("FormAttributes", FormAttributes);
		MethodParameters.Insert("TableOfUnapprovedLinks", GetFromTempStorage(UnapprovedRelationTableTempStorageAddress));
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.InfobaseObjectsMapping.RunAutomaticObjectMapping",
			MethodParameters,
			NStr("en='Automatic object mapping';ru='Автоматическое сопоставление объектов'")
		);
		
		If Result.JobCompleted Then
			AfterObjectsMapping(GetFromTempStorage(Result.StorageAddress));
		Else
			LongOperation = True;
			JobID = Result.JobID;
			TemporaryStorageAddress = Result.StorageAddress;
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(NStr("en='Object mapping wizard.Automatic mapping';ru='Помощник сопоставления объектов.Автоматическое сопоставление'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Mapping objects.
//
&AtServer
Procedure ExecuteMappingObjectsEnd(Cancel)
	
	Try
		AfterObjectsMapping(GetFromTempStorage(TemporaryStorageAddress));
	Except
		Cancel = True;
		WriteLogEvent(NStr("en='Object mapping wizard.Automatic mapping';ru='Помощник сопоставления объектов.Автоматическое сопоставление'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Mapping objects.
//
&AtServer
Procedure AfterObjectsMapping(Val ResultComparison)
	
	DataProcessorObject = DataProcessors.InfobaseObjectsMapping.Create();
	DataExchangeServer.ImportObjectContext(ResultComparison.ObjectContext, DataProcessorObject);
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	EmptyResult = ResultComparison.EmptyResult;
	
	If Not EmptyResult Then
		
		Modified = True;
		
		// Set the headers and visible of the table fields on a form.
		SetVisibleOfTableFields("TableOfAutomaticallyMappedObjects", MaximumQuantityOfCustomFields);
		
	EndIf;
	
EndProcedure

// Page 2: Work with the result of the automatic mapping.
//
&AtClient
Function Attachable_MappingObjects_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.Apply.DefaultButton = True;
	
	If EmptyResult Then
		SkipPage = True;
	EndIf;
	
EndFunction

// Page 3: Empty result of the automatic mapping.
//
&AtClient
Function Attachable_EmptyResultMappingObjectsEmptyResultMappingObjects_OnOpen(Cancel, SkipPage, IsGoNext)
	
	Items.Close.DefaultButton = True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Initialization of the assistant's transitions.

&AtServer
Procedure ScriptAutoMappingObjects()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ObjectsMappingError", "ErrorMappingObjects_OnOpen");
	
	// Waiting for objects mapping.
	GoToTableNewRow(2, "WaitObjectsMapping",, True, "MappingObjects_LongWaitActionProcessing");
	GoToTableNewRow(3, "WaitObjectsMapping",, True, "MappingObjectsWaitLongOperationLongOperation_ProcessingOfLongOperation");
	GoToTableNewRow(4, "WaitObjectsMapping",, True, "MappingObjectsWaitLongOperationEnd_ProcessingLongOperation");
	
	// Work with the result of automatic mapping.
	GoToTableNewRow(5, "MappingObjects", "MappingObjects_OnOpen");
	GoToTableNewRow(6, "EmptyResultMappingObjects", "EmptyResultMappingObjectsEmptyResultMappingObjects_OnOpen");
	
EndProcedure

#EndRegion
