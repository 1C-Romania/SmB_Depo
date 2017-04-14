#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ObjectFillingSB.FillDocument(ThisObject, FillingData, "FillingHandler");
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	FillAttributeParticipantsList();
	FillPresentation();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If EventType = Enums.EventTypes.Email
		And IncomingOutgoingEvent = Enums.IncomingOutgoingEvent.Incoming Then
		Raise NStr("ru = 'Копирование входящего письма невозможно.'; en = 'You can not copy an incoming message.'");
	EndIf;
	
	If EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS Then
		EventBegin	= '00010101';
		EventEnding	= '00010101';
	Else
		EventBegin = CurrentSessionDate();
		EventBegin = BegOfHour(EventBegin) + ?(Minute(EventBegin) < 30, 1800, 3600);
		EventEnding = EventBegin + 1800;
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If EventEnding < EventBegin Then
		CommonUseClientServer.MessageToUser(
			NStr("ru = 'Дата окончания не может быть меньше даты начала.'; en = 'The end date can not be less than the start date.'"),
			ThisObject,
			"EventEnding",
			,
			Cancel
		);
	EndIf;
	
	// For the form of other events its own table of contacts is implemented
	If Not (EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS) Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Participants.Contact"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Interface
	
Procedure FillAttributeParticipantsList() Export
	
	ParticipantsList = "";
	For Each Participant In Participants Do
		ParticipantsList = ParticipantsList + ?(ParticipantsList = "","","; ")
			+ Participant.Contact + ?(IsBlankString(Participant.HowToContact), "", " <" + Participant.HowToContact + ">");
	EndDo;
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillingHandler(FillingData) Export
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	If Not FillingData.Property("EventType") Then
		Return;
	EndIf;
	
	EventType = FillingData.EventType;
	
	If EventType <> Enums.EventTypes.Email
		And EventType <> Enums.EventTypes.SMS Then
		
		If Not ValueIsFilled(EventBegin) Or Not ValueIsFilled(EventEnding) Then
			If FillingData.Property("EventBegin") Then
				EventBegin = FillingData.EventBegin;
			Else
				EventBegin = CurrentSessionDate();
			EndIf;
			If FillingData.Property("EventEnding") Then
				EventEnding = FillingData.EventEnding;
			Else
				EventEnding = EventBegin + 1800;
			EndIf;
		EndIf;
		
	EndIf;
	
	If FillingData.Property("Counterparty")
		And TypeOf(FillingData.Counterparty) = Type("CatalogRef.Counterparties") Then
		FillByCounterparty(FillingData.Counterparty);
	EndIf;
	
	If FillingData.Property("Contact") Then
		
		If TypeOf(FillingData.Contact) = Type("CatalogRef.ContactPersons") Then
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact = CommonUse.ObjectAttributeValue(FillingData.Contact, "Owner");
		EndIf;
		
		ParticipantsRow = Participants.Add();
		ParticipantsRow.Contact = FillingData.Contact;
		
		If FillingData.Property("ValueCI") Then
			ParticipantsRow.HowToContact = FillingData.ValueCI;
		EndIf;
		
	EndIf;
	
	If FillingData.EventType = Enums.EventTypes.PhoneCall
		And FillingData.Property("PhoneNumber") Then
		
		ThisObject.Content = StrTemplate(NStr("ru='Звонок с номера: %1.'; en = 'Call from number:%1.'"), FillingData.PhoneNumber);
	EndIf;
	
	If Not FillingData.Property("FillingBasis") Then
		// Create a new event without basis
		FillByDefault();
		Return;
	EndIf;
	
	If TypeOf(FillingData.FillingBasis) = Type("CatalogRef.Counterparties") Then
		
		FillByCounterparty(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("CatalogRef.ContactPersons") Then
		
		FillByContactPerson(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.Event") Then
		
		FillByEvent(FillingData);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.WorkOrder") Then
		
		FillByWorkOrder(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.CustomerOrder") Then
		
		FillByCustomerOrder(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.ProductionOrder") Then
		
		FillByProductionOrder(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("DocumentRef.SettlementsReconciliation") Then
		
		FillBySettlementsReconciliation(FillingData.FillingBasis);
		
	ElsIf TypeOf(FillingData.FillingBasis) = Type("Structure") Then
		
		FillByStructure(FillingData.FillingBasis);
		
	ElsIf AvailableTypeForGeneratingOnBase(FillingData.FillingBasis) Then
		
		BasisDocuments.Clear();
		If EventType = Enums.EventTypes.Email Then
			BasisDocumentsRow = BasisDocuments.Add();
			BasisDocumentsRow.BasisDocument = FillingData.FillingBasis;
		Else
			BasisDocument = FillingData.FillingBasis;
		EndIf;
		
		Participants.Clear();
		ParticipantsRow = Participants.Add();
		ParticipantsRow.Contact = FillingData.FillingBasis.Counterparty;
		FillHowToContact();
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillByStructure(FillingBasis)
	
	FillPropertyValues(ThisObject, FillingBasis);
	
	If FillingBasis.Property("Basis")
		And TypeOf(FillingBasis.Basis)= Type("DocumentRef.WorkOrder") Then
		
		FillByCurrentRowWorkOrder(FillingBasis);
		Return;
		
	EndIf;
	
	If FillingBasis.Property("BasisDocument")
		And AvailableTypeForGeneratingOnBase(FillingBasis.BasisDocument) Then
		
		BasisDocuments.Clear();
		If EventType = Enums.EventTypes.Email Then
			BasisDocumentsRow = BasisDocuments.Add();
			BasisDocumentsRow.BasisDocument = FillingBasis.BasisDocument;
		Else
			BasisDocument = FillingBasis.BasisDocument;
		EndIf;
		
	EndIf;
	
	If FillingBasis.Property("Contact") And ValueIsFilled(FillingBasis.Contact) Then
		
		Participants.Clear();
		
		If TypeOf(FillingBasis.Contact) = Type("CatalogRef.ContactPersons") Then
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact = FillingBasis.Contact.Owner;
		EndIf;
		
		ParticipantsRow = Participants.Add();
		ParticipantsRow.Contact = FillingBasis.Contact;
		
		FillHowToContact();
		
	EndIf;
	
EndProcedure

Procedure FillByCounterparty(Counterparty)
	
	If Counterparty.IsFolder Then
		Raise NStr("ru = 'Нельзя выбирать группу контрагентов.'; en = 'You can not select a group of counterparties.'");
	EndIf;
	
	Participants.Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactPersons.Ref
		|FROM
		|	Catalog.ContactPersons AS ContactPersons
		|WHERE
		|	ContactPersons.Owner = &Owner
		|	AND ContactPersons.DeletionMark = FALSE
		|
		|ORDER BY
		|	ContactPersons.Description";
	
	Query.SetParameter("Owner", Counterparty);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ParticipantsRow	= Participants.Add();
		ParticipantsRow.Contact	= Selection.Ref;
	EndDo;
	
	RowParticipants = Participants.Insert(0);
	RowParticipants.Contact = Counterparty;
	FillHowToContact();
	
EndProcedure

Procedure FillByContactPerson(ContactPerson)
	
	Participants.Clear();
	
	TypesCI = New Array;
	If Not EventType = Enums.EventTypes.SMS Then
		TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	If Not EventType = Enums.EventTypes.Email Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CASE
		|		WHEN CounterpartiesContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			THEN 1
		|		ELSE 2
		|	END AS Order,
		|	CounterpartiesContactInformation.Presentation
		|FROM
		|	Catalog.Counterparties.ContactInformation AS CounterpartiesContactInformation
		|WHERE
		|	CounterpartiesContactInformation.Ref = &Counterparty
		|	AND CounterpartiesContactInformation.Type IN(&TypesCI)
		|
		|ORDER BY
		|	Order,
		|	CounterpartiesContactInformation.LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CASE
		|		WHEN ContactPersonsContactInformation.Type = VALUE(Enum.ContactInformationTypes.Phone)
		|			THEN 1
		|		ELSE 2
		|	END AS Order,
		|	ContactPersonsContactInformation.Presentation
		|FROM
		|	Catalog.ContactPersons.ContactInformation AS ContactPersonsContactInformation
		|WHERE
		|	ContactPersonsContactInformation.Ref = &ContactPerson
		|	AND ContactPersonsContactInformation.Type IN(&TypesCI)
		|
		|ORDER BY
		|	Order,
		|	ContactPersonsContactInformation.LineNumber";
	
	Query.SetParameter("Counterparty", ContactPerson.Owner);
	Query.SetParameter("ContactPerson", ContactPerson);
	Query.SetParameter("TypesCI", TypesCI);
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[0].Select();
	HowToContact = "";
	
	While Selection.Next() Do
		HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + Selection.Presentation;
	EndDo;
	
	RowParticipants = Participants.Add();
	RowParticipants.Contact = ContactPerson.Owner;
	RowParticipants.HowToContact = HowToContact;
	
	Selection = ResultsArray[1].Select();
	HowToContact = "";
	
	While Selection.Next() Do
		HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + Selection.Presentation;
	EndDo;
	
	RowParticipants = Participants.Add();
	RowParticipants.Contact = ContactPerson;
	RowParticipants.HowToContact = HowToContact;
	
EndProcedure

Procedure FillByEvent(FillingData)
	
	Participants.Clear();
	
	// Filling participants
	If CommonUseClientServer.StructureProperty(
		FillingData,
		"Command",
		EmailSBClientServer.CommandReply()) = EmailSBClientServer.CommandReply() Then
		
		Query = New Query(
		"SELECT
		|	EventParticipants.Contact AS Contact,
		|	EventParticipants.HowToContact AS HowToContact
		|FROM
		|	Document.Event.Participants AS EventParticipants
		|WHERE
		|	EventParticipants.Ref = &Ref
		|
		|ORDER BY
		|	EventParticipants.LineNumber");
		
		Query.SetParameter("Ref", FillingData.FillingBasis);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact			= Selection.Contact;
			ParticipantsRow.HowToContact	= Selection.HowToContact;
		EndDo;
		
	EndIf;
		
	// Filling of basis documents
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		BasisDocumentsRow = BasisDocuments.Add();
		BasisDocumentsRow.BasisDocument = FillingData.FillingBasis;
		FillEmailSubject(FillingData);
	Else
		BasisDocument = FillingData.FillingBasis;
	EndIf;
	
	UserAccount = CommonUse.ObjectAttributeValue(FillingData.FillingBasis, "UserAccount");
	
EndProcedure

Procedure FillBySettlementsReconciliation(FillingData)
	
	IncomingOutgoingEvent = Enums.IncomingOutgoingEvent.Outgoing;
	BasisDocument = FillingData.Ref;
	Counterparty = FillingData.Counterparty;
	
	Participants.Clear();
	If ValueIsFilled(BasisDocument.CounterpartyRepresentative) Then
		
		ContactPerson = BasisDocument.CounterpartyRepresentative;
		
		NewRow = Participants.Add();
		NewRow.Contact = ContactPerson;
		
		HowToContactPhone = ContactInformationManagement.GetObjectContactInformation(ContactPerson, Catalogs.ContactInformationKinds.ContactPersonPhone);
		HowToContactEmail = ContactInformationManagement.GetObjectContactInformation(ContactPerson, Catalogs.ContactInformationKinds.ContactPersonEmail);
		
		If IsBlankString(HowToContactPhone) Then
			NewRow.HowToContact = TrimAll(HowToContactEmail);
		ElsIf IsBlankString(HowToContactEmail) Then
			NewRow.HowToContact = TrimAll(HowToContactPhone);
		Else
			NewRow.HowToContact = TrimAll(HowToContactPhone) + "; " + TrimAll(HowToContactEmail);
		EndIf;
		
	EndIf;
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = BasisDocument;
	EndIf;
	
EndProcedure // FillBySettlementsReconciliation()

Procedure FillByWorkOrder(WorkOrder)
	
	Participants.Clear();
	
	// Filling out a document header.
	Query = New Query;
	Query.SetParameter("Ref", WorkOrder);
	
	Query.Text =
	"SELECT TOP 1
	|	CASE
	|		WHEN VALUETYPE(Works.Customer) = TYPE(Catalog.Counterparties)
	|			THEN Works.Customer
	|		WHEN VALUETYPE(Works.Customer) = TYPE(Catalog.CounterpartyContracts)
	|			THEN Works.Customer.Owner
	|		WHEN VALUETYPE(Works.Customer) = TYPE(Document.CustomerOrder)
	|			THEN Works.Customer.Counterparty
	|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
	|	END AS Counterparty,
	|	Works.BeginTime AS EventBegin,
	|	Works.EndTime AS EventEnding,
	|	Works.Day AS Day
	|FROM
	|	Document.WorkOrder.Works AS Works
	|WHERE
	|	Works.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
		If ValueIsFilled(Selection.Counterparty) Then
			ParticipantsRow = Participants.Add();
			ParticipantsRow.Contact = Selection.Counterparty;
			FillHowToContact();
		EndIf;
		
	EndIf;
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = WorkOrder;
	Else
		BasisDocument = WorkOrder;
	EndIf;
	
EndProcedure // FillByWorkOrder()

Procedure FillByCustomerOrder(CustomerOrder)
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = CustomerOrder;
	Else
		BasisDocument = CustomerOrder;
	EndIf;
	Project = CustomerOrder.Project;
	
	Participants.Clear();
	RowParticipants = Participants.Add();
	RowParticipants.Contact = CustomerOrder.Counterparty;
	FillHowToContact();
	
EndProcedure // FillByCustomerOrder()

Procedure FillByProductionOrder(ProductionOrder)
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		BasisDocumentsRow = BasisDocuments.Add();
		BasisDocumentsRow.BasisDocument = ProductionOrder;
	Else
		BasisDocument = ProductionOrder;
	EndIf;
	
	If EventType <> Enums.EventTypes.Email
		И EventType <> Enums.EventTypes.SMS Then
		
		EventBegin	= ProductionOrder.Start;
		EventEnding	= ProductionOrder.Finish;
	EndIf;
	
EndProcedure

Procedure FillByCurrentRowWorkOrder(FillingStructure)
	
	Participants.Clear();
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = FillingStructure.Basis;
	Else
		BasisDocument = FillingStructure.Basis;
	EndIf;
	
	If TypeOf(FillingStructure.Customer) = Type("CatalogRef.Counterparties") Then
		RowParticipants = Participants.Add();
		RowParticipants.Contact = FillingStructure.Customer;
	ElsIf TypeOf(FillingStructure.Customer) = Type("CatalogRef.CounterpartyContracts") Then
		RowParticipants = Participants.Add();
		RowParticipants.Contact = FillingStructure.Customer.Owner;
	ElsIf TypeOf(FillingStructure.Customer) = Type("DocumentRef.CustomerOrder") Then
		RowParticipants = Participants.Add();
		RowParticipants.Contact = FillingStructure.Customer.Counterparty;
	EndIf;
	
	If RowParticipants <> Undefined And ValueIsFilled(RowParticipants.Contact) Then
		FillHowToContact();
	EndIf;
	
	EventBegin	= FillingStructure.EventBegin;
	EventEnding	= FillingStructure.EventEnding;
	
	Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	
EndProcedure // FillByCurrentRowWorkOrders()

Procedure FillHowToContact()
	
	Counterparties = Participants.UnloadColumn("Contact");
	CommonUseClientServer.DeleteAllTypeOccurrencesFromArray(Counterparties, Type("String"));
	ContactPersons = CommonUseClientServer.CopyArray(Counterparties);
	CommonUseClientServer.DeleteAllTypeOccurrencesFromArray(Counterparties, Type("CatalogRef.ContactPersons"));
	CommonUseClientServer.DeleteAllTypeOccurrencesFromArray(ContactPersons, Type("CatalogRef.Counterparties"));
	
	TypesCI = New Array;
	If Not EventType = Enums.EventTypes.SMS And Not EventType = Enums.EventTypes.PhoneCall Then
		TypesCI.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	If Not EventType = Enums.EventTypes.Email Then
		TypesCI.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	If Counterparties.Count() > 0 Then
		TableCI_Counterparties = ContactInformationManagement.ObjectsContactInformation(Counterparties, TypesCI);
		TableCI_Counterparties.Sort("Object Asc, Type Desc");
	EndIf;
	
	If ContactPersons.Count() > 0 Then
		TableCI_ContactPersons = ContactInformationManagement.ObjectsContactInformation(ContactPersons, TypesCI);
		TableCI_ContactPersons.Sort("Object Asc, Type Desc");
	EndIf;
	
	Filter = New Structure("Object");
	Index = 0;
	
	While Index <= Participants.Count()-1 Do
		
		CurRow = Participants[Index];
		Filter.Object = CurRow.Contact;
		RowsCI = New Array;
		
		If TypeOf(CurRow.Contact) = Type("CatalogRef.Counterparties") And TableCI_Counterparties <> Undefined And TableCI_Counterparties.Count() > 0 Then
			RowsCI = TableCI_Counterparties.FindRows(Filter);
		ElsIf TypeOf(CurRow.Contact) = Type("CatalogRef.ContactPersons") And TableCI_ContactPersons <> Undefined And TableCI_ContactPersons.Count() > 0 Then
			RowsCI = TableCI_ContactPersons.FindRows(Filter);
		EndIf;
		
		// For SMS, each phone on a new line
		// For other types of events, we display the contact information in one line
		
		If EventType = Enums.EventTypes.SMS Then
			FirstValueCI = True;
			For Each RowCI In RowsCI Do
				If Not FirstValueCI Then
					Index = Index + 1;
					CurRow = Participants.Insert(Index);
					CurRow.Contact = Filter.Object;
				EndIf;
				CurRow.HowToContact = RowCI.Presentation;
				FirstValueCI = False;
			EndDo;
		Else
			For Each RowCI In RowsCI Do
				CurRow.HowToContact = "" + CurRow.HowToContact + ?(CurRow.HowToContact = "", "", ", ") + RowCI.Presentation;
			EndDo;
		EndIf;
		
		Index = Index + 1;
		
	EndDo;
	
EndProcedure

Function AvailableTypeForGeneratingOnBase(DocBasis)
	
	Return CommonUse.IsObjectAttribute(
	"Counterparty",
	DocBasis.Metadata());
	
EndFunction

#EndRegion

#Region InterfaceEmployeeCalendar

Procedure FillByDefault()
	
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctionsEmail

Procedure FillEmailSubject(FillingData)
	
	EventAttributesValues = CommonUse.ObjectAttributesValues(FillingData.FillingBasis, "Subject, IncomingOutgoingEvent");
	If EventAttributesValues.IncomingOutgoingEvent <> Enums.IncomingOutgoingEvent.Incoming Then
		Return;
	EndIf;
	
	Subject = Documents.Event.SubjectWithResponsePrefix(
	EventAttributesValues.Subject,
	CommonUseClientServer.StructureProperty(
	FillingData,
	"Command",
	EmailSBClientServer.CommandReply()));

EndProcedure

Procedure FillPresentation()
	
	
EndProcedure

#EndRegion

#EndIf