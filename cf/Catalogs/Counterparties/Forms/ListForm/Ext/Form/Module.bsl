
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Parameters.AdditionalParameters.Property("OperationKind") Then
		Relationship = ContactsClassification.CounterpartyRelationshipTypeByOperationKind(Parameters.AdditionalParameters.OperationKind);
		FilterCustomer			= Relationship.Customer;
		FilterSupplier			= Relationship.Supplier;
		FilterOtherRelationship	= Relationship.OtherRelationship;
	EndIf;
	
	If Parameters.Filter.Property("Customer") Then
		FilterCustomer = Parameters.Filter.Customer;
		Parameters.Filter.Delete("Customer");
	EndIf;
	
	If Parameters.Filter.Property("Supplier") Then
		FilterSupplier = Parameters.Filter.Supplier;
		Parameters.Filter.Delete("Supplier");
	EndIf;
	
	If Parameters.Filter.Property("OtherRelationship") Then
		FilterOtherRelationship = Parameters.Filter.OtherRelationship;
		Parameters.Filter.Delete("OtherRelationship");
	EndIf;
	
	SetFilterBusinessRelationship(ThisObject, "Customer",			FilterCustomer);
	SetFilterBusinessRelationship(ThisObject, "Supplier",			FilterSupplier);
	SetFilterBusinessRelationship(ThisObject, "OtherRelationship",	FilterOtherRelationship);
	SetFormTitle(ThisObject);
	
	ReadHierarchy();
	
	// Establish the form settings for the case of the opening in choice mode
	Items.List.ChoiceMode		= Parameters.ChoiceMode;
	Items.List.MultipleChoice	= ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		PurposeUseKey = "List";
	EndIf;
	
	Items.FilterHierarchyContextMenuIncludingNested.Check = CommonUse.FormDataSettingsStorageImport(
		FormName,
		"IncludingNested",
		False
	);
	
	// SB.ListFilter
	FormFilterOption = FilterOptionForSetting();
	WorkWithFilters.RestoreFilterSettings(ThisObject, List,,,New Structure("FilterPeriod", "CreationDate"), FormFilterOption);
	// End SB.ListFilter
	
	// SB.ContactInformationPanel
	ContactInformationPanelSB.OnCreateAtServer(ThisObject, "ContactInformation");
	// End SB.ContactInformationPanel
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.Counterparties, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.GroupObjectsChanging
	CanEdit = AccessRight("Edit", Metadata.Catalogs.Counterparties);
	Items.ListBatchObjectChanging.Visible = CanEdit;
	// End StandardSubsystems.GroupObjectsChanging
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.SubmenuPrint);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtClient
Procedure OnClose()
	
	//SB.ListFilter
	SaveFilterSettings();
	//End SB.ListFilter

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_CounterpartyGroup" Then
		
		ReadHierarchy();
		
	EndIf;
	
	// SB.ContactInformationPanel
	If ContactInformationPanelSBClient.ProcessNotifications(ThisObject, EventName, Parameter) Then
		RefreshContactInformationPanelServer();
	EndIf;
	// End SB.ContactInformationPanel
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure FilterCustomerOnChange(Item)
	
	SetFilterBusinessRelationship(ThisObject, "Customer", FilterCustomer);
	SetFormTitle(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterSupplierOnChange(Item)
	
	SetFilterBusinessRelationship(ThisObject, "Supplier", FilterSupplier);
	SetFormTitle(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterOtherRelationshipOnChange(Item)
	
	SetFilterBusinessRelationship(ThisObject, "OtherRelationship", FilterOtherRelationship);
	SetFormTitle(ThisObject);
	
EndProcedure

&AtClient
Procedure PeriodPresentationClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	WorkWithFiltersClient.PeriodPresentationSelectPeriod(ThisObject, "List", "CreationDate");
	
EndProcedure

&AtClient
Procedure FilterTagChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Tags.Tag", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure FilterSegmentChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	SetFilterBySegmentsAtServer(SelectedValue);
	
EndProcedure

&AtClient
Procedure FilterResponsibleChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	SetLabelAndListFilter("Responsible", Item.Parent.Name, SelectedValue);
	SelectedValue = Undefined;
	
EndProcedure

&AtClient
Procedure CollapseExpandFiltesPanelClick(Item)
	
	NewValueVisible = Not Items.FilterSettingsAndAddInfo.Visible;
	WorkWithFiltersClient.CollapseExpandFiltesPanel(ThisObject, NewValueVisible);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableList

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Item.CurrentRow) <> Type("DynamicalListGroupRow") Then
		
		CounterpartyCurrentRow = ?(Item.CurrentData = Undefined, Undefined, Item.CurrentData.Ref);
		If CounterpartyCurrentRow <> CurrentCounterparty Then
		
			CurrentCounterparty = CounterpartyCurrentRow;
			AttachIdleHandler("HandleActivateListRow", 0.2, True);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Not Folder Then
		KeyOperation = "FormCreatingCounterparties";
		PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	EndIf;

	If Not Clone And Not Folder Then
		
		Cancel = False;
		
		FillingValues = New Structure;
		FillingValues.Insert("Customer",			FilterCustomer);
		FillingValues.Insert("Supplier",			FilterSupplier);
		FillingValues.Insert("OtherRelationship",	FilterOtherRelationship);
		
		FiltersByParent = CommonUseClientServer.FindFilterItemsAndGroups(List.Filter, "Parent");
		If FiltersByParent.Count() > 0
			And FiltersByParent[0].Use
			And ValueIsFilled(FiltersByParent[0].RightValue) Then
			
			FillingValues.Insert("Parent",	FiltersByParent[0].RightValue);
		EndIf;
		
		FormParameters = New Structure;
		FormParameters.Insert("FillingValues", FillingValues);
		
		OpenForm("Catalog.Counterparties.ObjectForm", FormParameters, Item);
		
	EndIf;

EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	//If Not Item.CurrentData.IsFolder Then
	//	KeyOperation = "FormOpeningCounterparties";
	//	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	//EndIf;
	
EndProcedure

&AtClient
Procedure ListNewWriteProcessing(NewObject, Source, StandardProcessing)
	
	CurrentItem = Items.List;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableFilterHierarchy

&AtClient
Procedure FilterHierarchyOnActivateRow(Item)
	
	SetFilterByHierarchy(ThisObject);
	
EndProcedure

&AtClient
Procedure FilterHierarchyDragStart(Item, DragParameters, Perform)
	
	If Item.CurrentRow = Undefined Then
		Executing = False;
		Return;
	EndIf;
	
	HierarchyRow = FilterHierarchy.FindByID(Item.CurrentRow);
	If HierarchyRow = Undefined
		Or HierarchyRow.CounterpartyGroup = "All"
		Or HierarchyRow.CounterpartyGroup = "WithoutGroup" Then
		
		Executing = False;
		Return;
	EndIf;
	
	DragParameters.Value = CommonUseClientServer.ValueInArray(HierarchyRow.CounterpartyGroup);
	
EndProcedure

&AtClient
Procedure FilterHierarchyDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If Row = Undefined Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	HierarchyRow = FilterHierarchy.FindByID(Row);
	If HierarchyRow = Undefined Or HierarchyRow.CounterpartyGroup = "All" Then
		DragParameters.Action = DragAction.Cancel;
		Return;
	EndIf;
	
	DragParameters.AllowedActions	= DragAllowedActions.Move;
	DragParameters.Action			= DragAction.Move;
	
EndProcedure

&AtClient
Procedure FilterHierarchyDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) <> Type("Array")
		Or DragParameters.Value.Count() = 0
		Or TypeOf(DragParameters.Value[0]) <> Type("CatalogRef.Counterparties")Then
		
		Return;
	EndIf;
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	HierarchyRow = FilterHierarchy.FindByID(Row);
	If HierarchyRow = Undefined Or HierarchyRow.CounterpartyGroup = "All" Then
		Return;
	EndIf;
	
	NewGroup = ?(HierarchyRow.CounterpartyGroup = "WithoutGroup", PredefinedValue("Catalog.Counterparties.EmptyRef"), HierarchyRow.CounterpartyGroup);
	HierarchyDragServer(DragParameters.Value, NewGroup);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SMS(Command)
	
	If Items.List.CurrentData <> Undefined And ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("SMS", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure PersonalMeeting(Command)
	
	If Items.List.CurrentData <> Undefined And ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("PersonalMeeting", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure Other(Command)
	
	If Items.List.CurrentData <> Undefined And ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("Other", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure PhoneCall(Command)
	
	If Items.List.CurrentData <> Undefined And ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("PhoneCall", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure Email(Command)
	
	If Items.List.CurrentData <> Undefined And ValueIsFilled(Items.List.CurrentData.Ref) Then
		CreateEventByCounterparty("Email", Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure HierarchyChange(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined
		Or TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) <> Type("CatalogRef.Counterparties")
		Or Not ValueIsFilled(Items.FilterHierarchy.CurrentData.CounterpartyGroup) Then
		
		Return;
	EndIf;
	
	ShowValue(Undefined, Items.FilterHierarchy.CurrentData.CounterpartyGroup);
	
EndProcedure

&AtClient
Procedure HierarchyCreateGroup(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillingValues = New Structure;
	If TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) = Type("CatalogRef.Counterparties") Then
		FillingValues.Insert("Parent", Items.FilterHierarchy.CurrentData.CounterpartyGroup);
	EndIf;
	
	OpenForm("Catalog.Counterparties.FolderForm",
		New Structure("FillingValues, IsFolder", FillingValues, True),
		Items.List);
	
EndProcedure

&AtClient
Procedure HierarchyCopy(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined
		Or TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) <> Type("CatalogRef.Counterparties")
		Or Not ValueIsFilled(Items.FilterHierarchy.CurrentData.CounterpartyGroup) Then
		
		Return;
	EndIf;
	
	OpenForm("Catalog.Counterparties.FolderForm",
		New Structure("CopyingValue, IsFolder", Items.FilterHierarchy.CurrentData.CounterpartyGroup, True),
		Items.List);
	
EndProcedure

&AtClient
Procedure HierarchySetDeletionMark(Command)
	
	If Items.FilterHierarchy.CurrentData = Undefined
		Or TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) <> Type("CatalogRef.Counterparties")
		Or Not ValueIsFilled(Items.FilterHierarchy.CurrentData.CounterpartyGroup) Then
		
		Return;
	EndIf;
	
	DeletionMark = ChangeGroupDeletionMarkServer(Items.FilterHierarchy.CurrentData.GetID());
	
	NotificationText = StrTemplate(NStr("ru='Пометка удаления %1'; en = 'Deletion mark %1'"),
		?(DeletionMark, NStr("ru='установлена'; en = 'is set'"), NStr("ru='снята'; en = 'is removed'")));
		
	ShowUserNotification(
		NotificationText,
		GetURL(Items.FilterHierarchy.CurrentData.CounterpartyGroup),
		Items.FilterHierarchy.CurrentData.CounterpartyGroup,
		PictureLib.Information32);
		
	Items.List.Refresh();;
	
EndProcedure

&AtClient
Procedure HierarchyIncludingNested(Command)
	
	Items.FilterHierarchyContextMenuIncludingNested.Check = Not Items.FilterHierarchyContextMenuIncludingNested.Check;
	SetFilterByHierarchy(ThisObject);
	
EndProcedure

#EndRegion

#Region Hierarchy

&AtServer
Procedure ReadHierarchy()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CASE
		|		WHEN Counterparties.DeletionMark
		|			THEN 1
		|		ELSE 0
		|	END AS IconIndex,
		|	Counterparties.Ref AS CounterpartyGroup,
		|	PRESENTATION(Counterparties.Ref) AS GroupPresentation
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.IsFolder = TRUE
		|
		|ORDER BY
		|	Counterparties.Ref HIERARCHY
		|AUTOORDER";
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	ValueToFormAttribute(Tree, "FilterHierarchy");
	
	CollectionItems = FilterHierarchy.GetItems();
	
	TreeRow = CollectionItems.Insert(0);
	TreeRow.IconIndex			= -1;
	TreeRow.CounterpartyGroup	= "All";
	TreeRow.GroupPresentation	= NStr("ru='<Все группы>'; en = '<All groups>'");
	
	TreeRow = CollectionItems.Add();
	TreeRow.IconIndex			= -1;
	TreeRow.CounterpartyGroup	= "WithoutGroup";
	TreeRow.GroupPresentation	= NStr("ru='<Нет группы>'; en = '<No group>'");
	
EndProcedure
	
&AtClientAtServerNoContext
Procedure SetFilterByHierarchy(Form)
	
	Items = Form.Items;
	If Items.FilterHierarchy.CurrentData = Undefined Then
		Return;
	EndIf;
	
	IsFilterByGroup = TypeOf(Items.FilterHierarchy.CurrentData.CounterpartyGroup) = Type("CatalogRef.Counterparties");
	
	Items.FilterHierarchyContextMenuHierarchyChange.Enabled				= IsFilterByGroup;
	Items.FilterHierarchyContextMenuHierarchyCopy.Enabled				= IsFilterByGroup;
	Items.FilterHierarchyContextMenuHierarchySetDeletionMark.Enabled	= IsFilterByGroup;
	
	RightValue	= Undefined;
	Compare		= DataCompositionComparisonType.Equal;
	Use			= True;
	
	If IsFilterByGroup Then
		
		If Items.FilterHierarchyContextMenuIncludingNested.Check Then
			Compare = DataCompositionComparisonType.InHierarchy;
		EndIf;
		RightValue = Items.FilterHierarchy.CurrentData.CounterpartyGroup;
		
	ElsIf Items.FilterHierarchy.CurrentData.CounterpartyGroup = "All" Then
		
		Use = False;
		
	ElsIf Items.FilterHierarchy.CurrentData.CounterpartyGroup = "WithoutGroup" Then
		
		RightValue = PredefinedValue("Catalog.Counterparties.EmptyRef");
		
	EndIf;
	
	CommonUseClientServer.SetFilterDynamicListItem(
		Form.List,
		"Parent",
		RightValue,
		Compare,
		,
		Use
	);
	
EndProcedure

&AtServerNoContext
Function ChangeDeletionMark(Counterparty)
	
	CounterpartyObject = Counterparty.GetObject();
	CounterpartyObject.SetDeletionMark(Not CounterpartyObject.DeletionMark, True);
	
	Return CounterpartyObject.DeletionMark;
	
EndFunction

&AtServer
Function  ChangeGroupDeletionMarkServer(CurrentRowID)
	
	CurrentTreeRow = FilterHierarchy.FindByID(CurrentRowID);
	DeletionMark = ChangeDeletionMark(CurrentTreeRow.CounterpartyGroup);
	ChangeIconRecursively(CurrentTreeRow, DeletionMark);
	
	Return DeletionMark;
	
EndFunction

&AtServer
Procedure ChangeIconRecursively(TreeRow, DeletionMark)
	
	TreeRow.IconIndex = ?(DeletionMark, 1, 0);
	
	TreeRows = TreeRow.GetItems();
	For Each ChildRow In TreeRows Do
		ChangeIconRecursively(ChildRow, DeletionMark);
	EndDo;
	
EndProcedure

&AtServer
Процедура HierarchyDragServer(CounterpartiesArray, NewGroup)
	
	SetNewCounterpartiesGroup(CounterpartiesArray, NewGroup);
	
	If CounterpartiesArray[0].IsFolder Then
		
		ReadHierarchy();
		
		RowID = 0;
		CommonUseClientServer.GetTreeRowIDByFieldValue(
			"CounterpartyGroup",
			RowID,
			FilterHierarchy.GetItems(),
			CounterpartiesArray[0],
			False
		);
		Items.FilterHierarchy.CurrentRow = RowID;
		
	Else
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure SetNewCounterpartiesGroup(CounterpartiesArray, NewGroup)
	
	For Each Counterparty In CounterpartiesArray Do
		CounterpartyObject = Counterparty.GetObject();
		CounterpartyObject.Parent = NewGroup;
		CounterpartyObject.Write();
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure HandleActivateListRow()
	
	RefreshContactInformationPanelServer();
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFilterBusinessRelationship(Form, FieldName, Use)
	
	NumberChanged = CommonUseClientServer.ChangeFilterItems(
		Form.List.SettingsComposer.FixedSettings.Filter,
		FieldName,
		,
		True,
		DataCompositionComparisonType.Equal,
		Use,
		DataCompositionSettingsItemViewMode.Inaccessible);
		
	If NumberChanged = 0 Then
		
		GroupBusinessRelationship = CommonUseClientServer.FindFilterItemByPresentation(
			Form.List.SettingsComposer.FixedSettings.Filter.Items, "BusinessRelationship");
		
		If GroupBusinessRelationship = Undefined Then
			GroupBusinessRelationship = CommonUseClientServer.CreateGroupOfFilterItems(
				Form.List.SettingsComposer.FixedSettings.Filter.Items,
				"BusinessRelationship",
				DataCompositionFilterItemsGroupType.OrGroup);
		EndIf;
		
		CommonUseClientServer.AddCompositionItem(
			GroupBusinessRelationship,
			FieldName,
			DataCompositionComparisonType.Equal,
			True,
			,
			Use,
			DataCompositionSettingsItemViewMode.Inaccessible);
			
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetFormTitle(Form)
	
	RelationshipKinds = New Array;
	
	If Form.FilterCustomer Then
		RelationshipKinds.Add(NStr("ru='Покупатели'; en = 'Customers'"));
	EndIf;
	
	If Form.FilterSupplier Then
		RelationshipKinds.Add(NStr("ru='Поставщики'; en = 'Suppliers'"));
	EndIf;
	
	If Form.FilterOtherRelationship Then
		RelationshipKinds.Add(NStr("ru='Прочие отношения'; en = 'Other relationship'"));
	EndIf;
	
	If RelationshipKinds.Count() > 0 Then
		Title	= "";
		For Each Kind In RelationshipKinds Do
			Title = Title + Kind + ", ";
		EndDo;
		StringFunctionsClientServer.DeleteLatestCharInRow(Title, 2);
	Else
		Title = NStr("en='Counterparties';ru='Контрагенты'");
	EndIf;
	
	Form.Title = Title;
	
EndProcedure

&AtServerNoContext
Function SegmentCounterparties(Segment)
	
	SegmentCounterparties = New Array;
	
	SegmentContent = Catalogs.Segments.GetSegmentComposition(Segment);
	CommonUseClientServer.SupplementArray(SegmentCounterparties, SegmentContent, True);
	
	Return SegmentCounterparties;

EndFunction

&AtClient
Procedure CreateEventByCounterparty(EventTypeName, Counterparty)
	
	FillingValues = New Structure;
	FillingValues.Insert("EventType", PredefinedValue("Enum.EventTypes." + EventTypeName));
	FillingValues.Insert("Counterparty", Counterparty);
	
	FormParameters = New Structure;
	FormParameters.Insert("FillingValues", FillingValues);
	
	OpenForm("Document.Event.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

#EndRegion

#Region ContactInformationPanel

&AtServer
Procedure RefreshContactInformationPanelServer()
	
	ContactInformationPanelSB.RefreshPanelData(ThisObject, CurrentCounterparty);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataSelection(Item, SelectedRow, Field, StandardProcessing)
	
	ContactInformationPanelSBClient.ContactInformationPanelDataSelection(ThisObject, Item, SelectedRow, Field, StandardProcessing);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataOnActivateRow(Item)
	
	ContactInformationPanelSBClient.ContactInformationPanelDataOnActivateRow(ThisObject, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ContactInformationPanelDataExecuteCommand(Command)
	
	ContactInformationPanelSBClient.ExecuteCommand(ThisObject, Command);
	
EndProcedure

#EndRegion

#Region FilterLabel

&AtServer
Procedure SetFilterBySegmentsAtServer(SelectedValue)
	
	GroupName = Items.FilterSegment.Parent.Name;
	
	SegmentCounterparties = SegmentCounterparties(SelectedValue);
	SetLabelAndListFilter("Ref", GroupName, SegmentCounterparties, String(SelectedValue));
	SelectedValue = Undefined;
	
EndProcedure

&AtServer
Procedure SetLabelAndListFilter(ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation="")
	
	If ValuePresentation="" Then
		ValuePresentation=String(SelectedValue);
	EndIf; 
	
	WorkWithFilters.AttachFilterLabel(ThisObject, ListFilterFieldName, GroupLabelParent, SelectedValue, ValuePresentation);
	WorkWithFilters.SetListFilter(ThisObject, List, ListFilterFieldName,,True);
	
EndProcedure

&AtClient
Procedure Attachable_LabelURLProcessing(Item, URLFS, StandardProcessing)
	
	StandardProcessing = False;
	
	LabelID = Mid(Item.Name, StrLen("Label_")+1);
	DeleteFilterLabel(LabelID);
	
EndProcedure

&AtServer
Procedure DeleteFilterLabel(LabelID)
	
	WorkWithFilters.DeleteFilterLabelServer(ThisObject, List, LabelID);

EndProcedure

&AtServer
Function FilterOptionForSetting()
	
	If FilterCustomer And Not FilterSupplier Then
		FormFiltersOption = "Customers";
	ElsIf Not FilterCustomer And FilterSupplier Then
		FormFiltersOption = "Suppliers";
	Else
		FormFiltersOption = "";
	EndIf; 

	Return FormFiltersOption;
	
EndFunction

&AtServer
Procedure SaveFilterSettings()
	
	FormFiltersOption = FilterOptionForSetting();
	WorkWithFilters.SaveFilterSettings(ThisObject,,,FormFiltersOption);
	
	CommonUse.FormDataSettingsStorageSave(
		FormName,
		"IncludingNested",
		Items.FilterHierarchyContextMenuIncludingNested.Check
	);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TemplateNameWithTemplate", "LoadFromFile");
	DataLoadSettings.Insert("SelectionRowDescription", New Structure("FullMetadataObjectName, Type", "Counterparties", "AppliedImport"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		If ImportResult.ActionsDetails = "ChangeDataImportFromExternalSourcesMethod" Then
		
			DataImportFromExternalSources.ChangeDataImportFromExternalSourcesMethod(DataLoadSettings.DataImportFormNameFromExternalSources);
			
			NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
			DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
			
		ElsIf ImportResult.ActionsDetails = "ProcessPreparedData" Then
			
			ProcessPreparedData(ImportResult);
			Items.List.Refresh();
			ShowMessageBox(,NStr("en='Data import is complete.';ru='Загрузка данных завершена.'"));
			
		EndIf;
		
	ElsIf ImportResult = Undefined Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	Try
		
		BeginTransaction();
		
		UpdateExisting = ImportResult.DataLoadSettings.UpdateExisting;
		CreateIfNotMatched = ImportResult.DataLoadSettings.CreateIfNotMatched;
		DataMatchingTable = ImportResult.DataMatchingTable;
		For Each TableRow IN DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			
			CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
			
			If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
				
				If TableRow._RowMatched Then
					
					CatalogItem = TableRow.Counterparty.GetObject();
					
				Else
					
					CatalogItem = Catalogs.Counterparties.CreateItem();
					CatalogItem.Parent = TableRow.Parent;
					
				EndIf;
				
				CatalogItem.Description = TableRow.CounterpartyDescription;
				CatalogItem.DescriptionFull = TableRow.CounterpartyDescription;
				FillPropertyValues(CatalogItem, TableRow, , "Parent");
				
				CatalogItem.LegalEntityIndividual = ?(TableRow.ThisIsInd, Enums.CounterpartyKinds.Individual, Enums.CounterpartyKinds.LegalEntity);
				
				If Not IsBlankString(TableRow.TIN_KPP) Then
					
					Separators = New Array;
					Separators.Add("/");
					Separators.Add("\");
					Separators.Add("-");
					Separators.Add("|");
					
					TIN = "";
					
					For Each SeparatorValue IN Separators Do
						
						SeparatorPosition = Find(TableRow.TIN_KPP, SeparatorValue);
						If SeparatorPosition = 0 Then 
							
							Continue;
							
						EndIf;
						
						TIN = Left(TableRow.TIN_KPP, SeparatorPosition - 1);
						
					EndDo;
					
					If IsBlankString(TIN) Then
						
						TIN = TableRow.TIN_KPP;
						
					EndIf;
					
					CatalogItem.TIN = TIN;
					
				EndIf;
				
				If Not IsBlankString(TableRow.Phone) Then
					
					PhoneStructure = New Structure("Presentation, Comment", TableRow.Phone, NStr("en='Imported from external source';ru='Загружено из внешнего источника'"));
					ContactInformationManagement.FillContactInformationObject(CatalogItem, Catalogs.ContactInformationKinds.CounterpartyPhone, PhoneStructure);
					
				EndIf;
				
				If Not IsBlankString(TableRow.EMail_Address) Then
					
					StructureEmail = New Structure("Presentation", TableRow.EMail_Address);
					ContactInformationManagement.FillContactInformationObject(CatalogItem, Catalogs.ContactInformationKinds.CounterpartyEmail, StructureEmail);
					
				EndIf;
				
				CatalogItem.Write();
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import';ru='Загрузка данных'"), EventLogLevel.Error, Metadata.Catalogs.Counterparties, , ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

&AtClient
Procedure ChangeSelected(Command)
	
	GroupObjectsChangeClient.ChangeSelected(Items.List);
	
EndProcedure

#EndRegion
