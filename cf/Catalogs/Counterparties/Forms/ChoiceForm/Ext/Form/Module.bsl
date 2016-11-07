
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ContactsClassification.RefreshPeriodsFilterValues(ThisForm);
	ContactsClassification.RefreshTagFilterValues(ThisForm);
	ContactsClassification.RefreshSegmentsFilterValues(ThisForm);
	
	SetVisibleAndEnabled();
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterWriteTag" Or EventName = "AfterSegmentWriting" Then
		RefreshSelectionValuesPanelServer(EventName);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - event handler OnChange field FulltextSearchString.
//
&AtClient
Procedure FullTextSearchStringOnChange(Item)
	
	RunSearch();
	
EndProcedure // FullTextSearchStringOnChange()

// Procedure - event handler Click inscription SelectionBasis.
//
&AtClient
Procedure BasisSelectClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	Basis = Bases.FindRows(New Structure("Counterparty", Items.List.CurrentRow));
	If Basis.Count() > 0 Then
		ShowValue(Undefined,Basis[0].Ref);
	EndIf;
	
EndProcedure // SelectionBasisClick()

// Procedure - handler of the OnActivateRow list events.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined
		AND Item.CurrentData.Property("IsFolder")
		AND Not Item.CurrentData.IsFolder Then
		
		AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
		
	EndIf;
	
EndProcedure // ListOnActivateRow()

// Procedure - handler of clicking the SendEmailToCounterparty button.
//
&AtClient
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(CounterpartyInformationES) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Ref);
		StructureRecipient.Insert("Address", CounterpartyInformationES);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToCounterparty()

// Procedure - handler of clicking the SendEmailToContactPerson button.
//
&AtClient
Procedure SendEmailToContactPerson(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ContactPersonESInformation) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.ContactPerson);
		StructureRecipient.Insert("Address", ContactPersonESInformation);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure // SendEmailToContactPerson()

&AtClient
Procedure FilterCreatedTodayClick(Item)
	
	Check = ContactsClassificationClient.CreatedFilterClick(ThisForm, "List", "Today", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOver3DaysClick(Item)
	
	Check = ContactsClassificationClient.CreatedFilterClick(ThisForm, "List", "3Days", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOverWeekClick(Item)
	
	Check = ContactsClassificationClient.CreatedFilterClick(ThisForm, "List", "Week", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOverMonthClick(Item)
	
	Check = ContactsClassificationClient.CreatedFilterClick(ThisForm, "List", "Month", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOnChange(Item)
	
	Check = ContactsClassificationClient.CreatedFilterClick(ThisForm, "List", "Custom", Item);
	
EndProcedure

&AtClient
Procedure Attachable_TagFilterClick(Item, StandardProcessing)
	
	Check = ContactsClassificationClient.TagFilterClick(ThisForm, "List", Item, StandardProcessing);
	If Not Check = Undefined Then
		ChangeServerElementColor(Check, Item.Name);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SegmentFilterClick(Item, StandardProcessing)
	
	Check = ContactsClassificationClient.SegmentFilterClick(ThisForm, "List", Item, StandardProcessing);
	If Not Check = Undefined Then
		ChangeServerElementColor(Check, Item.Name);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - click handler on the hyperlink DocumentsByCounterparty.
//
&AtClient
Procedure OpenDocumentsOnCounterparty(Command)
	
	CurrentDataOfList = Items.List.CurrentData;
	If CurrentDataOfList = Undefined OR CurrentDataOfList.IsFolder Then
		WarningText = NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'");
		ShowMessageBox(Undefined,WarningText);
		Return;
	EndIf;
	
	FilterStructure = New Structure("Counterparty", CurrentDataOfList.Ref);
	FormParameters = New Structure("SettingKey, Filter, GenerateOnOpen, OpeningMode", "Counterparty", FilterStructure, True, FormWindowOpeningMode.LockOwnerWindow);
	
	OpenForm("DataProcessor.DocumentsByCounterparty.Form.DocumentsByCounterparty", FormParameters, ThisForm);
	
EndProcedure // OpenDocumentsByCounterparty()

// Procedure - click handler on the hyperlink Events.
//
&AtClient
Procedure OpenEventsByCounterparty(Command)
	
	CurrentDataOfList = Items.List.CurrentData;
	If CurrentDataOfList = Undefined OR CurrentDataOfList.IsFolder Then
		WarningText = NStr("en='Command can not be executed for the specified object';ru='Команда не может быть выполнена для указанного объекта!'");
		ShowMessageBox(Undefined,WarningText);
		Return;
	EndIf;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Counterparty", CurrentDataOfList.Ref);
	
	FormParameters = New Structure("InformationPanel", FilterStructure);
	FormParameters.Insert("OpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	
	OpenForm("Document.Event.ListForm", FormParameters, ThisForm);
	
EndProcedure // OpenEventsByCounterparty()

&AtClient
Procedure FilterPeriod(Command)
	
	ContactsClassificationClient.SelectFilterVariant(ThisForm, Command);
	
EndProcedure

&AtClient
Procedure FilterTags(Command)
	
	ContactsClassificationClient.SelectFilterVariant(ThisForm, Command);
	
EndProcedure

&AtClient
Procedure FilterSegments(Command)
	
	ContactsClassificationClient.SelectFilterVariant(ThisForm, Command);
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure of the list string activation processing.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	If UseFullTextSearch Then
		If SmallBusinessClient.PositioningIsCorrect(ThisForm) AND AdvancedSearch Then
			SmallBusinessClient.FillBasisRow(ThisForm);
			Items.ChoiceBasis.Visible = True;
		Else
			ChoiceBasis = "";
			Items.ChoiceBasis.Visible = False;
		EndIf;
	EndIf;
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Ref");
	SmallBusinessClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
EndProcedure // HandleListStringActivation()

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	UseFullTextSearch = GetFunctionalOption("UseFullTextSearch");
	If UseFullTextSearch Then
		
		AdvancedSearch = False;
		FileInfobase = CommonUse.FileInfobase();
		FulltextSearchIndexActual = FullTextSearchServer.SearchIndexTrue();
		SmallBusinessServer.Import("FindHistoryOfCounterparties", Items.FulltextSearchString.ChoiceList);
		
		Items.SearchVariants.CurrentPage = Items.FulltextSearchGroup;
		
	Else
		
		Items.SearchVariants.CurrentPage = Items.StandardSearchGroup;
		
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

&AtServer
Procedure ChangeServerElementColor(Check, ItemName)
	
	ContactsClassification.ChangeSelectionItemColor(ThisForm, Check, ItemName);
	
EndProcedure

&AtServer
Procedure RefreshSelectionValuesPanelServer(EventName)
	
	If EventName = "AfterWriteTag" Then
		ContactsClassification.RefreshTagFilterValues(ThisForm);
	ElsIf EventName = "AfterSegmentWriting" Then
		ContactsClassification.RefreshSegmentsFilterValues(ThisForm);
	EndIf;
	
EndProcedure

#EndRegion

#Region FullTextSearch

// Procedure executes the index and fulltext search relevance check of counterparties.
//
&AtClient
Procedure RunSearch()
	
	// We will remember display mode before search application
	If Not AdvancedSearch Then
		ViewModeBeforeFulltextSearchApplying = String(Items.List.Representation);
	EndIf;
	
	// If the search string is filled execute search
	If Not IsBlankString(FulltextSearchString) Then
		
		CheckIndexOfFullTextSearch();
		
	Else // Clear search
		
		// Restore the list
		AdvancedSearch = False;
		SmallBusinessClient.RecoverListDisplayingAfterFulltextSearch(ThisForm);
		
		// Delete filters by search
		CommonUseClientServer.SetFilterItem(List.Filter, "Search", Undefined, DataCompositionComparisonType.Equal,,False);
		ChoiceBasis = "";
		Items.ChoiceBasis.Visible = False;
		
	EndIf;
	
EndProcedure // ExecuteSearch()

// Procedure executes relevance check of the fulltext search index.
//
&AtClient
Procedure CheckIndexOfFullTextSearch()
	
	If Not FulltextSearchIndexActual AND FileInfobase Then
		
		// If index is updated less than 2 hours ago then update automatically
		If SmallBusinessServer.SearchIndexUpdateAutomatically() Then
			RefreshFullTextSearchIndex();
		Else
			Notification = New NotifyDescription("CheckIndexFullTextSearchEnd",ThisForm);
			ShowQueryBox(Notification,NStr("en='Full text search index is irrelevant. Update index?';ru='Индекс полнотекстового поиска неактуален. Обновить индекс?'"), QuestionDialogMode.YesNo);
		EndIf;
		
		Return;
		
	EndIf;
	
	ExecuteFullTextSearch();
	
EndProcedure // CheckIndexOfFullTextSearch()

&AtClient
Procedure CheckIndexFullTextSearchEnd(Result,Parameters) Export
	
	If Result = DialogReturnCode.Yes Then
		AttachIdleHandler("RefreshFullTextSearchIndex", 0.2, True);
	EndIf;
	
EndProcedure

// Procedure updates the indexes of fulltext search.
//
&AtClient
Procedure RefreshFullTextSearchIndex()
	
	Status(NStr("en='Full text search index is updating...';ru='Идет обновление индекса полнотекстового поиска...'"));
	SmallBusinessServer.RefreshFullTextSearchIndex();
	FulltextSearchIndexActual = True;
	Status(NStr("en='Updating of the full text search index is completed...';ru='Обновление индекса полнотекстового поиска завершено...'"));
	
	ExecuteFullTextSearch();
	
EndProcedure // UpdatehFullTextSearchIndex()

// Procedure executes a fulltext counterparty search.
//
&AtClient
Procedure ExecuteFullTextSearch()
	
	AdvancedSearch = True;
	ErrorText = FindCounterpartiesFulltextSearch();
	If ErrorText = Undefined Then
		
		SmallBusinessClient.FillBasisRow(ThisForm);
		Items.ChoiceBasis.Visible = True;
		
	ElsIf ErrorText = NStr("en='Nothing found';ru='Ничего не найдено'") Then
		
		ChoiceBasis = NStr("en='No counterparties have been found';ru='Не найдено ни одного контрагента'");
		Items.ChoiceBasis.Visible = True;
		
	Else
		
		ShowUserNotification(ErrorText);
		
	EndIf;
	
EndProcedure // ExecuteFullTextSearch()

// Function returns full text search result.
//
&AtServer
Function FindCounterpartiesFulltextSearch()
	
	Return SmallBusinessServer.FindCounterpartiesFulltextSearch(ThisForm);
	
EndFunction // FindCounterpartiesFulltextSearch()

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
