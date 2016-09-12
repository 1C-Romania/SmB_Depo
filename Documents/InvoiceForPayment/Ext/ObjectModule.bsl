#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Posting cancellation procedure of the subordinate customer invoice note
//
Procedure SubordinatedInvoiceControl()
	
	InvoiceStructure = SmallBusinessServer.GetSubordinateInvoice(Ref);
	If Not InvoiceStructure = Undefined Then
		
		CustomerInvoiceNote	 = InvoiceStructure.Ref;
		If CustomerInvoiceNote.Posted Then
			
			MessageText = NStr("en='As there are no register records of the %CurrentDocumentPresentation% document, undo the posting of %InvoicePresentation%.';ru='В связи с отсутствием движений у документа %ПредставлениеТекущегоДокумента% распроводится счет фактура %ПредставлениеСчетФактуры%.'");
			MessageText = StrReplace(MessageText, "%CurrentDocumentPresentation%", """Account on payment # " + Number + " dated " + Format(Date, "DF=dd.MM.yyyy") + """");
			MessageText = StrReplace(MessageText, "%InvoicePresentation%", """Customer invoice note (issued) # " + InvoiceStructure.Number + " dated " + InvoiceStructure.Date + """");
			
			CommonUseClientServer.MessageToUser(MessageText);
			
			InvoiceObject = CustomerInvoiceNote.GetObject();
			InvoiceObject.Write(DocumentWriteMode.UndoPosting);
			
		EndIf;
		
	EndIf;
	
EndProcedure //SubordinateInvoiceControl()

#EndRegion

#Region EventsHandlers

// Procedure - event handler "Posting".
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.InvoiceForPayment.InitializeDocumentData(Ref, AdditionalProperties);
	
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
	
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
		
		Company		= FillingData.Company;
		DocumentCurrency = FillingData.DocumentCurrency;
		Contract			= FillingData.Contract;
		Counterparty		= FillingData.Counterparty;
		BankAccount	= FillingData.Company.BankAccountByDefault;
		VATTaxation = FillingData.VATTaxation;
		// DiscountCards
		DiscountCard = FillingData.DiscountCard;
		DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
		// End DiscountCards
		
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
			NewRow.Batch				 = CurStringInventory.Batch;
			NewRow.Content			 = CurStringInventory.Content;
			NewRow.MeasurementUnit	 = CurStringInventory.MeasurementUnit;
			NewRow.Quantity			 = CurStringInventory.Quantity;
			NewRow.Price				 = CurStringInventory.Price;	
			NewRow.DiscountMarkupPercent = CurStringInventory.DiscountMarkupPercent;	
			NewRow.Amount				 = CurStringInventory.Amount;
			NewRow.VATRate			 = CurStringInventory.VATRate;
			NewRow.VATAmount			 = CurStringInventory.VATAmount;
			NewRow.Total				 = CurStringInventory.Total;
			// AutomaticDiscounts
			If UseAutomaticDiscounts Then
				NewRow.ConnectionKey			 = CurStringInventory.ConnectionKey;
				NewRow.AutomaticDiscountAmount	= CurStringInventory.AutomaticDiscountAmount;
				NewRow.AutomaticDiscountsPercent	= CurStringInventory.AutomaticDiscountsPercent;
			EndIf;
			// End AutomaticDiscounts
		EndDo;
		
		For Each CurRowWork IN FillingData.Works Do
			NewRow = Inventory.Add();
			NewRow.ProductsAndServices		 = CurRowWork.ProductsAndServices;
			NewRow.Characteristic		 = CurRowWork.Characteristic;
			NewRow.Content			 = CurRowWork.Content;
			NewRow.MeasurementUnit	 = CurRowWork.ProductsAndServices.MeasurementUnit;
			NewRow.Quantity			 = CurRowWork.Quantity * CurRowWork.Factor * CurRowWork.Multiplicity;
			NewRow.Price				 = CurRowWork.Price;	
			NewRow.DiscountMarkupPercent = CurRowWork.DiscountMarkupPercent;	
			NewRow.Amount				 = CurRowWork.Amount;
			NewRow.VATRate			 = CurRowWork.VATRate;
			NewRow.VATAmount			 = CurRowWork.VATAmount;
			NewRow.Total				 = CurRowWork.Total;
		EndDo;
		
		PaymentAmount = Inventory.Total("Total");
		
		// AutomaticDiscounts
		If UseAutomaticDiscounts Then
			DiscountsMarkups.Load(FillingData.DiscountsMarkups.Unload());
			DiscountsAreCalculated = FillingData.DiscountsAreCalculated;
		EndIf;
		// End AutomaticDiscounts
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
		
		Company		= FillingData.Company;
		DocumentCurrency = FillingData.DocumentCurrency;
		Contract			= FillingData.Contract;
		Counterparty		= FillingData.Counterparty;
		BankAccount	= FillingData.Company.BankAccountByDefault;
		VATTaxation = FillingData.VATTaxation;
		// DiscountCards
		DiscountCard = FillingData.DiscountCard;
		DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
		// End DiscountCards
		
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
			NewRow.Batch				 = CurStringInventory.Batch;
			NewRow.MeasurementUnit	 = CurStringInventory.MeasurementUnit;
			NewRow.Quantity			 = CurStringInventory.Quantity;
			NewRow.Price				 = CurStringInventory.Price;	
			NewRow.DiscountMarkupPercent = CurStringInventory.DiscountMarkupPercent;	
			NewRow.Amount				 = CurStringInventory.Amount;
			NewRow.VATRate			 = CurStringInventory.VATRate;
			NewRow.VATAmount			 = CurStringInventory.VATAmount;
			NewRow.Total				 = CurStringInventory.Total;
			NewRow.Content 			 = CurStringInventory.Content;
			// AutomaticDiscounts
			If UseAutomaticDiscounts Then
				NewRow.ConnectionKey			 = CurStringInventory.ConnectionKey;
				NewRow.AutomaticDiscountAmount	= CurStringInventory.AutomaticDiscountAmount;
				NewRow.AutomaticDiscountsPercent	= CurStringInventory.AutomaticDiscountsPercent;
			EndIf;
			// End AutomaticDiscounts
			
		EndDo;
		
		PaymentAmount = Inventory.Total("Total");
		
		// AutomaticDiscounts
		If UseAutomaticDiscounts Then
			DiscountsMarkups.Load(FillingData.DiscountsMarkups.Unload());
			DiscountsAreCalculated = FillingData.DiscountsAreCalculated;
		EndIf;
		// End AutomaticDiscounts
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.AcceptanceCertificate") Then
		
		Company		= FillingData.Company;
		DocumentCurrency = FillingData.DocumentCurrency;
		Contract			= FillingData.Contract;
		Counterparty		= FillingData.Counterparty;
		BankAccount	= FillingData.Company.BankAccountByDefault;
		VATTaxation = FillingData.VATTaxation;
		// DiscountCards
		DiscountCard = FillingData.DiscountCard;
		DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
		// End DiscountCards
		
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
		
		For Each CurStringInventory IN FillingData.WorksAndServices Do
			NewRow = Inventory.Add();
			NewRow.ProductsAndServices		 = CurStringInventory.ProductsAndServices;
			NewRow.Characteristic		 = CurStringInventory.Characteristic;
			NewRow.MeasurementUnit	 = CurStringInventory.MeasurementUnit;
			NewRow.Quantity			 = CurStringInventory.Quantity;
			NewRow.Price				 = CurStringInventory.Price;	
			NewRow.DiscountMarkupPercent = CurStringInventory.DiscountMarkupPercent;	
			NewRow.Amount				 = CurStringInventory.Amount;
			NewRow.VATRate			 = CurStringInventory.VATRate;
			NewRow.VATAmount			 = CurStringInventory.VATAmount;
			NewRow.Total				 = CurStringInventory.Total;
			NewRow.Content 			 = CurStringInventory.Content;
			// AutomaticDiscounts
			If UseAutomaticDiscounts Then
				NewRow.ConnectionKey			 = CurStringInventory.ConnectionKey;
				NewRow.AutomaticDiscountAmount	= CurStringInventory.AutomaticDiscountAmount;
				NewRow.AutomaticDiscountsPercent	= CurStringInventory.AutomaticDiscountsPercent;
			EndIf;
			// End AutomaticDiscounts
		EndDo;
		
		PaymentAmount = Inventory.Total("Total");
		
		// AutomaticDiscounts
		If UseAutomaticDiscounts Then
			DiscountsMarkups.Load(FillingData.DiscountsMarkups.Unload());
			DiscountsAreCalculated = FillingData.DiscountsAreCalculated;
		EndIf;
		// End AutomaticDiscounts
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProcessingReport") Then
		
		Company		= FillingData.Company;
		DocumentCurrency = FillingData.DocumentCurrency;
		Contract			= FillingData.Contract;
		Counterparty		= FillingData.Counterparty;
		BankAccount	= FillingData.Company.BankAccountByDefault;
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
		
		For Each CurStringInventory IN FillingData.Products Do
			
			NewRow = Inventory.Add();
			NewRow.ProductsAndServices		 = CurStringInventory.ProductsAndServices;
			NewRow.Characteristic		 = CurStringInventory.Characteristic;
			NewRow.Batch				 = CurStringInventory.Batch;
			NewRow.MeasurementUnit	 = CurStringInventory.MeasurementUnit;
			NewRow.Quantity			 = CurStringInventory.Quantity;
			NewRow.Price				 = CurStringInventory.Price;	
			NewRow.DiscountMarkupPercent = CurStringInventory.DiscountMarkupPercent;	
			NewRow.Amount				 = CurStringInventory.Amount;
			NewRow.VATRate			 = CurStringInventory.VATRate;
			NewRow.VATAmount			 = CurStringInventory.VATAmount;
			NewRow.Total				 = CurStringInventory.Total; 
			NewRow.Content 			 = CurStringInventory.Content;
			
		EndDo;
		
		PaymentAmount = Inventory.Total("Total");
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Event") Then
	
		Event = FillingData.Ref;
		If FillingData.Parties.Count() > 0 AND TypeOf(FillingData.Parties[0].Contact) = Type("CatalogRef.Counterparties") Then
			Counterparty = FillingData.Parties[0].Contact;
			Contract = Counterparty.ContractByDefault;
		EndIf;
		
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
		
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			If Company <> SettingValue Then
				Company = SettingValue;
			EndIf;
		Else
			Company = Catalogs.Companies.MainCompany;	
		EndIf;
		
		VATTaxation = SmallBusinessServer.VATTaxation(Company,, Date);
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseDiscountsMarkups");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups"); // AutomaticDiscounts
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory IN Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				MessageText = NStr("en='Column ""Amount"" is not populated in string %Number% of list ""Inventory"".';ru='Не заполнена колонка ""Сумма"" в строке %Номер% списка ""Запасы"".'");
				MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
				SmallBusinessServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
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

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Subordinate customer invoice note
	If Not Cancel Then
		
		SubordinatedInvoiceControl();
		
	EndIf;
	
EndProcedure // UndoPosting()

#EndRegion

#EndIf