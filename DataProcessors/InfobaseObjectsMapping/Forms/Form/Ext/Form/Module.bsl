
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	// Check that the form is opened applicationmatically.
	If Not Parameters.Property("ExchangeMessageFileName") Then
		Raise NStr("en='Data processor is not aimed for being used directly';ru='Обработка не предназначена для непосредственного использования.'");
	EndIf;
	
	PerformDataMapping = True;
	PerformDataImport      = True;
	
	If Parameters.Property("PerformDataMapping") Then
		PerformDataMapping = Parameters.PerformDataMapping;
	EndIf;
	
	If Parameters.Property("PerformDataImport") Then
		PerformDataImport = Parameters.PerformDataImport;
	EndIf;
	
	// Initialize the processing by passed parameters.
	FillPropertyValues(Object, Parameters);
	
	// Call constructor of the current data processor instance.
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.Assistant();
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	// Filters list by status:
	//
	//     MappingState - Number:
	//          0 - matched via
	//         IR (not strictly) -1 - receiver
	//         unmatched object +1 - receiver
	//          unmatched object 3 - matched but unapproved connection.
	//
	//     MappingStateAdditional - Number:
	//         1 - unmatched
	//         objects 0 - matched objects.
	
	VariantsOfFilterStatusMap = New Structure;
	
	// Fill in filters list
	ChoiceList = Items.FilterByMappingState.ChoiceList;;
	
	VariantsOfFilterStatusMap.Insert(ChoiceList.Add(
		"AllObjects", NStr("en='All data';ru='Все данные'")
	).Value, New FixedStructure);
	
	VariantsOfFilterStatusMap.Insert(ChoiceList.Add(
		"MappedObjectsUnapproved", NStr("en='Changes';ru='Изменения'"),
	).Value, New FixedStructure("MappingState",  3));
	
	VariantsOfFilterStatusMap.Insert(ChoiceList.Add(
		"MappedObjects", NStr("en='Compared data';ru='Сопоставленные данные'"),,
	).Value, New FixedStructure("MappingStateAdditional", 0));
	
	VariantsOfFilterStatusMap.Insert(ChoiceList.Add(
		"UnmappedObjects", NStr("en='Uncompared data';ru='Несопоставленные данные'"),
	).Value, New FixedStructure("MappingStateAdditional", 1));
	
	VariantsOfFilterStatusMap.Insert(ChoiceList.Add(
		"UnmappedObjectsSink", NStr("en='Unmatched data of this data base';ru='Несопоставленные данные этой базы'"),
	).Value, New FixedStructure("MappingState",  1));
	
	VariantsOfFilterStatusMap.Insert(ChoiceList.Add(
		"UnmappedSourceObjects", NStr("en='Second base unmatched data';ru='Несопоставленные данные второй базы'"),
	).Value, New FixedStructure("MappingState", -1));
	
	// Defaults
	FilterByMappingState = "UnmappedObjects";
		
	// Form title setting
	Synonym = Undefined;
	Parameters.Property("Synonym", Synonym);
	If IsBlankString(Synonym) Then
		DataPresentation = String(Metadata.FindByType(Type(Object.ReceiverTypeAsString)));
	Else
		DataPresentation = Synonym;
	EndIf;
	Title = NStr("en='Data match ""[DataPresentation]""';ru='Сопоставление данных ""[ПредставлениеДанных]""'");
	Title = StrReplace(Title, "[DataPresentation]", DataPresentation);
	
	// Set management items visible depending on the set options.
	Items.LinksGroup.Visible                                    = PerformDataMapping;
	Items.RunAutomaticMapping.Visible           = PerformDataMapping;
	Items.MappingDigestInfo.Visible               = PerformDataMapping;
	Items.MappingTableContextMenuLinksGroup.Visible = PerformDataMapping;
	
	Items.ExecuteDataImport.Visible = PerformDataImport;
	
	ThisApplicationName = DataExchangeReUse.ThisNodeDescription(Object.InfobaseNode);
	ThisApplicationName = ?(IsBlankString(ThisApplicationName), NStr("en='This application';ru='Эта программа'"), ThisApplicationName);
	
	SecondApplicationName = CommonUse.ObjectAttributeValue(Object.InfobaseNode, "Description");
	SecondApplicationName = ?(IsBlankString(SecondApplicationName), NStr("en='Second application';ru='Вторая программа'"), SecondApplicationName);
	
	Items.DataForThisApplication.Title = ThisApplicationName;
	Items.SecondApplicationData.Title = SecondApplicationName;
	
	Items.Explanation.Title = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='To match data"
"""%1"" to data ""%2"", use the ""Match automatically"" command...""."
"Remaining unmatched data can be linked with each other manually.';ru='Для сопоставления данных ""%1"""
"с данными ""%2"" воспользуйтесь командой ""Сопоставить автоматически...""."
"Оставшиеся несопоставленные данные можно связать друг с другом вручную.'"),
		ThisApplicationName, SecondApplicationName);
	
	ScriptExecutionMappingObjects();
	
	ApplyTableOfUnapprovedRecords = False;
	ApplyResultOfAutomaticMapping = False;
	AddressTableAutomaticallyMappedObjects = "";
	WriteAndClose = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	WarnOnCloseForm = True;
	
	// Sets the check box showing that the form is modified.
	AttachIdleHandler("SetFormModified", 2);
	
	UpdateMappingsTable();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If WriteAndClose Then
		Return;
	EndIf;
	
	If Object.TableOfUnapprovedLinks.Count() = 0 Then
		// Everything is matched
		Return;
	EndIf;
		
	If WarnOnCloseForm = True Then
		Notification = New NotifyDescription("BeforeCloseEnd", ThisObject);
		OldCheckBox = Modified;
		Modified = True;
		
		CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
		
		Modified = OldCheckBox;
		Return;
	EndIf;
	
	BeforeClosingContinue();
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Val QuestionResult = Undefined, Val AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		// Close the form saving the data.
		BeforeClosingContinue();
		Close();
		
	ElsIf QuestionResult = DialogReturnCode.No Then
		// Close without continuing
		WarnOnCloseForm = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClosingContinue()
	WriteAndClose = True;
	WarnOnCloseForm = True;
	UpdateMappingsTable();
EndProcedure

&AtClient
Procedure OnClose()
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("UniqueKey",       Parameters.Key);
	NotificationParameters.Insert("DataSuccessfullyImported", Object.DataSuccessfullyImported);
	
	Notify("ClosingObjectMappingForm", NotificationParameters);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectsMapping.Form.AutomaticMappingSetup") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		// Automatically match objects.
		FormParameters = New Structure;
		FormParameters.Insert("ReceiverTableName",                         Object.ReceiverTableName);
		FormParameters.Insert("ExchangeMessageFileName",                     Object.ExchangeMessageFileName);
		FormParameters.Insert("TableSourceObjectTypeName",              Object.TableSourceObjectTypeName);
		FormParameters.Insert("SourceTypeAsString",                         Object.SourceTypeAsString);
		FormParameters.Insert("ReceiverTypeAsString",                         Object.ReceiverTypeAsString);
		FormParameters.Insert("ReceiverTableFields",                        Object.ReceiverTableFields);
		FormParameters.Insert("SearchFieldsOfReceiverTable",                  Object.SearchFieldsOfReceiverTable);
		FormParameters.Insert("InfobaseNode",                      Object.InfobaseNode);
		FormParameters.Insert("TableFieldList",                          Object.TableFieldList.Copy());
		FormParameters.Insert("ListOfUsedFields",                     Object.ListOfUsedFields.Copy());
		FormParameters.Insert("MappingFieldList",                    ValueSelected.Copy());
		FormParameters.Insert("MaximumQuantityOfCustomFields", MaximumQuantityOfCustomFields());
		FormParameters.Insert("Title",                                   Title);
		
		FormParameters.Insert("UnapprovedRelationTableTempStorageAddress", PlaceTableOfUnapprovedLinksToTemporaryStorage());
		
		// Open the form of the automatic objects match.
		OpenForm("DataProcessor.InfobaseObjectsMapping.Form.ResultOfAutomaticMapping", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectsMapping.Form.ResultOfAutomaticMapping") Then
		
		If TypeOf(ValueSelected) = Type("String")
			AND Not IsBlankString(ValueSelected) Then
			
			ApplyResultOfAutomaticMapping = True;
			AddressTableAutomaticallyMappedObjects = ValueSelected;
			
			UpdateMappingsTable();
			
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectsMapping.Form.SettingOfTableFields") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.ListOfUsedFields = ValueSelected.Copy();
		SetVisibleOfTableFields("MappingTable"); // Visible and titles of the match table fields.
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectsMapping.Form.SettingOfMappingTableFields") Then
		
		If TypeOf(ValueSelected) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.TableFieldList = ValueSelected.Copy();
		
		FillListByMarkedItems(Object.TableFieldList, Object.ListOfUsedFields);
		
		// Generate Sorting table.
		FillSortingTable(Object.ListOfUsedFields);
		
		// Update the matching table considering new table fields.
		UpdateMappingsTable();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectsMapping.Form.SortingSetup") Then
		
		If TypeOf(ValueSelected) <> Type("FormDataCollection") Then
			Return;
		EndIf;
		
		Object.SortTable.Clear();
		
		// Fill in the form collection with the received settings.
		For Each TableRow IN ValueSelected Do
			FillPropertyValues(Object.SortTable.Add(), TableRow);
		EndDo;
		
		// Sort the matching table.
		RunSortingOfTable();
		
		// update filter in the tables
		SetTabularSectionsFilter();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectsMapping.Form.ChoiceFormLinksMapping") Then
		
		If ValueSelected = Undefined Then
			Return; // Cancel selecting a connection for matching.
		EndIf;
		
		BeginningRowID = Items.MappingTable.CurrentRow;
		
		// server call
		FoundStrings = MappingTable.FindRows(New Structure("SerialNumber", ValueSelected));
		If FoundStrings.Count() > 0 Then
			EndingRowID = FoundStrings[0].GetID();
			// Process the received match.
			AddUnapprovedMappingAtClient(BeginningRowID, EndingRowID);
		EndIf;
		
		// Refocus input on the match table.
		CurrentItem = Items.MappingTable;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure FilterByMappingStatusOnChange(Item)
	
	SetTabularSectionsFilter();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersMatchTable

&AtClient
Procedure MappingTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	SetConnectionInteractively();
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure MappingTableBeforeChangeStart(Item, Cancel)
	Cancel = True;
	SetConnectionInteractively();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateMappingsTable();
	
EndProcedure

&AtClient
Procedure RunAutomaticMapping(Command)
	
	Cancel = False;
	
	// Check for the user fields quantity for display.
	RunUserFieldsTaskCheck(Cancel, Object.ListOfUsedFields.UnloadValues());
	
	If Cancel Then
		Return;
	EndIf;
	
	// Receive match fields list from a user.
	FormParameters = New Structure;
	FormParameters.Insert("MappingFieldList", Object.TableFieldList.Copy());
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form.AutomaticMappingSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ExecuteDataImport(Command)
	NString = NStr("en='Do you want to receive data to the infobase?';ru='Получить данные в информационную базу?'");
	Notification = New NotifyDescription("ImportDataAfterQuestionOnDataReceiptConfirmation", ThisObject);
	
	ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure ChangeTableFields(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldList", Object.ListOfUsedFields.Copy());
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form.SettingOfTableFields", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure TableFieldsListSettings(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldList", Object.TableFieldList.Copy());
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form.SettingOfMappingTableFields", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure Sort(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("SortTable", Object.SortTable);
	
	OpenForm("DataProcessor.InfobaseObjectsMapping.Form.SortingSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddMapping(Command)
	
	SetConnectionInteractively();
	
EndProcedure

&AtClient
Procedure CancelMapping(Command)
	
	SelectedRows = Items.MappingTable.SelectedRows;
	
	CancelMappingAtServer(SelectedRows);
	
	// Update filter in the tabular sections.
	SetTabularSectionsFilter();
	
EndProcedure

&AtClient
Procedure WriteRefresh(Command)
	
	ApplyTableOfUnapprovedRecords = True;
	
	UpdateMappingsTable();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	ApplyTableOfUnapprovedRecords = True;
	WriteAndClose = True;
	
	UpdateMappingsTable();
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
		Raise NStr("en='Page for displaying has not been defined.';ru='Не определена страница для отображения.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage = Items[GoToRowCurrent.MainPageName];
	
	If IsGoNext AND GoToRowCurrent.LongOperation Then
		
		AttachIdleHandler("ExecuteLongOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
		// Go to event handlers.
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() = 0 Then
			Return;
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en='Page for displaying has not been defined.';ru='Не определена страница для отображения.'");
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
		Raise NStr("en='Page for displaying has not been defined.';ru='Не определена страница для отображения.'");
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
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTableTargetField1.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("MatchTable.MatchStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = -1;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnavailableCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en='There is no match, object will be copied';ru='Нет соответствия, объект будет скопирован'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTableSourceField1.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("MatchTable.MatchStatus");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 1;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.UnavailableCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en='There is no match, object will be copied';ru='Нет соответствия, объект будет скопирован'"));

EndProcedure

&AtClient
Procedure ImportDataAfterQuestionOnDataReceiptConfirmation(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Object.DataSuccessfullyImported Then
		NString = NStr("en='Data is already received. Do you want to receive the data again?';ru='Данные уже были получены. Выполнить получение данных повторно?'");
		Notification = New NotifyDescription("ImportDataAfterQuestionAboutDataReceivedAgain", ThisObject);
		
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	ImportDataAfterDataReceivedConfirmation();
EndProcedure

&AtClient
Procedure ImportDataAfterQuestionAboutDataReceivedAgain(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ImportDataAfterDataReceivedConfirmation();
EndProcedure

&AtClient
Procedure ImportDataAfterDataReceivedConfirmation()
	
	// Notification of state
	Status(NStr("en='Receiving data. Please wait...';ru='Выполняется получение данных. Пожалуйста, подождите..'"));
	
	// Import data on server.
	Cancel = False;
	ExecuteDataImportAtServer(Cancel);
	
	If Cancel Then
		NString = NStr("en='Errors occurred while receiving data."
"Do you want to open the event log?';ru='При получении данных возникли ошибки."
"Перейти в журнал регистрации?'");
		
		Notification = New NotifyDescription("ImportDataAfterQuestionAboutTransferToEventsLogMonitor", ThisObject);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		
		Return;
	EndIf;
	
	// Update data in the match table.
	UpdateMappingsTable();
EndProcedure

&AtClient
Procedure ImportDataAfterQuestionAboutTransferToEventsLogMonitor(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToEventLogMonitorOfDataEventsModalRegistartion(Object.InfobaseNode, ThisObject, "DataImport");
EndProcedure

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure SkipBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServer
Procedure CancelMappingAtServer(SelectedRows)
	
	For Each RowID IN SelectedRows Do
		
		CurrentData = MappingTable.FindByID(RowID);
		
		If CurrentData.MappingState = 0 Then // Matched via IR (not strictly).
			
			CancelDataMapping(CurrentData, False);
			
		ElsIf CurrentData.MappingState = 3 Then // Unapproved match.
			
			CancelDataMapping(CurrentData, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CancelDataMapping(CurrentData, IsUnapprovedRelation)
	
	Filter = New Structure;
	Filter.Insert("UniqueSourceHandle", CurrentData.UniqueReceiverHandle);
	Filter.Insert("UniqueReceiverHandle", CurrentData.UniqueSourceHandle);
	Filter.Insert("SourceType",                     CurrentData.ReceiverType);
	Filter.Insert("ReceiverType",                     CurrentData.SourceType);
	
	If IsUnapprovedRelation Then
		For Each FoundStrings IN Object.TableOfUnapprovedLinks.FindRows(Filter) Do
			// Delete unapproved connection in the unapproved connections table.
			Object.TableOfUnapprovedLinks.Delete(FoundStrings);
		EndDo;
		
	Else
		CancelApprovedMappingAtServer(Filter);
		
	EndIf;
	
	// Add two rows to the match table: row of source and receiver.
	NewSourceRow = MappingTable.Add();
	NewTargetRow = MappingTable.Add();
	
	FillPropertyValues(NewSourceRow, CurrentData, "SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, UniqueSourceHandle, SourceType, SourcePictureIndex");
	FillPropertyValues(NewTargetRow, CurrentData, "ReceiverField1, ReceiverField2, ReceiverField3, ReceiverField4, ReceiverField5, UniqueReceiverHandle, ReceiverType, ReceiverPictureIndex");
	
	// Set field values for the source string sorting.
	NewSourceRow.OrderField1 = CurrentData.SourceField1;
	NewSourceRow.OrderField2 = CurrentData.SourceField2;
	NewSourceRow.OrderField3 = CurrentData.SourceField3;
	NewSourceRow.OrderField4 = CurrentData.SourceField4;
	NewSourceRow.OrderField5 = CurrentData.SourceField5;
	NewSourceRow.PictureIndex  = CurrentData.SourcePictureIndex;
	
	// Set field values for the receiver string sorting.
	NewTargetRow.OrderField1 = CurrentData.ReceiverField1;
	NewTargetRow.OrderField2 = CurrentData.ReceiverField2;
	NewTargetRow.OrderField3 = CurrentData.ReceiverField3;
	NewTargetRow.OrderField4 = CurrentData.ReceiverField4;
	NewTargetRow.OrderField5 = CurrentData.ReceiverField5;
	NewTargetRow.PictureIndex  = CurrentData.ReceiverPictureIndex;
	
	NewSourceRow.MappingState = -1;
	NewSourceRow.MappingStateAdditional = 1; // unmatched objects
	
	NewTargetRow.MappingState = 1;
	NewTargetRow.MappingStateAdditional = 1; // unmatched objects
	
	// Delete the current match table row.
	MappingTable.Delete(CurrentData);
	
	// And update numbers
	NewSourceRow.SerialNumber = NextSerialNumberMatching();
	NewTargetRow.SerialNumber = NextSerialNumberMatching();
EndProcedure

&AtServer
Procedure CancelApprovedMappingAtServer(Filter)
	
	Filter.Insert("InfobaseNode", Object.InfobaseNode);
	
	InformationRegisters.InfobasesObjectsCompliance.DeleteRecord(Filter);
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Apply unapproved connection table to database.
	DataProcessorObject.ApplyTableOfUnapprovedRecords(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	TableToImport = New Array;
	
	DataTableKey = DataExchangeServer.DataTableKey(Object.SourceTypeAsString, Object.ReceiverTypeAsString, Object.ThisIsObjectDeletion);
	
	TableToImport.Add(DataTableKey);
	
	// Import data from the pack file in the data exchange mode.
	DataProcessorObject.ExecuteDataImportToInformationBase(Cancel, TableToImport);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	PictureIndex = DataExchangeServer.InformationStatisticsTablePictureIndex(UnmappedObjectsCount, Object.DataSuccessfullyImported);
	
EndProcedure

&AtServer
Function PlaceTableOfUnapprovedLinksToTemporaryStorage()
	
	Return PutToTempStorage(Object.TableOfUnapprovedLinks.Unload(), UUID);
	
EndFunction

&AtServer
Function GetTemporaryStorageAddressOfLinkChoiceTable(FilterParameters)
	
	Columns = "SerialNumber, OrderField1, OrderField2, OrderField3, OrderField4, OrderField5, PictureIndex";
	
	Return PutToTempStorage(MappingTable.Unload(FilterParameters, Columns));
	
EndFunction

&AtClient
Procedure SetFormModified()
	
	Modified = (Object.TableOfUnapprovedLinks.Count() > 0);
	
EndProcedure

&AtClient
Procedure UpdateMappingsTable()
	
	Items.TableButtons.Enabled = False;
	Items.TableHeaderGroup.Enabled = False;
	
	GoToNumber = 0;
	
	// Position to the assistant's second step.
	SetGoToNumber(2);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Applied

&AtClient
Procedure FillSortingTable(SourceValueList)
	
	Object.SortTable.Clear();
	
	For Each Item IN SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = Object.SortTable.Add();
		
		TableRow.FieldName               = Item.Value;
		TableRow.Use         = IsFirstField; // Sort by default by the first field.
		TableRow.SortDirection = True; // IN ascending order
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillListByMarkedItems(SourceList, TargetList)
	
	TargetList.Clear();
	
	For Each Item IN SourceList Do
		
		If Item.Check Then
			
			TargetList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetTabularSectionsFilter()
	
	Items.MappingTable.RowFilter = VariantsOfFilterStatusMap[FilterByMappingState];
	
EndProcedure

&AtClient
Procedure RunUserFieldsTaskCheck(Cancel, UserFields)
	
	If UserFields.Count() = 0 Then
		
		// The value should be zero.
		NString = NStr("en='You should set at least one field to display';ru='Следует указать хотя бы одно поле для отображения'");
		
		CommonUseClientServer.MessageToUser(NString,,"Object.TableFieldsList",, Cancel);
		
	ElsIf UserFields.Count() > MaximumQuantityOfCustomFields() Then
		
		// Value can not be greater than the set one.
		MessageString = NStr("en='Reduce the fields number (you can select no more than %1 fields)';ru='Уменьшите количество полей (можно выбирать не более %1 полей)'");
		MessageString = StringFunctionsClientServer.PlaceParametersIntoString(MessageString, String(MaximumQuantityOfCustomFields()));
		
		CommonUseClientServer.MessageToUser(MessageString,,"Object.TableFieldsList",, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisibleOfTableFields(FormTableName)
	
	SourceFieldName = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#ReceiverFieldNN","#FormTableName#", FormTableName);
	
	// Remove the visible of all fields of the mapping table.
	For FieldNumber = 1 To MaximumQuantityOfCustomFields() Do
		
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

&AtClient
Procedure SetConnectionInteractively()
	CurrentData = Items.MappingTable.CurrentData;
	
	If CurrentData=Undefined Then
		Return;
	EndIf;
	
	// You can select connection only for the unmatched objects of source or receiver.
	If Not (
		    CurrentData.MappingState=-1	// Unmatched source object.
		Or CurrentData.MappingState=+1	// Unmatched receiver object.
	) Then
		
		ShowMessageBox(, NStr("en='Objects already mapped';ru='Объекты уже сопоставлены'"), 2);
		
		// Refocus input on the match table.
		CurrentItem = Items.MappingTable;
		Return;
	EndIf;
	
	CannotSetLinkQuickly = False;
	
	SelectedRows = Items.MappingTable.SelectedRows;
	If SelectedRows.Count()<>2 Then
		CannotSetLinkQuickly = True;
		
	Else
		ID1 = SelectedRows[0];
		ID2 = SelectedRows[1];
		
		Row1 = MappingTable.FindByID(ID1);
		Row2 = MappingTable.FindByID(ID2);
		
		If Not (
			(
				  Row1.MappingState = -1 // Unmatched source object.
				AND Row2.MappingState = +1 // Unmatched receiver object.
			) Or (
				  Row1.MappingState = +1 // Unmatched receiver object.
				AND Row2.MappingState = -1 // Unmatched source object.
			) )
		Then
			CannotSetLinkQuickly = True;
		EndIf;
	EndIf;
	
	If CannotSetLinkQuickly Then
		// Full connection setting.
		BeginningRowID = Items.MappingTable.CurrentRow;
		
		FilterParameters = New Structure("MappingState", ?(CurrentData.MappingState = -1, 1, -1));
		
		FormParameters = New Structure;
		FormParameters.Insert("TemporaryStorageAddress",   GetTemporaryStorageAddressOfLinkChoiceTable(FilterParameters));
		FormParameters.Insert("StartRowSerialNumber", CurrentData.SerialNumber);
		FormParameters.Insert("ListOfUsedFields",    Object.ListOfUsedFields.Copy());
		FormParameters.Insert("MaximumQuantityOfCustomFields", MaximumQuantityOfCustomFields());
		FormParameters.Insert("ObjectToMap", GetObjectToMap(CurrentData));
		FormParameters.Insert("Application1", ?(CurrentData.MappingState = -1, SecondApplicationName, ThisApplicationName));
		FormParameters.Insert("Application2", ?(CurrentData.MappingState = -1, ThisApplicationName, SecondApplicationName));
		
		OpenForm("DataProcessor.InfobaseObjectsMapping.Form.ChoiceFormLinksMapping", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
		
		Return;
	EndIf;
	
	// Offer to set quickly.
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,     NStr("en='Set';ru='Установить'"));
	Buttons.Add(DialogReturnCode.Cancel, NStr("en='Cancel';ru='Отменить'"));
	
	Notification = New NotifyDescription("SetConnectionOnlineEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ID1", ID1);
	Notification.AdditionalParameters.Insert("ID2", ID2);
	
	QuestionText = NStr("en='Do you want to match the selected objects?';ru='Установить соответствие между выбранными объектами?'");
	ShowQueryBox(Notification, QuestionText, Buttons,, DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure SetConnectionOnlineEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AddUnapprovedMappingAtClient(AdditionalParameters.ID1, AdditionalParameters.ID2);
	CurrentItem = Items.MappingTable;
EndProcedure

&AtClient
Function GetObjectToMap(Data)
	
	Result = New Array;
	
	FieldNamePattern = ?(Data.MappingState = -1, "SourceFieldNN", "ReceiverFieldNN");
	
	For FieldNumber = 1 To MaximumQuantityOfCustomFields() Do
		
		Field = StrReplace(FieldNamePattern, "NN", String(FieldNumber));
		
		If Items["MappingTable" + Field].Visible
			AND ValueIsFilled(Data[Field]) Then
			
			Result.Add(Data[Field]);
			
		EndIf;
		
	EndDo;
	
	If Result.Count() = 0 Then
		
		Result.Add(NStr("en='<not specified>';ru='<не задан>'"));
		
	EndIf;
	
	Return StringFunctionsClientServer.RowFromArraySubrows(Result, ", ");
EndFunction

&AtClient
Procedure AddUnapprovedMappingAtClient(Val BeginningRowID, Val EndingRowID)
	
	// Receive two matched table rows by the specified IDs.
	// Add a row to the unapproved connections table.
	// Add a row to the match table.
	// Delete two matched rows from the match table.
	
	BeginningRow    = MappingTable.FindByID(BeginningRowID);
	EndingRow = MappingTable.FindByID(EndingRowID);
	
	If BeginningRow = Undefined Or EndingRow = Undefined Then
		Return;
	EndIf;
	
	If BeginningRow.MappingState=-1 AND EndingRow.MappingState=+1 Then
		SourceRow = BeginningRow;
		TargetRow = EndingRow;
	ElsIf BeginningRow.MappingState=+1 AND EndingRow.MappingState=-1 Then
		SourceRow = EndingRow;
		TargetRow = BeginningRow;
	Else
		Return;
	EndIf;
	
	// Add a row to the unapproved connections table.
	NewRow = Object.TableOfUnapprovedLinks.Add();
	
	NewRow.UniqueSourceHandle = TargetRow.UniqueReceiverHandle;
	NewRow.SourceType                     = TargetRow.ReceiverType;
	NewRow.UniqueReceiverHandle = SourceRow.UniqueSourceHandle;
	NewRow.ReceiverType                     = SourceRow.SourceType;
	
	// Add a row as an unapproved one to the match table.
	NewRowUnapproved = MappingTable.Add();
	
	// Take sorting fields from the receiver string.
	FillPropertyValues(NewRowUnapproved, SourceRow, "SourcePictureIndex, SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, UniqueSourceHandle, SourceType");
	FillPropertyValues(NewRowUnapproved, TargetRow, "ReceiverPictureIndex, ReceiverField1, ReceiverField2, ReceiverField3, ReceiverField4, ReceiverField5, UniqueReceiverHandle, ReceiverType, OrderField1, OrderField2, OrderField3, OrderField4, OrderField5, PictureIndex");
	
	NewRowUnapproved.MappingState               = 3; // unapproved connection
	NewRowUnapproved.MappingStateAdditional = 0;
	
	// Delete matched strings.
	MappingTable.Delete(BeginningRow);
	MappingTable.Delete(EndingRow);
	
	// And update numbers
	NewRowUnapproved.SerialNumber = NextSerialNumberMatching();
	
	// Set filter and update data in the match table.
	SetTabularSectionsFilter();
EndProcedure

&AtServer
Function NextSerialNumberMatching()
	Result = 0;
	
	For Each String IN MappingTable Do
		Result = Max(Result, String.SerialNumber);
	EndDo;
	
	Return Result + 1;
EndFunction
	
&AtClient
Procedure RunSortingOfTable()
	
	SortingFields = GetSortFields();
	If Not IsBlankString(SortingFields) Then
		MappingTable.Sort(SortingFields);
	EndIf;
	
EndProcedure

&AtClient
Function GetSortFields()
	
	// Return value of the function.
	SortingFields = "";
	
	FieldPattern = "FieldSortingNN #SortingDirection"; // Not localized
	
	For Each TableRow IN Object.SortTable Do
		
		If TableRow.Use Then
			
			Delimiter = ?(IsBlankString(SortingFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ItemOfList = Object.ListOfUsedFields.FindByValue(TableRow.FieldName);
			
			FieldIndex = Object.ListOfUsedFields.IndexOf(ItemOfList) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortingDirection", SortDirectionStr);
			
			SortingFields = SortingFields + Delimiter + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortingFields;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Properties

&AtClient
Function MaximumQuantityOfCustomFields()
	
	Return DataExchangeClient.MaximumQuantityOfFieldsOfObjectMapping();
	
EndFunction

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

// Page 0: An error occurred while matching objects.
//
&AtClient
Function Attachable_ObjectsMappingError_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ApplyTableOfUnapprovedRecords = False;
	ApplyResultOfAutomaticMapping = False;
	AddressTableAutomaticallyMappedObjects = "";
	WriteAndClose = False;
	
	Items.TableButtons.Enabled = True;
	Items.TableHeaderGroup.Enabled = True;
	
EndFunction

// Page 1 (waiting): Mapping the objects.
//
&AtClient
Function Attachable_WaitObjectsMapping_LongOperationProcessing(Cancel, GoToNext)
	
	// Check for the user fields quantity for display.
	RunUserFieldsTaskCheck(Cancel, Object.ListOfUsedFields.UnloadValues());
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
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
	
	If WriteAndClose Then
		GoToNext = False;
		Close();
		Return Undefined;
	EndIf;
	
	If LongOperationFinished Then
		
		ExecuteMappingObjectsEnd(Cancel);
		
	EndIf;
	
	Items.TableButtons.Enabled = True;
	Items.TableHeaderGroup.Enabled = True;
	
	// Set the current filter to the match tabular section.
	SetTabularSectionsFilter();
	
	// Set visible and titles of the match table fields.
	SetVisibleOfTableFields("MappingTable");

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
		FormAttributes.Insert("OnlyApplyTableUnapprovedRecords", WriteAndClose);
		FormAttributes.Insert("ApplyTableOfUnapprovedRecords", ApplyTableOfUnapprovedRecords);
		FormAttributes.Insert("ApplyResultOfAutomaticMapping", ApplyResultOfAutomaticMapping);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("ObjectContext", DataExchangeServer.GetObjectContext(FormAttributeToValue("Object")));
		MethodParameters.Insert("FormAttributes", FormAttributes);
		
		If ApplyResultOfAutomaticMapping Then
			MethodParameters.Insert("TableOfAutomaticallyMappedObjects", GetFromTempStorage(AddressTableAutomaticallyMappedObjects));
		EndIf;
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.InfobaseObjectsMapping.PerformMappingOfObjects",
			MethodParameters,
			NStr("en='Mapping objects';ru='Сопоставление объектов'")
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
		WriteLogEvent(NStr("en='Assistant of the objects matching. Data analysis';ru='Помощник сопоставления объектов.Анализ данных'", CommonUseClientServer.MainLanguageCode()),
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
		WriteLogEvent(NStr("en='Assistant of the objects matching. Data analysis';ru='Помощник сопоставления объектов.Анализ данных'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Mapping objects.
//
&AtServer
Procedure AfterObjectsMapping(Val ResultComparison)
	
	If WriteAndClose Then
		Return;
	EndIf;
	
	// {Match digest}
	ObjectsCountInSource       = ResultComparison.ObjectsCountInSource;
	ObjectsCountInReceiver       = ResultComparison.ObjectsCountInReceiver;
	NumberOfObjectsMapped   = ResultComparison.NumberOfObjectsMapped;
	UnmappedObjectsCount = ResultComparison.UnmappedObjectsCount;
	ObjectsMappingPercent       = ResultComparison.ObjectsMappingPercent;
	PictureIndex                     = DataExchangeServer.InformationStatisticsTablePictureIndex(UnmappedObjectsCount, Object.DataSuccessfullyImported);
	
	MappingTable.Load(ResultComparison.MappingTable);
	
	DataProcessorObject = DataProcessors.InfobaseObjectsMapping.Create();
	DataExchangeServer.ImportObjectContext(ResultComparison.ObjectContext, DataProcessorObject);
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	If ApplyTableOfUnapprovedRecords Then
		Modified = False;
	EndIf;
	
	ApplyTableOfUnapprovedRecords = False;
	ApplyResultOfAutomaticMapping = False;
	AddressTableAutomaticallyMappedObjects = "";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Initialization of the assistant's transitions.

&AtServer
Procedure ScriptExecutionMappingObjects()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ObjectsMappingError", "ErrorMappingObjects_OnOpen");
	
	// Waiting for objects mapping.
	GoToTableNewRow(2, "WaitObjectsMapping",, True, "MappingObjects_LongWaitActionProcessing");
	GoToTableNewRow(3, "WaitObjectsMapping",, True, "MappingObjectsWaitLongOperationLongOperation_ProcessingOfLongOperation");
	GoToTableNewRow(4, "WaitObjectsMapping",, True, "MappingObjectsWaitLongOperationEnd_ProcessingLongOperation");
	
	// Work with the objects match table.
	GoToTableNewRow(5, "MappingObjects");
	
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
