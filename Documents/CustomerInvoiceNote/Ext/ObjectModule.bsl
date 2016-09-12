#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF FILLING THE DOCUMENT

// Fills in the tabular section with inventory items and distributes advance amount among the strings
//
Procedure FillTabularSectionInventory(StringDetailsPayment, InventoryDocument)
	
	TabularSectionName	= "Inventory";
	
	DistributionAmounts = New Structure;
	DistributionAmounts.Insert("Amount", 	StringDetailsPayment.Amount);
	DistributionAmounts.Insert("VATAmount", StringDetailsPayment.VATAmount);
	DistributionAmounts.Insert("Total",	StringDetailsPayment.Total);
	
	TotalByDocumentInventory = 0;
	LineCount = 0;
	For Each TSRow IN InventoryDocument[TabularSectionName] Do
		
		If StringDetailsPayment.VATRate = TSRow.VATRate Then
			
			TotalByDocumentInventory = TotalByDocumentInventory + TSRow.Total;
			LineCount = LineCount + 1;
			
		EndIf;
		
	EndDo;
	
	If LineCount = 0
		OR TotalByDocumentInventory = 0 Then
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, StringDetailsPayment);
		
		//No string found for advance amount distributioin. Create a special advance string
		NewRow.Content = "Preliminary payment";
		
		// If VAT rate is not calculated, then substitute a payment rate
		If ValueIsFilled(NewRow.VATRate) AND Not NewRow.VATRate.Calculated Then
			NewRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(NewRow.VATRate);
		EndIf;
		
		Return;
		
	EndIf;
	
	For Each DocumentRow IN InventoryDocument[TabularSectionName] Do
		
		If StringDetailsPayment.VATRate = DocumentRow.VATRate Then
			
			NewRow = Inventory.Add();
			NewRow.ProductsAndServices		= DocumentRow.ProductsAndServices;
			NewRow.Content			= DocumentRow.Content;
			NewRow.Characteristic		= DocumentRow.Characteristic;
			NewRow.Batch				= DocumentRow.Batch;
			NewRow.MeasurementUnit	= DocumentRow.MeasurementUnit;
			NewRow.Quantity			= DocumentRow.Quantity;
			NewRow.VATRate			= DocumentRow.VATRate;
			ValueOfProductsAndServices 			= DocumentRow.Total / TotalByDocumentInventory;
			
			If LineCount = 1 Then
				
				// If the string is the last one, carry forward the rest of advance amount 
				FillPropertyValues(NewRow, DistributionAmounts);
				NewRow.Price = NewRow.Amount;
				
			Else
				
				For Each Indicator IN DistributionAmounts Do
					
					NewRow[Indicator.Key] = Round(StringDetailsPayment[Indicator.Key] * ValueOfProductsAndServices, 2);
					DistributionAmounts.Insert(Indicator.Key, Indicator.Value - NewRow[Indicator.Key]);
					
					If Indicator.Key = "Amount" Then
						
						NewRow.Price = NewRow.Amount;
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
			// If VAT rate is not calculated, then substitute a payment rate
			If ValueIsFilled(NewRow.VATRate) AND Not NewRow.VATRate.Calculated Then
				NewRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(NewRow.VATRate);
			EndIf;
			
			LineCount = LineCount - 1;
			
		EndIf;
		
	EndDo;
	
EndProcedure // FillProductsTabularSection()

// The procedure fills in the document using ReportToPrincipal.
//
Procedure FillByReportToPrincipal(FillingData) Export
	
	Query			= New Query;
	
	Query.Text	= 
	"SELECT
	|	ReportToPrincipalInventory.Ref AS Ref,
	|	SUM(CASE
	|			WHEN ReportToPrincipalInventory.BrokerageAmount = 0
	|				THEN 0
	|			WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|				THEN ReportToPrincipalInventory.BrokerageAmount / ((ReportToPrincipalInventory.VATRate.Rate + 100) / 100)
	|			ELSE ReportToPrincipalInventory.BrokerageAmount
	|		END) AS Price,
	|	SUM(CASE
	|			WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|				THEN ReportToPrincipalInventory.BrokerageAmount / ((ReportToPrincipalInventory.VATRate.Rate + 100) / 100)
	|			ELSE ReportToPrincipalInventory.BrokerageAmount
	|		END) AS Amount,
	|	ReportToPrincipalInventory.VATRate AS VATRate,
	|	SUM(ReportToPrincipalInventory.BrokerageVATAmount) AS VATAmount,
	|	SUM(CASE
	|			WHEN ReportToPrincipalInventory.Ref.AmountIncludesVAT
	|				THEN ReportToPrincipalInventory.BrokerageAmount
	|			ELSE ReportToPrincipalInventory.BrokerageAmount + ReportToPrincipalInventory.BrokerageVATAmount
	|		END) AS Total
	|INTO Remuneration
	|FROM
	|	Document.ReportToPrincipal.Inventory AS ReportToPrincipalInventory
	|WHERE
	|	ReportToPrincipalInventory.Ref = &Ref
	|
	|GROUP BY
	|	ReportToPrincipalInventory.Ref,
	|	ReportToPrincipalInventory.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsCustomerInvoiceNote.Sale) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract AS Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	TRUE AS Same,
	|	""Fee"" AS Content,
	|	1 AS Quantity,
	|	Remuneration.Price AS Price,
	|	Remuneration.Amount AS Amount,
	|	Remuneration.VATRate AS VATRate,
	|	Remuneration.VATAmount AS VATAmount,
	|	Remuneration.Total AS Total
	|FROM
	|	Document.ReportToPrincipal AS Document
	|		LEFT JOIN Remuneration AS Remuneration
	|		ON Document.Ref = Remuneration.Ref
	|WHERE
	|	Document.Ref = &Ref
	|
	|GROUP BY
	|	Document.Ref,
	|	Document.Company,
	|	Document.Counterparty,
	|	Document.Contract,
	|	Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity,
	|	Remuneration.Price,
	|	Remuneration.Amount,
	|	Remuneration.VATRate,
	|	Remuneration.VATAmount,
	|	Remuneration.Total";
	
	Query.SetParameter("Ref", FillingData);
	
	QueryResultSelection = Query.Execute().Select();
	
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		ThisObject.BasisDocument = FillingData;
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			
			StructureByCurrency	= InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate 				= StructureByCurrency.ExchangeRate;
			Multiplicity			= StructureByCurrency.Multiplicity;
			
		EndIf;
		
		Inventory.Clear();
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, QueryResultSelection);
		
	EndIf;
	
EndProcedure //FillInUsingReportToPrincipal()

// The procedure fills in the document using CashReceipt.
//
Procedure FillByCashReceipt(FillingData, FillingMultipleDocuments = False)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReceiptOfCFPaymentDetails.Ref AS PaymentDocument,
	|	ReceiptOfCFPaymentDetails.VATRate AS VATRate,
	|	SUM(ReceiptOfCFPaymentDetails.PaymentAmount - ReceiptOfCFPaymentDetails.VATAmount) AS Amount,
	|	SUM(ReceiptOfCFPaymentDetails.VATAmount) AS VATAmount,
	|	SUM(ReceiptOfCFPaymentDetails.PaymentAmount) AS Total,
	|	ReceiptOfCFPaymentDetails.Order AS CustomerOrder,
	|	ReceiptOfCFPaymentDetails.InvoiceForPayment AS InvoiceForPayment
	|FROM
	|	Document.CashReceipt.PaymentDetails AS ReceiptOfCFPaymentDetails
	|WHERE
	|	ReceiptOfCFPaymentDetails.Ref = &Ref
	|	AND ReceiptOfCFPaymentDetails.AdvanceFlag
	|	AND ReceiptOfCFPaymentDetails.VATRate.Rate > 0
	|	AND Not ReceiptOfCFPaymentDetails.VATRate.NotTaxable
	|
	|GROUP BY
	|	ReceiptOfCFPaymentDetails.Ref,
	|	ReceiptOfCFPaymentDetails.VATRate,
	|	ReceiptOfCFPaymentDetails.Order,
	|	ReceiptOfCFPaymentDetails.InvoiceForPayment";
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	
	// Check data for an advance invoice
	If QueryResult.IsEmpty() Then
		
		ErrorMessage = NStr("en='No data found for the advance invoice."
"Basis document ""%BasisDocument"".';ru='Нет данных для счета-фактуры на аванс!"
"Основание ""%ДокументОснование"".'");
		
		ErrorMessage = StrReplace(ErrorMessage, "%BasisDocument", FillingData);
		
		Raise ErrorMessage;
		
	EndIf;
	
	SelectionOfQueryResult = QueryResult.Select();
	
	//Fill in header
	FillPropertyValues(ThisObject, FillingData, , "Number, Date");
	
	If FillingData.PaymentDetails.Count() > 0 Then
		
		ThisObject.Contract = FillingData.PaymentDetails[0].Contract;
		
	EndIf;
	
	DocumentCurrency = FillingData.CashCurrency;
	OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance;
	BasisDocument = FillingData;
	If DocumentCurrency <> Constants.NationalCurrency.Get() Then
		
		StructureByCurrency 	= InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", DocumentCurrency));
		ExchangeRate 				= StructureByCurrency.ExchangeRate;
		Multiplicity 			= StructureByCurrency.Multiplicity;
		
	EndIf;
	
	//Fill in TS
	While SelectionOfQueryResult.Next() Do
		
		// If account is specified, get the TS list from the account and distribute the document amount
		DocumentForFillTP = ?(ValueIsFilled(SelectionOfQueryResult.InvoiceForPayment),
				SelectionOfQueryResult.InvoiceForPayment,
				SelectionOfQueryResult.CustomerOrder);
		
		If ValueIsFilled(DocumentForFillTP) Then
			
			FillTabularSectionInventory(SelectionOfQueryResult, DocumentForFillTP);
			
		Else
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			NewRow.Quantity = 1;
			NewRow.Price = NewRow.Amount;
			
			//If the "Products and services" field is empty, fill in the "Content" field
			If Not ValueIsFilled(NewRow.ProductsAndServices) Then
				NewRow.Content = "Preliminary payment";
			EndIf;
			
			// If VAT rate is not calculated, then substitute a payment rate
			If ValueIsFilled(NewRow.VATRate) AND Not NewRow.VATRate.Calculated Then
				NewRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(NewRow.VATRate);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	RowPaymentDocumentsDateNumber = PaymentDocumentsDateNumber.Add();
	RowPaymentDocumentsDateNumber.PaymentAccountingDocumentDate = FillingData.Date;
	RowPaymentDocumentsDateNumber.PaymentAccountingDocumentNumber = FillingData.Number;
	
EndProcedure // FillByCashReceipt()

// The procedure fills in the document using PaymentReceipt.
//
Procedure FillByPaymentReceipt(FillingData, FillingMultipleDocuments = False)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReceiptOfCFPaymentDetails.Ref AS PaymentDocument,
	|	ReceiptOfCFPaymentDetails.VATRate AS VATRate,
	|	SUM(ReceiptOfCFPaymentDetails.PaymentAmount - ReceiptOfCFPaymentDetails.VATAmount) AS Amount,
	|	SUM(ReceiptOfCFPaymentDetails.VATAmount) AS VATAmount,
	|	SUM(ReceiptOfCFPaymentDetails.PaymentAmount) AS Total,
	|	ReceiptOfCFPaymentDetails.Order AS CustomerOrder,
	|	ReceiptOfCFPaymentDetails.InvoiceForPayment AS InvoiceForPayment
	|FROM
	|	Document.PaymentReceipt.PaymentDetails AS ReceiptOfCFPaymentDetails
	|WHERE
	|	ReceiptOfCFPaymentDetails.Ref = &Ref
	|	AND ReceiptOfCFPaymentDetails.AdvanceFlag
	|	AND ReceiptOfCFPaymentDetails.VATRate.Rate > 0
	|	AND Not ReceiptOfCFPaymentDetails.VATRate.NotTaxable
	|
	|GROUP BY
	|	ReceiptOfCFPaymentDetails.Ref,
	|	ReceiptOfCFPaymentDetails.VATRate,
	|	ReceiptOfCFPaymentDetails.Order,
	|	ReceiptOfCFPaymentDetails.InvoiceForPayment";
	
	Query.SetParameter("Ref", FillingData);
	QueryResult = Query.Execute();
	
	// Check data for an advance invoice
	If QueryResult.IsEmpty() Then
		
		ErrorMessage = NStr("en='No data found for the advance invoice."
"Basis document ""%BasisDocument"".';ru='Нет данных для счета-фактуры на аванс!"
"Основание ""%ДокументОснование"".'");
		
		ErrorMessage = StrReplace(ErrorMessage, "%BasisDocument", FillingData);
		
		Raise ErrorMessage;
		
	EndIf;
	
	SelectionOfQueryResult = QueryResult.Select();
	
	//Fill in header
	FillPropertyValues(ThisObject, FillingData, , "Number, Date");
	
	If FillingData.PaymentDetails.Count() > 0 Then
		
		For Each RowOfDetails IN FillingData.PaymentDetails Do
			
			If RowOfDetails.VATRate.Rate > 0 Then
				
				ThisObject.Contract = RowOfDetails.Contract;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	DocumentCurrency = FillingData.CashCurrency;
	OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance;
	BasisDocument = FillingData;
	If DocumentCurrency <> Constants.NationalCurrency.Get() Then
		
		StructureByCurrency 	= InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", DocumentCurrency));
		ExchangeRate 				= StructureByCurrency.ExchangeRate;
		Multiplicity 			= StructureByCurrency.Multiplicity;
		
	EndIf;
	
	//Fill in TS
	While SelectionOfQueryResult.Next() Do
		
		// If account is specified, get the TS list from the account and distribute the document amount
		DocumentForFillTP = ?(ValueIsFilled(SelectionOfQueryResult.InvoiceForPayment),
				SelectionOfQueryResult.InvoiceForPayment,
				SelectionOfQueryResult.CustomerOrder);
		
		If ValueIsFilled(DocumentForFillTP) Then
			
			FillTabularSectionInventory(SelectionOfQueryResult, DocumentForFillTP);
			
		Else
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			NewRow.Quantity = 1;
			NewRow.Price = NewRow.Amount;
			
			//If the "Products and services" field is empty, fill in the "Content" field
			If Not ValueIsFilled(NewRow.ProductsAndServices) Then
				NewRow.Content = "Preliminary payment";
			EndIf;
			
			// If VAT rate is not calculated, then substitute a payment rate
			If ValueIsFilled(NewRow.VATRate) AND Not NewRow.VATRate.Calculated Then
				NewRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(NewRow.VATRate);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(FillingData.IncomingDocumentDate)
		OR ValueIsFilled(FillingData.IncomingDocumentNumber) Then
		
		RowPaymentDocumentsDateNumber = PaymentDocumentsDateNumber.Add();
		RowPaymentDocumentsDateNumber.PaymentAccountingDocumentDate = FillingData.IncomingDocumentDate;
		RowPaymentDocumentsDateNumber.PaymentAccountingDocumentNumber = FillingData.IncomingDocumentNumber;
		
	EndIf;
	
EndProcedure // FillByPaymentReceipt()

// The procedure fills in the CCD numbers.
//
Procedure FillCCDNumbers(FillingData, FillingMultipleDocuments = False)
	
	SetPrivilegedMode(True);
	
	Map = New Map;
	Map.Insert(Type("DocumentRef.CustomerInvoice"), "CustomerInvoice");
	Map.Insert(Type("DocumentRef.CustomerOrder"), "CustomerOrder");
	Map.Insert(Type("DocumentRef.ProcessingReport"), "ProcessingReport");
	Map.Insert(Type("DocumentRef.ReportToPrincipal"), "ReportToPrincipal");
	Map.Insert(Type("DocumentRef.AgentReport"), "AgentReport");
	
	FillDocument = FillingData.FillDocument;
	
	If TypeOf(FillDocument) = Type("DocumentRef.CustomerOrder")
	   AND FillDocument.OperationKind <> Enums.OperationKindsCustomerOrder.JobOrder Then
		Raise NStr("en='Invoice can be entered on the basis of the job order only!';ru='Счет-фактуру можно ввести только на основании заказ-наряда!'");
	EndIf;
	
	If TypeOf(FillDocument) = Type("DocumentRef.ProcessingReport") Then
		TabularSectionName = "Products";
	Else
		TabularSectionName = "Inventory";
	EndIf;
	
	If TypeOf(FillDocument) = Type("DocumentRef.ReportToPrincipal")
		OR TypeOf(FillDocument) = Type("DocumentRef.AgentReport") Then
		Content = "NULL";
	Else
		Content = "TabSection.Content";
	EndIf; 
	
	// FILL IN HEADER
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument,
	|	VALUE(Enum.OperationKindsCustomerInvoiceNote.Sale) AS OperationKind,
	|	Document.Company,
	|	Document.Counterparty," + ?(TypeOf(FillDocument) = Type("DocumentRef.CustomerInvoice"), "
	|		Document.Consignor AS Consignor,
	|		Document.Consignee AS Consignee,
	|		CASE
	|			WHEN Document.Consignor = VALUE(Catalog.Counterparties.EmptyRef)
	|				THEN TRUE
	|			ELSE FALSE
	|		END AS Same,", "
	|		TRUE AS Same,") + "
	|	Document.Contract
	|	AS Contract, Document.DocumentCurrency,
	|	Document.ExchangeRate,
	|	Document.Multiplicity
	|FROM
	|	Document." + Map.Get(TypeOf(FillDocument)) + " AS
	|Document
	|	WHERE Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillDocument);
	QueryResult = Query.Execute();
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		FillPropertyValues(ThisObject, QueryResultSelection);
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
	EndIf;
	
	// GET TABULAR Parts
	Query = New Query(
	"SELECT	
	|		TabSection.ProductsAndServices,
	|		TabSection.Characteristic,
	|		TabSection.Batch,
	|		" + Content + " AS Content,
	|		TabSection.MeasurementUnit,
	|		TabSection.Quantity,
	|		CASE
	|			WHEN TabSection.Quantity = 0
	|				THEN 0
	|			WHEN TabSection.Ref.AmountIncludesVAT
	|				THEN TabSection.Amount / ((TabSection.VATRate.Rate + 100) / 100) / TabSection.Quantity
	|			ELSE TabSection.Amount / TabSection.Quantity
	|		END AS Price,
	|		CASE
	|			WHEN TabSection.Ref.AmountIncludesVAT
	|				THEN TabSection.Amount / ((TabSection.VATRate.Rate + 100) / 100)
	|			ELSE TabSection.Amount
	|		END AS Amount,
	|		VATRate,
	|		VATAmount,
	|		Total
	|FROM
	|	Document." + Map.Get(TypeOf(FillDocument)) + "." + TabularSectionName + " AS
	|TabSection
	|	WHERE TabSection.Ref = &Ref" +  ?(TypeOf(FillDocument) = Type("DocumentRef.CustomerOrder"), "
	|
	|UNION ALL
	|
	|SELECT	
	|		TabSection.ProductsAndServices,
	|		TabSection.Characteristic,
	|		UNDEFINED,
	|		Content AS Content,
	|		TabSection.ProductsAndServices.MeasurementUnit,
	|		TabSection.Quantity * TabSection.Factor * TabSection.Multiplicity,
	|		CASE
	|			WHEN TabSection.Quantity * TabSection.Factor * TabSection.Multiplicity = 0
	|				THEN 0
	|			WHEN TabSection.Ref.AmountIncludesVAT
	|				THEN TabSection.Amount / ((TabSection.VATRate.Rate + 100) / 100) / (TabSection.Quantity * TabSection.Factor * TabSection.Multiplicity)
	|			ELSE TabSection.Amount / (TabSection.Quantity * TabSection.Factor * TabSection.Multiplicity)
	|		END AS Price,
	|		CASE
	|			WHEN TabSection.Ref.AmountIncludesVAT
	|				THEN TabSection.Amount / ((TabSection.VATRate.Rate + 100) / 100)
	|			ELSE TabSection.Amount
	|		END AS Amount,
	|		VATRate,
	|		VATAmount,
	|		Total
	|FROM
	|	Document.CustomerOrder.Works AS TabSection
	|WHERE
	|	TabSection.Ref = &Ref", ""));
	
	Query.SetParameter("Ref", FillDocument);
	Selection = Query.Execute().Select();
	
	// RECEIVE BALANCE BY CCD
	Query = New Query(
	"SELECT
	|	InventoryByCCDBalances.CountryOfOrigin,
	|	InventoryByCCDBalances.QuantityBalance,
	|	InventoryByCCDBalances.ProductsAndServices,
	|	InventoryByCCDBalances.Characteristic,
	|	InventoryByCCDBalances.Batch,
	|	InventoryByCCDBalances.CCDNo,
	|	InventoryByCCDBalances.CCDNo.Code AS CCDCode,
	|	DATETIME(1, 1, 1) AS DateCCD
	|FROM
	|	AccumulationRegister.InventoryByCCD.Balance(
	|			,
	|			Company = &Company
	|				AND (ProductsAndServices, Characteristic, Batch) In
	|					(SELECT
	|						TabSection.ProductsAndServices AS ProductsAndServices,
	|						TabSection.Characteristic AS Characteristic,
	|						TabSection.Batch AS Batch
	|					FROM
	|						Document." + Map.Get(TypeOf(FillDocument)) + "." + TabularSectionName + " AS TabSection
	|					WHERE
	|						TabSection.Ref = &Ref)) AS InventoryByCCDBalances
	|WHERE
	|	InventoryByCCDBalances.QuantityBalance > 0");
	
	Query.SetParameter("Ref", FillDocument);
	Query.SetParameter("Company", SmallBusinessServer.GetCompany(FillDocument.Company));
	BalancesByCCD = Query.Execute().Unload();
	
	// SORT BALANCES BY CCD DATE
	For Each TableRow IN BalancesByCCD Do
		
		Position1 = Find(TableRow.CCDCode, "/");
		DateCCD = Right(TableRow.CCDCode, StrLen(TableRow.CCDCode) - Position1);
		Position2 = Find(DateCCD, "/");
		DateCCD = Left(DateCCD, Position2 - 1);
		
		If StrLen(DateCCD) = 6 Then
			
			DateDay = Left(DateCCD, 2);
			DateMonth = Mid(DateCCD, 3, 2);
			DateYear = Mid(DateCCD, 5, 2);
		
			Try
				DateYear = ?(Number(DateYear) >= 30, "19" + DateYear, "20" + DateYear);
				TableRow.DateCCD = Date(DateYear, DateMonth, DateDay);
			Except
				
			EndTry;
			
		EndIf;
		
	EndDo;
	
	BalancesByCCD.Sort("ProductsAndServices, Characteristic, Batch, DateCCD");
	
	// BALANCE DIVERSITY
	While Selection.Next() Do
		
		AmountByRow = Selection.Amount;
		VATAmountByRow = Selection.VATAmount;
		TotalOnLine = Selection.Total;
		
		FilterStructure = New Structure("ProductsAndServices, Characteristic, Batch", Selection.ProductsAndServices, Selection.Characteristic, Selection.Batch);
		RowsArrayCCD = BalancesByCCD.FindRows(FilterStructure);
		
		QuantityBalance = Selection.Quantity;
			
		For Each ArrayRow IN RowsArrayCCD Do
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			NewRow.CCDNo = ArrayRow.CCDNo;
			NewRow.CountryOfOrigin = ArrayRow.CountryOfOrigin;
				
			If QuantityBalance <= ArrayRow.QuantityBalance Then
				NewRow.Quantity = QuantityBalance;
				ArrayRow.QuantityBalance = ArrayRow.QuantityBalance - QuantityBalance;
				QuantityBalance = 0;
				BalancesByCCD.Delete(ArrayRow);
				
				NewRow.Amount = AmountByRow;
				NewRow.VATAmount = VATAmountByRow;
				NewRow.Total = TotalOnLine;
				
				Break;
			Else
				NewRow.Quantity = ArrayRow.QuantityBalance;
				QuantityBalance = QuantityBalance - ArrayRow.QuantityBalance;
				BalancesByCCD.Delete(ArrayRow);
				
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				VATRate = ?(ValueIsFilled(NewRow.VATRate), NewRow.VATRate.Rate, 0);
				NewRow.VATAmount = NewRow.Amount * VATRate / 100;
				NewRow.Total = NewRow.Amount + NewRow.VATAmount;
				
				AmountByRow = AmountByRow - NewRow.Amount;
				VATAmountByRow = VATAmountByRow - NewRow.VATAmount;
				TotalOnLine = TotalOnLine - NewRow.Total;
				
			EndIf;
			
		EndDo;
		
		If QuantityBalance > 0 Then
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			NewRow.Quantity = QuantityBalance;
			
			NewRow.Amount = AmountByRow;
			NewRow.VATAmount = VATAmountByRow;
			NewRow.Total = TotalOnLine;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
EndProcedure

// The procedure fills in the document using.
//
Procedure FillByAgentReportCustomers(FillStructure) Export
	
	// Header filling.
	FillingData = FillStructure.Ref;
	Date = FillStructure.Date;
	OperationKind = Enums.OperationKindsCustomerInvoiceNote.Sale;
	Company = FillStructure.Company;
	Counterparty = FillStructure.Customer;
	Contract = FillStructure.Customer.ContractByDefault;
	ConsolidatedCommission = FillStructure.ConsolidatedCommission;
	DocumentCurrency = FillStructure.DocumentCurrency;
	AmountIncludesVAT = FillStructure.AmountIncludesVAT;
	ExchangeRate = FillStructure.ExchangeRate;
	Multiplicity  = FillStructure.Multiplicity;
	Same = True;
	
	If DocumentCurrency <> Constants.NationalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	BasisDocument = FillingData;
	
	// Fill in TS.
	Inventory.Clear();
	SearchResult = FillStructure.Inventory;
	For Each TabularSectionRow IN SearchResult Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		If NewRow.Quantity = 0 Then
			NewRow.Price = 0;
		ElsIf AmountIncludesVAT Then
			NewRow.Price = NewRow.Amount / ((NewRow.VATRate.Rate + 100) / 100) / NewRow.Quantity;
		Else
			NewRow.Price = NewRow.Amount / NewRow.Quantity;
		EndIf;
		
		If AmountIncludesVAT Then
			NewRow.Amount = NewRow.Amount / ((NewRow.VATRate.Rate + 100) / 100);
		EndIf;
		
	EndDo;
	
EndProcedure // FillByAgentReportCustomers()

// The procedure fills in the document using.
//
Procedure FillByOtherDocuments(FillingData) Export
	
	Map = New Map;
	Map.Insert(Type("DocumentRef.CustomerInvoice"), "CustomerInvoice");
	Map.Insert(Type("DocumentRef.ProcessingReport"), "ProcessingReport");
	Map.Insert(Type("DocumentRef.AcceptanceCertificate"), "AcceptanceCertificate");
	Map.Insert(Type("DocumentRef.ReportToPrincipal"), "ReportToPrincipal");
	Map.Insert(Type("DocumentRef.AgentReport"), "AgentReport");
	Map.Insert(Type("DocumentRef.InvoiceForPayment"), "InvoiceForPayment");
	Map.Insert(Type("DocumentRef.CustomerOrder"), "CustomerOrder");
	
	If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder")
		AND FillingData.OperationKind <> Enums.OperationKindsCustomerOrder.JobOrder Then
		Raise NStr("en='Invoice can be entered on the basis of the job order only!';ru='Счет-фактуру можно ввести только на основании заказ-наряда!'");
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.AcceptanceCertificate") Then
		TabularSectionName = "WorksAndServices";
		Batch = "";
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProcessingReport") Then
		TabularSectionName = "Products";
		Batch = "
		|		Batch,";
	Else
		TabularSectionName = "Inventory";
		Batch = "
		|		Batch,";
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.ReportToPrincipal")
	 OR TypeOf(FillingData) = Type("DocumentRef.AgentReport") Then
		Content = "NULL";
	Else
		Content = "Content";
	EndIf; 
	
	Query = New Query(
	"SELECT
	|	Document.Ref AS BasisDocument," + ?(TypeOf(FillingData) = Type("DocumentRef.InvoiceForPayment"), "
	|		VALUE(Enum.OperationKindsCustomerInvoiceNote.Advance) AS OperationKind,", " 
	|		VALUE(Enum.OperationKindsCustomerInvoiceNote.Sale) AS OperationKind,") + "
	|	Document.Company, Document.Counterparty, Document.Contract AS Contract, Document.DocumentCurrency, Document.ExchangeRate, Document.Multiplicity,"
  + ?(TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice"), 
		"		Document.Consignor AS Consignor,
		|		Document.Consignee AS Consignee,
		|		CASE
		|			WHEN Document.Consignor = VALUE(Catalog.Counterparties.EmptyRef)
		|				THEN TRUE
		|			ELSE FALSE
		|		END AS Same,",
		"		TRUE AS Same,")
  + ?(TypeOf(FillingData) <> Type("DocumentRef.InvoiceForPayment"),
		"Document.Prepayment.(
		|		Document AS PrepaymentDocument,
		|		Document.Number AS Number,
		|		Document.Date AS Date,
		|		Document.IncomingDocumentNumber AS IncomingDocumentNumber,
		|		Document.IncomingDocumentDate AS IncomingDocumentDate,
		|	),",
		"")
  + "Document." + TabularSectionName + ".(
	|		ProductsAndServices,
	|		Characteristic," + Batch + "
	|		" + Content + " AS Content,
	|		MeasurementUnit,
	|		Quantity,
	|		CASE
	|			WHEN Document." + TabularSectionName + ".Quantity = 0
	|				THEN 0
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document." + TabularSectionName + ".Amount / ((Document." + TabularSectionName + ".VATRate.Rate + 100) / 100) / Document." + TabularSectionName + ".Quantity
	|			ELSE Document." + TabularSectionName + ".Amount / Document." + TabularSectionName + ".Quantity
	|		END AS Price,
	|		CASE
	|			WHEN Document.AmountIncludesVAT
	|				THEN Document." + TabularSectionName + ".Amount / ((Document." + TabularSectionName + ".VATRate.Rate + 100)
	|			/ 100) ELSE Document." + TabularSectionName + ".Amount
	|		END
	|		AS
	|		Amount,
	|		VATRate, VATAmount, Total
	|	)"
  + ?(TypeOf(FillingData) = Type("DocumentRef.CustomerOrder"), 
		",
		|	Document.Works.(
		|		ProductsAndServices,
		|		Characteristic,
		|		Content AS Content,
		|		ProductsAndServices.MeasurementUnit AS MeasurementUnit,
		|		Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity AS Quantity,
		|		CASE
		|			WHEN Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity = 0
		|				THEN 0
		|			WHEN Document.AmountIncludesVAT
		|				THEN Document.Works.Amount / ((Document.Works.VATRate.Rate + 100) / 100) / (Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity)
		|			ELSE Document.Works.Amount / (Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity)
		|		END AS Price,
		|		CASE
		|			WHEN Document.AmountIncludesVAT
		|				THEN Document.Works.Amount / ((Document.Works.VATRate.Rate + 100) / 100)
		|			ELSE Document.Works.Amount
		|		END AS Amount,
		|		VATRate,
		|		VATAmount,
		|		Total
		|	),
		|	Document.Works.(
		|		ProductsAndServices,
		|		Characteristic,
		|		Content AS Content,
		|		ProductsAndServices.MeasurementUnit AS MeasurementUnit,
		|		Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity AS Quantity,
		|		CASE
		|			WHEN Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity = 0
		|				THEN 0
		|			WHEN Document.AmountIncludesVAT
		|				THEN Document.Works.Amount / ((Document.Works.VATRate.Rate + 100) / 100) / (Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity)
		|			ELSE Document.Works.Amount / (Document.Works.Quantity *  Document.Works.Factor *  Document.Works.Multiplicity)
		|		END AS Price,
		|		CASE
		|			WHEN Document.AmountIncludesVAT
		|				THEN Document.Works.Amount / ((Document.Works.VATRate.Rate + 100) / 100)
		|			ELSE Document.Works.Amount
		|		END AS Amount,
		|		VATRate,
		|		VATAmount,
		|		Total
		|	)",
		"")
  + "FROM Document." + Map.Get(TypeOf(FillingData)) + " AS
	|Document
	|	WHERE Document.Ref = &Ref");
	
	Query.SetParameter("Ref", FillingData);
	
	QueryResult = Query.Execute();
	QueryResultSelection = QueryResult.Select();
	If QueryResultSelection.Next() Then
		
		FillPropertyValues(ThisObject, QueryResultSelection);
		ThisObject.BasisDocument = FillingData;
		
		If DocumentCurrency <> Constants.NationalCurrency.Get() Then
			StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
			ExchangeRate = StructureByCurrency.ExchangeRate;
			Multiplicity = StructureByCurrency.Multiplicity;
		EndIf;
		
		InventoryTable = QueryResultSelection[TabularSectionName].Unload();
		For Each StringInventoryTable IN InventoryTable Do
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, StringInventoryTable);
			
			// If VAT rate is not calculated, then substitute a payment rate
			If OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance
				AND ValueIsFilled(NewRow.VATRate)
				AND Not NewRow.VATRate.Calculated Then
				NewRow.VATRate = SmallBusinessReUse.GetVATRateEstimated(NewRow.VATRate);
			EndIf;
			
		EndDo;
		
		If TypeOf(FillingData) <> Type("DocumentRef.InvoiceForPayment") Then
			PrepaymentTable = QueryResultSelection.Prepayment.Unload();
			For Each RowPrepaymentTable IN PrepaymentTable Do
				If TypeOf(RowPrepaymentTable.PrepaymentDocument) = Type("DocumentRef.PaymentReceipt") Then
					If ValueIsFilled(RowPrepaymentTable.IncomingDocumentDate)
					 OR ValueIsFilled(RowPrepaymentTable.IncomingDocumentNumber) Then
						NewRow = PaymentDocumentsDateNumber.Add();
						NewRow.PaymentAccountingDocumentDate = RowPrepaymentTable.IncomingDocumentDate;
						NewRow.PaymentAccountingDocumentNumber = RowPrepaymentTable.IncomingDocumentNumber;
					EndIf;
				Else
					NewRow = PaymentDocumentsDateNumber.Add();
					NewRow.PaymentAccountingDocumentDate = RowPrepaymentTable.Date;
					NewRow.PaymentAccountingDocumentNumber = RowPrepaymentTable.Number;
				EndIf;
			EndDo;
		EndIf;
		
		If TypeOf(FillingData) = Type("DocumentRef.CustomerOrder") Then
			Works = QueryResultSelection.Works.Unload();
			For Each CurRowWork IN Works Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, CurRowWork);
			EndDo;
		EndIf;
		
		If TypeOf(FillingData) = Type("DocumentRef.CustomerInvoice") Then
			
			ThisObject.StampBase = FillingData.StampBase;
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	SmallBusinessManagementElectronicDocumentsServer.ClearIncomingDocumentDateNumber(ThisObject);
	
EndProcedure // OnCopy()

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	// Check invoice note duplicate
	If TypeOf(FillingData) = Type("Structure") Then
		
		If FillingData.Property("FillDocument") Then
			
			BasisDocument				= FillingData.FillDocument;
			BasisDocuments.Clear();
			
			NewRow 					= BasisDocuments.Add();
			NewRow.BasisDocument	= FillingData.FillDocument;
			
		ElsIf FillingData.Property("FillByBasisDocuments")
			AND FillingData.FillByBasisDocuments Then
			
		Else
			
			Return;
			
		EndIf;
		
	Else
		
		// Attribute
		BasisDocument				= FillingData;
		
		// Tabular section
		BasisDocuments.Clear();
		NewRow 					= BasisDocuments.Add();
		NewRow.BasisDocument	= FillingData;
		
	EndIf;
	
	For Each CurRow IN BasisDocuments Do
		
		InvoiceFound = SmallBusinessServer.GetSubordinateInvoice(CurRow.BasisDocument);
		
		If ValueIsFilled(InvoiceFound)
			AND InvoiceFound.Ref <> Ref Then
			
			MessageText = NStr("en='Invoice note ""%InvoiceNote%"" already exists for document ""%Reference%""."
"Cannot add another document ""Invoice"".';ru='Для документа ""%Ссылка%"" уже введен счет-фактура ""%СчетФактура%""."
"Запись еще одного документа ""Счет-фактура"" не допускается!'"
			);
			
			MessageText = StrReplace(MessageText, "%Ref%", CurRow.BasisDocument);
			MessageText = StrReplace(MessageText, "%CustomerInvoiceNote%", InvoiceFound.Ref);
			
			Raise MessageText;
			
		EndIf;
		
	EndDo;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("FillCCDNumbers")
		AND FillingData.FillCCDNumbers Then
		
		FillCCDNumbers(FillingData);
		
	Else
		
		Inventory.Clear();
		PaymentDocumentsDateNumber.Clear();
		For Each RowDocumentsBases IN BasisDocuments Do
			
			If TypeOf(RowDocumentsBases.BasisDocument) = Type("DocumentRef.CashReceipt") Then
				
				FillByCashReceipt(RowDocumentsBases.BasisDocument);
				
			ElsIf TypeOf(RowDocumentsBases.BasisDocument) = Type("DocumentRef.PaymentReceipt") Then
				
				FillByPaymentReceipt(RowDocumentsBases.BasisDocument);
				
			ElsIf TypeOf(RowDocumentsBases.BasisDocument) = Type("DocumentRef.ReportToPrincipal") Then
				
				FillByReportToPrincipal(RowDocumentsBases.BasisDocument);
				
			Else
				
				FillByOtherDocuments(RowDocumentsBases.BasisDocument);
				
			EndIf;
			
		EndDo;
		
		Inventory.GroupBy("ProductsAndServices, Content, Characteristic, Batch, MeasurementUnit, Price, VATRate, CountryOfOrigin, CCDNo", "Quantity, Amount, VATAmount, Total");
		
	EndIf;
	
EndProcedure // FillingProcessor()

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not (OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance 
		OR OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance) Then
		
		CheckedAttributes.Add("Inventory.Quantity");
		CheckedAttributes.Add("Inventory.Price");
		
		If Not TypeOf(BasisDocument) = Type("DocumentRef.ReportToPrincipal") Then
			
			CheckedAttributes.Add("Inventory.ProductsAndServices");
			CheckedAttributes.Add("Inventory.MeasurementUnit");
			
		EndIf;
		
	EndIf;
	
	For Each InventoryTableRow IN Inventory Do
		
		If Not OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance
			AND ValueIsFilled(InventoryTableRow.CCDNo)
			AND (NOT ValueIsFilled(InventoryTableRow.CountryOfOrigin)
				OR InventoryTableRow.CountryOfOrigin = Catalogs.WorldCountries.Russia) Then
			
			ErrorText = NStr("en='Incorrect country of origin in string [%LineNumberWithError%]';ru='В строке [%НомерСтрокиСОшибкой%] не верно указана страна происхождения'");
			ErrorText = StrReplace(ErrorText, "%LineNumberWithError%", TrimAll(InventoryTableRow.LineNumber));
			
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject, 
				ErrorText,
				"Inventory",
				InventoryTableRow.LineNumber,
				"CountryOfOrigin",
				Cancel
			);
			
		EndIf;
		
		If Not (OperationKind = Enums.OperationKindsCustomerInvoiceNote.Advance 
				OR OperationKind = Enums.OperationKindsCustomerInvoiceNote.OnPrincipalAdvance)
			AND (ValueIsFilled(InventoryTableRow.CountryOfOrigin)
				AND Not InventoryTableRow.CountryOfOrigin = Catalogs.WorldCountries.Russia)
			AND Not ValueIsFilled(InventoryTableRow.CCDNo) Then
			
			ErrorText = NStr("en='Specify the CCD number in string [%LineNumberWithError%]';ru='В строке [%НомерСтрокиСОшибкой%] не указан номер ГТД'");
			ErrorText = StrReplace(ErrorText, "%LineNumberWithError%", TrimAll(InventoryTableRow.LineNumber));
			
			SmallBusinessServer.ShowMessageAboutError(
				ThisObject,
				ErrorText,
				"Inventory",
				InventoryTableRow.LineNumber,
				"CCDNo",
				Cancel
			);
			
		EndIf;
		
	EndDo;
	
	//  Post basis document
	BasisDocumentsArray		= BasisDocuments.Unload();
	NewRow						= BasisDocumentsArray.Add();
	NewRow.BasisDocument	= BasisDocument;
	
	BasisDocumentsArray.GroupBy("BasisDocument");
	
	For Each TableRow IN BasisDocumentsArray Do
		
		BasisDocument = TableRow.BasisDocument;
		
		If ValueIsFilled(BasisDocument)
			AND Not BasisDocument.Posted Then
			
			ErrorText = NStr("en='Basis document %BasisDocumentView% is not posted. Invoice posting is impossible.';ru='Документ-основание %ПредставлениеДокументаОснования% не проведен. Проведение счет фактуры не возможно.'");
			ErrorText = StrReplace(ErrorText, "%BasisDocumentView%", """" + TypeOf(BasisDocument) + " #" + BasisDocument.Number + " dated " + BasisDocument.Date + """");
			
			SmallBusinessServer.ShowMessageAboutError(ThisObject, ErrorText, , , , Cancel);
			
		EndIf;
		
	EndDo;
	
	If Not Counterparty.DoOperationsByContracts Then
		SmallBusinessServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure // FillCheckProcessing()

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	// Check invoice note duplicate
	If ValueIsFilled(BasisDocument) AND Not TypeOf(BasisDocument) = Type("DocumentRef.AgentReport") Then
		
		InvoiceFound = SmallBusinessServer.GetSubordinateInvoice(BasisDocument);
		If ValueIsFilled(InvoiceFound) AND InvoiceFound.Ref <> Ref Then
		
			MessageText = NStr("en='Invoice note ""%InvoiceNote%"" already exists for document ""%Reference%"". "
"Cannot add another document ""Invoice"".';ru='Для документа ""%Ссылка%"" уже введен счет-фактура ""%СчетФактура%"". "
"Запись еще одного документа ""Счет-фактура"" не допускается!'");
			MessageText = StrReplace(MessageText, "%Ref%", BasisDocument);
			MessageText = StrReplace(MessageText, "%CustomerInvoiceNote%", InvoiceFound.Ref);
			MessageField = "Object.BasisDocument";
			
			SmallBusinessServer.ShowMessageAboutError(ThisObject, MessageText,,,MessageField, Cancel);
			
			Return;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
EndProcedure // BeforeWrite()

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CustomerInvoiceNote.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	SmallBusinessServer.ReflectInventoryByCCD(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);

    // Control
	Documents.CustomerInvoiceNote.RunControl(Ref, AdditionalProperties, Cancel);    
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure // Posting()

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	SmallBusinessServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	SmallBusinessServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	SmallBusinessServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.CustomerInvoiceNote.RunControl(Ref, AdditionalProperties, Cancel, True);
		
EndProcedure // UndoPosting()

#EndIf