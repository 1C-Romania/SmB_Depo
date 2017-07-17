////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR EXPORT

// The function checks whether it is necessary to transfer the data to this node
//
// Parameters:
//  The	data means an object, set of records, etc., which has to be checked.
// 		What is transferred everywhere
//  is not processed ExchangeNode - is the exchange plan node to which the data is transferred
//
// Returns:
//  Transfer - Boolean if True - then it is
// 		necessary to do the transfer, otherwise - the transfer is not needed
//
Function NeedTransferData(Data, ExchangeNode) Export
	
	Transfer = True;
	
	If TypeOf(Data) = Type("DocumentObject.CustomerOrder")
		OR TypeOf(Data) = Type("DocumentRef.CustomerOrder") Then
		
		User = Users.CurrentUser();
		
		FiltersForExportingsDocuments = GetFiltersForDocumentsInMobileApplicationExportings();
		
		// We check that the author of the document is the current user  
		If Data.Company <> FiltersForExportingsDocuments.MainCompany
		 OR Data.Date < FiltersForExportingsDocuments.ExportStartDate Then
			Transfer = False;
		EndIf;
		
		// If the responsible is filled, we export by it.
		If ValueIsFilled(FiltersForExportingsDocuments.MainResponsible)
		   AND ValueIsFilled(Data.Responsible) Then
			If Data.Responsible <> FiltersForExportingsDocuments.MainResponsible Then
				Transfer = False;
			EndIf;
		Else
			If Data.Author <> User Then
				Transfer = False;
			EndIf;
		EndIf;
		
		If Data.OperationKind <> Enums.OperationKindsCustomerOrder.OrderForSale Then
			Transfer = False;
		EndIf;
		
		If Data.OrderState.OrderStatus <> Enums.OrderStatuses.InProcess
		   AND Data.OrderState.OrderStatus <> Enums.OrderStatuses.Completed Then
			Transfer = False;
		EndIf;
		
		For Each CurRow IN Data.Inventory Do
			If CurRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
				Transfer = False;
				Break;
			EndIf;
		EndDo;
		
	ElsIf TypeOf(Data) = Type("CatalogObject.ProductsAndServices")
		OR TypeOf(Data) = Type("CatalogRef.ProductsAndServices")Then
		
		If Data.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem
		   AND Data.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.Service Then
			Transfer = False;
		EndIf;
		
	ElsIf TypeOf(Data) = Type("InformationRegisterRecordSet.ProductsAndServicesPrices") Then
		
		If Data.Filter.ProductsAndServices.Value.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.InventoryItem
		   AND Data.Filter.ProductsAndServices.Value.ProductsAndServicesType <> Enums.ProductsAndServicesTypes.Service Then
			Transfer = False;
		EndIf;
		
	EndIf;
	
	Return Transfer;
	
EndFunction // DataTransferIsRequired()

// Receives the XDTO object from the transferred configuration object.
//
Function GetXDTOObject(Data)
	
	PassedObject = Undefined;
	
	// Serialization of the Counterparties catalog.
	If TypeOf(Data) = Type("CatalogObject.Counterparties")
		OR TypeOf(Data) = Type("CatalogRef.Counterparties") Then
		
		PassedObject = CreateXDTOObject("CatContractors");
		PassedObject.Id = String(Data.Ref.UUID());
		PassedObject.Name = Data.Description;
		PassedObject.DeletionMark = Data.DeletionMark;
		If ValueIsFilled(Data.Parent) Then
			PassedObject.Group = GetXDTOObject(Data.Parent);
		EndIf;
		If Data.IsFolder Then
			PassedObject.IsFolder = True;
			Return PassedObject;
		Else
			PassedObject.IsFolder = False;
		EndIf;
		
		CounterpartyPostalAddress = "";
		CounterpartyLegalAddress = "";
		CounterpartyFactAddress = "";
		PassedObject.Tel = "";
		PassedObject.Fax = "";
		PassedObject.Email = "";
		PassedObject.Web = "";
		PassedObject.Adress = "";
		
		For Each CurRow IN Data.ContactInformation Do
			If CurRow.Type = Enums.ContactInformationTypes.Phone Then
				PassedObject.Tel = CurRow.Presentation;
			ElsIf CurRow.Type = Enums.ContactInformationTypes.Fax Then
				PassedObject.Fax = CurRow.Presentation;
			ElsIf CurRow.Type = Enums.ContactInformationTypes.Address
				AND CurRow.Type = Catalogs.ContactInformationKinds.CounterpartyPostalAddress Then
				CounterpartyPostalAddress = CurRow.Presentation;
			ElsIf CurRow.Type = Enums.ContactInformationTypes.Address
				AND CurRow.Type = Catalogs.ContactInformationKinds.CounterpartyLegalAddress Then
				CounterpartyLegalAddress = CurRow.Presentation;
			ElsIf CurRow.Type = Enums.ContactInformationTypes.Address
				AND CurRow.Type = Catalogs.ContactInformationKinds.CounterpartyFactAddress Then
				CounterpartyFactAddress = CurRow.Presentation;
			ElsIf CurRow.Type = Enums.ContactInformationTypes.EmailAddress Then
				PassedObject.Email = CurRow.Presentation;
			ElsIf CurRow.Type = Enums.ContactInformationTypes.WebPage Then
				PassedObject.Web = CurRow.Presentation;
			EndIf;
		EndDo;
		
		If Not IsBlankString(CounterpartyFactAddress) Then
			PassedObject.Adress = CounterpartyFactAddress;
		ElsIf Not IsBlankString(CounterpartyPostalAddress) Then
			PassedObject.Adress = CounterpartyPostalAddress;
		ElsIf Not IsBlankString(CounterpartyLegalAddress) Then
			PassedObject.Adress = CounterpartyLegalAddress;
		EndIf;
		
		PassedObject.AdditionalInfo = Data.Comment;
		PassedObject.ContactName = Data.ContactPerson.Description;
		
	// Serialization of the ProductsAndServices catalog.
	ElsIf TypeOf(Data) = Type("CatalogObject.ProductsAndServices")
		OR TypeOf(Data) = Type("CatalogRef.ProductsAndServices") Then
		
		PassedObject = CreateXDTOObject("CatItems");
		PassedObject.Id = String(Data.Ref.UUID());
		PassedObject.Name = Data.Description;
		PassedObject.DeletionMark = Data.DeletionMark;
		If ValueIsFilled(Data.Parent) Then
			PassedObject.Group = GetXDTOObject(Data.Parent);
		EndIf;
		If Data.IsFolder Then
			PassedObject.IsFolder = True;
			Return PassedObject;
		Else
			PassedObject.IsFolder = False;
		EndIf;
		PassedObject.Item = Data.SKU;
		If ValueIsFilled(Data.Vendor) Then
			PassedObject.Supplier = GetXDTOObject(Data.Vendor);
		EndIf;
		PassedObject.TypeItem = GetXDTOObject(Data.ProductsAndServicesType);
		
	// Serialization of the Customer Order document.
	ElsIf TypeOf(Data) = Type("DocumentObject.CustomerOrder")
		OR TypeOf(Data) = Type("DocumentRef.CustomerOrder") Then
	
		PassedObject = CreateXDTOObject("DocOrders");
		PassedObject.Id = String(Data.Ref.UUID());
		PassedObject.DeletionMark = Data.DeletionMark;
		PassedObject.Posted = Data.Posted;
		PassedObject.Name = Data.Number;
		PassedObject.Date = Data.Date;
		PassedObject.Comment = Data.Comment;
		If ValueIsFilled(Data.Counterparty) Then
			PassedObject.Buyer = GetXDTOObject(Data.Counterparty);
		EndIf;
		AddingRowsType = PassedObject.Properties().Get("Items").Type;
		AddingRows = XDTOFactory.Create(AddingRowsType);
		
		NeedToRecalculateAmounts = Data.DocumentCurrency <> Constants.NationalCurrency.Get();
		
		For Each TSRow IN Data.Inventory Do
			RowBeingAddedType = AddingRows.Properties().Get("Item").Type;
			RowBeingAdded = XDTOFactory.Create(RowBeingAddedType);
			If ValueIsFilled(TSRow.ProductsAndServices) Then
				RowBeingAdded.Nomenclature = GetXDTOObject(TSRow.ProductsAndServices);
			EndIf;
			If NeedToRecalculateAmounts Then
				RowBeingAdded.Price = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					TSRow.Price,
					Data.ExchangeRate,
					1,
					Data.Multiplicity,
					1
				);
				RowBeingAdded.Total = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
					TSRow.Amount,
					Data.ExchangeRate,
					1,
					Data.Multiplicity,
					1
				);
			Else
				RowBeingAdded.Price = TSRow.Price;
				RowBeingAdded.Total = TSRow.Amount;
			EndIf;
			RowBeingAdded.Quantity = TSRow.Quantity;
			AddingRows.Item.Add(RowBeingAdded);
		EndDo;
		
		PassedObject.Items = AddingRows;
		
		Query = New Query(
			"SELECT
			|	CASE
			|		WHEN ISNULL(CustomerOrdersBalanceAndTurnovers.QuantityReceipt, 0) <> 0
			|				AND ISNULL(CustomerOrdersBalanceAndTurnovers.QuantityExpense, 0) <> 0
			|				AND ISNULL(CustomerOrdersBalanceAndTurnovers.QuantityClosingBalance, 0) = 0
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS FullyShipped,
			|	CASE
			|		WHEN ISNULL(InvoicesAndOrdersPaymentTurnovers.AmountTurnover, 0) <= ISNULL(InvoicesAndOrdersPaymentTurnovers.PaymentAmountTurnover, 0) + ISNULL(InvoicesAndOrdersPaymentTurnovers.AdvanceAmountTurnover, 0)
			|			THEN TRUE
			|		ELSE FALSE
			|	END AS FullPaid,
			|	DocumentCustomerOrder.Ref
			|FROM
			|	Document.CustomerOrder AS DocumentCustomerOrder
			|		LEFT JOIN AccumulationRegister.CustomerOrders.BalanceAndTurnovers(, , Auto, , ) AS CustomerOrdersBalanceAndTurnovers
			|		ON DocumentCustomerOrder.Ref = CustomerOrdersBalanceAndTurnovers.CustomerOrder
			|		LEFT JOIN AccumulationRegister.InvoicesAndOrdersPayment.Turnovers AS InvoicesAndOrdersPaymentTurnovers
			|		ON DocumentCustomerOrder.Ref = InvoicesAndOrdersPaymentTurnovers.InvoiceForPayment
			|WHERE
			|	DocumentCustomerOrder.Ref = &Ref"
		);
		Query.SetParameter("Ref", Data.Ref);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			PassedObject.Shipped = Selection.FullyShipped;
			PassedObject.Paid = Selection.FullPaid;
		EndIf;
		
		If NeedToRecalculateAmounts Then
			PassedObject.Total = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
				Data.DocumentAmount,
				Data.ExchangeRate,
				1,
				Data.Multiplicity,
				1
			);
		Else
			PassedObject.Total = Data.DocumentAmount;
		EndIf;
		
	// Transformation of a Products and services type.
	ElsIf TypeOf(Data) = Type("EnumRef.ProductsAndServicesTypes") Then
		
		If Data = Enums.ProductsAndServicesTypes.InventoryItem Then
			PassedObject = "Product";
		Else
			PassedObject = "Service";
		EndIf;
		
	// Serialization of ProductsAndServices prices.
	ElsIf TypeOf(Data) = Type("InformationRegisterRecordSet.ProductsAndServicesPrices") Then
		
		If Data.Count() = 0 Then
			Return PassedObject;
		EndIf;
		
		PassedObject = CreateXDTOObject("Prices");
		RegisterDump = Data.Unload();
		
		If ValueIsFilled(RegisterDump[0].ProductsAndServices) Then
			PassedObject.Nomenclature = GetXDTOObject(RegisterDump[0].ProductsAndServices);
		Else
			Return Undefined;
		EndIf;
		PassedObject.Date = RegisterDump[0].Period;
		PassedObject.Price = RegisterDump[0].Price;
		
	// Serialization of prices object deletion.
	ElsIf TypeOf(Data) = Type("ObjectDeletion") Then
		
		PassedObject = CreateXDTOObject("ObjectDeletion");
		PassedObject.Id = String(Data.Ref.UUID());
		
		If TypeOf(Data.Ref) = Type("CatalogRef.Counterparties") Then
			PassedObject.Type = "CatContractors";
		ElsIf TypeOf(Data.Ref) = Type("CatalogRef.ProductsAndServices") Then
			PassedObject.Type = "CatItems";
		ElsIf TypeOf(Data.Ref) = Type("DocumentRef.CustomerOrder") Then
			PassedObject.Type = "DocOrders";
		EndIf;
		
	EndIf;
	
	Return PassedObject;
	
EndFunction // GetXDTOObject()

// The procedure writes data in
// the XML format The procedure analyses the transferred data object
// and based on this analysis writes it in a specific way to the XML format.
//
// Parameters:
//  XMLWriter	- object which writes
//  XML data Data 		- data to be recorded in the XML format
//
Procedure WriteData(ReturnedList, Data) Export
	
	XDTODataObject = GetXDTOObject(Data);
	If XDTODataObject <> Undefined Then
		ReturnedList.objects.Add(XDTODataObject);
	EndIf;
	
EndProcedure // WriteData()

// The procedure writes stock balance.
//
Procedure WriteBalance(ReturnedList, Data) Export
	
	Query = New Query(
		"SELECT
		|	InventoryBalances.ProductsAndServices,
		|	InventoryBalances.QuantityBalance,
		|	InventoryBalances.AmountBalance
		|FROM
		|	AccumulationRegister.Inventory.Balance AS InventoryBalances
		|WHERE
		|	InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
		|	AND InventoryBalances.QuantityBalance > 0"
	);
	Selection = Query.Execute().Select();
	
	PassedObject = CreateXDTOObject("Remains");

	While Selection.Next() Do
		RowBeingAddedType = PassedObject.Properties().Get("Item").Type;
		RowBeingAdded = XDTOFactory.Create(RowBeingAddedType);
		If ValueIsFilled(Selection.ProductsAndServices) Then
			RowBeingAdded.Nomenclature = GetXDTOObject(Selection.ProductsAndServices.GetObject());
		EndIf;
		RowBeingAdded.Quantity = Selection.QuantityBalance;
		RowBeingAdded.Total = Selection.AmountBalance;
		PassedObject.Item.Add(RowBeingAdded);
	EndDo;
	
	ReturnedList.objects.Add(PassedObject);
	
EndProcedure // WriteBalance()

// The procedure registers changes for all data included in
// the exchange plan Parameters:
//  ExchangeNode - exchange plan node, for which the changes are being registered
Procedure RecordChangesData(ExchangeNode) Export
	
	ExchangePlanContent = ExchangeNode.Metadata().Content;
	For Each ExchangePlanContentItem IN ExchangePlanContent Do
		
		If CommonUse.ThisIsDocument(ExchangePlanContentItem.Metadata) Then
			
			FullObjectName = ExchangePlanContentItem.Metadata.FullName();
			Selection = GetSampleDocumentsForRegistration(FullObjectName);
			
			While Selection.Next() Do
				
				ExchangePlans.RecordChanges(ExchangeNode, Selection.Ref);
				
			EndDo;
			
		Else
			
			ExchangePlans.RecordChanges(ExchangeNode, ExchangePlanContentItem.Metadata);
			
		EndIf;
		
	EndDo;
	
EndProcedure // RecordDataChanges()

// The function receives filtered results for documents exporting.
//
Function GetFiltersForDocumentsInMobileApplicationExportings()
	
	User = Users.CurrentUser();
	
	MainResponsible = SmallBusinessReUse.GetValueByDefaultUser(
		User,
		"MainResponsible"
	);
	
	MainCompany = SmallBusinessReUse.GetValueByDefaultUser(
		User,
		"MainCompany"
	);
	If Not ValueIsFilled(MainCompany) Then
		MainCompany = Catalogs.Companies.MainCompany;
	EndIf;
	
	MobileApplicationExportingsPeriod = SmallBusinessReUse.GetValueByDefaultUser(
		User,
		"MobileApplicationExportingsPeriod"
	);
	
	If MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.RecentMonth Then
		ExportStartDate = BegOfMonth(CurrentDate());
	ElsIf MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.RecentWeek Then
		ExportStartDate = BegOfWeek(CurrentDate());
	ElsIf MobileApplicationExportingsPeriod = Enums.ExportPeriodsInMobileApplication.RecentDay Then
		ExportStartDate = BegOfDay(CurrentDate());
	EndIf;
	
	FiltersForExportingsDocuments = New Structure;
	
	FiltersForExportingsDocuments.Insert("MainResponsible", MainResponsible);
	FiltersForExportingsDocuments.Insert("MainCompany", MainCompany);
	FiltersForExportingsDocuments.Insert("ExportStartDate", ExportStartDate);
	
	Return FiltersForExportingsDocuments;
	
EndFunction // GetFiltersForExportingDocumentsToMobileApplication()

// The function receives a sampling of documents corresponding to selection criteria.
//
Function GetSampleDocumentsForRegistration(FullObjectName)
	
	FiltersForExportingsDocuments = GetFiltersForDocumentsInMobileApplicationExportings();
	
	QueryText =
	"SELECT
	|	Table.Ref AS Ref
	|FROM
	|	[FullObjectName] AS Table
	|WHERE
	|	Table.Date >= &ExportStartDate
	|	AND Table.Company = &Company
	|	AND Table.Responsible = &Responsible
	|	AND (Table.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|			OR Table.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
		
	QueryText = StrReplace(QueryText, "[FullObjectName]", FullObjectName);
	
	Query = New Query;
	Query.SetParameter("ExportStartDate", FiltersForExportingsDocuments.ExportStartDate);
	Query.SetParameter("Company", FiltersForExportingsDocuments.MainCompany);
	Query.SetParameter("Responsible", FiltersForExportingsDocuments.MainResponsible);
	
	Query.Text = QueryText;
	
	Return Query.Execute().Select();
	
EndFunction // GetDocumentsSamplingForRegistration()

// The procedure adds the exchange message to the messages queue for transfer to the mobile client.
//
// Parameters
//  ExchangeMessage  - ValuesStorage - exchange message for inclusion in the queue.
//
Procedure AddMessageInQueueMessagesExchange(ExchangeNode, QueueMessageNumber, ExchangeMessage) Export
	
	RecordSet = InformationRegisters.MessagesExchangeWithMobileClientsQueues.CreateRecordSet();
	RecordSet.Filter.MobileClient.Set(ExchangeNode);
	RecordSet.Filter.MessageNo.Set(QueueMessageNumber);
	RecordSet.Read();
	
	// If a message with such number is already in the queue, we generate an exception.
	If RecordSet.Count() > 0 Then
		
		WriteLogEvent(
			NStr("en='Exchange with the mobile client. Add a message to the exchange message queue';ru='Обмен с мобильным клиентом.Добавление сообщения в очередь сообщений обмена'", CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,
			,
			ExchangeNode,
			NStr("ru = 'The queue of exchange messages has already a message with the number " + QueueMessageNumber + ".'"));
			
		// We set to zero the counters of received and sent messages for reregistration and sending all data at the next exchange.
		ReinitializeMessagesOnSiteCountersPlanExchange(ExchangeNode);
		
		Raise(NStr("en='Cannot send data. For more information, see the Infobase event log.';ru='Не удалось выполнить отправку данных. Подробности см. в Журнале регистрации информационной базы.'"));
		
	EndIf;
	
	NewRecord = RecordSet.Add();
	NewRecord.MobileClient = ExchangeNode;
	NewRecord.MessageNo = QueueMessageNumber;
	NewRecord.ExchangeMessage = ExchangeMessage;
	
	RecordSet.DataExchange.Load = True;
	RecordSet.Write(True);
	
EndProcedure // AddMessageInExchangeMessagesQueue()

// The procedure on the basis of data type analysis replaces
// it by data which removes information from the node in which it must not be
//
// Parameters:
//  The	data means an object, set of records, etc., which has to be converted
//
Procedure DeleteData(Data) Export
	
	// We get the metadata description object which correspods to the data.
	MetadataObject = ?(TypeOf(Data) = Type("ObjectDeletion"), Data.Ref.Metadata(), Data.Metadata());
	
	// We check the type, only the types implemented on a mobile platform are of interest.
	If Metadata.Catalogs.Contains(MetadataObject)
		OR Metadata.Documents.Contains(MetadataObject) Then
		
		// Transfer of object delete for object.
		Data = New ObjectDeletion(Data.Ref);
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject)
		OR Metadata.AccumulationRegisters.Contains(MetadataObject)
		OR Metadata.Sequences.Contains(MetadataObject) Then
		
		// We clear the data.
		Data.Clear();
		
	EndIf;
	
EndProcedure // DataDeletion()

// The function creates an object of the type transferred.
//
Function CreateXDTOObject(ObjectType) Export
	
	SetPrivilegedMode(True);
	Return XDTOFactory.Create(XDTOFactory.Type("http://www.1c.ru/SB/MobileExchange", ObjectType));
	
EndFunction // CreateXDTOObject()

Function GetXMLWriterForMessageExchange(ExchangeNode, WriteMessage)
	
	XMLWriter = New XMLWriter;
	
	XMLWriter.SetString("UTF-8");
	XMLWriter.WriteXMLDeclaration();
	
	WriteMessage = ExchangePlans.CreateMessageWriter();
	WriteMessage.BeginWrite(XMLWriter, ExchangeNode);
	
	XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
	XMLWriter.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
	
	Return XMLWriter;
	
EndFunction

// The procedure generates exchange messages from the registered data and adds them to the messages queue for transfer to a mobile client.
//
Procedure RegisteredDataInWriteQueueMessagesExchange(ExchangeNode, QueueMessageNumber) Export

	WriteMessage = Undefined;
	XMLWriter = GetXMLWriterForMessageExchange(ExchangeNode, WriteMessage);
	ChangeSelection = ExchangePlans.SelectChanges(ExchangeNode, WriteMessage.MessageNo);
	
	ReturnedList = CreateXDTOObject("Objects");
	
	Ct = 0;
	While ChangeSelection.Next() Do
		
		Ct = Ct + 1;
		If Ct >= 1000 Then
			
			XDTOFactory.WriteXML(XMLWriter, ReturnedList);
			WriteMessage.EndWrite();
			ExchangeMessage = New ValueStorage(XMLWriter.Close(), New Deflation(9));
			QueueMessageNumber = QueueMessageNumber + 1;
			ExchangeMobileApplicationOverridable.AddMessageInQueueMessagesExchange(ExchangeNode, QueueMessageNumber, ExchangeMessage);
			
			XMLWriter = GetXMLWriterForMessageExchange(ExchangeNode, WriteMessage);
			ReturnedList = CreateXDTOObject("Objects");
			
			Ct = 0;
			
		EndIf;
		
		Data = ChangeSelection.Get();
		
		// If a data transfer is not needed, then it may be required to record deletion of the data.
		If Not ExchangeMobileApplicationOverridable.NeedTransferData(Data, ExchangeNode) Then
			
			// We get the value with possible deletion of the data.
			DeleteData(Data);
			
		EndIf;
		
		ExchangeMobileApplicationOverridable.WriteData(ReturnedList, Data);
		
	EndDo;
	
	XDTOFactory.WriteXML(XMLWriter, ReturnedList);
	WriteMessage.EndWrite();
	ExchangeMessage = New ValueStorage(XMLWriter.Close(), New Deflation(9));
	QueueMessageNumber = QueueMessageNumber + 1;
	ExchangeMobileApplicationOverridable.AddMessageInQueueMessagesExchange(ExchangeNode, QueueMessageNumber, ExchangeMessage);

EndProcedure // WriteRegisteredDataInExchangeMessagesQueue()

// The rrocedure receives the balance and adds it to the messages queue for transfer to the mobile client.
//
Procedure WriteMessagesToQueueInBalanceOfExchange(ExchangeNode, QueueMessageNumber) Export

	Query = New Query(
		"SELECT
		|	InventoryBalances.ProductsAndServices,
		|	InventoryBalances.QuantityBalance,
		|	InventoryBalances.AmountBalance
		|FROM
		|	AccumulationRegister.Inventory.Balance AS InventoryBalances
		|WHERE
		|	InventoryBalances.CustomerOrder = VALUE(Document.CustomerOrder.EmptyRef)
		|	AND InventoryBalances.QuantityBalance > 0"
	);
	
	Result = Query.Execute();
	
	SelectionBalances = Result.Select();
	
	WriteMessage = Undefined;
	XMLWriter = GetXMLWriterForMessageExchange(ExchangeNode, WriteMessage);
	ChangeSelection = ExchangePlans.SelectChanges(ExchangeNode, WriteMessage.MessageNo);
	
	ReturnedList = CreateXDTOObject("Objects");
	PassedObject = CreateXDTOObject("Remains");
	
	Ct = 0;
	While SelectionBalances.Next() Do
		
		Ct = Ct + 1;
		If Ct >= 5000 Then
			
			ReturnedList.objects.Add(PassedObject);
			
			XDTOFactory.WriteXML(XMLWriter, ReturnedList);
			WriteMessage.EndWrite();
			ExchangeMessage = New ValueStorage(XMLWriter.Close(), New Deflation(9));
			QueueMessageNumber = QueueMessageNumber + 1;
			ExchangeMobileApplicationOverridable.AddMessageInQueueMessagesExchange(ExchangeNode, QueueMessageNumber, ExchangeMessage);
			
			XMLWriter = GetXMLWriterForMessageExchange(ExchangeNode, WriteMessage);
			ReturnedList = CreateXDTOObject("Objects");
			PassedObject = CreateXDTOObject("Remains");
			
			Ct = 0;
			
		EndIf;
		
		RowBeingAddedType = PassedObject.Properties().Get("Item").Type;
		RowBeingAdded = XDTOFactory.Create(RowBeingAddedType);
		If ValueIsFilled(SelectionBalances.ProductsAndServices) Then
			RowBeingAdded.Nomenclature = GetXDTOObject(SelectionBalances.ProductsAndServices.GetObject());
		EndIf;
		RowBeingAdded.Quantity = SelectionBalances.QuantityBalance;
		RowBeingAdded.Total = SelectionBalances.AmountBalance;
		PassedObject.Item.Add(RowBeingAdded);
		
	EndDo;
	
	ReturnedList.objects.Add(PassedObject);
	XDTOFactory.WriteXML(XMLWriter, ReturnedList);
	WriteMessage.EndWrite();
	ExchangeMessage = New ValueStorage(XMLWriter.Close(), New Deflation(9));
	QueueMessageNumber = QueueMessageNumber + 1;
	ExchangeMobileApplicationOverridable.AddMessageInQueueMessagesExchange(ExchangeNode, QueueMessageNumber, ExchangeMessage);

EndProcedure // WriteBalanceToExchangeMessagesQueue()

// The procedure checks the sequence of messages in the queue after the number of the last successfully accepted message.
Procedure ValidateQueueMessagesExchange(ExchangeNode, Val ReceivedNo) Export

	QueueMessageNumber = ReceivedNo + 1;
	
	Filter = New Structure("MobileClient", ExchangeNode);
	Order = "MessageNo Asc";
	SelectionMessagesExchange = InformationRegisters.MessagesExchangeWithMobileClientsQueues.Select(Filter, Order);
	
	While SelectionMessagesExchange.Next() Do
		
		If SelectionMessagesExchange.MessageNo < QueueMessageNumber Then
			
			Continue;
			
		ElsIf SelectionMessagesExchange.MessageNo > QueueMessageNumber Then
			
			WriteLogEvent(
				NStr("en='Exchange with the mobile client. Check exchange message queue';ru='Обмен с мобильным клиентом.Проверка очереди сообщений обмена'", CommonUseClientServer.MainLanguageCode()),
				EventLogLevel.Error,
				,
				SelectionMessagesExchange.MobileClient,
				NStr("en='Exchange message sequence is violated.';ru='Нарушен порядок следования сообщений обмена.'"));
				
			// We set to zero the counters of received and sent messages for reregistration and sending all data at the next exchange.
			ReinitializeMessagesOnSiteCountersPlanExchange(ExchangeNode);
			
			Raise(NStr("en='Cannot send data. For more information, see the Infobase event log.';ru='Не удалось выполнить отправку данных. Подробности см. в Журнале регистрации информационной базы.'"));
			
		EndIf;
		
		QueueMessageNumber = QueueMessageNumber + 1;
	EndDo;

EndProcedure

// Procedure calculates the amount in the row of tabular section.
//
Procedure CalculateAmountsInTabularSectionRow(Object, NewRow)
	
	If Object.VATTaxation <> Enums.VATTaxationTypes.TaxableByVAT Then
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
			NewRow.VATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			NewRow.VATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;
	ElsIf ValueIsFilled(NewRow.ProductsAndServices.VATRate) Then
		NewRow.VATRate = NewRow.ProductsAndServices.VATRate;
	Else
		NewRow.VATRate = Object.Company.DefaultVATRate;
	EndIf;
	
	VATRate = SmallBusinessReUse.GetVATRateValue(NewRow.VATRate);
	NewRow.VATAmount = ?(
		Object.AmountIncludesVAT,
		NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
		NewRow.Amount * VATRate / 100
	);
	NewRow.TotalAmount = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
	
EndProcedure // CalculateAmountInTabularSectionLine()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR LOADING

// The function receives the status of messages queue formation initiation for the mobile client.
//
Function QueueMessagesFormed(JobID, HasErrors) Export

	Try
		JobCompleted = LongActions.JobCompleted(JobID);
		Return JobCompleted;
	Except
	EndTry;
	
	HasErrors = True;
	Return False;

EndFunction // QueueFormationTaskIsCompletedSuccessfully()

// Receives an exchange message for the mobile client based on the message number.
//
Function GetMessageExchangeByNumber(ExchangeNode, MessageNumberExchange) Export

	Query = New Query;
	Query.Text = 
	"SELECT
	|	MessagesExchangeWithMobileClientsQueues.ExchangeMessage
	|FROM
	|	InformationRegister.MessagesExchangeWithMobileClientsQueues AS MessagesExchangeWithMobileClientsQueues
	|WHERE
	|	MessagesExchangeWithMobileClientsQueues.MobileClient = &MobileClient
	|	AND MessagesExchangeWithMobileClientsQueues.MessageNo = &MessageNo";
	
	Query.SetParameter("MobileClient", ExchangeNode);
	Query.SetParameter("MessageNo", MessageNumberExchange);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Selection = Result.Select();
	Selection.Next();
	
	Return Selection.ExchangeMessage;

EndFunction // GetExchangeMessageByNumber()

// The procedure loads objects in the infobase.
//
Procedure ImportObjects(ExchangeNode, Objects) Export
	
	DocumentsForDelayedPosting = New ValueTable;
	DocumentsForDelayedPosting.Columns.Add("DocumentRef");
	DocumentsForDelayedPosting.Columns.Add("DocumentType");
	
	BeginTransaction();
	
	If Objects <> Undefined Then
		For Each XDTODataObject IN Objects.objects Do
			If XDTODataObject.Type().Name = "CatContractors" Then
				FindCreateCounterparties(ExchangeNode, XDTODataObject);
			ElsIf XDTODataObject.Type().Name = "CatItems" Then
				FindCreateProductsAndServices(ExchangeNode, XDTODataObject);
			ElsIf XDTODataObject.Type().Name = "DocOrders" Then
				FoundCreateCustomerOrder(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting);
			ElsIf XDTODataObject.Type().Name = "DocInvoice" Then
				FindCreateCustomerInvoice(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting);
			ElsIf XDTODataObject.Type().Name = "DocPurshareInvoice" Then
				FindCreateSupplierInvoice(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting);
			ElsIf XDTODataObject.Type().Name = "DocIncomingPayment" Then
				FindCreateCashIncome(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting);
			ElsIf XDTODataObject.Type().Name = "DocOutgoingPayment" Then
				FindCreateCashExpense(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting);
			ElsIf XDTODataObject.Type().Name = "Prices" Then
				ImportPrices(ExchangeNode, XDTODataObject);
			ElsIf XDTODataObject.Type().Name = "ObjectDeletion" Then
				MarkObjectForDeletion(ExchangeNode, XDTODataObject);
			EndIf;
		EndDo;
	EndIf;
	
	CommitTransaction();
	
	RunDelayedDocumentPosting(ExchangeNode, DocumentsForDelayedPosting);
	
EndProcedure // ImportObjects()

// Function finds / generates a counterparty.
//
Function FindCreateCounterparties(ExchangeNode, XDTODataObject)
	
	If XDTODataObject = Undefined Then
		Return Catalogs.Counterparties.EmptyRef();
	EndIf;
	
	ID = New UUID(XDTODataObject.Id);
	Ref = Catalogs.Counterparties.GetRef(ID);
	Object = Ref.GetObject();
	IsNew = False;
	If Object = Undefined Then
		If XDTODataObject.IsFolder Then
			Object = Catalogs.Counterparties.CreateFolder();
		Else
			Object = Catalogs.Counterparties.CreateItem();
		EndIf;
		Object.SetNewObjectRef(Ref);
		Object.SetNewCode();
		Object.Write();
		IsNew = True;
	EndIf;
	
	If Not IsNew Then
		Return Object.Ref;
	EndIf;
	
	NeedToWriteObject = False;
	If Object.Description <> XDTODataObject.Name Then
		Object.Description = XDTODataObject.Name;
		NeedToWriteObject = True;
	EndIf;
	
	Parent = FindCreateCounterparties(ExchangeNode, XDTODataObject.Group);
	If Object.Parent <> Parent Then
		Object.Parent = Parent;
		NeedToWriteObject = True;
	EndIf;
	If Object.Comment <> XDTODataObject.AdditionalInfo
		AND Not Object.IsFolder Then
		Object.Comment = XDTODataObject.AdditionalInfo;
		NeedToWriteObject = True;
	EndIf;
	If Not Object.IsFolder Then
		If Not ValueIsFilled(Object.DescriptionFull) Then
			Object.DescriptionFull = Object.Description;
			NeedToWriteObject = True;
		EndIf;
		If Not ValueIsFilled(Object.LegalEntityIndividual) Then
			Object.LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity;
			NeedToWriteObject = True;
		EndIf;
		If Not ValueIsFilled(Object.Responsible) Then
			MainResponsible = SmallBusinessReUse.GetValueByDefaultUser(
				Users.CurrentUser(),
				"MainResponsible"
			);
			Object.Responsible = MainResponsible;
			NeedToWriteObject = True;
		EndIf;
		If Not ValueIsFilled(Object.GLAccountCustomerSettlements) Then
			Object.GLAccountCustomerSettlements = ChartsOfAccounts.Managerial.AccountsReceivable;
			NeedToWriteObject = True;
		EndIf;
		If Not ValueIsFilled(Object.CustomerAdvancesGLAccount) Then
			Object.CustomerAdvancesGLAccount = ChartsOfAccounts.Managerial.AccountsByAdvancesReceived;
			NeedToWriteObject = True;
		EndIf;
		If Not ValueIsFilled(Object.GLAccountVendorSettlements) Then
			Object.GLAccountVendorSettlements = ChartsOfAccounts.Managerial.AccountsPayable;
			NeedToWriteObject = True;
		EndIf;
		If Not ValueIsFilled(Object.VendorAdvancesGLAccount) Then
			Object.VendorAdvancesGLAccount = ChartsOfAccounts.Managerial.SettlementsByAdvancesIssued;
			NeedToWriteObject = True;
		EndIf;
		If IsNew Then
			Object.DoOperationsByContracts = True;
			Object.DoOperationsByDocuments = True;
			Object.DoOperationsByOrders = True;
			Object.TrackPaymentsByBills = True;
			NeedToWriteObject = True;
		EndIf;
		If ValueIsFilled(XDTODataObject.Adress) Then
			FoundAddressString = False;
			For Each CurRow IN Object.ContactInformation Do
				If CurRow.Type = Enums.ContactInformationTypes.Address
				   AND CurRow.Type = Catalogs.ContactInformationKinds.CounterpartyFactAddress Then
					FoundAddressString = True;
					If CurRow.Presentation <> XDTODataObject.Adress Then
						CurRow.Presentation = XDTODataObject.Adress;
						NeedToWriteObject = True;
					EndIf;
				EndIf;
			EndDo;
			If Not FoundAddressString Then
				NewRow = Object.ContactInformation.Add();
				NewRow.Type = Enums.ContactInformationTypes.Address;
				NewRow.Type = Catalogs.ContactInformationKinds.CounterpartyFactAddress;
				NewRow.Presentation = XDTODataObject.Adress;
				NeedToWriteObject = True;
			EndIf;
		EndIf;
		If ValueIsFilled(XDTODataObject.Tel) Then
			FoundString = False;
			For Each CurRow IN Object.ContactInformation Do
				If CurRow.Type =  Enums.ContactInformationTypes.Phone
				   AND CurRow.Type = Catalogs.ContactInformationKinds.CounterpartyPhone Then
					FoundString = True;
					If CurRow.Presentation <> XDTODataObject.Tel Then
						CurRow.Presentation = XDTODataObject.Tel;
						NeedToWriteObject = True;
					EndIf;
				EndIf;
			EndDo;
			If Not FoundString Then
				NewRow = Object.ContactInformation.Add();
				NewRow.Type = Enums.ContactInformationTypes.Phone;
				NewRow.Type = Catalogs.ContactInformationKinds.CounterpartyPhone;
				NewRow.Presentation = XDTODataObject.Tel;
				NeedToWriteObject = True;
			EndIf;
		EndIf;
		If ValueIsFilled(XDTODataObject.Email) Then
			FoundString = False;
			For Each CurRow IN Object.ContactInformation Do
				If CurRow.Type =  Enums.ContactInformationTypes.EmailAddress
				   AND CurRow.Type = Catalogs.ContactInformationKinds.CounterpartyEmail Then
					FoundString = True;
					If CurRow.Presentation <> XDTODataObject.Email Then
						CurRow.Presentation = XDTODataObject.Email;
						NeedToWriteObject = True;
					EndIf;
				EndIf;
			EndDo;
			If Not FoundString Then
				NewRow = Object.ContactInformation.Add();
				NewRow.Type = Enums.ContactInformationTypes.EmailAddress;
				NewRow.Type = Catalogs.ContactInformationKinds.CounterpartyEmail;
				NewRow.Presentation = XDTODataObject.Email;
				NeedToWriteObject = True;
			EndIf;
		EndIf;

	EndIf;
	If NeedToWriteObject Then
		Object.Write();
	EndIf;
	
	If Object.DeletionMark <> XDTODataObject.DeletionMark Then
		Object.SetDeletionMark(XDTODataObject.DeletionMark, False);
	EndIf;
	
	ExchangePlans.DeleteChangeRecords(ExchangeNode, Object);
	
	Return Object.Ref;
	
EndFunction // FindCreateCounterparty()

// Function finds / generates products and services.
//
Function FindCreateProductsAndServices(ExchangeNode, XDTODataObject)
	
	If XDTODataObject = Undefined Then
		Return Catalogs.ProductsAndServices.EmptyRef();
	EndIf;
	
	ID = New UUID(XDTODataObject.Id);
	Ref = Catalogs.ProductsAndServices.GetRef(ID);
	Object = Ref.GetObject();
	IsNew = False;
	If Object = Undefined Then
		If XDTODataObject.IsFolder Then
			Object = Catalogs.ProductsAndServices.CreateFolder();
		Else
			Object = Catalogs.ProductsAndServices.CreateItem();
		EndIf;
		Object.SetNewObjectRef(Ref);
		Object.SetNewCode();
		Object.Write();
		IsNew = True;
	EndIf;
	
	If Not IsNew Then
		Return Object.Ref;
	EndIf;
	
	NeedToWriteObject = False;
	If Object.Description <> XDTODataObject.Name Then
		Object.Description = XDTODataObject.Name;
		NeedToWriteObject = True;
	EndIf;
	If Object.SKU <> XDTODataObject.Item
		AND Not Object.IsFolder Then
		Object.SKU = XDTODataObject.Item;
		NeedToWriteObject = True;
	EndIf;
	Parent = FindCreateProductsAndServices(ExchangeNode, XDTODataObject.Group);
	If Object.Parent <> Parent Then
		Object.Parent = Parent;
		NeedToWriteObject = True;
	EndIf;
	Vendor = FindCreateCounterparties(ExchangeNode, XDTODataObject.Supplier);
	If Object.Vendor <> Vendor
		AND Not Object.IsFolder Then
		Object.Vendor = Vendor;
		NeedToWriteObject = True;
	EndIf;
	If Object.ProductsAndServicesType <> FindProductsAndServicesTypes(XDTODataObject.TypeItem)
		AND Not Object.IsFolder Then
		Object.ProductsAndServicesType = FindProductsAndServicesTypes(XDTODataObject.TypeItem);
		NeedToWriteObject = True;
	EndIf;
	If Not Object.IsFolder Then
		If Not ValueIsFilled(Object.ReplenishmentDeadline) Then
			Object.ReplenishmentDeadline = 1;
		EndIf;
		If Not ValueIsFilled(Object.Warehouse) Then
			Object.Warehouse = Catalogs.StructuralUnits.MainWarehouse;
		EndIf;
		If Not ValueIsFilled(Object.InventoryGLAccount) Then
			Object.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
		EndIf;
		If Not ValueIsFilled(Object.ExpensesGLAccount) Then
			Object.ExpensesGLAccount = ChartsOfAccounts.Managerial.CommercialExpenses;
		EndIf;
		If Not ValueIsFilled(Object.DescriptionFull) Then
			Object.DescriptionFull = Object.Description;
		EndIf;
		If Not ValueIsFilled(Object.MeasurementUnit) Then
			Object.MeasurementUnit = Catalogs.UOMClassifier.pcs;
		EndIf;
		If Not ValueIsFilled(Object.ProductsAndServicesCategory) Then
			Object.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
		EndIf;
		If Not ValueIsFilled(Object.EstimationMethod) Then
			Object.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
		EndIf;
		If Not ValueIsFilled(Object.BusinessActivity) Then
			Object.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
		EndIf;
		If Not ValueIsFilled(Object.ReplenishmentMethod) Then
			Object.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
		EndIf;
		If Not ValueIsFilled(Object.VATRate) Then
			Query = New Query(
				"SELECT
				|	VATRates.Ref
				|FROM
				|	Catalog.VATRates AS VATRates
				|WHERE
				|	VATRates.Rate = 18
				|	AND Not VATRates.Calculated"
			);
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				Object.VATRate = Selection.Ref;
			EndIf;
		EndIf;

		NeedToWriteObject = True;
	EndIf;
	
	If NeedToWriteObject Then
		Object.Write();
	EndIf;
	
	If Object.DeletionMark <> XDTODataObject.DeletionMark Then
		Object.SetDeletionMark(XDTODataObject.DeletionMark, False);
	EndIf;
	
	ExchangePlans.DeleteChangeRecords(ExchangeNode, Object);
	
	Return Object.Ref;
	
EndFunction // FindCreateProductsAndServices()

// The procedure fills in basic document attributes.
//
Procedure FillMainDocumentAttributes(Object, XDTODataObject, NeedToWriteObject)
	
	If Object.Date <> XDTODataObject.Date Then
		Object.Date = XDTODataObject.Date;
		NeedToWriteObject = True;
	EndIf;
	If Object.DocumentAmount <> XDTODataObject.Total Then
		Object.DocumentAmount = XDTODataObject.Total;
		NeedToWriteObject = True;
	EndIf;
	If Not ValueIsFilled(Object.Author) Then
		Object.Author = Users.CurrentUser();
		NeedToWriteObject = True;
	EndIf;
	If Not ValueIsFilled(Object.Company) Then
		MainCompany = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainCompany"
		);
		Object.Company = ?(ValueIsFilled(MainCompany), MainCompany, Catalogs.Companies.MainCompany);
		NeedToWriteObject = True;
	EndIf;
	If Not ValueIsFilled(Object.VATTaxation) Then
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, , Object.Date);
		NeedToWriteObject = True;
	EndIf;
	
EndProcedure // FillMainDocumentAttributes()

// The procedure writes the document in the infobase.
//
Procedure WriteDocument(ExchangeNode, Object, XDTODataObject, NeedToWriteObject, DocumentsForDelayedPosting)
	
	If NeedToWriteObject Then
		
		Object.DeletionMark = XDTODataObject.DeletionMark;
		
		WriteMode = DocumentWriteMode.Posting;
		If Not XDTODataObject.Posted Then
			WriteMode = DocumentWriteMode.UndoPosting;
		EndIf;
		
		If Object.DeletionMark
			AND (WriteMode = DocumentWriteMode.Posting) Then
			
			Object.DeletionMark = False;
			
		EndIf;
		
		If Not ValueIsFilled(Object.Number) Then
			
			Object.SetNewNumber();
			
		EndIf;
		
		Object.DataExchange.Load = True;
		Try
			
			If Not Object.Posted Then
				Object.Write();
			Else
				// We cancel posting of the document.
				Object.Posted = False;
				Object.Write();
				DeleteDocumentRegisterRecords(Object);
			EndIf;
			
		Except
			
			Raise DetailErrorDescription(ErrorInfo());
			
		EndTry;
		
		If WriteMode = DocumentWriteMode.Posting Then
			
			If DocumentsForDelayedPosting.Find(Object.Ref, "DocumentRef") = Undefined Then
				TableRow = DocumentsForDelayedPosting.Add();
				TableRow.DocumentRef = Object.Ref;
				TableRow.DocumentType = Object.Metadata().Name;
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure // WriteDocument()

// The function creates a new document in the infobase.
//
Function CreateDocument(DocumentName, XDTODataObject)
	
	ID = New UUID(XDTODataObject.Id);
	Ref = Documents[DocumentName].GetRef(ID);
	Object = Ref.GetObject();
	If Object = Undefined Then
		Object = Documents[DocumentName].CreateDocument();
		Object.SetNewObjectRef(Ref);
	EndIf;
	
	Return Object;
	
EndFunction // CreateDocument()

// The function finds / generates a customer order.
//
Function FoundCreateCustomerOrder(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting)
	
	If XDTODataObject = Undefined Then
		Return Documents.CustomerOrder.EmptyRef();
	EndIf;
	
	Object = CreateDocument("CustomerOrder", XDTODataObject);
	
	NeedToWriteObject = False;
	
	FillMainDocumentAttributes(Object, XDTODataObject, NeedToWriteObject);
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale;
	EndIf;
	
	If Not ValueIsFilled(Object.Responsible) Then
		Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainResponsible"
		);
	EndIf;
	
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = Constants.NationalCurrency.Get();
		NeedToWriteObject = True;
	EndIf;
	
	Counterparty = FindCreateCounterparties(ExchangeNode, XDTODataObject.Buyer);
	If Object.Counterparty <> Counterparty Then
		Object.Counterparty = Counterparty;
		NeedToWriteObject = True;
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		ContractByDefault = GetContractByDefault(
			Object.Ref,
			Object.Counterparty,
			Object.Company,
			Object.OperationKind
		);
		If Not ValueIsFilled(ContractByDefault) Then
			ContractByDefault = CreateDefaultContract(Object.Counterparty, Object.Company, Enums.ContractKinds.WithCustomer);
		EndIf;
		Object.Contract = ContractByDefault;
		Query = New Query(
			"SELECT
			|	CurrencyRatesSliceLast.ExchangeRate,
			|	CurrencyRatesSliceLast.Multiplicity
			|FROM
			|	InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &Currency) AS CurrencyRatesSliceLast"
		);
		Query.SetParameter("Period", Object.Date);
		Query.SetParameter("Currency", Object.Contract.SettlementsCurrency);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Object.ExchangeRate = Selection.ExchangeRate;
			Object.Multiplicity = Selection.Multiplicity;
		Else
			Object.ExchangeRate = 1;
			Object.Multiplicity = 1;
		EndIf;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.ShipmentDate) Then
		Object.ShipmentDate = Object.Date;
		NeedToWriteObject = True;
	EndIf;
	
	If Object.OrderState <> FindCustomerOrderStates(XDTODataObject.OrderState) Then
		Object.OrderState = FindCustomerOrderStates(XDTODataObject.OrderState);
		Object.Closed = False;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.SalesStructuralUnit) Then
		Object.SalesStructuralUnit = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainDepartment"
		);
		Object.SalesStructuralUnit = ?(ValueIsFilled(Object.SalesStructuralUnit), Object.SalesStructuralUnit, Catalogs.StructuralUnits.MainDepartment);
		NeedToWriteObject = True;
	EndIf;
	
	If Object.IsNew() Then
		Object.PriceKind = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainPriceKindSales"
		);
		Object.PriceKind = ?(ValueIsFilled(Object.PriceKind), Object.PriceKind, Object.Contract.PriceKind);
		Object.PriceKind = ?(ValueIsFilled(Object.PriceKind), Object.PriceKind, Catalogs.PriceKinds.Wholesale);
		Object.AmountIncludesVAT = ?(ValueIsFilled(Object.PriceKind), Object.PriceKind.PriceIncludesVAT, True);
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "ShipmentDatePositionInCustomerOrder");
		If ValueIsFilled(SettingValue) Then
			If Object.ShipmentDatePosition <> SettingValue Then
				Object.ShipmentDatePosition = SettingValue;
			EndIf;
		Else
			Object.ShipmentDatePosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
		
		NeedToWriteObject = True;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		Object.Inventory.Clear();
		NeedToWriteObject = True;
	EndIf;
	
	If XDTODataObject.Items <> Undefined Then
		For Each CurRow IN XDTODataObject.Items.Item Do
			NewRow = Object.Inventory.Add();
			NewRow.ProductsAndServices = FindCreateProductsAndServices(ExchangeNode, CurRow.Nomenclature);
			NewRow.ProductsAndServicesTypeInventory = NewRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
			NewRow.MeasurementUnit = NewRow.ProductsAndServices.MeasurementUnit;
			NewRow.Price = CurRow.Price;
			NewRow.Quantity = CurRow.Quantity;
			NewRow.Amount = CurRow.Total;
			NewRow.ShipmentDate = Object.Date;
			CalculateAmountsInTabularSectionRow(Object, NewRow);
			NeedToWriteObject = True;
		EndDo;
	EndIf;
	
	If Object.Comment <> XDTODataObject.Comment Then
		Object.Comment = XDTODataObject.Comment;
		NeedToWriteObject = True;
	EndIf;
	
	WriteDocument(ExchangeNode, Object, XDTODataObject, NeedToWriteObject, DocumentsForDelayedPosting);
	
	// If an order number in the mobile application does not match the
	// order number in the central base, we transfer it back for synchronization of numbers.
	If XDTODataObject.name = Object.Number Then
		ExchangePlans.DeleteChangeRecords(ExchangeNode, Object);
	EndIf;
	
	Return Object.Ref;
	
EndFunction // FindCreateCustomerOrder()

// The function finds / creates the "cash payment" order.
//
Function FindCreateCashExpense(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting)
	
	If XDTODataObject = Undefined Then
		Return Documents.CashPayment.EmptyRef();
	EndIf;
	
	Object = CreateDocument("CashPayment", XDTODataObject);
	
	NeedToWriteObject = False;
	
	FillMainDocumentAttributes(Object, XDTODataObject, NeedToWriteObject);
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsCashPayment.Vendor;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		Object.CashCurrency = Constants.NationalCurrency.Get();
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.PettyCash) Then
		Object.PettyCash = Object.Company.PettyCashByDefault;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.Item) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
		NeedToWriteObject = True;
	EndIf;
	
	Counterparty = FindCreateCounterparties(ExchangeNode, XDTODataObject.Contractor);
	If Object.Counterparty <> Counterparty Then
		Object.Counterparty = Counterparty;
		NeedToWriteObject = True;
	EndIf;
	
	Object.PaymentDetails.Clear();
	NeedToWriteObject = True;
	NewRow = Object.PaymentDetails.Add();
	ContractByDefault = GetContractByDefault(
		Object.Ref,
		Object.Counterparty,
		Object.Company,
		Object.OperationKind
	);
	If Not ValueIsFilled(ContractByDefault) Then
		ContractByDefault = CreateDefaultContract(Object.Counterparty, Object.Company, Enums.ContractKinds.WithVendor);
	EndIf;
	NewRow.Contract = ContractByDefault;
	Query = New Query(
		"SELECT
		|	CurrencyRatesSliceLast.Currency,
		|	CurrencyRatesSliceLast.ExchangeRate,
		|	CurrencyRatesSliceLast.Multiplicity
		|FROM
		|	InformationRegister.CurrencyRates.SliceLast(&Period, Currency IN (&Currencies)) AS CurrencyRatesSliceLast"
	);
	CurrencyArray = New Array();
	CurrencyArray.Add(ContractByDefault.SettlementsCurrency);
	CurrencyArray.Add(Object.CashCurrency);
	Query.SetParameter("Period", Object.Date);
	Query.SetParameter("Currencies", CurrencyArray);
	TableOfCurrency = Query.Execute().Unload();
	SettlementsCurrency = TableOfCurrency.Find(ContractByDefault.SettlementsCurrency, "Currency");
	CashCurrency = TableOfCurrency.Find(Object.CashCurrency, "Currency");
	
	If ValueIsFilled(SettlementsCurrency) Then
		NewRow.ExchangeRate = SettlementsCurrency.ExchangeRate;
		NewRow.Multiplicity = SettlementsCurrency.Multiplicity;
	Else
		NewRow.ExchangeRate = 1;
		NewRow.Multiplicity = 1;
	EndIf;
	
	NewRow.PaymentAmount = Object.DocumentAmount;
	NewRow.AdvanceFlag = True;
	
	If ValueIsFilled(CashCurrency) Then
		NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			NewRow.PaymentAmount,
			CashCurrency.ExchangeRate,
			NewRow.ExchangeRate,
			CashCurrency.Multiplicity,
			NewRow.Multiplicity
		);
	Else
		NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			NewRow.PaymentAmount,
			1,
			NewRow.ExchangeRate,
			1,
			NewRow.Multiplicity
		);
	EndIf;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Object.Company.DefaultVATRate; 
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
	NewRow.VATRate = DefaultVATRate;
	NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
	
	WriteDocument(ExchangeNode, Object, XDTODataObject, NeedToWriteObject, DocumentsForDelayedPosting);
	
	Return Object.Ref;
	
EndFunction // FindCreatePettyCashExpense()

// The function finds / generates a petty cash receipt.
//
Function FindCreateCashIncome(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting)
	
	If XDTODataObject = Undefined Then
		Return Documents.CashReceipt.EmptyRef();
	EndIf;
	
	Object = CreateDocument("CashReceipt", XDTODataObject);
	
	NeedToWriteObject = False;
	
	FillMainDocumentAttributes(Object, XDTODataObject, NeedToWriteObject);
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		Object.CashCurrency = Constants.NationalCurrency.Get();
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.PettyCash) Then
		Object.PettyCash = Object.Company.PettyCashByDefault;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.Item) Then
		Object.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
		NeedToWriteObject = True;
	EndIf;
	
	Counterparty = FindCreateCounterparties(ExchangeNode, XDTODataObject.Contractor);
	If Object.Counterparty <> Counterparty Then
		Object.Counterparty = Counterparty;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.AcceptedFrom) Then
		Object.AcceptedFrom = Object.Counterparty.FullDescr;
		NeedToWriteObject = True;
	EndIf;
	
	CustomerOrder = FoundCreateCustomerOrder(ExchangeNode, XDTODataObject.Order, DocumentsForDelayedPosting);
	If Object.BasisDocument <> CustomerOrder Then
		Object.BasisDocument = CustomerOrder;
		NeedToWriteObject = True;
	EndIf;
	
	Object.PaymentDetails.Clear();
	NeedToWriteObject = True;
	NewRow = Object.PaymentDetails.Add();
	ContractByDefault = GetContractByDefault(
		Object.Ref,
		Object.Counterparty,
		Object.Company,
		Object.OperationKind
	);
	If Not ValueIsFilled(ContractByDefault) Then
		ContractByDefault = CreateDefaultContract(Object.Counterparty, Object.Company, Enums.ContractKinds.WithCustomer);
	EndIf;
	NewRow.Contract = ContractByDefault;
	Query = New Query(
		"SELECT
		|	CurrencyRatesSliceLast.Currency,
		|	CurrencyRatesSliceLast.ExchangeRate,
		|	CurrencyRatesSliceLast.Multiplicity
		|FROM
		|	InformationRegister.CurrencyRates.SliceLast(&Period, Currency IN (&Currencies)) AS CurrencyRatesSliceLast"
	);
	CurrencyArray = New Array();
	CurrencyArray.Add(ContractByDefault.SettlementsCurrency);
	CurrencyArray.Add(Object.CashCurrency);
	Query.SetParameter("Period", Object.Date);
	Query.SetParameter("Currencies", CurrencyArray);
	TableOfCurrency = Query.Execute().Unload();
	SettlementsCurrency = TableOfCurrency.Find(ContractByDefault.SettlementsCurrency, "Currency");
	CashCurrency = TableOfCurrency.Find(Object.CashCurrency, "Currency");
	
	If ValueIsFilled(SettlementsCurrency) Then
		NewRow.ExchangeRate = SettlementsCurrency.ExchangeRate;
		NewRow.Multiplicity = SettlementsCurrency.Multiplicity;
	Else
		NewRow.ExchangeRate = 1;
		NewRow.Multiplicity = 1;
	EndIf;
	
	NewRow.PaymentAmount = Object.DocumentAmount;
	NewRow.AdvanceFlag = True;
	NewRow.Order = CustomerOrder;
	
	If ValueIsFilled(CashCurrency) Then
		NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			NewRow.PaymentAmount,
			CashCurrency.ExchangeRate,
			NewRow.ExchangeRate,
			CashCurrency.Multiplicity,
			NewRow.Multiplicity
		);
	Else
		NewRow.SettlementsAmount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			NewRow.PaymentAmount,
			1,
			NewRow.ExchangeRate,
			1,
			NewRow.Multiplicity
		);
	EndIf;
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		DefaultVATRate = Object.Company.DefaultVATRate; 
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
		DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
	Else
		DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
	EndIf;
	
	NewRow.VATRate = DefaultVATRate;
	NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
	
	WriteDocument(ExchangeNode, Object, XDTODataObject, NeedToWriteObject, DocumentsForDelayedPosting);
	
	Return Object.Ref;
	
EndFunction // FindCreatePettyCashReceipt()

// The function finds / generates an inventory expense.
//
Function FindCreateCustomerInvoice(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting)
	
	If XDTODataObject = Undefined Then
		Return Documents.CustomerOrder.EmptyRef();
	EndIf;
	
	Object = CreateDocument("CustomerInvoice", XDTODataObject);
	
	NeedToWriteObject = False;
	
	FillMainDocumentAttributes(Object, XDTODataObject, NeedToWriteObject);
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
	EndIf;
	
	If Not ValueIsFilled(Object.Responsible) Then
		Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainResponsible"
		);
	EndIf;
	
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = Constants.NationalCurrency.Get();
		NeedToWriteObject = True;
	EndIf;
	
	Counterparty = FindCreateCounterparties(ExchangeNode, XDTODataObject.Buyer);
	If Object.Counterparty <> Counterparty Then
		Object.Counterparty = Counterparty;
		NeedToWriteObject = True;
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		ContractByDefault = GetContractByDefault(
			Object.Ref,
			Object.Counterparty,
			Object.Company,
			Object.OperationKind
		);
		If Not ValueIsFilled(ContractByDefault) Then
			ContractByDefault = CreateDefaultContract(Object.Counterparty, Object.Company, Enums.ContractKinds.WithCustomer);
		EndIf;
		Object.Contract = ContractByDefault;
		Query = New Query(
			"SELECT
			|	CurrencyRatesSliceLast.ExchangeRate,
			|	CurrencyRatesSliceLast.Multiplicity
			|FROM
			|	InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &Currency) AS CurrencyRatesSliceLast"
		);
		Query.SetParameter("Period", Object.Date);
		Query.SetParameter("Currency", Object.Contract.SettlementsCurrency);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Object.ExchangeRate = Selection.ExchangeRate;
			Object.Multiplicity = Selection.Multiplicity;
		Else
			Object.ExchangeRate = 1;
			Object.Multiplicity = 1;
		EndIf;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.Department) Then
		Object.Department = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainDepartment"
		);
		Object.Department = ?(ValueIsFilled(Object.Department), Object.Department, Catalogs.StructuralUnits.MainDepartment);
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Object.StructuralUnit = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainWarehouse"
		);
		Object.StructuralUnit = ?(ValueIsFilled(Object.StructuralUnit), Object.StructuralUnit, Catalogs.StructuralUnits.MainWarehouse);
		NeedToWriteObject = True;
	EndIf;
	
	If Object.IsNew() Then
		Object.PriceKind = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainPriceKindSales"
		);
		Object.PriceKind = ?(ValueIsFilled(Object.PriceKind), Object.PriceKind, Object.Contract.PriceKind);
		Object.PriceKind = ?(ValueIsFilled(Object.PriceKind), Object.PriceKind, Catalogs.PriceKinds.Wholesale);
		Object.AmountIncludesVAT = ?(ValueIsFilled(Object.PriceKind), Object.PriceKind.PriceIncludesVAT, True);
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "CustomerOrderPositionInShipmentDocuments");
		If ValueIsFilled(SettingValue) Then
			If Object.CustomerOrderPosition <> SettingValue Then
				Object.CustomerOrderPosition = SettingValue;
			EndIf;
		Else
			Object.CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
		
		NeedToWriteObject = True;
	EndIf;
	
	CustomerOrder = FoundCreateCustomerOrder(ExchangeNode, XDTODataObject.Order, DocumentsForDelayedPosting);
	If Object.BasisDocument <> CustomerOrder Then
		Object.BasisDocument = CustomerOrder;
		NeedToWriteObject = True;
	EndIf;
	If Object.Order <> CustomerOrder Then
		Object.Order = CustomerOrder;
		NeedToWriteObject = True;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		Object.Inventory.Clear();
		NeedToWriteObject = True;
	EndIf;

	If XDTODataObject.Items <> Undefined Then
		For Each CurRow IN XDTODataObject.Items.Item Do
			NewRow = Object.Inventory.Add();
			NewRow.ProductsAndServices = FindCreateProductsAndServices(ExchangeNode, CurRow.Nomenclature);
			NewRow.ProductsAndServicesTypeInventory = NewRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
			NewRow.MeasurementUnit = NewRow.ProductsAndServices.MeasurementUnit;
			NewRow.Price = CurRow.Price;
			NewRow.Order = CustomerOrder;
			NewRow.Quantity = CurRow.Quantity;
			NewRow.Amount = CurRow.Total;
			CalculateAmountsInTabularSectionRow(Object, NewRow);
			NeedToWriteObject = True;
		EndDo;
	EndIf;
	
	WriteDocument(ExchangeNode, Object, XDTODataObject, NeedToWriteObject, DocumentsForDelayedPosting);
	
	Return Object.Ref;
	
EndFunction // FindCreateInventoryExpense()

// The function finds / generates an inventory receipt.
//
Function FindCreateSupplierInvoice(ExchangeNode, XDTODataObject, DocumentsForDelayedPosting)
	
	If XDTODataObject = Undefined Then
		Return Documents.CustomerOrder.EmptyRef();
	EndIf;
	
	Object = CreateDocument("SupplierInvoice", XDTODataObject);
	
	NeedToWriteObject = False;
	
	FillMainDocumentAttributes(Object, XDTODataObject, NeedToWriteObject);
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
	EndIf;
	
	If Not ValueIsFilled(Object.Responsible) Then
		Object.Responsible = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainResponsible"
		);
	EndIf;
	
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		Object.DocumentCurrency = Constants.NationalCurrency.Get();
		NeedToWriteObject = True;
	EndIf;
	
	Counterparty = FindCreateCounterparties(ExchangeNode, XDTODataObject.Supplier);
	If Object.Counterparty <> Counterparty Then
		Object.Counterparty = Counterparty;
		NeedToWriteObject = True;
	EndIf;
	If Not ValueIsFilled(Object.Contract) Then
		ContractByDefault = GetContractByDefault(
			Object.Ref,
			Object.Counterparty,
			Object.Company,
			Object.OperationKind
		);
		If Not ValueIsFilled(ContractByDefault) Then
			ContractByDefault = CreateDefaultContract(Object.Counterparty, Object.Company, Enums.ContractKinds.WithVendor);
		EndIf;
		Object.Contract = ContractByDefault;
		Query = New Query(
			"SELECT
			|	CurrencyRatesSliceLast.ExchangeRate,
			|	CurrencyRatesSliceLast.Multiplicity
			|FROM
			|	InformationRegister.CurrencyRates.SliceLast(&Period, Currency = &Currency) AS CurrencyRatesSliceLast"
		);
		Query.SetParameter("Period", Object.Date);
		Query.SetParameter("Currency", Object.Contract.SettlementsCurrency);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Object.ExchangeRate = Selection.ExchangeRate;
			Object.Multiplicity = Selection.Multiplicity;
		Else
			Object.ExchangeRate = 1;
			Object.Multiplicity = 1;
		EndIf;
		NeedToWriteObject = True;
	EndIf;
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Object.StructuralUnit = SmallBusinessReUse.GetValueByDefaultUser(
			Object.Author,
			"MainWarehouse"
		);
		Object.StructuralUnit = ?(ValueIsFilled(Object.StructuralUnit), Object.StructuralUnit, Catalogs.StructuralUnits.MainWarehouse);
		NeedToWriteObject = True;
	EndIf;
	
	If Object.IsNew() Then
		Object.CounterpartyPriceKind = Object.Contract.CounterpartyPriceKind;
		Object.CounterpartyPriceKind = ?(ValueIsFilled(Object.CounterpartyPriceKind), Object.CounterpartyPriceKind, Catalogs.CounterpartyPriceKind.CounterpartyDefaultPriceKind(Object.Counterparty));
		Object.AmountIncludesVAT = ?(ValueIsFilled(Object.CounterpartyPriceKind), Object.CounterpartyPriceKind.PriceIncludesVAT, True);
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "PurchaseOrderPositionInReceiptDocuments");
		If ValueIsFilled(SettingValue) Then
			If Object.PurchaseOrderPosition <> SettingValue Then
				Object.PurchaseOrderPosition = SettingValue;
			EndIf;
		Else
			Object.PurchaseOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
		
		NeedToWriteObject = True;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		Object.Inventory.Clear();
		NeedToWriteObject = True;
	EndIf;
	
	If XDTODataObject.Items <> Undefined Then
		For Each CurRow IN XDTODataObject.Items.Item Do
			NewRow = Object.Inventory.Add();
			NewRow.ProductsAndServices = FindCreateProductsAndServices(ExchangeNode, CurRow.Nomenclature);
			NewRow.MeasurementUnit = NewRow.ProductsAndServices.MeasurementUnit;
			NewRow.Price = CurRow.Price;
			NewRow.Quantity = CurRow.Quantity;
			NewRow.Amount = CurRow.Total;
			CalculateAmountsInTabularSectionRow(Object, NewRow);
			NeedToWriteObject = True;
		EndDo;
	EndIf;
	
	WriteDocument(ExchangeNode, Object, XDTODataObject, NeedToWriteObject, DocumentsForDelayedPosting);
	
	Return Object.Ref;
	
EndFunction // FindCreateInventoryReceipt()

// The function finds the products and services type.
//
Function FindProductsAndServicesTypes(XDTODataObject)
	
	If XDTODataObject = Undefined Then
		Return Enums.ProductsAndServicesTypes.EmptyRef();
	EndIf;
	
	If XDTODataObject = "Product" Then
		Object = Enums.ProductsAndServicesTypes.InventoryItem;
	Else
		Object = Enums.ProductsAndServicesTypes.Service;
	EndIf;
	
	Return Object;
	
EndFunction // FindProductsAndServicesTypes()

// The function finds statuses of customer orders.
//
Function FindCustomerOrderStates(XDTODataObject)
	
	If XDTODataObject = Undefined Then
		Return Catalogs.CustomerOrderStates.EmptyRef();
	EndIf;
	
	If XDTODataObject = "Complete" Then
		Object = Constants.CustomerOrdersCompletedStatus.Get();
	Else
		Object = Constants.CustomerOrdersInProgressStatus.Get();
	EndIf;
	
	Return Object;
	
EndFunction // FindCustomerOrderStatuses()

// The function loads the prices.
//
Function ImportPrices(ExchangeNode, XDTODataObject)
	
	If XDTODataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	User = Users.CurrentUser();
	PriceKind = SmallBusinessReUse.GetValueByDefaultUser(
		User,
		"MainPriceKindSales"
	);
		
	If Not ValueIsFilled(PriceKind) Then
		PriceKind = Catalogs.PriceKinds.Wholesale;
	EndIf;
		
	ProductsAndServices = FindCreateProductsAndServices(ExchangeNode, XDTODataObject.Nomenclature);
	
	RecordSet = InformationRegisters.ProductsAndServicesPrices.CreateRecordSet();
	RecordSet.Filter.Period.Set(XDTODataObject.Date);
	RecordSet.Filter.PriceKind.Set(PriceKind);
	RecordSet.Filter.ProductsAndServices.Set(ProductsAndServices);
	RecordSet.Filter.Characteristic.Set(Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
	
	NewRecord = RecordSet.Add();
	NewRecord.Period = XDTODataObject.Date;
	NewRecord.PriceKind = PriceKind;
	NewRecord.ProductsAndServices = ProductsAndServices;
	NewRecord.Price = XDTODataObject.Price;
	NewRecord.Actuality = True;
	NewRecord.MeasurementUnit = ProductsAndServices.MeasurementUnit;
	NewRecord.Author = User;
	
	RecordSet.Write();
	
	ExchangePlans.DeleteChangeRecords(ExchangeNode, RecordSet);
	
EndFunction // ImportPrices()

// The function marks the object for deletion.
//
Function MarkObjectForDeletion(ExchangeNode, XDTODataObject)
	
	If XDTODataObject = Undefined Then
		Return Undefined;
	EndIf;
	
	ID = New UUID(XDTODataObject.Id);
	
	If XDTODataObject.Type = "CatContractors" Then
		//Refs = Catalogs.Counterparties.GetRef(Identifier);
		Return Undefined;
	ElsIf XDTODataObject.Type = "CatItems" Then
		//Refs = Catalogs.ProductsAndServices.GetRef(Identifier);
		Return Undefined;
	ElsIf XDTODataObject.Type = "DocOrders" Then
		Ref = Documents.CustomerOrder.GetRef(ID);
	ElsIf XDTODataObject.Type = "DocInvoice" Then
		Ref = Documents.CustomerInvoice.GetRef(ID);
	ElsIf XDTODataObject.Type = "DocPurshareInvoice" Then
		Ref = Documents.SupplierInvoice.GetRef(ID);
	ElsIf XDTODataObject.Type = "DocIncomingPayment" Then
		Ref = Documents.CashReceipt.GetRef(ID);
	ElsIf XDTODataObject.Type = "DocOutgoingPayment" Then
		Ref = Documents.CashPayment.GetRef(ID);
	EndIf;
	
	Try
		Object = Ref.GetObject();
		Object.SetDeletionMark(True);
		ExchangePlans.DeleteChangeRecords(ExchangeNode, Object);
	Except
	EndTry;
	
EndFunction // MarkObjectForDeletion()

// The procedure performs documents posting.
//
Procedure RunDelayedDocumentPosting(ExchangeNode, DocumentsForDelayedPosting)

	DocumentsForDelayedPosting.Sort("DocumentType");
	
	For Each TableRow IN DocumentsForDelayedPosting Do
		
		If TableRow.DocumentRef.IsEmpty() Then
			Continue;
		EndIf;
		
		Object = TableRow.DocumentRef.GetObject();
		
		If Object = Undefined Then
			Continue;
		EndIf;
		
		DeleteChangesRegistration = Not ExchangePlans.IsChangeRecorded(ExchangeNode, Object);
		Object.DataExchange.Load = False;
		
		Try
			
			Object.CheckFilling();
			Object.Write(DocumentWriteMode.Posting);
			
			If DeleteChangesRegistration Then
				ExchangePlans.DeleteChangeRecords(ExchangeNode, Object);
			EndIf;
			
		Except
		EndTry;
		
	EndDo;

EndProcedure // RunDelayedDocumentPosting()

////////////////////////////////////////////////////////////////////////////////
// SUBSCRIPTION TO EVENTS

// The procedure handles the document OnDWriting event for the mechanism of objects registration in nodes.
//
Procedure ExchangeMobileApplicationOnDocumentWrite(Source, Cancel, WriteMode, PostingMode) Export
	
	SetPrivilegedMode(True);
	NodeArrayForRegistration = New Array;
	
	Selection = ExchangePlans.MobileApplication.Select();
	While Selection.Next() Do
		If Selection.Ref <> ExchangePlans.MobileApplication.ThisNode() Then
			If TypeOf(Source) = Type("DocumentObject.CustomerOrder")
			   AND Source.OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale
			   AND (Source.OrderState.OrderStatus = Enums.OrderStatuses.InProcess
			 OR Source.OrderState.OrderStatus = Enums.OrderStatuses.Completed) Then
				NeedToExport = True;
				For Each CurRow IN Source.Inventory Do
					If CurRow.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
						NeedToExport = False;
						Break;
					EndIf;
				EndDo;
				If NeedToExport Then
					NodeArrayForRegistration.Add(Selection.Ref);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	If NodeArrayForRegistration.Count() > 0 Then
		ExchangePlans.RecordChanges(NodeArrayForRegistration, Source.Ref);
	EndIf;
	SetPrivilegedMode(False);
	
EndProcedure // ExchangeMobileApplicationOnDocumentWriting()

// The procedure handles the registers OnWrite event for the mechanism of objects registration in nodes
//
// Parameters:
//  Source       - RegisterRecordSet - the
//  Denial event source          - Boolean - check box of the
//  Replace handler run denial      - Boolean - shows that an existing records set was replaced
// 
Procedure ExchangeMobileApplicationOnRegisterWrite(Source, Cancel, Replacing) Export
	
	SetPrivilegedMode(True);
	NodeArrayForRegistration = New Array;
	
	NeedToPerformRegistration = False;
	
	Selection = ExchangePlans.MobileApplication.Select();
	While Selection.Next() Do
		If Selection.Ref <> ExchangePlans.MobileApplication.ThisNode() Then
			NeedToPerformRegistration = True;
		EndIf;
	EndDo;
	
	If NeedToPerformRegistration Then
		If TypeOf(Source) = Type("AccumulationRegisterRecordSet.InvoicesAndOrdersPayment") Then
			Query = New Query(
				"SELECT
				|	InvoicesAndOrdersPayment.InvoiceForPayment AS Order,
				|	TRUE AS Register
				|FROM
				|	AccumulationRegister.InvoicesAndOrdersPayment AS InvoicesAndOrdersPayment
				|WHERE
				|	InvoicesAndOrdersPayment.Recorder = &Recorder
				|	AND InvoicesAndOrdersPayment.InvoiceForPayment.OperationKind = &OperationKind
				|
				|GROUP BY
				|	InvoicesAndOrdersPayment.InvoiceForPayment"
			);
		ElsIf TypeOf(Source) = Type("AccumulationRegisterRecordSet.CustomerOrders") Then
			Query = New Query(
				"SELECT
				|	CustomerOrders.CustomerOrder AS Order,
				|	TRUE AS Register
				|FROM
				|	AccumulationRegister.CustomerOrders AS CustomerOrders
				|WHERE
				|	CustomerOrders.Recorder = &Recorder
				|	AND CustomerOrders.CustomerOrder.OperationKind = &OperationKind
				|
				|GROUP BY
				|	CustomerOrders.CustomerOrder"
			);
		EndIf;
		Query.SetParameter("Recorder", Source.Filter.Recorder.Value);
		Query.SetParameter("OperationKind", Enums.OperationKindsCustomerOrder.OrderForSale);
		OrdersTable = Query.Execute().Unload();
		For Each CurRow IN OrdersTable Do
			ObjectOrder = CurRow.Order.GetObject();
			For Each RowOrder IN ObjectOrder.Inventory Do
				If RowOrder.ProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Work Then
					CurRow.Register = False;
					Break;
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	ExportingRecordSet = Source.Unload();
	
	Selection = ExchangePlans.MobileApplication.Select();
	While Selection.Next() Do
		If Selection.Ref <> ExchangePlans.MobileApplication.ThisNode() Then
			For Each CurRow IN OrdersTable Do
				If ValueIsFilled(CurRow.Order)
				   AND CurRow.Register Then
					NodeArrayForRegistration.Add(Selection.Ref);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	If NodeArrayForRegistration.Count() > 0 Then
		For Each CurRow IN OrdersTable Do
			If ValueIsFilled(CurRow.Order)
			   AND CurRow.Register Then
				ExchangePlans.RecordChanges(NodeArrayForRegistration, CurRow.Order);
			EndIf;
		EndDo;
	EndIf;
	
	SetPrivilegedMode(False);
	
EndProcedure // ExchangeMobileApplicationBeforeRegisterWriting()

// The procedure handles the OnWrite event of data reference types (exept documents)for the mechanism of objects registration in nodes
//
// Parameters:
//  Source       - source of the event
//  in addition to the ObjectDocument Denial type          - Boolean - check box of handler run denial
// 
Procedure ExchangeMobileApplicationOnWrite(Source, Cancel) Export
	
	SetPrivilegedMode(True);
	NodeArrayForRegistration = New Array;
	
	Selection = ExchangePlans.MobileApplication.Select();
	While Selection.Next() Do
		If Selection.Ref <> ExchangePlans.MobileApplication.ThisNode() Then
			If TypeOf(Source) = Type("CatalogObject.ProductsAndServices")
			   AND (Source.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem
			   OR Source.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service) Then
				NodeArrayForRegistration.Add(Selection.Ref);
			EndIf;
		EndIf;
	EndDo;
	
	If NodeArrayForRegistration.Count() > 0 Then
		ExchangePlans.RecordChanges(NodeArrayForRegistration, Source.Ref);
	EndIf;
	SetPrivilegedMode(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

// The function receives the default contract.
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction // GetContractByDefault()

// The function creates a new default contract.
//
Function CreateDefaultContract(Counterparty, Company, ContractKind)
	
	If Not ValueIsFilled(Counterparty) Then
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	SetPrivilegedMode(True);
	
	NewContract = Catalogs.CounterpartyContracts.CreateItem();
	
	NewContract.Description = NStr("en='Main contract (" + String(ContractKind) + ")'");
	NewContract.SettlementsCurrency = Constants.NationalCurrency.Get();
	NewContract.Company = Company;
	NewContract.ContractKind = ContractKind;
	NewContract.PriceKind = Catalogs.PriceKinds.GetMainKindOfSalePrices();
	NewContract.Owner = Counterparty;
	NewContract.VendorPaymentDueDate = Constants.VendorPaymentDueDate.Get();
	NewContract.CustomerPaymentDueDate = Constants.CustomerPaymentDueDate.Get();
	
	// Let's fill in the type of counterparty's prices
	NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.CounterpartyDefaultPriceKind(Counterparty);
	
	If Not ValueIsFilled(NewCounterpartyPriceKind) Then 
		
		NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.FindAnyFirstKindOfCounterpartyPrice(Counterparty);
		
		If Not ValueIsFilled(NewCounterpartyPriceKind) Then
			
			NewCounterpartyPriceKind = Catalogs.CounterpartyPriceKind.CreateCounterpartyPriceKind(
				Counterparty,
				NewContract.SettlementsCurrency
			);
			
		EndIf;
		
	EndIf;
	
	NewContract.CounterpartyPriceKind = NewCounterpartyPriceKind;
	
	NewContract.Write();
	
	SetPrivilegedMode(False);
	
	Return NewContract.Ref;
	
EndFunction // CreateDefaultContract()

// Procedure of removing the existing movements of the document during reposting (posting cancelation).
//
Procedure DeleteDocumentRegisterRecords(DocumentObject)
	
	RecordTableRowToProcessArray = New Array();
	
	// reception of the list of registers with existing movements
	RegisterRecordTable = DefineIfThereAreRegisterRecordsByDocument(DocumentObject.Ref);
	RegisterRecordTable.Columns.Add("RecordSet");
	RegisterRecordTable.Columns.Add("ForceDelete", New TypeDescription("Boolean"));
		
	For Each RegisterRecordRow IN RegisterRecordTable Do
		// the register name is transferred as a
		// value received using the FullName()function of register metadata
		DotPosition = Find(RegisterRecordRow.Name, ".");
		TypeRegister = Left(RegisterRecordRow.Name, DotPosition - 1);
		RegisterName = TrimR(Mid(RegisterRecordRow.Name, DotPosition + 1));

		RecordTableRowToProcessArray.Add(RegisterRecordRow);
		
		If TypeRegister = "AccumulationRegister" Then
			SetMetadata = Metadata.AccumulationRegisters[RegisterName];
			Set = AccumulationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "AccountingRegister" Then
			SetMetadata = Metadata.AccountingRegisters[RegisterName];
			Set = AccountingRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "InformationRegister" Then
			SetMetadata = Metadata.InformationRegisters[RegisterName];
			Set = InformationRegisters[RegisterName].CreateRecordSet();
			
		ElsIf TypeRegister = "CalculationRegister" Then
			SetMetadata = Metadata.CalculationRegisters[RegisterName];
			Set = CalculationRegisters[RegisterName].CreateRecordSet();
			
		EndIf;
		
		If Not AccessRight("Update", Set.Metadata()) Then
			// No rights to all register table.
			Raise "Access violation: " + RegisterRecordRow.Name;
			Return;
		EndIf;

		Set.Filter.Recorder.Set(DocumentObject.Ref);

		// the set is not written immediately not to cancel
		// the transaction if it turns out later that you do not have enough rights for one of the registers.
		RegisterRecordRow.RecordSet = Set;
		
	EndDo;	
	
	For Each RegisterRecordRow IN RecordTableRowToProcessArray Do		
		Try
			RegisterRecordRow.RecordSet.Write();
		Except
			// RLS or the change disable date subsystem may be activated
			Raise "The operation failed. " + RegisterRecordRow.Name + Chars.LF + BriefErrorDescription(ErrorInfo());
		EndTry;
	EndDo;
	
	DocumentRecordsCollectionClear(DocumentObject);
	
EndProcedure // DeleteDocumentRegisterRecords()

// The function determines whether there are any document movements.
//
Function DefineIfThereAreRegisterRecordsByDocument(DocumentRef)
	
	SetPrivilegedMode(True);
	
	QueryText = "";
	// to prevent from a crash of documents being posted for more than 256 tables
	Counter_tables = 0;
	
	DocumentMetadata = DocumentRef.Metadata();
	
	If DocumentMetadata.RegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		// in the query we get names of the registers which have
		// at
		// least one movement, for
		// example, SELECT
		// First 1 AccumulationRegister.ProductsInWarehouses FROM AccumulationRegister.ProductsInWarehouses WHERE Recorder = &Recorder
		
		// we reduce the register name to Row(200), see below
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + RegisterRecord.FullName() 
		+  """ AS String(200)) AS Name FROM " + RegisterRecord.FullName() 
		+ " WHERE Recorder = &Recorder";
		
		// if a query has more than 256 tables - we break it
		// into two parts (a version of the document with posting over 512 registers is considered unvital)
		Counter_tables = Counter_tables + 1;
		If Counter_tables = 256 Then
			Break;
		EndIf;
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", DocumentRef);
	// at exporting for the "Name" column, the type is set according to
	// the longest row from the query, at the second pass through the table, a new
	// name may not fit the space, therefore it is reduced to Row(200) already in the query
	QueryTable = Query.Execute().Unload();
	
	// if the number of tables does not exceed 256, we return the table
	If Counter_tables = DocumentMetadata.RegisterRecords.Count() Then
		Return QueryTable;			
	EndIf;
	
	// there are more than 256 tables, we make an add. query and amend the rows of the table.
	
	QueryText = "";
	For Each RegisterRecord IN DocumentMetadata.RegisterRecords Do
		
		If Counter_tables > 0 Then
			Counter_tables = Counter_tables - 1;
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 """ + RegisterRecord.FullName() +  """ AS Name IN " 
		+ RegisterRecord.FullName() + " WHERE Recorder = &Recorder";	
		
		
	EndDo;
	Query.Text = QueryText;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		TableRow = QueryTable.Add();
		FillPropertyValues(TableRow, Selection);
	EndDo;
	
	Return QueryTable;
	
EndFunction // DefineIfThereAreRegisterRecordsByDocument()

// The procedure clears the collection of document register records.
//
Procedure DocumentRecordsCollectionClear(DocumentObject)
		
	For Each RegisterRecord IN DocumentObject.RegisterRecords Do
		If RegisterRecord.Count() > 0 Then
			RegisterRecord.Clear();
		EndIf;
	EndDo;
	
EndProcedure // DocumentRecordsCollectionClearing()

// The procedure removes data packages from the messages queue for transfer to the mobile client.
//
Procedure ClearQueueMessagesExchangeWithMobileClient(MobileClient, MessageNo = Undefined) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MessagesExchangeWithMobileClientsQueues.MessageNo
	|FROM
	|	InformationRegister.MessagesExchangeWithMobileClientsQueues AS MessagesExchangeWithMobileClientsQueues
	|WHERE
	|	MessagesExchangeWithMobileClientsQueues.MobileClient = &MobileClient
	|	AND (&MessageNo = UNDEFINED
	|			OR MessagesExchangeWithMobileClientsQueues.MessageNo <= &MessageNo)";
	
	Query.SetParameter("MobileClient", MobileClient);
	Query.SetParameter("MessageNo", MessageNo);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.MessagesExchangeWithMobileClientsQueues.CreateRecordSet();
	RecordSet.DataExchange.Load = True;
	
	SelectionMessages = Result.Select();
	While SelectionMessages.Next() Do
		
		RecordSet.Filter.MobileClient.Set(MobileClient);
		RecordSet.Filter.MessageNo.Set(SelectionMessages.MessageNo);
		
		RecordSet.Write(True);
		
	EndDo;
	
EndProcedure // ClearMobileClientExchangeMessagesQueue()

// The procedure resets the number of the received and sent messages in the exchange plan node.
//
Procedure ReinitializeMessagesOnSiteCountersPlanExchange(ExchangeNode) Export
	
	SetPrivilegedMode(True);
	
	ExchangeNodeObject = ExchangeNode.GetObject();
	ExchangeNodeObject.ReceivedNo = 0;
	ExchangeNodeObject.SentNo = 0;
	ExchangeNodeObject.Write();
	
	SetPrivilegedMode(False);
	
EndProcedure // ReinitializeExchangePlanNodeMessagesCounters()
// 
