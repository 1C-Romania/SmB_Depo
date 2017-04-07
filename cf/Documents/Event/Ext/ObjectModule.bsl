#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
// Parameters:
//  FillingData	 - Structure	 - For execution of the FillIn() method,
//  the structure should contain StandardProcessing - 	 - 
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("EventType") Then
	// Opening the preform of event type selection
		Return;
	EndIf;
	
	EventType = FillingData.EventType;
	
	If Not EventType = Enums.EventTypes.Email AND Not EventType = Enums.EventTypes.SMS Then
		If FillingData.Property("EventBegin") Then
			EventBegin = FillingData.EventBegin;
		Else
			EventBegin = CurrentDate();
		EndIf;
		If FillingData.Property("EventEnding") Then
			EventEnding = FillingData.EventEnding;
		Else
			EventEnding = EventBegin + 1800;
		EndIf;
		FillingData.Property("Responsible", Responsible);
	EndIf;
	
	If Not FillingData.Property("FillBasis") Then
	// Creating a new event without a basis
		Return;
	EndIf;
	
	If TypeOf(FillingData.FillBasis) = Type("CatalogRef.Counterparties") Then
		
		If FillingData.FillBasis.IsFolder Then
			Raise NStr("en='Unable to select counterparty group.';ru='Нельзя выбирать группу контрагентов.'");
		EndIf;
		
		FillInByCounterparty(FillingData.FillBasis);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("CatalogRef.ContactPersons") Then
		FillByContactPersons(FillingData.FillBasis);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("DocumentRef.Event") Then
		FillByEvent(FillingData.FillBasis);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("DocumentRef.WorkOrder") Then
		FillByJobOrder(FillingData.FillBasis);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("DocumentRef.CustomerOrder") Then
		FillByCustomerOrder(FillingData.FillBasis);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("DocumentRef.SettlementsReconciliation") Then
		FillBySettlementsReconciliation(FillingData.FillBasis);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("Structure")
		AND FillingData.FillBasis.Property("Basis")
		AND TypeOf(FillingData.FillBasis.Basis)= Type("DocumentRef.WorkOrder") Then
		FillByCurrentRowWorkOrders(FillingData.FillBasis);
		
	ElsIf CheckTypeOfFillingData(FillingData.FillBasis) Then
		
		BasisDocuments.Clear();
		If EventType = Enums.EventTypes.Email Then
			RowDocumentsBases = BasisDocuments.Add();
			RowDocumentsBases.BasisDocument = FillingData.FillBasis.Ref;
		Else
			BasisDocument = FillingData.FillBasis.Ref;
		EndIf;
		
		Parties.Clear();
		RowParticipants = Parties.Add();
		RowParticipants.Contact = FillingData.FillBasis.Counterparty;
		RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("Structure")
		AND FillingData.FillBasis.Property("BasisDocument") 
		AND CheckTypeOfFillingData(FillingData.FillBasis.BasisDocument) Then
		
		BasisDocuments.Clear();
		If EventType = Enums.EventTypes.Email Then
			RowDocumentsBases = BasisDocuments.Add();
			RowDocumentsBases.BasisDocument = FillingData.FillBasis.BasisDocument;
		Else
			BasisDocument = FillingData.FillBasis.BasisDocument;
		EndIf;
		
		Parties.Clear();
		RowParticipants = Parties.Add();
		RowParticipants.Contact = FillingData.FillBasis.BasisDocument.Counterparty;
		RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
		
	ElsIf TypeOf(FillingData.FillBasis) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData.FillBasis);
		
		If FillingData.FillBasis.Property("Counterparty") AND ValueIsFilled(FillingData.FillBasis.Counterparty) Then
			Parties.Clear();
			RowParticipants = Parties.Add();
			RowParticipants.Contact = FillingData.FillBasis.Counterparty;
			RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
		EndIf;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	MembersList = "";
	For Each Participant IN Parties Do
		MembersList = MembersList + ?(MembersList = "","","; ")
			+ Participant.Contact + ?(IsBlankString(Participant.HowToContact), "", " <" + Participant.HowToContact + ">");
	EndDo;
	
EndProcedure // BeforeWrite()

// Procedure - event handler  AtCopy.
//
Procedure OnCopy(CopiedObject)
	
	If EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS Then
		EventBegin = '00010101';
		EventEnding = '00010101';
	Else
		EventBegin = CurrentDate();
		EventBegin = BegOfHour(EventBegin) + ?(Minute(EventBegin) < 30, 1800, 3600);
		EventEnding = EventBegin + 1800;
	EndIf;
	
EndProcedure // OnCopy()

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If EventEnding < EventBegin Then
		CommonUseClientServer.MessageToUser(
			NStr("en='End date can not be less than start date.';ru='Дата окончания не может быть меньше даты начала.'"),
			ThisObject,
			"EndDate",
			,
			Cancel
		);
	EndIf;
	
	// For the form of other events its own table of contacts is implemented
	If Not (EventType = Enums.EventTypes.Email Or EventType = Enums.EventTypes.SMS) Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Parties.Contact"));
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndRegion

#Region FillProceduresAndFunctions

// The procedure of document completion on the basis of a counterparty.
//
// Parameters:
// Counterparty - CatalogRef.Counterparties - counterparty.
//	
Procedure FillInByCounterparty(Counterparty)
	
	Parties.Clear();
	
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
		RowParticipants = Parties.Add();
		RowParticipants.Contact = Selection.Ref;
		RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
	EndDo;
	
	RowParticipants = Parties.Insert(0);
	RowParticipants.Contact = Counterparty;
	RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
	
EndProcedure // FillByContactPersons()

// The procedure of document completion on the basis of a contact person.
//
// Parameters:
// ContactPerson	 - CatalogRef.ContactPersons - contact person.
//	
Procedure FillByContactPersons(ContactPerson)
	
	Parties.Clear();
	
	CITypes = New Array;
	If Not EventType = Enums.EventTypes.SMS Then
		CITypes.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	If Not EventType = Enums.EventTypes.Email Then
		CITypes.Add(Enums.ContactInformationTypes.Phone);
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
		|	AND CounterpartiesContactInformation.Type IN(&CITypes)
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
		|	AND ContactPersonsContactInformation.Type IN(&CITypes)
		|
		|ORDER BY
		|	Order,
		|	ContactPersonsContactInformation.LineNumber";
	
	Query.SetParameter("Counterparty", ContactPerson.Owner);
	Query.SetParameter("ContactPerson", ContactPerson);
	Query.SetParameter("CITypes", CITypes);
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[0].Select();
	HowToContact = "";
	
	While Selection.Next() Do
		HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + Selection.Presentation;
	EndDo;
	
	RowParticipants = Parties.Add();
	RowParticipants.Contact = ContactPerson.Owner;
	RowParticipants.HowToContact = HowToContact;
	
	Selection = ResultsArray[1].Select();
	HowToContact = "";
	
	While Selection.Next() Do
		HowToContact = HowToContact + ?(HowToContact = "", "", ", ") + Selection.Presentation;
	EndDo;
	
	RowParticipants = Parties.Add();
	RowParticipants.Contact = ContactPerson;
	RowParticipants.HowToContact = HowToContact;
	
EndProcedure // FillByContactPersons()

// The procedure of document completion on the basis of an event.
//
// Parameters:
// Event - DocumentRef.Event - Event
//	
Procedure FillByEvent(Event)
	
	Parties.Clear();
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	EventParties.Ref,
		|	EventParties.Contact,
		|	EventParties.HowToContact
		|FROM
		|	Document.Event.Parties AS EventParties
		|WHERE
		|	EventParties.Ref = &Ref
		|
		|ORDER BY
		|	EventParties.LineNumber";
		
	Query.SetParameter("Ref", Event);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		RowParticipants = Parties.Add();
		FillPropertyValues(RowParticipants, Selection);
	EndDo;
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = Event;
	Else
		BasisDocument = Event;
	EndIf;
	
EndProcedure // FillByEvent()

// The procedure of document completion on the basis of settlements reconciliation.
//
Procedure FillBySettlementsReconciliation(FillingData)
	
	IncomingOutgoingEvent = Enums.IncomingOutgoingEvent.Outgoing;
	BasisDocument = FillingData.Ref;
	Counterparty = FillingData.Counterparty;
	
	Parties.Clear();
	If ValueIsFilled(BasisDocument.CounterpartyRepresentative) Then
		
		ContactPerson = BasisDocument.CounterpartyRepresentative;
		
		NewRow = Parties.Add();
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

// The procedure of document completion on the basis of a work order.
//
// Parameters:
// WorkOrder - DocumentRef.WorkOrder. - job.
//	
Procedure FillByJobOrder(WorkOrder)
	
	Parties.Clear();
	
	// Filling out a document header.
	Query = New Query;
	Query.SetParameter("Ref", WorkOrder);
	
	Query.Text =
	"SELECT TOP 1
	|	CASE
	|		WHEN VALUETYPE(Works.Customer) = Type(Catalog.Counterparties)
	|			THEN Works.Customer
	|		WHEN VALUETYPE(Works.Customer) = Type(Catalog.CounterpartyContracts)
	|			THEN Works.Customer.Owner
	|		WHEN VALUETYPE(Works.Customer) = Type(Document.CustomerOrder)
	|			THEN Works.Customer.Counterparty
	|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
	|	END AS Counterparty,
	|	Works.BeginTime AS BeginTime,
	|	Works.EndTime AS EndTime,
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
		
		EventBegin = BegOfDay(Selection.Day) + Hour(Selection.BeginTime) * 60 * 60 + Minute(Selection.BeginTime) * 60;
		EventEnding = BegOfDay(Selection.Day) + Hour(Selection.EndTime) * 60 * 60 + Minute(Selection.EndTime) * 60;
		
		RowParticipants = Parties.Add();
		RowParticipants.Contact = Selection.Counterparty;
		RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
		
	EndIf;
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = WorkOrder;
	Else
		BasisDocument = WorkOrder;
	EndIf;
	
EndProcedure // FillByJobOrder()

// Procedure of document filling based on customer order.
//
// Parameters:
// CustomerOrder - DocumentRef.CustomerOrder - customer order.
//	
Procedure FillByCustomerOrder(CustomerOrder)
	
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = CustomerOrder;
	Else
		BasisDocument = CustomerOrder;
	EndIf;
	Project = CustomerOrder.Project;
	
	Parties.Clear();
	RowParticipants = Parties.Add();
	RowParticipants.Contact = CustomerOrder.Counterparty;
	RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
	
EndProcedure // FillByCustomerOrder()

// The procedure of document completion on the basis of a work order.
//
// Parameters:
// FillStructure - structure - structure with filling data.
//	
Procedure FillByCurrentRowWorkOrders(FillStructure)
	
	Parties.Clear();
	BasisDocuments.Clear();
	If EventType = Enums.EventTypes.Email Then
		RowDocumentsBases = BasisDocuments.Add();
		RowDocumentsBases.BasisDocument = FillStructure.Basis;
	Else
		BasisDocument = FillStructure.Basis;
	EndIf;
	
	If TypeOf(FillStructure.Customer) = Type("CatalogRef.Counterparties") Then
		RowParticipants = Parties.Add();
		RowParticipants.Contact = FillStructure.Customer;
	ElsIf TypeOf(FillStructure.Customer) = Type("CatalogRef.CounterpartyContracts") Then
		RowParticipants = Parties.Add();
		RowParticipants.Contact = FillStructure.Customer.Owner;
	ElsIf TypeOf(FillStructure.Customer) = Type("DocumentRef.CustomerOrder") Then
		RowParticipants = Parties.Add();
		RowParticipants.Contact = FillStructure.Customer.Counterparty;
	EndIf;
	
	If RowParticipants <> Undefined AND ValueIsFilled(RowParticipants.Contact) Then
		RowParticipants.HowToContact = GetHowToContact(RowParticipants.Contact, EventType);
	EndIf;
	
	EventBegin = BegOfDay(FillStructure.Day) + Hour(FillStructure.BeginTime) * 60 * 60 + Minute(FillStructure.BeginTime) * 60;
	EventEnding = BegOfDay(FillStructure.Day) + Hour(FillStructure.EndTime) * 60 * 60 + Minute(FillStructure.EndTime) * 60;
	
	Responsible = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	
EndProcedure // FillByCurrentRowWorkOrders()

// The function checks the value type of the basis document.
//
Function CheckTypeOfFillingData(BasisDocument)
	
	If TypeOf(BasisDocument) = Type("DocumentRef.PurchaseOrder")
		OR TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoice")
		OR TypeOf(BasisDocument) = Type("DocumentRef.CustomerInvoice")
		OR TypeOf(BasisDocument) = Type("DocumentRef.InvoiceForPayment")
		OR TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoiceForPayment")
		OR TypeOf(BasisDocument) = Type("DocumentRef.PaymentExpense")
		OR TypeOf(BasisDocument) = Type("DocumentRef.CashPayment")
		OR TypeOf(BasisDocument) = Type("DocumentRef.PaymentReceipt")
		OR TypeOf(BasisDocument) = Type("DocumentRef.CashReceipt")
		OR TypeOf(BasisDocument) = Type("DocumentRef.PaymentOrder")
		OR TypeOf(BasisDocument) = Type("DocumentRef.AgentReport")
		OR TypeOf(BasisDocument) = Type("DocumentRef.ReportToPrincipal")
		OR TypeOf(BasisDocument) = Type("DocumentRef.ProcessingReport")
		OR TypeOf(BasisDocument) = Type("DocumentRef.SubcontractorReport")
		OR TypeOf(BasisDocument) = Type("DocumentRef.AcceptanceCertificate") Then
		
		Return True
		
	EndIf;
	
	Return False;
	
EndFunction // CheckValueTypeFillingData(BasisDoc)

// The function receives the value of "how to contact" attribute.
//
// Parameters:
//  Contact				 - CatalogRef.Counterparties, CatalogRef.ContactPersons	 - reference
// to the contact Return value:
//  String - value to connect with contact
Function GetHowToContact(Contact, DocumentEventType)
	
	Result = "";
	
	Contacts = New Array;
	Contacts.Add(Contact);
	
	CITypes = New Array;
	If Not DocumentEventType = Enums.EventTypes.SMS Then
		CITypes.Add(Enums.ContactInformationTypes.EmailAddress);
	EndIf;
	If Not DocumentEventType = Enums.EventTypes.Email Then
		CITypes.Add(Enums.ContactInformationTypes.Phone);
	EndIf;
	
	CITable = ContactInformationManagement.ObjectsContactInformation(Contacts, CITypes);
	CITable.Sort("Type DESC");
	For Each CIRow IN CITable Do
		Result = "" + Result + ?(Result = "", "", ", ") + CIRow.Presentation;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf