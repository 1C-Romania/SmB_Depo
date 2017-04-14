#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.SupplierInvoiceForPayment.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	SmallBusinessServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	SmallBusinessServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Inventory.Total("Total");
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
EndProcedure // BeforeWrite()

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		
		Company		= FillingData.Company;
		DocumentCurrency = FillingData.DocumentCurrency;
		Contract			= FillingData.Contract;
		Counterparty		= FillingData.Counterparty;
		BankAccount	= FillingData.Company.BankAccountByDefault;
		CounterpartyPriceKind = FillingData.CounterpartyPriceKind;
		VATTaxation = FillingData.VATTaxation;
		If DocumentCurrency = Constants.NationalCurrency.Get() Then
			ExchangeRate = FillingData.ExchangeRate;
			Multiplicity = FillingData.Multiplicity;
		Else
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
		
		Company		  = FillingData.Company;
		AmountIncludesVAT  = FillingData.AmountIncludesVAT;
		BasisDocument = FillingData;
		
		Inventory.Clear();
		
		For Each CurStringInventory IN FillingData.Inventory Do
			NewRow = Inventory.Add();
			NewRow.ProductsAndServices		 = CurStringInventory.ProductsAndServices;
			NewRow.Characteristic		 = CurStringInventory.Characteristic;
			NewRow.Content			 = CurStringInventory.Content;
			NewRow.MeasurementUnit	 = CurStringInventory.MeasurementUnit;
			NewRow.Quantity			 = CurStringInventory.Quantity;
			NewRow.Price				 = CurStringInventory.Price;
			NewRow.Amount				 = CurStringInventory.Amount;
			NewRow.VATRate			 = CurStringInventory.VATRate;
			NewRow.VATAmount			 = CurStringInventory.VATAmount;
			NewRow.Total				 = CurStringInventory.Total;
		EndDo;
		
		PaymentAmount = Inventory.Total("Total");
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Event") Then
	
		Event = FillingData.Ref;
		If FillingData.Participants.Count() > 0 AND TypeOf(FillingData.Participants[0].Contact) = Type("CatalogRef.Counterparties") Then
			Counterparty = FillingData.Participants[0].Contact;
			Contract = Counterparty.ContractByDefault;
			CounterpartyPriceKind = Contract.CounterpartyPriceKind;
		EndIf;
		
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SchedulePayment
	   AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
	   
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		
	ElsIf SchedulePayment
	   AND CashAssetsType = Enums.CashAssetTypes.Cash Then
	   
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	Else
		
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	EndIf;
	
	If SchedulePayment
	   AND PaymentCalendar.Count() = 1
	   AND Not ValueIsFilled(PaymentCalendar[0].PayDate) Then
		
		MessageText = NStr("en='Field ""Payment date"" is required.';ru='Поле ""Дата оплаты"" не заполнено.'");
		SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText, , , "PayDate", Cancel);
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
		
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure // FillCheckProcessing()

#EndRegion

#EndIf