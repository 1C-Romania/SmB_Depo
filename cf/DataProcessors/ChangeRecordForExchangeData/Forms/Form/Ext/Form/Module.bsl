// Editing form of the objects exchange changes registration on the specified node.
// It can be opened with the following parameters:
// 
// ExchangeNode                  - ExchangePlanRef - Ref to the exchange plan for operation.
// ProhibitedToChooseExchangeNode - Boolean           - Check box showing that user is not allowed to change the specified node.
//                                                  The ExchangeNode parameter should be specified.
// NamesOfHiddenMetadata   - ValueList   - Contains metadata names that will be
//                                                  excluded from the registration tree.
//
// Additional parameters are used while working with the subsystem of additional reports and data processors:
//
// AdditionalInformationProcessorRef - Arbitrary - Ref to the catalog item of the
//                                                additional reports and data processors that calls the form.
//                                                The "DestinationObjects" parameter should be filled in during usage.
// DestinationObjects             - Array       - Objects for the data processor. The first item will be
//                                                used to open the object registration form on nodes. The "CommandID" should
//                                                be filled in during the usage.
//

&AtClient
Var CurrentRowMetadata;

#Region FormEventsHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ValidateVersionAndPlatformCompatibilityMode();
	
	ParameterTableRegistration = Undefined;
	ParameterRegistrationObject  = Undefined;
	
	OpenNodeParameter = False;
	CurrentObject = ThisObject();
	
	// Determine what they create
	If Parameters.AdditionalInformationProcessorRef = Undefined Then
		// Start offline, possibly with the node parameter.
		ExchangeNodeRef = Parameters.ExchangeNode;
		Parameters.Property("ProhibitedToChooseExchangeNode", ProhibitedToChooseExchangeNode);
		OpenNodeParameter = True;
		
	Else
		// Call from the subsystem of additional data processors and reports.
		If TypeOf(Parameters.DestinationObjects) = Type("Array") AND Parameters.DestinationObjects.Count() > 0 Then
			
			// You are opened specifying the object.
			ObjectDestination = Parameters.DestinationObjects[0];
			Type = TypeOf(ObjectDestination);
			
			If ExchangePlans.AllRefsType().ContainsType(Type) Then
				ExchangeNodeRef = ObjectDestination;
				OpenNodeParameter = True;
			Else
				// Convert to two internal parameters.
				Definition = CurrentObject.MetadataCharacteristics(ObjectDestination.Metadata());
				If Definition.IsReference Then
					ParameterRegistrationObject = ObjectDestination;
					
				ElsIf Definition.ThisIsSet Then
					// Table structure and name
					ParameterTableRegistration = Definition.TableName;
					ParameterRegistrationObject  = New Structure;
					For Each Dimension IN CurrentObject.RegisterSetDimensions(ParameterTableRegistration) Do
						curName = Dimension.Name;
						ParameterRegistrationObject.Insert(curName, ObjectDestination.Filter[curName].Value);
					EndDo;
					
				EndIf;
			EndIf;
			
		Else
			Raise StrReplace(
				NStr("en='Incorrect object parameters of assigning the command opening ""%1""';ru='Некорректные параметры объектов назначения открытия команды ""%1""'"),
				"%1", Parameters.CommandID);
		EndIf;
		
	EndIf;
	
	// Always initialize object settings.
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	ThisObject(CurrentObject);
	
	// Initialize the rest only if you open this form,
	If ParameterRegistrationObject <> Undefined Then
		Return;
	EndIf;
	
	// List of prohibited metadata objects from the parameters.
	Parameters.Property("NamesOfHiddenMetadata", NamesOfHiddenMetadata);
	
	CurrentRowMetadata = Undefined;
	Items.ObjectListVariants.CurrentPage = Items.PageBlank;
	Parameters.Property("ProhibitedToChooseExchangeNode", ProhibitedToChooseExchangeNode);
	
	NodeNameExchangePlan = String(ExchangeNodeRef);
	
	If Not MonitorSettings() AND OpenNodeParameter Then
		
		MessageText = StrReplace(
			NStr("en='For ""%1"" objects registration editing is unavailable.';ru='Для ""%1"" редактирование регистрации объектов недоступно.'"),
			"%1", NodeNameExchangePlan);
		
		Raise MessageText;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure OnClose()
	// Settings auto save
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	// Query selection result, wait for a structure.
	If TypeOf(ValueSelected) <> Type("Structure") 
		Or (NOT ValueSelected.Property("ActionSelect"))
		Or (NOT ValueSelected.Property("ChoiceData"))
		Or TypeOf(ValueSelected.ActionSelect) <> Type("Boolean")
		Or TypeOf(ValueSelected.ChoiceData) <> Type("String")
	Then
		Error = NStr("en='Unexpected result of selection from the request console';ru='Неожиданный результат выбора из консоли запросов'");
	Else
		Error = QuerySelectControlLinks(ValueSelected.ChoiceData);
	EndIf;
	
	If Error <> "" Then 
		ShowMessageBox(,Error);
		Return;
	EndIf;
		
	If ValueSelected.ActionSelect Then
		Text = NStr("en='Register query
		|result on the node ""%1""?';ru='Зарегистрировать
		|результат запроса на узле ""%1""?'"); 
	Else
		Text = NStr("en='Cancel query result
		|registration on the node ""%1""?';ru='Отменить
		|регистрацию результата запроса на узле ""%1""?'");
	EndIf;
	Text = StrReplace(Text, "%1", String(ExchangeNodeRef));
					 
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
	
	Notification = New NotifyDescription("ChoiceProcessingEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ValueSelected", ValueSelected);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "UpdateRegistrationExchangeDataObject" Then
		FillCountRegistrationsInTree();
		UpdatePageContent();

	ElsIf EventName = "ExchangeNodeDataChange" AND ExchangeNodeRef = Parameter Then
		SetTitleNumbersMessages();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	// Automatic settings
	CurrentObject = ThisObject();
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If ParameterRegistrationObject <> Undefined Then
		// There will be work with another form.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.ExchangeNode) Then
		ExchangeNodeRef = Parameters.ExchangeNode;
	Else
		ExchangeNodeRef = Settings["ExchangeNodeRef"];
		// If the restored exchange node is deleted, clear it.
		If ExchangeNodeRef <> Undefined 
		    AND ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef))
		    AND IsBlankString(ExchangeNodeRef.DataVersion) 
		Then
			ExchangeNodeRef = Undefined;
		EndIf;
	EndIf;
	
	MonitorSettings();
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers
//

&AtClient
Procedure ExchangeNodeReferenceStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CurFormName = GetFormName() + "Form.ExchangePlanNodeChoice";
	CurParameters = New Structure("Multiselect, ChoiceInitialValue", False, ExchangeNodeRef);
	OpenForm(CurFormName, CurParameters, Item);
EndProcedure

&AtClient
Procedure ExchangeNodeReferenceChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ExchangeNodeRef <> ValueSelected Then
		ExchangeNodeRef = ValueSelected;
		ChoiceProcessingNodeExchange();
	EndIf;
EndProcedure

&AtClient
Procedure ExchangeNodeRefOnChange(Item)
	ChoiceProcessingNodeExchange();
	ExpandMetadataTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ExchangeNodeRefClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure VariantFilterMessagesByNumberOnChange(Item)
	SetFilterByMessageNumber(ConstantList,       VariantFilterMessagesByNumber);
	SetFilterByMessageNumber(RefsList,         VariantFilterMessagesByNumber);
	SetFilterByMessageNumber(ListOfSetsRecords, VariantFilterMessagesByNumber);
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ObjectsListVariantsOnCurrentPageChange(Item, CurrentPage)
	UpdatePageContent(CurrentPage);
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersMetadataTree
//

&AtClient
Procedure MetadataTreeCheckOnChange(Item)
	MarkChange(Items.MetadataTree.CurrentRow);
EndProcedure

&AtClient
Procedure MetadataTreeOnActivateRow(Item)
	If Items.MetadataTree.CurrentRow <> CurrentRowMetadata Then
		CurrentRowMetadata  = Items.MetadataTree.CurrentRow;
		AttachIdleHandler("CustomizeEditChanges", 0.0000001, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersConstantList
//

&AtClient
Procedure ConstantListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Result = AddRegistrationAtServer(True, ExchangeNodeRef, ValueSelected);
	Items.ConstantList.Refresh();
	FillCountRegistrationsInTree();
	MessageAboutResultsOfRegistration(True, Result);
	
	If TypeOf(ValueSelected) = Type("Array") AND ValueSelected.Count() > 0 Then
		Item.CurrentRow = ValueSelected[0];
	Else
		Item.CurrentRow = ValueSelected;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersListLinks
//

&AtClient
Procedure ListLinksSelectionProcessing(Item, ValueSelected, StandardProcessing)
	ChoiceProcessingData(Item, ValueSelected);
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersListRecordsets
//

&AtClient
Procedure ListOfSetsRecordsSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	WriteParameters = StructureOfSetKeyRecords(Item.CurrentData);
	If WriteParameters <> Undefined Then
		OpenForm(WriteParameters.FormName, New Structure(WriteParameters.Parameter, WriteParameters.Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListOfRecordSetsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	ChoiceProcessingData(Item, ValueSelected);
EndProcedure

#EndRegion

#Region FormCommandsHandlers
//

&AtClient
Procedure AddRegistrationOfOneObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurRow = Items.ObjectListVariants.CurrentPage;
	If CurRow = Items.PageOfConstant Then
		AddLoggingConstantsInList();
		
	ElsIf CurRow = Items.PageRefsList Then
		AddRegistrationInRefsList();
		
	ElsIf CurRow = Items.PageRecordSet Then
		AddRegistrationInRecordFilterSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationOfOneObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurRow = Items.ObjectListVariants.CurrentPage;
	If CurRow = Items.PageOfConstant Then
		DeleteConstantRegistrationInList();
		
	ElsIf CurRow = Items.PageRefsList Then
		DeleteRegistrationFromRefsList();
		
	ElsIf CurRow = Items.PageRecordSet Then
		DeleteRegistrationInRecordSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddFilterRegistration(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurRow = Items.ObjectListVariants.CurrentPage;
	If CurRow = Items.PageRefsList Then
		AddRegistrationInListFilter();
		
	ElsIf CurRow = Items.PageRecordSet Then
		AddRegistrationInRecordFilterSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteFilterRegistration(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurRow = Items.ObjectListVariants.CurrentPage;
	If CurRow = Items.PageRefsList Then
		DeleteRegistrationInListFilter();
		
	ElsIf CurRow = Items.PageRecordSet Then
		DeleteRegistrationRecordsInFilterSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenRegistrationFormAtNodes(Command)
	
	If ProhibitedToChooseExchangeNode Then
		Return;
	EndIf;
		
	Data = GetCurrentObjectEditing();
	If Data <> Undefined Then
		TableRegistration = ?(TypeOf(Data) = Type("Structure"), ListOfSetsRecordsTableName, "");
		OpenForm(GetFormName() + "Form.NodesRegistrationObject",
			New Structure("RegistrationObject, TableRegistration, NotifyAboutChanges", 
				Data, TableRegistration, True
			),
			ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExportResult(Command)
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	Serialization = New Array;
	
	If CurPage = Items.PageOfConstant Then 
		FormItem = Items.ConstantList;
		For Each String IN FormItem.SelectedRows Do
			CurData = FormItem.RowData(String);
			Serialization.Add(New Structure("TypeCheckBox, Data", 1, CurData.MetaFullName));
		EndDo;
		
	ElsIf CurPage = Items.PageRecordSet Then
		DimensionList = ArrayOfKeyNamesOfRecordSet(ListOfSetsRecordsTableName);
		FormItem = Items.ListOfSetsRecords;
		Prefix = "ListOfSetsRecords";
		For Each Item IN FormItem.SelectedRows Do
			CurData = New Structure();
			Data = FormItem.RowData(Item);
			For Each Name IN DimensionList Do
				CurData.Insert(Name, Data[Prefix + Name]);
			EndDo;
			Serialization.Add(New Structure("TypeCheckBox, Data", 2, CurData));
		EndDo;
		
	ElsIf CurPage = Items.PageRefsList Then
		FormItem = Items.RefsList;
		For Each Item IN FormItem.SelectedRows Do
			CurData = FormItem.RowData(Item);
			Serialization.Add(New Structure("TypeCheckBox, Data", 3, CurData.Ref));
		EndDo;
		
	Else
		Return;
		
	EndIf;
	
	If Serialization.Count() > 0 Then
		Text = SerializationText(Serialization);
		TitleText = NStr("en='Standard export result (RIB)';ru='Результат стандартной выгрузки (РИБ)'");
		Text.Show(TitleText);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditMessagesNumber(Command)
	
	If ValueIsFilled(ExchangeNodeRef) Then
		
		CurFormName = GetFormName() + "Form.ExchangePlanNodeMessageNumbers";
		CurParameters = New Structure("ExchangeNodeRef, Name", ExchangeNodeRef);
		FillPropertyValues(CurParameters, CurrentItem);
		
		OpenForm(CurFormName, CurParameters, ThisObject, , , , ,FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddLoggingConstants(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddLoggingConstantsInList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegisterOfConstant(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationReferences(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInRefsList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationRemoveObject(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddObjectDeletionToListRegistrationLinks();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationReferences(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationFromRefsList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationReferencesPickup(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInRefsList(True);
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationReferencesFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationLinksFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegisteringOfAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectsRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteAutoRecordObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectsRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure AddCheckAllObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectsRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationOfAllObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectsRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationRecordSetFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInRecordFilterSet();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationSetRecords(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSet();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationRecordSetFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationRecordsInFilterSet();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAllData(Command)
	FillCountRegistrationsInTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure AddRegistrationQueryResult(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		OperationWithResultsOfQuery(True);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationQueryResult(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		OperationWithResultsOfQuery(False);
	EndIf;
EndProcedure

&AtClient
Procedure OpenFormSettings(Command)
	OpenFormSettingsDataProcessors();
EndProcedure

&AtClient
Procedure EditMessageNoObject(Command)
	
	If Items.ObjectListVariants.CurrentPage = Items.PageOfConstant Then
		EditMessageNoOfConstant();
		
	ElsIf Items.ObjectListVariants.CurrentPage = Items.PageRefsList Then
		EditMessageNoLinks();
		
	ElsIf Items.ObjectListVariants.CurrentPage = Items.PageRecordSet Then
		EditMessageNoListOfSets()
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisterIOMAndPredetermined(Command)
	
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
	QuestionText     = StrReplace( 
		NStr("en='Register data to restore DIB
		|subordinate node on the node ""%1""?';ru='Зарегистрировать данные для восстановления подчиненного узла РИБ на узле ""%1""?'"),
		"%1", ExchangeNodeRef
	);
	
	Notification = New NotifyDescription("RegisterIOMEnd", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RefsListMessageNo.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("RefsList.NotExported");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en='Not exported';ru='Не выгружалось'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConstantListMessageNo.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("ConstantList.NotExported");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en='Not exported';ru='Не выгружалось'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ListOfSetsRecordsMessageNo.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("RecordSetsList.NotExported");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en='Not exported';ru='Не выгружалось'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MetadataTreeCountChangesString.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("MetadataTree.CountChanges");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 0;

	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	Item.Appearance.SetParameterValue("Text", NStr("en='No changes';ru='Нет изменений'"));

EndProcedure
//

// Export commands handler for the subsystem of additional reports and data processors.
//
// Parameters:
//     CommandID - String - Command ID for execution.
//     DestinationObjects    - Array - References for the data processor. It is not used here, it
//                                     is expected that the same parameter has been transferred and processed while creating a form.
//     CreatedObjects     - Array - Returned array of references to the created objects. 
//                                     It is not used in this data processor.
//
&AtClient
Procedure RunCommand(CommandID, DestinationObjects, CreatedObjects) Export
	
	If CommandID = "OpenEditRegistrationForm" Then
		
		If ParameterRegistrationObject <> Undefined Then
			// Use parameters received while creating on server.
			
			FormRegistrationParameters = New Structure;
			FormRegistrationParameters.Insert("RegistrationObject",  ParameterRegistrationObject);
			FormRegistrationParameters.Insert("TableRegistration", ParameterTableRegistration);

			OpenForm(GetFormName() + "Form.NodesRegistrationObject", FormRegistrationParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler of the dialog continuation notification.
&AtClient 
Procedure RegisterIOMEnd(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	MessageAboutResultsOfRegistration(True, RegisterIOMAndPredeterminedOnServer() );
		
	FillCountRegistrationsInTree();
	UpdatePageContent();
EndProcedure

// Handler of the dialog continuation notification.
&AtClient 
Procedure ChoiceProcessingEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return
	EndIf;
	ValueSelected = AdditionalParameters.ValueSelected;
	
	MessageAboutResultsOfRegistration(ValueSelected.ActionSelect,
		ChangeRegistrationResultQueryServer(ValueSelected.ActionSelect, ValueSelected.ChoiceData));
		
	FillCountRegistrationsInTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure EditMessageNoOfConstant()
	CurData = Items.ConstantList.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditConstantMessageNumberEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaFullName", CurData.MetaFullName);
	
	MessageNo = CurData.MessageNo;
	ToolTip = NStr("en='Sent Number';ru='Номер отправленного'"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient
Procedure EditConstantMessageNumberEnd(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// Refusal to enter
		Return;
	EndIf;
	
	MessageAboutResultsOfRegistration(MessageNo, 
		ChangeMessageNoAtServer(ExchangeNodeRef, MessageNo, AdditionalParameters.MetaFullName));
		
	Items.ConstantList.Refresh();
	FillCountRegistrationsInTree();
EndProcedure

&AtClient
Procedure EditMessageNoLinks()
	CurData = Items.RefsList.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditRefMessageNumberEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Ref", CurData.Ref);
	
	MessageNo = CurData.MessageNo;
	ToolTip = NStr("en='Sent Number';ru='Номер отправленного'"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient
Procedure EditRefMessageNumberEnd(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// Refusal to enter
		Return;
	EndIf;
	
	MessageAboutResultsOfRegistration(MessageNo, 
		ChangeMessageNoAtServer(ExchangeNodeRef, MessageNo, AdditionalParameters.Ref));
		
	Items.RefsList.Refresh();
	FillCountRegistrationsInTree();
EndProcedure

&AtClient
Procedure EditMessageNoListOfSets()
	CurData = Items.ListOfSetsRecords.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditSetsListMessageNumberEnd", ThisObject, New Structure);
	
	RowData = New Structure;
	KeyNames = ArrayOfKeyNamesOfRecordSet(ListOfSetsRecordsTableName);
	For Each Name IN KeyNames Do
		RowData.Insert(Name, CurData["ListOfSetsRecords" + Name]);
	EndDo;
	
	Notification.AdditionalParameters.Insert("RowData", RowData);
	
	MessageNo = CurData.MessageNo;
	ToolTip = NStr("en='Sent Number';ru='Номер отправленного'"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient
Procedure EditSetsListMessageNumberEnd(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// Refusal to enter
		Return;
	EndIf;
	
	MessageAboutResultsOfRegistration(MessageNo, ChangeMessageNoAtServer(
		ExchangeNodeRef, MessageNo, AdditionalParameters.RowData, ListOfSetsRecordsTableName));
	
	Items.ListOfSetsRecords.Refresh();
	FillCountRegistrationsInTree();
EndProcedure

&AtClient
Procedure CustomizeEditChanges()
	CustomizeEditChangesServer(CurrentRowMetadata);
EndProcedure

&AtClient
Procedure ExpandMetadataTree()
	For Each String IN MetadataTree.GetItems() Do
		Items.MetadataTree.Expand( String.GetID() );
	EndDo;
EndProcedure

&AtServer
Procedure SetTitleNumbersMessages()
	
	Text = NStr("en='%1 sent No, %2 receved No';ru='№ отправленного %1, № принятого %2'");
	
	Data = ReadNumberMessages();
	Text = StrReplace(Text, "%1", Format(Data.SentNo, "NFD=0; NZ="));
	Text = StrReplace(Text, "%2", Format(Data.ReceivedNo, "NFD=0; NZ="));
	
	Items.FormEditMessagesNumber.Title = Text;
EndProcedure	

&AtServer
Procedure ChoiceProcessingNodeExchange()
	
	// Change node numbers in the hyperlink on editing.
	SetTitleNumbersMessages();
	
	// Update metadata tree.
	ReadMetadataTree();
	FillCountRegistrationsInTree();
	
	// Update active page.
	LastActiveColumnMetadata = Undefined;
	LastActiveRowMetadata  = Undefined;
	Items.ObjectListVariants.CurrentPage = Items.PageBlank;
	
	// Update commands that depend on the node.
	
	MetaPlanExchangeSite = ExchangeNodeRef.Metadata();
	
	If Object.DIBIsAvailable                             // Work with MOI by SSL version is available.
		AND (ExchangePlans.MasterNode() = Undefined)          // Current base - the main node.
		AND MetaPlanExchangeSite.DistributedInfobase // The current node - DIB
	Then
		Items.RegisterIOMAndPredefinedForm.Visible = True;
	Else
		Items.RegisterIOMAndPredefinedForm.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure MessageAboutResultsOfRegistration(Command, Results)
	
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			TitleWarnings = NStr("en='Change records:';ru='Регистрация изменений:'");
			WarningText = NStr("en='%1 changes are registered
		|from %2 on the node ""%0""';ru='Зарегистрировано
		|%1 изменений из %2 на узле ""%0""'");
		Else
			TitleWarnings = NStr("en='Registration cancel:';ru='Отмена регистрации:'");
			WarningText = NStr("en='%1 changes registration is canceled on the node ""%0"".';ru='Отменена регистрация %1 изменений на узле ""%0"".'");
		EndIf;
	Else
		TitleWarnings = NStr("en='The message number change:';ru='Изменение номера сообщения:'");
		WarningText = NStr("en='Message number is changed
		|to %3 in the %1 object(s)';ru='Номер сообщения
		|изменен на %3 у %1 объекта(ов)'");
	EndIf;
	
	WarningText = StrReplace(WarningText, "%0", ExchangeNodeRef);
	WarningText = StrReplace(WarningText, "%1", Format(Results.Successfully, "NZ="));
	WarningText = StrReplace(WarningText, "%2", Format(Results.Total, "NZ="));
	WarningText = StrReplace(WarningText, "%3", Command);
	
	Warning = Results.Total <> Results.Successfully;
	If Warning Then
		RefreshDataRepresentation();
		ShowMessageBox(, WarningText, , TitleWarnings);
	Else
		ShowUserNotification(TitleWarnings,
			GetURL(ExchangeNodeRef),
			WarningText,
			Items.HiddenPictureInformation32.Picture);
	EndIf;
EndProcedure

&AtServer
Function GetQueryResultFormChoice()
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	ThisObject(CurrentObject);
	
	Checking = CurrentObject.CheckSettingsCorrectness();
	ThisObject(CurrentObject);
	
	If Checking.SettingAddressExternalDataQueryProcessors <> Undefined Then
		Return Undefined;
		
	ElsIf IsBlankString(CurrentObject.SettingAddressExternalDataQueryProcessors) Then
		Return Undefined;
		
	ElsIf Lower(Right(TrimAll(CurrentObject.SettingAddressExternalDataQueryProcessors), 4)) = ".epf" Then
		DataProcessor = ExternalDataProcessors.Create(CurrentObject.SettingAddressExternalDataQueryProcessors);
		FormID = ".ObjectForm";
		
	Else
		DataProcessor = DataProcessors[CurrentObject.SettingAddressExternalDataQueryProcessors].Create();
		FormID = ".Form";
		
	EndIf;
	
	Return DataProcessor.Metadata().FullName() + FormID;
EndFunction

&AtClient
Procedure AddLoggingConstantsInList()
	CurFormName = GetFormName() + "Form.ConstantChoice";
	CurParameters = New Structure("ExchangeNode, MetadataNamesArray, PresentationsArray, ArrayAutoRecord", 
		ExchangeNodeRef,
		StructureNameMetadata.Constants,
		MetadataPresentationsStructure.Constants,
		StructureAutoRecordMetadata.Constants);
	OpenForm(CurFormName, CurParameters, Items.ConstantList);
EndProcedure

&AtClient
Procedure DeleteConstantRegistrationInList()
	
	Item = Items.ConstantList;
	
	PresentationsList = New Array;
	ListOfNames          = New Array;
	For Each String IN Item.SelectedRows Do
		Data = Item.RowData(String);
		PresentationsList.Add(Data.Description);
		ListOfNames.Add(Data.MetaFullName);
	EndDo;
	
	Quantity = ListOfNames.Count();
	If Quantity = 0 Then
		Return;
	ElsIf Quantity = 1 Then
		Text = NStr("en='Cancel registration
		|""%2"" on the node ""%1""?';ru='Отменить
		|регистрацию ""%2"" на узле ""%1""?'"); 
	Else
		Text = NStr("en='Cancel registration of
		|the selected constants on the node ""%1""?';ru='Отменить регистрацию
		|выбранных констант на узле ""%1""?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", PresentationsList[0]);
	
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
	
	Notification = New NotifyDescription("DeleteConstantRegistrationInListEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ListOfNames", ListOfNames);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient
Procedure DeleteConstantRegistrationInListEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
		
	MessageAboutResultsOfRegistration(False, 
		DeleteRegistrationAtServer(True, ExchangeNodeRef, AdditionalParameters.ListOfNames));
		
	Items.ConstantList.Refresh();
	FillCountRegistrationsInTree();
EndProcedure

&AtClient
Procedure AddRegistrationInRefsList(ThisSelection = False)
	CurFormName = GetFormName(RefsList) + "ChoiceForm";
	CurParameters = New Structure("ChoiceMode, Multiselect, CloseOnChoice, ChoiceFoldersAndItems", 
		True, True, ThisSelection, FoldersAndItemsUse.FoldersAndItems);
	OpenForm(CurFormName, CurParameters, Items.RefsList);
EndProcedure

&AtClient
Procedure AddObjectDeletionToListRegistrationLinks()
	Ref = RefForObjectDeletion();
	ChoiceProcessingData(Items.RefsList, Ref);
EndProcedure

&AtServer
Function RefForObjectDeletion(Val UUID = Undefined)
	Definition = ThisObject().MetadataCharacteristics(RefsList.MainTable);
	If UUID = Undefined Then
		Return Definition.Manager.GetRef();
	EndIf;
	Return Definition.Manager.GetRef(UUID);
EndFunction

&AtClient 
Procedure AddRegistrationInListFilter()
	CurFormName = GetFormName() + "Form.ObjectsSelectionByFilter";
	CurParameters = New Structure("ActionSelect, TableName", 
		True,
		MainTableDynamicList(RefsList));
	OpenForm(CurFormName, CurParameters, Items.RefsList);
EndProcedure

&AtClient 
Procedure DeleteRegistrationInListFilter()
	CurFormName = GetFormName() + "Form.ObjectsSelectionByFilter";
	CurParameters = New Structure("ActionSelect, TableName", 
		False,
		MainTableDynamicList(RefsList));
	OpenForm(CurFormName, CurParameters, Items.RefsList);
EndProcedure

&AtClient
Procedure DeleteRegistrationFromRefsList()
	
	Item = Items.RefsList;
	
	DeletionList = New Array;
	For Each String IN Item.SelectedRows Do
		Data = Item.RowData(String);
		DeletionList.Add(Data.Ref);
	EndDo;
	
	Quantity = DeletionList.Count();
	If Quantity = 0 Then
		Return;
	ElsIf Quantity = 1 Then
		Text = NStr("en='Cancel registration
		|""%2"" on the node ""%1""?';ru='Отменить
		|регистрацию ""%2"" на узле ""%1""?'"); 
	Else
		Text = NStr("en='Cancel registration of
		|the selected objects on the node ""%1""?';ru='Отменить регистрацию
		|выбранных объектов на узле ""%1""?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", DeletionList[0]);
	
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
	
	Notification = New NotifyDescription("DeleteRegistrationFromRefsListEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("DeletionList", DeletionList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient 
Procedure DeleteRegistrationFromRefsListEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	MessageAboutResultsOfRegistration(False,
		DeleteRegistrationAtServer(True, ExchangeNodeRef, AdditionalParameters.DeletionList));
		
	Items.RefsList.Refresh();
	FillCountRegistrationsInTree();
EndProcedure

&AtClient
Procedure AddRegistrationInRecordFilterSet()
	CurFormName = GetFormName() + "Form.ObjectsSelectionByFilter";
	CurParameters = New Structure("ActionSelect, TableName", 
		True,
		ListOfSetsRecordsTableName);
	OpenForm(CurFormName, CurParameters, Items.ListOfSetsRecords);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSet()
	
	DataStructure = "";
	KeyNames = ArrayOfKeyNamesOfRecordSet(ListOfSetsRecordsTableName);
	For Each Name IN KeyNames Do
		DataStructure = DataStructure +  "," + Name;
	EndDo;
	DataStructure = Mid(DataStructure, 2);
	
	Data = New Array;
	Item = Items.ListOfSetsRecords;
	For Each String IN Item.SelectedRows Do
		CurData = Item.RowData(String);
		RowData = New Structure;
		For Each Name IN KeyNames Do
			RowData.Insert(Name, CurData["ListOfSetsRecords" + Name]);
		EndDo;
		Data.Add(RowData);
	EndDo;
	
	If Data.Count() = 0 Then
		Return;
	EndIf;
	
	Choice = New Structure("TableName, ChoiceData, ChoiceAction, FieldStructure",
		ListOfSetsRecordsTableName,
		Data,
		False,
		DataStructure);
		
	ChoiceProcessingData(Items.ListOfSetsRecords, Choice);
EndProcedure

&AtClient
Procedure DeleteRegistrationRecordsInFilterSet()
	CurFormName = GetFormName() + "Form.ObjectsSelectionByFilter";
	CurParameters = New Structure("ActionSelect, TableName", 
		False,
		ListOfSetsRecordsTableName);
	OpenForm(CurFormName, CurParameters, Items.ListOfSetsRecords);
EndProcedure

&AtClient
Procedure AddSelectedObjectsRegistration(WithoutAccountingAutoRecord = True)
	
	Data = GetSelectedMetadataNames(WithoutAccountingAutoRecord);
	Quantity = Data.MetaNames.Count();
	If Quantity = 0 Then
		// Current row
		Data = GetMetadataNamesCurrentRows(WithoutAccountingAutoRecord);
	EndIf;
	
	Text = NStr("en='Register %1 for export
		|
		|on the node ""%2""? Changing the registration of many objects may take a long time.';ru='Зарегистрировать %1 для выгрузки на узле ""%2""? Изменение регистрации большого количества объектов может занять продолжительное время!'");
					 
	Text = StrReplace(Text, "%1", Data.Definition);
	Text = StrReplace(Text, "%2", ExchangeNodeRef);
	
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
	
	Notification = New NotifyDescription("AddSelectedObjectsRegistrationEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("WithoutAccountingAutoRecord", WithoutAccountingAutoRecord);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient 
Procedure AddSelectedObjectsRegistrationEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Result = AddRegistrationAtServer(AdditionalParameters.WithoutAccountingAutoRecord, 
		ExchangeNodeRef, AdditionalParameters.MetaNames);
	
	FillCountRegistrationsInTree();
	UpdatePageContent();
	MessageAboutResultsOfRegistration(True, Result);
EndProcedure

&AtClient
Procedure DeleteSelectedObjectsRegistration(WithoutAccountingAutoRecord = True)
	
	Data = GetSelectedMetadataNames(WithoutAccountingAutoRecord);
	Quantity = Data.MetaNames.Count();
	If Quantity = 0 Then
		Data = GetMetadataNamesCurrentRows(WithoutAccountingAutoRecord);
	EndIf;
	
	Text = NStr("en='Cancel %1 registration for export
		|
		|on the node ""%2""? Changing the registration of many objects may take a long time.';ru='Отменить регистрацию %1 для выгрузки на узле ""%2""? Изменение регистрации большого количества объектов может занять продолжительное время!'");
	
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
	
	Text = StrReplace(Text, "%1", Data.Definition);
	Text = StrReplace(Text, "%2", ExchangeNodeRef);
	
	Notification = New NotifyDescription("DeleteSelectedObjectsRegistrationEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("WithoutAccountingAutoRecord", WithoutAccountingAutoRecord);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient
Procedure DeleteSelectedObjectsRegistrationEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	MessageAboutResultsOfRegistration(False,
		DeleteRegistrationAtServer(AdditionalParameters.WithoutAccountingAutoRecord, 
			ExchangeNodeRef, AdditionalParameters.MetaNames));
		
	FillCountRegistrationsInTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ChoiceProcessingData(FormTable, ValueSelected)
	
	Ref = Undefined;
	Type    = TypeOf(ValueSelected);
	
	If Type = Type("Structure") Then
		TableName = ValueSelected.TableName;
		Action   = ValueSelected.ActionSelect;
		Data     = ValueSelected.ChoiceData;
	Else
		TableName = Undefined;
		Action = True;
		If Type = Type("Array") Then
			Data = ValueSelected;
		Else		
			Data = New Array;
			Data.Add(ValueSelected);
		EndIf;
		
		If Data.Count() = 1 Then
			Ref = Data[0];
		EndIf;
	EndIf;
	
	If Action Then
		Result = AddRegistrationAtServer(True, ExchangeNodeRef, Data, TableName);
		
		FormTable.Refresh();
		FillCountRegistrationsInTree();
		MessageAboutResultsOfRegistration(Action, Result);
		
		FormTable.CurrentRow = Ref;
		Return;
	EndIf;
	
	If Ref = Undefined Then
		Text = NStr("en='Cancel registration of
		|the selected objects on the node ""%1""?';ru='Отменить регистрацию
		|выбранных объектов на узле ""%1""?'"); 
	Else
		Text = NStr("en='Cancel %2
		|registration on the node ""%1""?';ru='Отменить
		|регистрацию ""%2"" на узле ""%1?'"); 
	EndIf;
		
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", Ref);
	
	QuestionTitle = NStr("en='Confirmation';ru='Подтверждение'");
		
	Notification = New NotifyDescription("ChoiceProcessingDataEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Action",     Action);
	Notification.AdditionalParameters.Insert("FormTable", FormTable);
	Notification.AdditionalParameters.Insert("Data",       Data);
	Notification.AdditionalParameters.Insert("TableName",   TableName);
	Notification.AdditionalParameters.Insert("Ref",       Ref);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient
Procedure ChoiceProcessingDataEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Result = DeleteRegistrationAtServer(True, ExchangeNodeRef, AdditionalParameters.Data, AdditionalParameters.TableName);
	
	AdditionalParameters.FormTable.Refresh();
	FillCountRegistrationsInTree();
	MessageAboutResultsOfRegistration(AdditionalParameters.Action, Result);
	
	AdditionalParameters.FormTable.CurrentRow = AdditionalParameters.Ref;
EndProcedure

&AtServer
Procedure UpdatePageContent(Page = Undefined)
	CurRow = ?(Page = Undefined, Items.ObjectListVariants.CurrentPage, Page);
	
	If CurRow = Items.PageRefsList Then
		Items.RefsList.Refresh();
		
	ElsIf CurRow = Items.PageOfConstant Then
		Items.ConstantList.Refresh();
		
	ElsIf CurRow = Items.PageRecordSet Then
		Items.ListOfSetsRecords.Refresh();
		
	ElsIf CurRow = Items.PageBlank Then
		String = Items.MetadataTree.CurrentRow;
		If String <> Undefined Then
			Data = MetadataTree.FindByID(String);
			If Data <> Undefined Then
				CustomizeBlankPage(Data.Description, Data.MetaFullName);
			EndIf;
		EndIf;
	EndIf;
EndProcedure	

&AtClient
Function GetCurrentObjectEditing()
	
	CurRow = Items.ObjectListVariants.CurrentPage;
	
	If CurRow = Items.PageRefsList Then
		Data = Items.RefsList.CurrentData;
		If Data <> Undefined Then
			Return Data.Ref; 
		EndIf;
		
	ElsIf CurRow = Items.PageOfConstant Then
		Data = Items.ConstantList.CurrentData;
		If Data <> Undefined Then
			Return Data.MetaFullName; 
		EndIf;
		
	ElsIf CurRow = Items.PageRecordSet Then
		Data = Items.ListOfSetsRecords.CurrentData;
		If Data <> Undefined Then
			Result = New Structure;
			Dimensions = ArrayOfKeyNamesOfRecordSet(ListOfSetsRecordsTableName);
			For Each Name IN Dimensions  Do
				Result.Insert(Name, Data["ListOfSetsRecords" + Name]);
			EndDo;
		EndIf;
		Return Result;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure OpenFormSettingsDataProcessors()
	CurFormName = GetFormName() + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure OperationWithResultsOfQuery(CommandOperations)
	
	CurFormName = GetQueryResultFormChoice();
	If CurFormName <> Undefined Then
		// Open
		If CommandOperations Then
			Text = NStr("en='Request result modifications registration';ru='Регистрация изменений результата запроса'");
		Else
			Text = NStr("en='Cancel the modifications registration of the request result';ru='Отмена регистрации изменений результата запроса'");
		EndIf;
		OpenForm(CurFormName, 
			New Structure("Title, ActionSelect, ChoiceMode, CloseOnChoice, ", 
				Text, CommandOperations, True, False
			), ThisObject);
		Return;
	EndIf;
	
	// If something is not set or something is broken, you may select.
	Text = NStr("en='Data processor for queries execution is not specified in the settings.
		|Customize now?';ru='В настройках не указана обработка для выполнения запросов.
		|Настроить сейчас?'");
	
	QuestionTitle = NStr("en='Settings';ru='Настройки'");

	Notification = New NotifyDescription("OperationWithResultsOfQueryEnd", ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Handler of the dialog continuation notification.
&AtClient 
Procedure OperationWithResultsOfQueryEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	OpenFormSettingsDataProcessors();
EndProcedure

&AtServer
Function HandleQuotesAtRow(String)
	Return StrReplace(String, """", """""");
EndFunction

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction

&AtServer
Function MainTableDynamicList(FormAttribute)
	Return FormAttribute.MainTable;
EndFunction

&AtServer
Procedure MarkChange(String)
	DataItem = MetadataTree.FindByID(String);
	ThisObject().MarkChange(DataItem);
EndProcedure

&AtServer
Procedure ReadMetadataTree()
	Data = ThisObject().GenerateMetadataStructure(ExchangeNodeRef);
	
	// Delete strings that can not be edited.
	MetaTree = Data.Tree;
	For Each ItemOfList IN NamesOfHiddenMetadata Do
		DeleteTreeRowsValuesMetadata(ItemOfList.Value, MetaTree.Rows);
	EndDo;
	
	ValueToFormAttribute(MetaTree, "MetadataTree");
	StructureAutoRecordMetadata = Data.StructureAutoRecord;
	MetadataPresentationsStructure   = Data.PresentationsStructure;
	StructureNameMetadata            = Data.StructureName;
EndProcedure

&AtServer 
Procedure DeleteTreeRowsValuesMetadata(Val MetaFullName, TreeRows)
	If IsBlankString(MetaFullName) Then
		Return;
	EndIf;
	
	// IN the current set
	Filter = New Structure("MetaFullName", MetaFullName);
	For Each RemovalLine IN TreeRows.FindRows(Filter, False) Do
		TreeRows.Delete(RemovalLine);
		// If it is the last descendant, then delete parent as well.
		If TreeRows.Count() = 0 Then
			ParentalRow = TreeRows.Parent;
			If ParentalRow.Parent <> Undefined Then
				ParentalRow.Parent.Rows.Delete(ParentalRow);
				// And do not go downwards hierarchically.
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	// Delete from the left subordinate ones.
	For Each TreeRow IN TreeRows Do
		DeleteTreeRowsValuesMetadata(MetaFullName, TreeRow.Rows);
	EndDo;
EndProcedure

&AtServer
Procedure FormatCountChanges(String)
	String.CountChangesString = Format(String.CountChanges, "NZ=") + " / " + Format(String.CountNotExported, "NZ=");
EndProcedure

&AtServer
Procedure FillCountRegistrationsInTree()
	
	Data = ThisObject().GetNumberOfChanges(StructureNameMetadata, ExchangeNodeRef);
	
	// Set to the tree
	Filter = New Structure("MetaFullName, ExchangeNode", Undefined, ExchangeNodeRef);
	Zeros   = New Structure("CountChanges, ExportedQuantity, CountNotExported", 0,0,0);
	
	For Each Root IN MetadataTree.GetItems() Do
		AmountRoot = New Structure("CountChanges, ExportedQuantity, CountNotExported", 0,0,0);
		
		For Each Group IN Root.GetItems() Do
			AmountGroup = New Structure("CountChanges, ExportedQuantity, CountNotExported", 0,0,0);
			
			ListOfNodes = Group.GetItems();
			If ListOfNodes.Count() = 0 AND StructureNameMetadata.Property(Group.MetaFullName) Then
				// Collection of nodes without nodes, sum manually, take auto registration from the structure.
				For Each MetaName IN StructureNameMetadata[Group.MetaFullName] Do
					Filter.MetaFullName = MetaName;
					Found = Data.FindRows(Filter);
					If Found.Count() > 0 Then
						String = Found[0];
						AmountGroup.CountChanges     = AmountGroup.CountChanges     + String.CountChanges;
						AmountGroup.CountExported   = AmountGroup.CountExported   + String.CountExported;
						AmountGroup.CountNotExported = AmountGroup.CountNotExported + String.CountNotExported;
					EndIf;
				EndDo;
				
			Else
				// Count by each node
				For Each Node IN ListOfNodes Do
					Filter.MetaFullName = Node.MetaFullName;
					Found = Data.FindRows(Filter);
					If Found.Count() > 0 Then
						String = Found[0];
						FillPropertyValues(Node, String, "CountChanges, ExportedQuantity, CountNotExported");
						AmountGroup.CountChanges     = AmountGroup.CountChanges     + String.CountChanges;
						AmountGroup.CountExported   = AmountGroup.CountExported   + String.CountExported;
						AmountGroup.CountNotExported = AmountGroup.CountNotExported + String.CountNotExported;
					Else
						FillPropertyValues(Node, Zeros);
					EndIf;
					
					FormatCountChanges(Node);
				EndDo;
				
			EndIf;
			FillPropertyValues(Group, AmountGroup);
			
			AmountRoot.CountChanges     = AmountRoot.CountChanges     + Group.CountChanges;
			AmountRoot.CountExported   = AmountRoot.CountExported   + Group.CountExported;
			AmountRoot.CountNotExported = AmountRoot.CountNotExported + Group.CountNotExported;
			
			FormatCountChanges(Group);
		EndDo;
		
		FillPropertyValues(Root, AmountRoot);
		
		FormatCountChanges(Root);
	EndDo;
	
EndProcedure

&AtServer
Function ChangeRegistrationResultQueryServer(Command, Address)
	
	Result = GetFromTempStorage(Address);
	Result= Result[Result.UBound()];
	Data = Result.Unload().UnloadColumn("Ref");
	
	If Command Then
		Return AddRegistrationAtServer(True, ExchangeNodeRef, Data);
	EndIf;
	
	Return DeleteRegistrationAtServer(True, ExchangeNodeRef, Data);
EndFunction

&AtServer
Function QuerySelectControlLinks(Address)
	
	Result = ?(Address = Undefined, Undefined, GetFromTempStorage(Address));
	If TypeOf(Result) = Type("Array") Then 
		Result = Result[Result.UBound()];	
		If Result.Columns.Find("Ref") = Undefined Then
			Return NStr("en='There is no ""Ref"" column in the last query result.';ru='В последнем результате запроса отсутствует колонка ""Ссылка""'");
		EndIf;
	Else		
		Return NStr("en='Error when receiving the request result data';ru='Ошибка получения данных результата запроса'");
	EndIf;
	
	Return "";
EndFunction

&AtServer
Procedure CustomizeEditChangesServer(CurrentRow)
	
	Data = MetadataTree.FindByID(CurrentRow);
	If Data = Undefined Then
		Return;
	EndIf;
	
	TableName   = Data.MetaFullName;
	Description = Data.Description;
	CurrentObject   = ThisObject();
	
	If IsBlankString(TableName) Then
		Meta = Undefined;
	Else		
		Meta = CurrentObject.MetadataByFullname(TableName);
	EndIf;
	
	If Meta = Undefined Then
		CustomizeBlankPage(Description, TableName);
		NewPage = Items.PageBlank;
		
	ElsIf Meta = Metadata.Constants Then
		// All system constants
		AdjustConstantList();
		NewPage = Items.PageOfConstant;
		
	ElsIf TypeOf(Meta) = Type("MetadataObjectCollection") Then
		// All catalogs, documents, etc.
		CustomizeBlankPage(Description, TableName);
		NewPage = Items.PageBlank;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		// A single constant
		AdjustConstantList(TableName, Description);
		NewPage = Items.PageOfConstant;
		
	ElsIf Metadata.Catalogs.Contains(Meta) 
		Or Metadata.Documents.Contains(Meta)
		Or Metadata.ChartsOfCharacteristicTypes.Contains(Meta)
		Or Metadata.ChartsOfAccounts.Contains(Meta)
		Or Metadata.ChartsOfCalculationTypes.Contains(Meta)
		Or Metadata.BusinessProcesses.Contains(Meta)
		Or Metadata.Tasks.Contains(Meta)
	Then
		// Reference type
		AdjustRefsList(TableName, Description);
		NewPage = Items.PageRefsList;
		
	Else
		// Check for the records set
		Dimensions = CurrentObject.RegisterSetDimensions(TableName);
		If Dimensions <> Undefined Then
			CustomizeRecordSet(TableName, Dimensions, Description);
			NewPage = Items.PageRecordSet;
		Else
			CustomizeBlankPage(Description, TableName);
			NewPage = Items.PageBlank;
		EndIf;
		
	EndIf;
	
	Items.PageOfConstant.Visible    = False;
	Items.PageRefsList.Visible = False;
	Items.PageRecordSet.Visible = False;
	Items.PageBlank.Visible       = False;
	
	Items.ObjectListVariants.CurrentPage = NewPage;
	NewPage.Visible = True;
	
	CustomizeVisibleCommonMenuCommands();
EndProcedure

// Output changes for a reference type (catalog, document, chart of characteristic types, chart of accounts, calculation type, business processes, jobs).
// 
&AtServer
Procedure AdjustRefsList(TableName, Description)
	
	RefsList.QueryText = "
		|SELECT
		|	ChangeTable.Ref         AS Ref,
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported,
		|
		|	MainTable.Ref AS ObjectRef
		|FROM
		|	" + TableName + " AS
		|MainTable RIGHT JOIN
		|	" + TableName + ".Changes
		|AS
		|ChangesTable BY MainTable.Ref
		|=
		|ChangesTable.Ref WHERE ChangesTable.Node = &SelectedNode
		|";
		
	RefsList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	RefsList.MainTable = TableName;
	RefsList.DynamicDataRead = True;
	
	// Object presentation
	Meta = ThisObject().MetadataByFullname(TableName);
	CurTitle = Meta.ObjectPresentation;
	If IsBlankString(CurTitle) Then
		CurTitle = Description;
	EndIf;
	Items.ListRefLinkPresentation.Title = CurTitle;
EndProcedure

// Output changes for constants.
//
&AtServer
Procedure AdjustConstantList(TableName = Undefined, Description = "")
	
	If TableName = Undefined Then
		// All constants
		names = StructureNameMetadata.Constants;
		Presentation = MetadataPresentationsStructure.Constants;
		AutoRecord = StructureAutoRecordMetadata.Constants;
	Else
		names = New Array;
		names.Add(TableName);
		Presentation = New Array;
		Presentation.Add(Description);
		IndexOf = StructureNameMetadata.Constants.Find(TableName);
		AutoRecord = New Array;
		AutoRecord.Add(StructureAutoRecordMetadata.Constants[IndexOf]);
	EndIf;
	
	// And remember about restriction on tables quantity.
	Text = "";
	For IndexOf = 0 To names.UBound() Do
		Name = names[IndexOf];
		Text = Text + ?(Text = "", "SELECT", "MERGE ALL SELECT") + "
		|	" + Format(AutoRecord[IndexOf], "NZ=; NG=") + " AS
		|	PictureIndexAutoRecord, 2 AS PictureIndex, """ + HandleQuotesAtRow(Presentation[IndexOf]) + """ AS
		|	Description, """ + Name +                                     """ AS MetaFullName,
		|
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|FROM
		|	" + Name + ".Changes
		|AS
		|ChangesTable WHERE ChangesTable.Node = &SelectedNode
		|";
	EndDo;
	
	ConstantList.QueryText = "
		|SELECT
		|	PictureIndexAutoRecord, PictureIndex, MetaFullName, NotExported,
		|	Description, MessageNo
		|
		|{SELECT
		|	PictureIndexAutoRecord, PictureIndex, 
		|	Description, MetaFullName, 
		|	MessageNo, NotExported
		|}
		|
		|FROM (" + Text + ")
		|
		|Data
		|	{WHERE Description, MessageNo,
		|NotExported }
		|";
		
	ListItems = ConstantList.Order.Items;
	If ListItems.Count() = 0 Then
		Item = ListItems.Add(Type("DataCompositionOrderItem"));
		Item.Field = New DataCompositionField("Description");
		Item.Use = True;
	EndIf;
	
	ConstantList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	ConstantList.DynamicDataRead = True;
EndProcedure	

// Output stub with a blank page.
&AtServer
Procedure CustomizeBlankPage(Description, TableName = Undefined)
	
	If TableName = Undefined Then
		CountsText = "";
	Else
		Tree = FormAttributeToValue("MetadataTree");
		String = Tree.Rows.Find(TableName, "MetaFullName", True);
		If String <> Undefined Then
			CountsText = NStr("en='Objects registered:
		|%1 Objects
		|exported: %2 Objects not exported: %3
		|';ru='Зарегистрировано
		|объектов:
		|%1 Выгружено объектов: %2 Не выгружено объектов: %3
		|'");
	
			CountsText = StrReplace(CountsText, "%1", Format(String.CountChanges, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%2", Format(String.CountExported, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%3", Format(String.CountNotExported, "NFD=0; NZ="));
		EndIf;
	EndIf;
	
	Text = NStr("en='%1.
		|
		|%2
		|To register or cancel registration of the data
		|exchange
		|on the node ""%3"", select object type on the
		|left in the metadata tree and use the commands ""Register"" or ""Cancel registration""';ru='%1.
		|
		|%2
		|Для регистрации или отмены регистрации обмена
		|данными
		|на узле ""%3"" выберите тип объекта слева в
		|дереве метаданных и воспользуйтесь командами ""Зарегистрировать"" или ""Отменить регистрацию""'");
		
	Text = StrReplace(Text, "%1", Description);
	Text = StrReplace(Text, "%2", CountsText);
	Text = StrReplace(Text, "%3", ExchangeNodeRef);
	Items.EmptyDecorationPage.Title = Text;
EndProcedure

// Output changes for record sets.
//
&AtServer
Procedure CustomizeRecordSet(TableName, Dimensions, Description)
	
	TextSelect = "";
	Prefix     = "ListOfSetsRecords";
	For Each String IN Dimensions Do
		Name = String.Name;
		TextSelect = TextSelect + ",ChangeTable." + Name + " AS " + Prefix + Name + Chars.LF;
		// Not to interfere with the dimension "MessageNumber" or "NotExported".
		String.Name = Prefix + Name;
	EndDo;
	
	ListOfSetsRecords.QueryText = "
		|SELECT ALLOWED
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|
		|
		|SELECT ALLOWED
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|
		|	" + TextSelect + "
		|IN
		|	" + TableName + ".Changes
		|AS
		|ChangesTable WHERE ChangesTable.Node = &SelectedNode
		|";
	ListOfSetsRecords.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	
	// Add to the dimensions group.
	ThisObject().FormTableAddColumns(
		Items.ListOfSetsRecords, 
		"MessageNo, NotExported, Order, Filter, Group, DefaultPicture, Parameters, ConditionalAppearance",
		Dimensions,
		Items.ListOfSetsRecordsGroupMeasurements);
	ListOfSetsRecords.DynamicDataRead = True;
	ListOfSetsRecordsTableName = TableName;
EndProcedure

// General filter by the "MessageNumber" field.
//
&AtServer
Procedure SetFilterByMessageNumber(DynamoList, Variant)
	
	Field = New DataCompositionField("NotExported");
	// Search for your field and disable everything related to it.
	ListItems = DynamoList.Filter.Items;
	IndexOf = ListItems.Count();
	While IndexOf > 0 Do
		IndexOf = IndexOf - 1;
		Item = ListItems[IndexOf];
		If Item.LeftValue = Field Then 
			ListItems.Delete(Item);
		EndIf;
	EndDo;
	
	FilterItem = ListItems.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = Field;
	FilterItem.ComparisonType  = DataCompositionComparisonType.Equal;
	FilterItem.Use = False;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	If Variant = 1 Then 		// Exported
		FilterItem.RightValue = False;
		FilterItem.Use  = True;
		
	ElsIf Variant = 2 Then	// Not exported
		FilterItem.RightValue = True;
		FilterItem.Use  = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CustomizeVisibleCommonMenuCommands()
	
	CurRow = Items.ObjectListVariants.CurrentPage;
	
	If CurRow = Items.PageOfConstant Then
		Items.AddOneObjectRegistrationForm.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteOneObjectRegistration.Enabled  = True;
		Items.FormDeleteFilterRegistration.Enabled          = False;
		
	ElsIf CurRow = Items.PageRefsList Then
		Items.AddOneObjectRegistrationForm.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = True;
		Items.FormDeleteOneObjectRegistration.Enabled  = True;
		Items.FormDeleteFilterRegistration.Enabled          = True;
		
	ElsIf CurRow = Items.PageRecordSet Then
		Items.AddOneObjectRegistrationForm.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteOneObjectRegistration.Enabled  = True;
		Items.FormDeleteFilterRegistration.Enabled          = False;
		
	Else
		Items.AddOneObjectRegistrationForm.Enabled = False;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteOneObjectRegistration.Enabled  = False;
		Items.FormDeleteFilterRegistration.Enabled          = False;
		
	EndIf;
EndProcedure	

&AtServer
Function ArrayOfKeyNamesOfRecordSet(TableName, PrefixNames = "")
	Result = New Array;
	Dimensions = ThisObject().RegisterSetDimensions(TableName);
	If Dimensions <> Undefined Then
		For Each String IN Dimensions Do
			Result.Add(PrefixNames + String.Name);
		EndDo;
	EndIf;
	Return Result;
EndFunction	

&AtServer
Function MetadataManager(TableName) 
	Definition = ThisObject().MetadataCharacteristics(TableName);
	If Definition <> Undefined Then
		Return Definition.Manager;
	EndIf;
	Return Undefined;
EndFunction

&AtServer
Function SerializationText(Serialization)
	
	Text = New TextDocument;
	
	Record = New XMLWriter;
	For Each Item IN Serialization Do
		Record.SetString("UTF-16");	
		Value = Undefined;
		
		If Item.FlagType = 1 Then
			// Metadata
			Manager = MetadataManager(Item.Data);
			Value = Manager.CreateValueManager();
			
		ElsIf Item.FlagType = 2 Then
			// Data set with filter
			Manager = MetadataManager(ListOfSetsRecordsTableName);
			Value = Manager.CreateRecordSet();
			Filter = Value.Filter;
			For Each NameValue IN Item.Data Do
				Filter[NameValue.Key].Set(NameValue.Value);
			EndDo;
			Value.Read();
			
		ElsIf Item.FlagType = 3 Then
			// Ref
			Value = Item.Data.GetObject();
			If Value = Undefined Then
				Value = New ObjectDeletion(Item.Data);
			EndIf;
		EndIf;
		
		WriteXML(Record, Value); 
		Text.AddLine(Record.Close());
	EndDo;
	
	Return Text;
EndFunction	

&AtServer
Function DeleteRegistrationAtServer(WithoutAccountingAutoRecord, Node, ToDelete, TableName = Undefined)
	Return ThisObject().ChangeRegistrationAtServer(False, WithoutAccountingAutoRecord, Node, ToDelete, TableName);
EndFunction

&AtServer
Function AddRegistrationAtServer(WithoutAccountingAutoRecord, Node, Adding, TableName = Undefined)
	Return ThisObject().ChangeRegistrationAtServer(True, WithoutAccountingAutoRecord, Node, Adding, TableName);
EndFunction

&AtServer
Function ChangeMessageNoAtServer(Node, MessageNo, Data, TableName = Undefined)
	Return ThisObject().ChangeRegistrationAtServer(MessageNo, True, Node, Data, TableName);
EndFunction

&AtServer
Function GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord, MetaNameGroup = Undefined, MetaNameNode = Undefined)
    
	If MetaNameGroup = Undefined AND MetaNameNode = Undefined Then
		// Nothing is specified
		Text = NStr("en='all objects %1 by the selected type hierarchy';ru='все объекты %1 по выбранной иерархии вида'");
		
	ElsIf MetaNameGroup <> Undefined AND MetaNameNode = Undefined Then
		// Only the group is specified, treat it as the group name.
		Text = "%2 %1";
		
	ElsIf MetaNameGroup = Undefined AND MetaNameNode <> Undefined Then
		// Only the node is specified, treat it as a lot of selected objects.
		Text = NStr("en='all objects %1 by the selected type hierarchy';ru='все объекты %1 по выбранной иерархии вида'");
		
	Else
		// Both group and node are specified, treat them as the metadata names.
		Text = NStr("en='all objects of the type ""%3"" %1';ru='все объекты типа ""%3"" %1'");
		
	EndIf;
	
	If WithoutAccountingAutoRecord Then
		FlagText = "";
	Else
		FlagText = NStr("en='with autoregistration sign';ru='с признаком авторегистрации'");
	EndIf;
	
	Presentation = "";
	For Each KeyValue IN MetadataPresentationsStructure Do
		If KeyValue.Key = MetaNameGroup Then
			IndexOf = StructureNameMetadata[MetaNameGroup].Find(MetaNameNode);
			Presentation = ?(IndexOf = Undefined, "", KeyValue.Value[IndexOf]);
			Break;
		EndIf;
	EndDo;
	
	Text = StrReplace(Text, "%1", FlagText);
	Text = StrReplace(Text, "%2", Lower(MetaNameGroup));
	Text = StrReplace(Text, "%3", Presentation);
	
	Return TrimAll(Text);
EndFunction

&AtServer
Function GetMetadataNamesCurrentRows(WithoutAccountingAutoRecord) 
	
	String = MetadataTree.FindByID(Items.MetadataTree.CurrentRow);
	If String = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("MetaNames, Definition", 
		New Array, GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord));
	MetaName = String.MetaFullName;
	If IsBlankString(MetaName) Then
		Result.MetaNames.Add(Undefined);	
	Else
		Result.MetaNames.Add(MetaName);	
		
		Parent = String.GetParent();
		MetaParentName = Parent.MetaFullName;
		If IsBlankString(MetaParentName) Then
			Result.Definition = GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord, String.Description);
		Else
			Result.Definition = GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord, MetaParentName, MetaName);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function GetSelectedMetadataNames(WithoutAccountingAutoRecord)
	
	Result = New Structure("MetaNames, Definition", 
		New Array, GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord));
	
	For Each Root IN MetadataTree.GetItems() Do
		
		If Root.Check = 1 Then
			Result.MetaNames.Add(Undefined);
			Return Result;
		EndIf;
		
		PartialNumber = 0;
		GroupCount     = 0;
		NodesNumber     = 0;
		For Each Group IN Root.GetItems() Do
			
			If Group.Check = 0 Then
				Continue;
			ElsIf Group.Check = 1 Then
				//	The whole group, look from where to select values.
				GroupCount = GroupCount + 1;
				GroupDetails = GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord, Group.Description);
				
				If Group.GetItems().Count() = 0 Then
					// Try from the metadata names structure, consider everything marked.
					PresentationArray = MetadataPresentationsStructure[Group.MetaFullName];
					ArrayAuto          = StructureAutoRecordMetadata[Group.MetaFullName];
					NameArray          = StructureNameMetadata[Group.MetaFullName];
					For IndexOf = 0 To NameArray.UBound() Do
						If WithoutAccountingAutoRecord Or ArrayAuto[IndexOf] = 2 Then
							Result.MetaNames.Add(NameArray[IndexOf]);
							NodeDescription = GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord, Group.MetaFullName, NameArray[IndexOf]);
						EndIf;
					EndDo;
					
					Continue;
				EndIf;
				
			Else
				PartialNumber = PartialNumber + 1;
			EndIf;
			
			For Each Node IN Group.GetItems() Do
				If Node.Check = 1 Then
					// Node.AutoRecord =2 -> allowed
					If WithoutAccountingAutoRecord Or Node.AutoRecord = 2 Then
						Result.MetaNames.Add(Node.MetaFullName);
						NodeDescription = GetDescriptionSelectedMetadata(WithoutAccountingAutoRecord, Group.MetaFullName, Node.MetaFullName);
						NodesNumber = NodesNumber + 1;
					EndIf;
				EndIf
			EndDo;
			
		EndDo;
		
		If GroupCount = 1 AND PartialNumber = 0 Then
			Result.Definition = GroupDetails;
		ElsIf GroupCount = 0 AND NodesNumber = 1 Then
			Result.Definition = NodeDescription;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function ReadNumberMessages()
	AttributesQuery = "SentNo, ReceivedNo";
	Data = ThisObject().GetNodExchangeParameters(ExchangeNodeRef, AttributesQuery);
	If Data = Undefined Then
		Return New Structure(AttributesQuery)
	EndIf;
	Return Data;
EndFunction

&AtServer
Procedure HandleProhibitionChangesNode()
	OperationsAllowed = Not ProhibitedToChooseExchangeNode;
	
	If OperationsAllowed Then
		Items.ExchangeNodeRef.Visible = True;
		Title = NStr("en='Registration of modifications for the data exchange';ru='Регистрация изменений для обмена данными'");
	Else
		Items.ExchangeNodeRef.Visible = False;
		Title = StrReplace(NStr("en='Changes registration for the exchange with ""%1""';ru='Регистрация изменений для обмена с ""%1""'"), "%1", String(ExchangeNodeRef));
	EndIf;
	
	Items.FormOpenFormRegistrationForNodes.Visible = OperationsAllowed;
	
	Items.ConstantsListContextMenuToOpenRegistrationFormAtNodes.Visible       = OperationsAllowed;
	Items.RefsListContextMenuToOpenRegistrationFormAtNodes.Visible         = OperationsAllowed;
	Items.ListOfSetsRecordsContextMenuOpenRegistrationFormAtNodes.Visible = OperationsAllowed;
EndProcedure

&AtServer
Function MonitorSettings()
	Result = True;
	
	// Check whether the node passed from a parameter of settings is allowed.
	CurrentObject = ThisObject();
	If ExchangeNodeRef <> Undefined AND ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef)) Then
		ValidExchangeNodes = CurrentObject.SetNodTree();
		PlanName = ExchangeNodeRef.Metadata().Name;
		If ValidExchangeNodes.Rows.Find(PlanName, "ExchangePlanName", True) = Undefined Then
			// Incorrect exchange plan node.
			ExchangeNodeRef = Undefined;
			Result = False;
		ElsIf ExchangeNodeRef = ExchangePlans[PlanName].ThisNode() Then
			// This node
			ExchangeNodeRef = Undefined;
			Result = False;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ExchangeNodeRef) Then
		ChoiceProcessingNodeExchange();
	EndIf;
	HandleProhibitionChangesNode();
	
	// Settings dependence
	SetFilterByMessageNumber(ConstantList,       VariantFilterMessagesByNumber);
	SetFilterByMessageNumber(RefsList,         VariantFilterMessagesByNumber);
	SetFilterByMessageNumber(ListOfSetsRecords, VariantFilterMessagesByNumber);
	
	Return Result;
EndFunction

&AtServer
Function StructureOfSetKeyRecords(Val CurrentData)
	
	Definition = ThisObject().MetadataCharacteristics(ListOfSetsRecordsTableName);
	
	If Definition = Undefined Then
		// Unknown source
		Return Undefined;
	EndIf;
	
	Result = New Structure("FormName, Parameter, Value");
	
	Dimensions = New Structure;
	KeyNames = ArrayOfKeyNamesOfRecordSet(ListOfSetsRecordsTableName);
	For Each Name IN KeyNames Do
		Dimensions.Insert(Name, CurrentData["ListOfSetsRecords" + Name]);
	EndDo;
	
	If Dimensions.Property("Recorder") Then
		MetaOfRegistrar = Metadata.FindByType(TypeOf(Dimensions.Recorder));
		If MetaOfRegistrar = Undefined Then
			Result = Undefined;
		Else
			Result.FormName = MetaOfRegistrar.FullName() + ".ObjectForm";
			Result.Parameter = "Key";
			Result.Value = Dimensions.Recorder;
		EndIf;
		
	ElsIf Dimensions.Count() = 0 Then
		// Degenerated records set
		Result.FormName = ListOfSetsRecordsTableName + ".ListForm";
		
	Else
		Set = Definition.Manager.CreateRecordSet();
		For Each KeyValue IN Dimensions Do
			Set.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		Set.Read();
		If Set.Count() = 1 Then
			// Single item
			Result.FormName = ListOfSetsRecordsTableName + ".RecordForm";
			Result.Parameter = "Key";
			
			Key = New Structure;
			For Each RequestColumn IN Set.Unload().Columns Do
				ColumnName = RequestColumn.Name;
				Key.Insert(ColumnName, Set[0][ColumnName]);
			EndDo;
			Result.Value = Definition.Manager.CreateRecordKey(Key);
		Else
			// List
			Result.FormName = ListOfSetsRecordsTableName + ".ListForm";
			Result.Parameter = "Filter";
			Result.Value = Dimensions;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function ValidateVersionAndPlatformCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		AND (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_3"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_4"]))) Then
		
		Raise NStr("en='Data processor is designed to start
		|on the 1C:Enterprise 8.3.5 platform version with the disabled compatibility mode or higher';ru='Обработка предназначена для
		|запуска на версии платформы 1С:Предприятие 8.3.5 с отключенным режимом совместимости или выше'");
		
	EndIf;
	
EndFunction

&AtServer
Function RegisterIOMAndPredeterminedOnServer()
	
	CurrentObject = ThisObject();
	Return CurrentObject.SSL_RefreshAndRegisterHostIOM(ExchangeNodeRef);
	
EndFunction


#EndRegion














