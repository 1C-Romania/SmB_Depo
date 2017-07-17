
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.ContactsContact.TypeRestriction	= New TypeDescription("String",, New StringQualifiers(100));
	Items.Subject.TypeRestriction			= New TypeDescription("String",, New StringQualifiers(200));
	
	If ValueIsFilled(Object.Ref) Then
		DocumentDate = Object.Date;
	Else
		ReadAttributes(Object);
		AutoTitle = False;
		Title = StrTemplate(
		NStr("ru = 'Событие: %1 (создание)'; en = 'Event: %1 (create)'"),
		Object.EventType);
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	NotifyWorkCalendar = False;
	
	EventsSBClientServer.FillTimeChoiceList(Items.EventBeginTime);
	EventsSBClientServer.FillTimeChoiceList(Items.EventEndTime);
	
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
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If NotifyWorkCalendar Then
		Notify("EventChanged", Object.Responsible);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

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

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ReadAttributes(CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

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

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = "";
	AutoTitle = True;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each RowContacts IN Contacts Do
		If Not ValueIsFilled(RowContacts.Contact) Then
			CommonUseClientServer.MessageToUser(
				CommonUseClientServer.TextFillingErrors("Column", "Filling", "Contact", Contacts.IndexOf(RowContacts) + 1, "Participants"),
				,
				StringFunctionsClientServer.SubstituteParametersInString("Contacts[%1].Contact", Contacts.IndexOf(RowContacts)),
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

#Region FormItemEventHandlers

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

&AtClient
Procedure EventBeginTimeOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EventBeginTimeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	SelectedValue = BegOfDay(Object.EventBegin) + (SelectedValue - BegOfDay(SelectedValue));
	
EndProcedure

&AtClient
Procedure EventBeginDateOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EventEndTimeOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure EventEndTimeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	SelectedValue = BegOfDay(Object.EventEnding) + (SelectedValue - BegOfDay(SelectedValue));
	
EndProcedure

&AtClient
Procedure EventEndDateOnChange(Item)
	
	FormDurationPresentation(ThisObject);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyOnChangeServer();
	
EndProcedure

&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	If TypeOf(Object.Subject) = Type("CatalogRef.EventsSubjects") AND ValueIsFilled(Object.Subject) Then
		FormParameters.Insert("CurrentRow", Object.Subject);
	EndIf;
	
	OpenForm("Catalog.EventsSubjects.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure SubjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		Object.Subject = ValueSelected;
		FillContentEvents(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectAutoSelection(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		
		StandardProcessing = False;
		ChoiceData = GetSubjectChoiceList(Text, SubjectRowHistory);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ValueIsFilled(Counterparty) Then
		CommonUseClientServer.MessageToUser(NStr("en='Select a counterparty.';ru='Необходимо выбрать контрагента.'"), , "Counterparty");
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("Owner",Counterparty));
	FormParameters.Insert("CurrentRow", Items.Contacts.CurrentData.Contact);
	FormParameters.Insert("ChoiceMode", True);
	
	OpenForm("Catalog.ContactPersons.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ContactsContactOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Items.Contacts.CurrentData.Contact) Then
		Contact = Contacts.FindByID(Items.Contacts.CurrentRow).Contact;
		ShowValue(,Contact);
	EndIf;
	
EndProcedure

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

&AtClient
Procedure ContactsContactAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) AND ValueIsFilled(Counterparty) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text, Counterparty);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined, NStr("ru='Не указано основание для заполнения.'; en = 'The basis for filling is not specified.'"));
		Возврат;
	КонецЕсли;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en='The  document will be fully filled out according to the ""Basis"". Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
		
EndProcedure

&AtClient
Procedure FillContent(Command)
	
	If ValueIsFilled(Object.Subject) Then
		FillContentEvents(Object.Subject);
	EndIf;
	
EndProcedure

&AtClient
Procedure FillByCounterparty(Command)
	
	If Contacts.Count() > 0 Then
		ShowQueryBox(New NotifyDescription("FillByCounterpartyEnd", ThisObject),
			NStr("en='Contacts will be completely refilled according to the counterparty. Continue?';ru='Контакты будут полностью перезаполнены по контрагенту! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	Else
		FillByCounterpartyFragment(DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateContact(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("Owner", Counterparty);
	
	OpenForm("Catalog.ContactPersons.ObjectForm", New Structure("Basis", OpenParameters), ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure ReadAttributes(Object)
	
	Contacts.Clear();
	FirstRow = True;
	
	For Each RowParticipants IN Object.Participants Do
		
		If FirstRow Then
			Counterparty				= RowParticipants.Contact;
			CounterpartyHowToContact	= RowParticipants.HowToContact;
			FirstRow = False;
			Continue;
		EndIf;
		
		RowContacts = Contacts.Add();
		FillPropertyValues(RowContacts, RowParticipants);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure WriteAttributes(Object)
	
	Object.Participants.Clear();
	
	RowParticipants = Object.Participants.Add();
	RowParticipants.Contact = Counterparty;
	RowParticipants.HowToContact = CounterpartyHowToContact;
	
	For Each RowContacts IN Contacts Do
		FillPropertyValues(Object.Participants.Add(), RowContacts);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetContactPersonParameters(ContactPerson)
	
	Result = New Structure;
	Result.Insert("Owner", ContactPerson.Owner);
	Result.Insert("HowToContact", GetHowToContact(ContactPerson, False));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetHowToContact(Contact, IsEmail = False)
	
	Return Documents.Event.GetHowToContact(Contact, IsEmail);
	
EndFunction

&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction

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

&AtServer
Procedure ImportSubjectHistoryByString()
	
	ListChoiceOfTopics = CommonUse.CommonSettingsStorageImport("ThemeEventsChoiceList");
	If ListChoiceOfTopics <> Undefined Then
		SubjectRowHistory.LoadValues(ListChoiceOfTopics);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetSubjectChoiceList(val SearchString, val SubjectRowHistory)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList IN SubjectSelectionData Do
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, NStr("ru = ' (тема события)'; en = ' (event subject)'")));
	EndDo;
	
	For Each HistoryItem IN SubjectRowHistory Do
		If Left(HistoryItem.Value, StrLen(SearchString)) = SearchString Then
			ListChoiceOfTopics.Add(HistoryItem.Value, 
				New FormattedString(New FormattedString(SearchString,New Font(,,True),WebColors.Green), Mid(HistoryItem.Value, StrLen(SearchString)+1)));
		EndIf;
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

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

&AtClient
Procedure FillContentEvents(EventSubject)
	
	If TypeOf(EventSubject) <> Type("CatalogRef.EventsSubjects") Then
		Return;
	EndIf;
	
	If Not IsBlankString(Object.Content) Then
		ShowQueryBox(New NotifyDescription("FillEventContentEnd", ThisObject, New Structure("EventSubject", EventSubject)),
			NStr("en='Refill the content by the selected topic?';ru='Перезаполнить содержание по выбранной теме?'"), QuestionDialogMode.YesNo, 0);
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
	
EndProcedure

&AtServerNoContext
Function GetContentSubject(EventSubject)
	
	Return EventSubject.Content;
	
EndFunction

&AtClient
Procedure FillByCounterpartyEnd(Result, AdditionalParameters) Export
	
	FillByCounterpartyFragment(Result);
	
EndProcedure

&AtClient
Procedure FillByCounterpartyFragment(Val Response)
	
	If Response = DialogReturnCode.Yes Then
		FillByCounterpartyServer(Counterparty);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByCounterpartyServer(Counterparty)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(New Structure("FillingBasis, EventType", Counterparty, Object.EventType));
	ValueToFormAttribute(Document, "Object");
	
	ReadAttributes(Object);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByBasisServer(Object.BasisDocument);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillByBasisServer(BasisDocument)
	
	DocumentObject = FormAttributeToValue("Object");
	DocumentObject.Fill(New Structure("FillingBasis, EventType, Responsible", BasisDocument, Object.EventType, Object.Responsible));
	ValueToFormAttribute(DocumentObject, "Object");
	
	ReadAttributes(DocumentObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormDurationPresentation(Form)
	
	Form.DurationPresentation = "";
	
	Begin	= Form.Object.EventBegin;
	End		= Form.Object.EventEnding;
	
	If Not ValueIsFilled(Begin)
		Or Not ValueIsFilled(End) Then
		
		Return;
	EndIf;
	
	DurationSec = End - Begin;
	
	Days = Int(DurationSec / 86400);
	CaptionDays = SmallBusinessClientServer.PluralForm(
		NStr("en='Day';ru='день'"),
		NStr("ru = 'дня'; en = 'day'"),
		NStr("ru = 'дней'; en = 'days'"),
		Days
	);
	
	Hours = Int((DurationSec - Days * 86400) / 3600);
	CaptionHours = SmallBusinessClientServer.PluralForm(
		NStr("ru = 'час'; en = 'hour'"),
		NStr("ru = 'часа'; en = 'hours'"),
		NStr("ru = 'часов'; en = 'hours'"),
		Hours
	);
	
	Minutes = Int((DurationSec - Days * 86400 - Hours * 3600) / 60);
	CaptionMinutes = SmallBusinessClientServer.PluralForm(
		NStr("ru = 'минута'; en = 'minute'"),
		NStr("en='minutes';ru='минуты'"),
		NStr("ru = 'минут'; en = 'minutes'"),
		Minutes
	);
	
	If Days > 0 Тогда 
		Form.DurationPresentation = Form.DurationPresentation + String(Days) + " " + CaptionDays;
	EndIf;
	
	If Hours > 0 Then 
		
		If Days > 0 Then
			Form.DurationPresentation = Form.DurationPresentation + " ";
		EndIf;
		
		Form.DurationPresentation = Form.DurationPresentation + String(Hours) + " " + CaptionHours;
	EndIf;
	
	If Minutes > 0 Then 
		
		If Days > 0 Or Hours > 0 Then
			Form.DurationPresentation = Form.DurationPresentation + " ";
		EndIf;
		
		Form.DurationPresentation = Form.DurationPresentation + String(Minutes) + " " + CaptionMinutes;
	EndIf;
	
EndProcedure

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