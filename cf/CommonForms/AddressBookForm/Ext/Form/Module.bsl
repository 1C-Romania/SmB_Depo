
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not IsBlankString(Parameters.CIType) Then
		TypeArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Parameters.CIType, ",", , True);
		For Each TypeName IN TypeArray Do
			If Upper(TypeName) = Upper("EmailAddress") Then
				CITypes.Add(Enums.ContactInformationTypes.EmailAddress);
			ElsIf Upper(TypeName) = Upper("Phone") Then
				CITypes.Add(Enums.ContactInformationTypes.Phone);
			ElsIf Upper(TypeName) = Upper("Address") Then
				CITypes.Add(Enums.ContactInformationTypes.Address);
			EndIf;
		EndDo;
	EndIf;
	
	If CITypes.Count() = 0 Then
		CITypes.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	
	CounterpartiesList.Parameters.SetParameterValue("CITypes", CITypes);
	If Not Parameters.CurrentCounterparty.IsEmpty() Then
		Items.CounterpartiesList.CurrentRow = Parameters.CurrentCounterparty;
	EndIf;
	
	ContactsClassification.RefreshPeriodsFilterValues(ThisForm);
	ContactsClassification.RefreshTagFilterValues(ThisForm, 45);
	ContactsClassification.RefreshSegmentsFilterValues(ThisForm, 45);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OwnerUuid = FormOwner.UUID;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If IsBlankString(AddressInStorage) AND SelectedRecipients.GetItems().Count() > 0 Then
		
		QuestionText = NStr("en='Transfer marked recipients?';ru='Перенести отмеченных адресатов?'");
		
		Notification = New NotifyDescription("BeforeCloseingTransferProposed", ThisForm);
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes, NStr("en='Address book';ru='Адресная книга'"));
		
		Cancel = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterWriteTag" Or EventName = "AfterSegmentWriting" Then
		RefreshSelectionValuesPanelServer(EventName);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure CounterpartiesChoiceList(Item, SelectedRow, Field, StandardProcessing)
	
	For Each Counterparty IN SelectedRow Do
		If Items.CounterpartiesList.RowData(Counterparty).IsFolder Then
			Return;
		EndIf;
	EndDo;
	
	ExecuteTransfer(SelectedRow);
	
EndProcedure

&AtClient
Procedure SelectedRecipientsBeforeDelete(Item, Cancel)
	
	For Each ID IN Item.SelectedRows Do
		RecipientRow = SelectedRecipients.FindByID(ID);
		If Not TypeOf(RecipientRow.Value) = Type("CatalogRef.Counterparties") Then
			Cancel = True;
			Return;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectedRecipientsDragging(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If DragParameters.Value.Count() > 0 Then
		ExecuteTransfer(DragParameters.Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectedRecipientsDraggingCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	If DragParameters.Value.Count() > 0 AND TypeOf(DragParameters.Value[0]) = Type("CatalogRef.Counterparties") Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SelectedRecipientsMarkOnChange(Item)
	
	SetSubordinatedMarkRecursively(Items.SelectedRecipients.CurrentData.Check, Items.SelectedRecipients.CurrentData.GetItems());
	If Items.SelectedRecipients.CurrentData.Check AND TypeOf(Items.SelectedRecipients.CurrentData.Value) = Type("CatalogRef.ContactInformationKinds") Then
		Parent = Items.SelectedRecipients.CurrentData.GetParent();
		Parent.Check= True;
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterCreatedTodayClick(Item)
	
	Mark = ContactsClassificationClient.CreatedFilterClick(ThisForm, "CounterpartiesList", "Today", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOver3DaysClick(Item)
	
	Mark = ContactsClassificationClient.CreatedFilterClick(ThisForm, "CounterpartiesList", "3Days", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOverWeekClick(Item)
	
	Mark = ContactsClassificationClient.CreatedFilterClick(ThisForm, "CounterpartiesList", "Week", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOverMonthClick(Item)
	
	Mark = ContactsClassificationClient.CreatedFilterClick(ThisForm, "CounterpartiesList", "Month", Item);
	
EndProcedure

&AtClient
Procedure FilterCreatedOnChange(Item)
	
	Mark = ContactsClassificationClient.CreatedFilterClick(ThisForm, "CounterpartiesList", "Custom", Item);
	
EndProcedure

&AtClient
Procedure Attachable_TagFilterClick(Item, StandardProcessing)
	
	Mark = ContactsClassificationClient.TagFilterClick(ThisForm, "CounterpartiesList", Item, StandardProcessing);
	If Not Mark = Undefined Then
		ChangeServerElementColor(Mark, Item.Name);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SegmentFilterClick(Item, StandardProcessing)
	
	Mark = ContactsClassificationClient.SegmentFilterClick(ThisForm, "CounterpartiesList", Item, StandardProcessing);
	If Not Mark = Undefined Then
		ChangeServerElementColor(Mark, Item.Name);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	
	AddressInStorage = SelectedRecipientsAddressInTemporaryStorage();
	Close(AddressInStorage);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	AddressInStorage = "CloseWithoutTransfer";
	Close(AddressInStorage);
	
EndProcedure

&AtClient
Procedure TransferToSelected(Command)
	
	ExecuteTransfer(Items.CounterpartiesList.SelectedRows);
	
EndProcedure

&AtClient
Procedure TransferFromSelected(Command)
	
	For Each ID IN Items.SelectedRecipients.SelectedRows Do
		RecipientRow = SelectedRecipients.FindByID(ID);
		If TypeOf(RecipientRow.Value) = Type("CatalogRef.Counterparties") Then
			RowsFirstLevel = SelectedRecipients.GetItems();
			RowsFirstLevel.Delete(RecipientRow);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SetCounterpartiesMarks(Command)
	
	ChangeCounterpartyMarkups(True, SelectedRecipients);
	
EndProcedure

&AtClient
Procedure UncheckCounterpartiesMarks(Command)
	
	ChangeCounterpartyMarkups(False, SelectedRecipients);
	
EndProcedure

&AtClient
Procedure SetContactPersonsMarks(Command)
	
	ChangeContactMarkups(True, SelectedRecipients);
	
EndProcedure

&AtClient
Procedure UncheckRecipientsMarks(Command)
	
	ChangeContactMarkups(False, SelectedRecipients);
	
EndProcedure

&AtClient
Procedure GroupAll(Command)
	
	For Each RowFirstLevel IN SelectedRecipients.GetItems() Do
		RowID = RowFirstLevel.GetID();
		Items.SelectedRecipients.Collapse(RowID);
	EndDo;
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	
	For Each RowFirstLevel IN SelectedRecipients.GetItems() Do
		RowID = RowFirstLevel.GetID();
		Items.SelectedRecipients.Expand(RowID, True);
	EndDo;
	
EndProcedure

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

#Region InteractiveActionsResults

&AtClient
Procedure BeforeCloseingTransferProposed(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
	//  TODO  we need to analyse it for 8.3.8
		#if not webclient then
			AddressInStorage = SelectedRecipientsAddressInTemporaryStorage();
			Close(AddressInStorage);
		#endif
	ElsIf QuestionResult = DialogReturnCode.No Then
		AddressInStorage = "CloseWithoutTransfer";
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteTransferEnd(ChoiceResult, AdditionalParameters) Export
	
	DoNotShowGroupSelectionQuestion = ChoiceResult.DontAskAgain;
	
	If ChoiceResult.Value = DialogReturnCode.Yes Then
		AddSelectedRecipients(AdditionalParameters.SelectedRows);
	EndIf;
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

&AtClient
Procedure ExecuteTransfer(val Counterparties)
	
	If DoNotShowGroupSelectionQuestion = False Then
		For Each SelectedRow IN Items.CounterpartiesList.SelectedRows Do
			Data = Items.CounterpartiesList.RowData(SelectedRow);
			If SelectedRow.IsEmpty() Or Data.IsFolder Then
				QuestionParameters = New Structure;
				QuestionParameters.Insert("Title", NStr("en='Confirm group selection';ru='Подтверждение выбора группы'"));
				QuestionParameters.Insert("MessageText", NStr("en='Select all counterparties of the group?';ru='Выбрать всех контрагентов группы?'"));
				QuestionParameters.Insert("Buttons", "DialogModeQuestion.YesNo");
				QuestionParameters.Insert("OfferDontAskAgain", True);
				NotifyDescription = New NotifyDescription("ExecuteTransferEnd", ThisForm, New Structure("SelectedRows", Items.CounterpartiesList.SelectedRows));
				OpenForm("CommonForm.Question", QuestionParameters, ThisForm,,,, NotifyDescription);
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	AddSelectedRecipients(Counterparties);
	
EndProcedure

&AtServer
Procedure AddSelectedRecipients(val Counterparties)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CounterpartiesContactInformation.Ref AS Ref,
		|	CounterpartiesContactInformation.Kind,
		|	CounterpartiesContactInformation.Presentation,
		|	CASE
		|		WHEN CounterpartiesContactInformation.Type = VALUE(Enum.ContactInformationTypes.EmailAddress)
		|			THEN 0
		|		WHEN CounterpartiesContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			THEN 3
		|		WHEN CounterpartiesContactInformation.Type = VALUE(Enum.ContactInformationTypes.Address)
		|			THEN 0
		|	END AS PictureIndex,
		|	CounterpartiesContactInformation.Kind.AdditionalOrderingAttribute AS Order
		|INTO tCounterpartiesCI
		|FROM
		|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
		|WHERE
		|	CounterpartiesContactInformation.Ref IN HIERARCHY(&Counterparties)
		|	AND CounterpartiesContactInformation.Type IN(&CITypes)
		|
		|INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Counterparties.Ref AS Counterparty,
		|	Counterparties.Presentation AS CounterpartyPresentation,
		|	Counterparties.ContactPerson AS MainContactPerson,
		|	ISNULL(tCounterpartiesCI.Kind, UNDEFINED) AS CIKind,
		|	ISNULL(tCounterpartiesCI.Presentation, """") AS ValueCI,
		|	tCounterpartiesCI.PictureIndex AS PictureIndex
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|		LEFT JOIN tCounterpartiesCI AS tCounterpartiesCI
		|		ON Counterparties.Ref = tCounterpartiesCI.Ref
		|WHERE
		|	Counterparties.Ref IN HIERARCHY(&Counterparties)
		|	AND Counterparties.IsFolder = FALSE
		|
		|ORDER BY
		|	CounterpartyPresentation,
		|	tCounterpartiesCI.Order
		|TOTALS
		|	MAX(MainContactPerson)
		|BY
		|	Counterparty
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactPersonsContactInformation.Ref AS Ref,
		|	ContactPersonsContactInformation.Kind,
		|	ContactPersonsContactInformation.Presentation,
		|	CASE
		|		WHEN ContactPersonsContactInformation.Type = VALUE(Enum.ContactInformationTypes.EmailAddress)
		|			THEN 0
		|		WHEN ContactPersonsContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			THEN 3
		|		WHEN ContactPersonsContactInformation.Type = VALUE(Enum.ContactInformationTypes.Address)
		|			THEN 0
		|	END AS PictureIndex,
		|	ContactPersonsContactInformation.Kind.AdditionalOrderingAttribute AS Order
		|INTO tCIContacts
		|FROM
		|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
		|WHERE
		|	ContactPersonsContactInformation.Ref.Owner IN HIERARCHY(&Counterparties)
		|	AND ContactPersonsContactInformation.Type IN(&CITypes)
		|
		|INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactPersons.Owner AS Counterparty,
		|	ContactPersons.Ref AS ContactPerson,
		|	ContactPersons.Presentation AS ContactPersonPresentation,
		|	ContactPersons.ContactPersonRoles.(
		|		ContactPersonRole
		|	),
		|	ISNULL(tCIContacts.Kind, UNDEFINED) AS CIKind,
		|	ISNULL(tCIContacts.Presentation, """") AS ValueCI,
		|	tCIContacts.PictureIndex
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|		LEFT JOIN tCIContacts AS tCIContacts
		|		ON ContactPersons.Ref = tCIContacts.Ref
		|WHERE
		|	ContactPersons.Owner IN HIERARCHY(&Counterparties)
		|	AND ContactPersons.DeletionMark = FALSE
		|
		|ORDER BY
		|	ContactPersonPresentation,
		|	tCIContacts.Order
		|TOTALS
		|	MAX(Counterparty)
		|BY
		|	ContactPerson";
	
	Query.SetParameter("Counterparties", Counterparties);
	Query.SetParameter("CITypes", CITypes);
	
	ResultsArray = Query.ExecuteBatch();
	CounterpartiesSelection = ResultsArray[1].Select(QueryResultIteration.ByGroups);
	ContactsSelection = ResultsArray[3].Select(QueryResultIteration.ByGroups);
	Filter = New Structure("Counterparty");
	
	While CounterpartiesSelection.Next() Do
		
		CounterpartyIsInSelected = False;
		RowsFirstLevel = SelectedRecipients.GetItems();
		For Each RowFirstLevel IN RowsFirstLevel Do
			If RowFirstLevel.Value = CounterpartiesSelection.Counterparty Then
				CounterpartyIsInSelected = True;
				Break;
			EndIf;
		EndDo;
		If CounterpartyIsInSelected Then
			Continue;
		EndIf;
		
		RowFirstLevel = RowsFirstLevel.Add();
		RowFirstLevel.Check = True;
		RowFirstLevel.Value = CounterpartiesSelection.Counterparty;
		RowFirstLevel.ValuePresentation = CounterpartiesSelection.CounterpartyPresentation;
		RowFirstLevel.PictureIndex = 1;
		
		RowsSecondLevel = RowFirstLevel.GetItems();
		
		CISelection_Counterparties = CounterpartiesSelection.Select();
		While CISelection_Counterparties.Next() Do
			
			If CISelection_Counterparties.CIKind = Undefined Then
				Continue;
			EndIf;
			
			RowSecondLevel = RowsSecondLevel.Add();
			RowSecondLevel.Check = True;
			RowSecondLevel.Value = CISelection_Counterparties.CIKind;
			RowSecondLevel.ValuePresentation = CISelection_Counterparties.ValueCI;
			RowSecondLevel.PictureIndex = CISelection_Counterparties.PictureIndex;
			
		EndDo;
		
		ContactsSelection.Reset();
		Filter.Counterparty = CounterpartiesSelection.Counterparty;
		While ContactsSelection.FindNext(Filter) Do
			
			RowSecondLevel = RowsSecondLevel.Add();
			RowSecondLevel.Check = False;
			RowSecondLevel.Value = ContactsSelection.ContactPerson;
			RowSecondLevel.ValuePresentation = ContactsSelection.ContactPersonPresentation;
			RowSecondLevel.PictureIndex = 2;
			
			RowsThirdLevel = RowSecondLevel.GetItems();
			
			CISelection_ContactPersons = ContactsSelection.Select();
			While CISelection_ContactPersons.Next() Do
				
				If CISelection_ContactPersons.CIKind = Undefined Then
					Continue;
				EndIf;
				
				RowThirdLevel = RowsThirdLevel.Add();
				RowThirdLevel.Check = False;
				RowThirdLevel.Value = CISelection_ContactPersons.CIKind;
				RowThirdLevel.ValuePresentation = CISelection_ContactPersons.ValueCI;
				RowThirdLevel.PictureIndex = CISelection_ContactPersons.PictureIndex;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetSubordinatedMarkRecursively(Mark, TreeRows)
	
	For Each TreeRow IN TreeRows Do
		TreeRow.Check = Mark;
		SubordinateTreeRows = TreeRow.GetItems();
		If SubordinateTreeRows.Count() > 0 Then
			SetSubordinatedMarkRecursively(Mark, SubordinateTreeRows);
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ChangeCounterpartyMarkups(Mark, Tree)
	
	RowsFirstLevel = Tree.GetItems();
	For Each RowFirstLevel IN RowsFirstLevel Do
		RowFirstLevel.Check = Mark;
		RowsSecondLevel = RowFirstLevel.GetItems();
		For Each RowSecondLevel IN RowsSecondLevel Do
			If TypeOf(RowSecondLevel.Value) <> Type("CatalogRef.ContactInformationKinds") Then
				Continue;
			EndIf;
			RowSecondLevel.Check = Mark;
		EndDo;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure ChangeContactMarkups(Mark, Tree)
	
	RowsFirstLevel = Tree.GetItems();
	For Each RowFirstLevel IN RowsFirstLevel Do
		RowsSecondLevel = RowFirstLevel.GetItems();
		For Each RowSecondLevel IN RowsSecondLevel Do
			If TypeOf(RowSecondLevel.Value) <> Type("CatalogRef.ContactPersons") Then
				Continue;
			EndIf;
			RowSecondLevel.Check = Mark;
			RowsThirdLevel = RowSecondLevel.GetItems();
			For Each RowThirdLevel IN RowsThirdLevel Do
				RowThirdLevel.Check = Mark;
			EndDo;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function SelectedRecipientsAddressInTemporaryStorage()
	
	RecipientsTable = ConvertRecipientsTreeInValuesTable(SelectedRecipients);
	Return PutToTempStorage(RecipientsTable, OwnerUuid);
	
EndFunction

&AtServerNoContext
Function ConvertRecipientsTreeInValuesTable(Tree)
	
	RecipientsTable = New ValueTable;
	RecipientsTable.Columns.Add("Contact", New TypeDescription("CatalogRef.Counterparties,CatalogRef.ContactPersons"));
	RecipientsTable.Columns.Add("HowToContact", New TypeDescription("String"));
	
	RowsFirstLevel = Tree.GetItems();
	For Each RowFirstLevel IN RowsFirstLevel Do
		
		If RowFirstLevel.Check Then
			NewRowCounterparty = RecipientsTable.Add();
			NewRowCounterparty.Contact = RowFirstLevel.Value;
		EndIf;
		
		RowsSecondLevel = RowFirstLevel.GetItems();
		
		For Each RowSecondLevel IN RowsSecondLevel Do
			
			If RowFirstLevel.Check AND TypeOf(RowSecondLevel.Value) = Type("CatalogRef.ContactInformationKinds") AND RowSecondLevel.Check Then
				
				If NewRowCounterparty = Undefined Then
					NewRowCounterparty = RecipientsTable.Add();
				EndIf;
				
				NewRowCounterparty.Contact = RowFirstLevel.Value;
				NewRowCounterparty.HowToContact = RowSecondLevel.ValuePresentation;
				NewRowCounterparty = Undefined;
				
			ElsIf TypeOf(RowSecondLevel.Value) = Type("CatalogRef.ContactPersons") AND RowSecondLevel.Check Then
				
				NewRowContactPerson = RecipientsTable.Add();
				NewRowContactPerson.Contact = RowSecondLevel.Value;
				
				RowsThirdLevel = RowSecondLevel.GetItems();
				
				For Each RowThirdLevel IN RowsThirdLevel Do
					
					If TypeOf(RowThirdLevel.Value) = Type("CatalogRef.ContactInformationKinds") AND RowThirdLevel.Check Then
						
						If NewRowContactPerson = Undefined Then
							NewRowContactPerson = RecipientsTable.Add();
						EndIf;
						
						NewRowContactPerson.Contact = RowSecondLevel.Value;
						NewRowContactPerson.HowToContact = RowThirdLevel.ValuePresentation;
						NewRowContactPerson = Undefined;
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return RecipientsTable;
	
EndFunction

&AtServer
Procedure ChangeServerElementColor(Mark, ItemName)
	
	ContactsClassification.ChangeSelectionItemColor(ThisForm, Mark, ItemName);
	
EndProcedure

&AtServer
Procedure RefreshSelectionValuesPanelServer(EventName)
	
	If EventName = "AfterWriteTag" Then
		ContactsClassification.RefreshTagFilterValues(ThisForm, 45);
	ElsIf EventName = "AfterSegmentWriting" Then
		ContactsClassification.RefreshSegmentsFilterValues(ThisForm, 45);
	EndIf;
	
EndProcedure

#EndRegion
