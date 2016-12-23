#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	Items.ContactsContact.TypeRestriction = New TypeDescription(TypeArray, New StringQualifiers(100));
	Items.Subject.TypeRestriction			 = New TypeDescription(TypeArray, New StringQualifiers(200));
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	If Parameters.Key.IsEmpty() Then
		ReadAttributes(Object);
		AutoTitle = False;
		Title = "Event: " + Object.EventType + " (create)";
		DocumentDate = CurrentDate();
	Else
		DocumentDate = Object.Date;
	EndIf;
	
	NotifyWorkCalendar = False;
	
	// Filling time selection list
	SmallBusinessClientServer.FillListByList(GetListSelectTime(Object.EventBegin),Items.EventBeginTime.ChoiceList);
	SmallBusinessClientServer.FillListByList(GetListSelectTime(Object.EventEnding),Items.EventEndTime.ChoiceList);
	
	// Subject history for automatic selection
	ImportSubjectHistoryByString();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose()
	
	If NotifyWorkCalendar Then
		Notify("EventChanged", Object.Responsible);
	EndIf;
	
EndProcedure

// Procedure - event handler NewWriteDataProcessor.
//
&AtClient
Procedure NewWriteProcessing(NewObject, Source, StandardProcessing)
	
	If TypeOf(NewObject) = Type("CatalogRef.ContactPersons") Then
		
		ContactPersonParameters = GetContactPersonParameters(NewObject);
		If ContactPersonParameters.Owner <> Counterparty Then
			Return;
		EndIf;
		
		RowContacts = Contacts.Add();
		RowContacts.Contact = NewObject;
		RowContacts.HowToContact = ContactPersonParameters.HowToContact;
		
	EndIf;
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ReadAttributes(CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler BeforeWriteAtServer.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		NotifyWorkCalendar = True;
	EndIf;
	
	WriteAttributes(CurrentObject);
	
	If TypeOf(CurrentObject.Subject) = Type("String") Then
	// Save subjects in history for automatic selection
		
		HistoryItem = SubjectRowHistory.FindByValue(TrimAll(CurrentObject.Subject));
		If HistoryItem <> Undefined Then
			SubjectRowHistory.Delete(HistoryItem);
		EndIf;
		SubjectRowHistory.Insert(0, TrimAll(CurrentObject.Subject));
		
		CommonUse.CommonSettingsStorageSave("ThemeEventsChoiceList", , SubjectRowHistory.UnloadValues());
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = "";
	AutoTitle = True;
	
EndProcedure

// Procedure - event handler FillCheckProcessingAtServer.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each RowContacts IN Contacts Do
		If Not ValueIsFilled(RowContacts.Contact) Then
			CommonUseClientServer.MessageToUser(
				CommonUseClientServer.TextFillingErrors("Column", "Filling", "Contact", Contacts.IndexOf(RowContacts) + 1, "Parties"),
				,
				StringFunctionsClientServer.PlaceParametersIntoString("Contacts[%1].Contact", Contacts.IndexOf(RowContacts)),
				,
				Cancel
			);
		EndIf;
	EndDo;
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - event handler OnChange of the Date input field.
// The procedure defines the situation, when after changing the date of the document, the document appears in the other period of document numbering, and in this case the procedure assigns a new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event processor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If DocumentDate <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field EventBeginDate.
//
&AtClient
Procedure EventBeginDateOnChange(Item)
	
	SmallBusinessClientServer.FillListByList(GetListSelectTime(Object.EventBegin),Items.EventBeginTime.ChoiceList);
	
EndProcedure

// Procedure - event handler OnChange input field EventEndingDate.
//
&AtClient
Procedure EventEndDateOnChange(Item)
	
	SmallBusinessClientServer.FillListByList(GetListSelectTime(Object.EventBegin),Items.EventBeginTime.ChoiceList);
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyOnChangeServer();
	
EndProcedure

// Procedure - event handler SelectionStart input field Subject.
//
&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	If TypeOf(Object.Subject) = Type("CatalogRef.EventsSubjects") AND ValueIsFilled(Object.Subject) Then
		FormParameters.Insert("CurrentRow", Object.Subject);
	EndIf;
	
	OpenForm("Catalog.EventsSubjects.ChoiceForm", FormParameters, Item);
	
EndProcedure

// Procedure - event handler SelectionDataProcessor input field Subject.
//
&AtClient
Procedure SubjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		Object.Subject = ValueSelected;
		FillContentEvents(ValueSelected);
	EndIf;
	
EndProcedure

// Procedure - event handler AutoPick input field Subject.
//
&AtClient
Procedure SubjectAutoSelection(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		
		StandardProcessing = False;
		ChoiceData = GetSubjectChoiceList(Text, SubjectRowHistory);
		
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart of item ContactsContact.
//
&AtClient
Procedure ContactsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ValueIsFilled(Counterparty) Then
		CommonUseClientServer.MessageToUser(NStr("en='It is necessary to select counterparty.';ru='Необходимо выбрать контрагента.'"), , "Counterparty");
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Owner",Counterparty));
	FormParameters.Insert("CurrentRow", Items.Contacts.CurrentData.Contact);
	
	OpenForm("Catalog.ContactPersons.ChoiceForm", FormParameters, Item);
	
EndProcedure

// Procedure - events handler Open item ContactsContact.
//
&AtClient
Procedure ContactsContactOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Items.Contacts.CurrentData.Contact) Then
		Contact = Contacts.FindByID(Items.Contacts.CurrentRow).Contact;
		ShowValue(,Contact);
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionDataProcessor of item ContactsContact.
//
&AtClient
Procedure ContactsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		HowToContact = GetHowToContact(ValueSelected, False);
	EndIf;
	
	RowContacts = Contacts.FindByID(Items.Contacts.CurrentRow);
	RowContacts.Contact = ValueSelected;
	RowContacts.HowToContact = HowToContact;
	
EndProcedure

// Procedure - event handler AutoPick of item ContactsContact.
//
&AtClient
Procedure ContactsContactAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) AND ValueIsFilled(Counterparty) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text, Counterparty);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler FillByBasis.
//
&AtClient
Procedure FillByBasis(Command)
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
		
EndProcedure

// Procedure - command handler FillContent.
//
&AtClient
Procedure FillContent(Command)
	
	If ValueIsFilled(Object.Subject) Then
		FillContentEvents(Object.Subject);
	EndIf;
	
EndProcedure

// Procedure - command handler FillByCounterparty.
//
&AtClient
Procedure FillByCounterparty(Command)
	
	If Contacts.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillByCounterpartyEnd", ThisObject),
			NStr("en='Contacts will be completely refilled by counterparty! Continue?';ru='Контакты будут полностью перезаполнены по контрагенту! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	Else
		FillByCounterpartyFragment(DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - command handler CreateContact.
//
&AtClient
Procedure CreateContact(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Owner", Counterparty);
	
	OpenForm("Catalog.ContactPersons.ObjectForm", New Structure("Basis", OpenParameters), ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - command handler SendEmailToCounterparty.
//
&AtClient
Procedure SendEmailToCounterparty(Command)
	
	ListOfEmailAddresses = GetEmailCounterparty(Object.Ref);
	
	If Object.Ref.IsEmpty() Or Modified Then
		
		ListOfEmailAddresses	= New ValueList;
		NotificationText = NStr("en='Event is not written.';ru='Событие не записано.'");
		NotificationExplanation = NStr("en='Electronic addresses
		|list will be blank.';ru='Список электронных адресов
		|будет пуст.'");
		ShowUserNotification(NotificationText, , NotificationExplanation, PictureLib.Information32);
		
	Else
		
		ListOfEmailAddresses = GetEmailCounterparty(Object.Ref);
		
	EndIf;
	
	SendingParameters = New Structure("Recipient, Subject, Text", ListOfEmailAddresses, Object.Subject, Object.Content);
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure

#EndRegion

#Region CommonUseProceduresAndFunctions

// Procedure synchronizes the data object with form attributes.
//
&AtServer
Procedure ReadAttributes(Object)
	
	Contacts.Clear();
	FirstRow = True;
	
	For Each RowParticipants IN Object.Parties Do
		
		If FirstRow Then
			Counterparty = RowParticipants.Contact;
			HowToContact = RowParticipants.HowToContact;
			FirstRow = False;
			Continue;
		EndIf;
		
		RowContacts = Contacts.Add();
		FillPropertyValues(RowContacts, RowParticipants);
		
	EndDo;
	
EndProcedure

// Procedure synchronizes the data object with form attributes.
//
&AtServer
Procedure WriteAttributes(Object)
	
	Object.Parties.Clear();
	
	RowParticipants = Object.Parties.Add();
	RowParticipants.Contact = Counterparty;
	RowParticipants.HowToContact = CounterpartyHowToContact;
	
	For Each RowContacts IN Contacts Do
		FillPropertyValues(Object.Parties.Add(), RowContacts);
	EndDo;
	
EndProcedure

// Function returns parameter structure for contact person.
//
// Parameters:
//  ContactPerson	 - CatalogRef.ContactPersons	 - Contact person reference
&AtServerNoContext
Function GetContactPersonParameters(ContactPerson)
	
	Result = New Structure;
	Result.Insert("Owner", ContactPerson.Owner);
	Result.Insert("HowToContact", GetHowToContact(ContactPerson, False));
	
	Return Result;
	
EndFunction

// Function - Get how to contact
//
// Parameters:
//  Contact				 - CatalogRef.Counterparties, CatalogRef.ContactPersons	 - Contact
//  reference ThisIsEMail - Boolean	 - for emails only email addresses
// returned value:
//  String - value to connect with contact
&AtServerNoContext
Function GetHowToContact(Contact, ThisIsEMail = False)
	
	Result = "";
	
	Contacts = New Array;
	Contacts.Add(Contact);
	
	CITypes = New Array;
	CITypes.Add(Enums.ContactInformationTypes.EmailAddress);
	If Not ThisIsEMail Then
		CITypes.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	CITable = ContactInformationManagement.ContactInformationOfObjects(Contacts, CITypes);
	CITable.Sort("Type DESC");
	For Each CIRow IN CITable Do
		Result = "" + Result + ?(Result = "", "", ", ") + CIRow.Presentation;
	EndDo;
	
	Return Result;
	
EndFunction

// Procedure allows to get list for time selection broken by hours.
//
&AtClientAtServerNoContext
Function GetListSelectTime(DateForChoice)
	
	WorkingDayBeginning    = BegOfDay(DateForChoice);
	WorkingDayEnd = BegOfHour(EndOfDay(DateForChoice));
	
	TimeList = New ValueList;
	
	ListTime = WorkingDayBeginning;
	While BegOfHour(ListTime) <= WorkingDayEnd Do
		
		TimeList.Add(ListTime, Format(ListTime,"DF=HH:mm; DP=00:00"));
		ListTime = ListTime + 3600;
		
	EndDo;
	
	Return TimeList;
	
EndFunction // GetTimeChoiceList()

&AtServerNoContext
// It receives data set from server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// It gets EMail by sent link
// 
// RefOnCurrentDocument - references on the current document if the document is not written then it returns Undefined. If the document is written then it returns value list "ElectronicAddressList"
//
// List format:
// 	Presentation - recipient
// 	name value      - Mail address
//
&AtServerNoContext
Function GetEmailCounterparty(RefOnCurrentDocument)
	
	Result = New Array;
	MailAddressArray = New Array;
	StructureRecipient = New Structure("Presentation, Address", 
		?(RefOnCurrentDocument.Parties.Count() = 0, Undefined, RefOnCurrentDocument.Parties[0].Contact));
	
	Query	 		= New Query;
	Query.SetParameter("Ref", RefOnCurrentDocument);
	
	Query.Text	= 
	"SELECT
	|	ContactPersonsContactInformation.Ref AS Contact,
	|	ContactPersonsContactInformation.EMail_Address,
	|	1 AS Order
	|FROM
	|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
	|WHERE
	|	ContactPersonsContactInformation.Ref In
	|			(SELECT
	|				EventParties.Contact
	|			FROM
	|				Document.Event.Parties AS EventParties
	|			WHERE
	|				EventParties.Ref = &Ref
	|				AND EventParties.LineNumber <> 1)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	CounterpartiesContactInformation.Ref,
	|	CounterpartiesContactInformation.EMail_Address,
	|	2
	|FROM
	|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
	|WHERE
	|	CounterpartiesContactInformation.Ref In
	|			(SELECT
	|				EventParties.Contact
	|			FROM
	|				Document.Event.Parties AS EventParties
	|			WHERE
	|				EventParties.Ref = &Ref
	|				AND EventParties.LineNumber = 1)
	|
	|ORDER BY
	|	Order";
	
	SelectionFromQuery					= Query.Execute().Select();
	AddCounterpartyEmailAddress = True;
	
	While SelectionFromQuery.Next() Do
		
		If Not ValueIsFilled(SelectionFromQuery.EMail_Address) 
			OR (SelectionFromQuery.Order = 2 AND Not AddCounterpartyEmailAddress) Then
			
			Continue;
			
		EndIf;
		
		If MailAddressArray.Find(SelectionFromQuery.EMail_Address) = Undefined Then
			
			MailAddressArray.Add(SelectionFromQuery.EMail_Address);
			AddCounterpartyEmailAddress = False;
			
		EndIf;
		
	EndDo;
	
	StructureRecipient.Address = StringFunctionsClientServer.GetStringFromSubstringArray(MailAddressArray, "; ");
	Result.Add(StructureRecipient);
	
	Return Result;
	
EndFunction //GetEMAILCounterparty()

&AtServer
Procedure CounterpartyOnChangeServer()
	
	CounterpartyHowToContact = GetHowToContact(Counterparty, False);
	
	// Clear contact person other counterparties
	For Each RowContacts IN Contacts Do
		If TypeOf(RowContacts.Contact) = Type("CatalogRef.ContactPersons") AND RowContacts.Contact.Owner <> Counterparty Then
			RowContacts.Contact = Catalogs.ContactPersons.EmptyRef();
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForAutomaticSelections

// Procedure imports the event subject automatic selection history.
//
&AtServer
Procedure ImportSubjectHistoryByString()
	
	ListChoiceOfTopics = CommonUse.CommonSettingsStorageImport("ThemeEventsChoiceList");
	If ListChoiceOfTopics <> Undefined Then
		SubjectRowHistory.LoadValues(ListChoiceOfTopics);
	EndIf;
	
EndProcedure // ImportEventSubjectChoiceList()

// Procedure fills subject selection data.
//
// Parameters:
//  SearchString - String	 - The SubjectHistoryByRow text being typed - ValueList	 - Used subjects in the row form
&AtServerNoContext
Function GetSubjectChoiceList(val SearchString, val SubjectRowHistory)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList IN SubjectSelectionData Do
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (event subject)"));
	EndDo;
	
	For Each HistoryItem IN SubjectRowHistory Do
		If Left(HistoryItem.Value, StrLen(SearchString)) = SearchString Then
			ListChoiceOfTopics.Add(HistoryItem.Value, 
				New FormattedString(New FormattedString(SearchString,New Font(,,True),WebColors.Green), Mid(HistoryItem.Value, StrLen(SearchString)+1)));
		EndIf;
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

// Procedure fills contact selection data.
//
// Parameters:
//  SearchString - String	 - Text being typed
&AtServerNoContext
Function GetContactChoiceList(val SearchString, Counterparty)
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("Owner, DeletionMark", Counterparty, False));
	ChoiceParameters.Insert("SearchString", SearchString);
	
	ContactPersonSelectionData = Catalogs.ContactPersons.GetChoiceData(ChoiceParameters);
	
	Return ContactPersonSelectionData;
	
EndFunction

#EndRegion

#Region SecondaryDataFilling

// Procedure fills the event content from the subject template.
//
&AtClient
Procedure FillContentEvents(EventSubject)
	
	If TypeOf(EventSubject) <> Type("CatalogRef.EventsSubjects") Then
		Return;
	EndIf;
	
	If Not IsBlankString(Object.Content) Then
		ShowQueryBox(New NotifyDescription("FillEventContentEnd", ThisObject, New Structure("EventSubject", EventSubject)),
			NStr("en='Do you want to refill the content by the selected topic?';ru='Перезаполнить содержание по выбранной теме?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillEventContentFragment(EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentEnd(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	FillEventContentFragment(AdditionalParameters.EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentFragment(Val EventSubject)
	
	Object.Content = GetContentSubject(EventSubject);
	
EndProcedure // FillEventContent()

// Function returns the content by selected subject.
//
&AtServerNoContext
Function GetContentSubject(EventSubject)
	
	Return EventSubject.Content;
	
EndFunction // GetSubjectContent()

&AtClient
Procedure FillByCounterpartyEnd(Result, AdditionalParameters) Export
	
	FillByCounterpartyFragment(Result);
	
EndProcedure

&AtClient
Procedure FillByCounterpartyFragment(Val Response)
	
	If Response = DialogReturnCode.Yes Then
		FillByCounterpartyServer(Counterparty);
	EndIf;
	
EndProcedure // FillByCounterparty()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByCounterpartyServer(Counterparty)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(New Structure("FillBasis, EventType", Counterparty, Object.EventType));
	ValueToFormAttribute(Document, "Object");
	
	ReadAttributes(Object);
	
EndProcedure // FillPartisipantsByCounterparty()

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByBasisServer(Object.BasisDocument);
	EndIf;
	
EndProcedure // FillByBasis()

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByBasisServer(BasisDocument)
	
	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.Fill(New Structure("FillBasis, EventType", BasisDocument, Object.EventType));
	ValueToFormAttribute(DocumentObject, "Object");
	
	ReadAttributes(DocumentObject);
	
EndProcedure // FillByDocument()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm);
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion













