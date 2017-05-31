Procedure GenerateAPARRecordsOnBookkeepingRecords(DocumentObject,BookkeepingRecords,Cancel = False) Export
	
	If NOT SessionParameters.IsBookkeepingAvailable Then
		Return;
	Else	
		DocumentMetadata = DocumentObject.Metadata();
		IsBookkeepingOperation = TypeOf(DocumentObject) = Type("DocumentObject.BookkeepingOperation");
		
		NationalCurrency = Constants.NationalCurrency.Get();
		For Each BookkeepingRecord In BookkeepingRecords Do
			
			MessageTextBegin = Alerts.ParametrizeString(NStr("en = 'Tabular part ''Records'', line number %P1.'; pl = 'Część tabelaryczna ''Zapisy'', numer linii %P1.'"),New Structure("P1",TrimAll(BookkeepingRecord.LineNumber)));
			
			If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsPayable
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsReceivable
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsPayablePrepayment
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsReceivablePrepayment Then
				
				NewRecord = DocumentObject.RegisterRecords.PartnersSettlements.Add();
				DocumentObject.RegisterRecords.PartnersSettlements.Write = True;
				DocumentObject.RegisterRecords.PartnersSettlements.LockForUpdate = True;
				NewRecord.Partner = BookkeepingRecord.ExtDimension1;
				
				If IsBookkeepingOperation Then
					NewRecord.Currency	  = BookkeepingRecord.Currency;
					If ValueIsNotFilled(NewRecord.Currency) Then
						NewRecord.Currency = NationalCurrency;
					EndIf;	
				ElsIf CommonAtServer.IsDocumentAttribute("RecordsCurrency",DocumentMetadata) Then
					NewRecord.Currency	  = DocumentObject.RecordsCurrency;
				ElsIf CommonAtServer.IsDocumentAttribute("SettlementCurrency",DocumentMetadata) Then
					NewRecord.Currency	  = DocumentObject.SettlementCurrency;
				EndIf;	
				NewRecord.Company	  = DocumentObject.Company;
				NewRecord.Period	  = DocumentObject.Date;
				NewRecord.Document	  = BookkeepingRecord.ExtDimension2;
				If ValueIsNotFilled(NewRecord.Document) Then
					NewRecord.Document = DocumentObject.Ref;
				EndIf;
				If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsPayable Then
					NewRecord.SettlementType = Enums.PartnerSettlementTypes.SupplierSettlement;
				ElsIf BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsPayablePrepayment Then
					NewRecord.SettlementType = Enums.PartnerSettlementTypes.PrepaymentToSupplier;
				ElsIf BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsReceivable Then
					NewRecord.SettlementType = Enums.PartnerSettlementTypes.CustomerSettlement;
				ElsIf BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.AccountsReceivablePrepayment Then
					NewRecord.SettlementType = Enums.PartnerSettlementTypes.PrepaymentFromCustomer;	
				EndIf;
				
				If IsBookkeepingOperation Then
					If BookkeepingRecord.AmountCr<>0 Then
						NewRecord.AmountNational = BookkeepingRecord.AmountCr;
						NewRecord.RecordType = AccumulationRecordType.Expense;
					Else
						NewRecord.AmountNational = BookkeepingRecord.AmountDr;
						NewRecord.RecordType = AccumulationRecordType.Receipt;
					EndIf;
					
					If BookkeepingRecord.Account.Currency Then
						NewRecord.Amount = BookkeepingRecord.CurrencyAmount;
					Else	
						NewRecord.Amount = NewRecord.AmountNational;
					EndIf;	
				Else	
					If BookkeepingRecord.AmountCr<>0 Then
						NewRecord.Amount = BookkeepingRecord.AmountCr;
						NewRecord.RecordType = AccumulationRecordType.Expense;
					Else
						NewRecord.Amount = BookkeepingRecord.AmountDr;
						NewRecord.RecordType = AccumulationRecordType.Receipt;
					EndIf;
					
					If BookkeepingRecord.AmountCrNational<>0 Then
						NewRecord.AmountNational = BookkeepingRecord.AmountCrNational;
					Else
						NewRecord.AmountNational = BookkeepingRecord.AmountDrNational;
					EndIf;
				EndIf;
				
			ElsIf BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.Employees
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.EmployeesPrepayment Then
				NewRecord = DocumentObject.RegisterRecords.EmployeesSettlements.Add();
				DocumentObject.RegisterRecords.EmployeesSettlements.Write = True;
				DocumentObject.RegisterRecords.EmployeesSettlements.LockForUpdate = True;
				NewRecord.Employee = BookkeepingRecord.ExtDimension1;
				If IsBookkeepingOperation Then
					NewRecord.Currency	  = BookkeepingRecord.Currency;
					If ValueIsNotFilled(NewRecord.Currency) Then
						NewRecord.Currency = NationalCurrency;
					EndIf;	
				ElsIf CommonAtServer.IsDocumentAttribute("RecordsCurrency",DocumentMetadata) Then
					NewRecord.Currency	  = DocumentObject.RecordsCurrency;
				EndIf;	
				
				NewRecord.Company	  = DocumentObject.Company;
				NewRecord.Period	  = DocumentObject.Date;
				NewRecord.Document	  = BookkeepingRecord.ExtDimension2;
				If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.Employees Then
					NewRecord.SettlementType = Enums.EmployeeSettlementTypes.EmployeeSettlement;
				EndIf;
				
				
				If IsBookkeepingOperation Then
					
					If BookkeepingRecord.AmountCr<>0 Then
						NewRecord.AmountNational = BookkeepingRecord.AmountCr;
						NewRecord.RecordType = AccumulationRecordType.Expense;
						If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.EmployeesPrepayment Then
							NewRecord.SettlementType = Enums.EmployeeSettlementTypes.PrepaymentFromEmployee;
						EndIf;	
					Else
						NewRecord.AmountNational = BookkeepingRecord.AmountDr;
						NewRecord.RecordType = AccumulationRecordType.Receipt;
						If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.EmployeesPrepayment Then
							NewRecord.SettlementType = Enums.EmployeeSettlementTypes.PrepaymentToEmployee;
						EndIf;	
					EndIf;
					
					If BookkeepingRecord.Account.Currency Then
						NewRecord.Amount = BookkeepingRecord.CurrencyAmount;
					Else	
						NewRecord.Amount = NewRecord.AmountNational;
					EndIf;	
				Else
					If BookkeepingRecord.AmountCr<>0 Then
						NewRecord.Amount = BookkeepingRecord.AmountCr;
						NewRecord.RecordType = AccumulationRecordType.Expense;
						If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.EmployeesPrepayment Then
							NewRecord.SettlementType = Enums.EmployeeSettlementTypes.PrepaymentFromEmployee;
						EndIf;	
					Else
						NewRecord.Amount = BookkeepingRecord.AmountDr;
						NewRecord.RecordType = AccumulationRecordType.Receipt;
						If BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.EmployeesPrepayment Then
							NewRecord.SettlementType = Enums.EmployeeSettlementTypes.PrepaymentToEmployee;
						EndIf;	
					EndIf;
					
					If BookkeepingRecord.AmountCrNational<>0 Then
						NewRecord.AmountNational = BookkeepingRecord.AmountCrNational;
					Else
						NewRecord.AmountNational = BookkeepingRecord.AmountDrNational;
					EndIf;
				EndIf;
				
			ElsIf BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.Bank
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.Cash
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.FixedAssets
				OR BookkeepingRecord.Account.Purpose = Enums.AccountPurpose.PrepaidExpenses Then
				
				Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = '%P0 Account %P1 with purpose %P2 can be used only in the bookkeeping operation based on document.'; pl = '%P0 Konto %P1 z przyznaczeniem %P2 może być użyte tylko w dowodzie księgowym na podstawie dokumentu.'"),New Structure("P0,P1,P2",MessageTextBegin,BookkeepingRecord.Account,BookkeepingRecord.Account.Purpose)),Enums.AlertType.Error,Cancel,DocumentObject);
				
			EndIf;	
			
		EndDo;	
	EndIf;
	
EndProcedure	

///////////////////////////////////////////////////////////////////////////////////////////////////
Procedure AmountOnChange(CurrentRow, ColumnName,MultiCurrencySettlement = False,ExchangeRates = Undefined,LockSettlementAmountToAmountCalculation = False) Export
	
	CurrencyStructure = GetDocumentsCurrencyAndExchangeRate(CurrentRow.Document);
	
	If MultiCurrencySettlement Then
		
		FoundRows = ExchangeRates.FindRows(New Structure("Currency",CurrentRow.DocumentSettlementCurrency));
		If FoundRows.Count()=0 Then
			Return;		
		EndIf; 
		CrossRate = FoundRows[0].CrossExchangeRate;
		
	EndIf;	
	
	If ColumnName = "AmountDr" And CurrentRow.AmountDr <> 0 Then
		
		CurrentRow.AmountDrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountDr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		If MultiCurrencySettlement AND NOT LockSettlementAmountToAmountCalculation Then
			CurrentRow.AmountCrSettlement = 0;
			CurrentRow.AmountDrSettlement = CurrentRow.AmountDr*CrossRate;
		EndIf;	
		
	ElsIf ColumnName = "AmountDrNational" And CurrentRow.AmountDrNational <> 0 Then
		
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		If MultiCurrencySettlement Then
			CurrentRow.AmountCrSettlement = 0;
		EndIf;	
		
	ElsIf MultiCurrencySettlement AND ColumnName = "AmountDrSettlement" And CurrentRow.AmountDrSettlement <> 0 Then
		
		CurrentRow.AmountCr = 0;
		CurrentRow.AmountCrNational = 0;
		CurrentRow.AmountCrSettlement = 0;
		
		CurrentRow.AmountDr = CurrentRow.AmountDrSettlement/CrossRate;
		CurrentRow.AmountDrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountDr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		
	ElsIf ColumnName = "AmountCr" And CurrentRow.AmountCr <> 0 Then
		
		CurrentRow.AmountCrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountCr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		If MultiCurrencySettlement AND NOT LockSettlementAmountToAmountCalculation Then
			CurrentRow.AmountDrSettlement = 0;
			CurrentRow.AmountCrSettlement = CurrentRow.AmountCr*CrossRate;
		EndIf;	
		
	ElsIf ColumnName = "AmountCrNational" And CurrentRow.AmountCrNational <> 0 Then
		
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		If MultiCurrencySettlement Then
			CurrentRow.AmountDrSettlement = 0;
		EndIf;	
		
	ElsIf MultiCurrencySettlement AND ColumnName = "AmountCrSettlement" And CurrentRow.AmountCrSettlement <> 0 Then
		
		CurrentRow.AmountDr = 0;
		CurrentRow.AmountDrNational = 0;
		CurrentRow.AmountDrSettlement = 0;
		
		CurrentRow.AmountCr = CurrentRow.AmountCrSettlement/CrossRate;
		CurrentRow.AmountCrNational = CommonAtServer.GetNationalAmount(CurrentRow.AmountCr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
		
	EndIf;
	
EndProcedure

Procedure AutoNationalAmountsRecalculate(Document, TabularSectionName) Export
		
	DocumentMetadata = Document.Metadata();
	If NOT Common.IsDocumentTabularPart(TabularSectionName,DocumentMetadata) Then
		Return;
	EndIf;	
	
	For Each TabularSectionRow In Document[TabularSectionName] Do
		
		If Common.IsDocumentTabularPartAttribute("Document", DocumentMetadata,TabularSectionName) Then
			CurrencyStructure = GetDocumentsCurrencyAndExchangeRate(TabularSectionRow.Document);
		ElsIf Common.IsDocumentTabularPartAttribute("ReservationDocument", DocumentMetadata, TabularSectionName) Then
			CurrencyStructure = GetDocumentsCurrencyAndExchangeRate(Document);
		EndIf;	
		
		IsDocumentTabularPartAttributeAmountDr = Common.IsDocumentTabularPartAttribute("AmountDr", DocumentMetadata, TabularSectionName);
		IsDocumentTabularPartAttributeAmountCr = Common.IsDocumentTabularPartAttribute("AmountCr", DocumentMetadata, TabularSectionName);
		
		If IsDocumentTabularPartAttributeAmountDr AND 
			TabularSectionRow.AmountDr <> 0 Then
			
			TabularSectionRow.AmountDrNational = CommonAtServer.GetNationalAmount(TabularSectionRow.AmountDr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
			If IsDocumentTabularPartAttributeAmountCr Then
				TabularSectionRow.AmountCr = 0;
				TabularSectionRow.AmountCrNational = 0;
			EndIf;	
			
		ElsIf IsDocumentTabularPartAttributeAmountCr AND 
			TabularSectionRow.AmountCr <> 0 Then
			
			TabularSectionRow.AmountCrNational = CommonAtServer.GetNationalAmount(TabularSectionRow.AmountCr, CurrencyStructure.Currency, CurrencyStructure.ExchangeRate);
			If IsDocumentTabularPartAttributeAmountDr Then
				TabularSectionRow.AmountDr = 0;
				TabularSectionRow.AmountDrNational = 0;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CheckDocumentOnPartnerChange(Partner, Document) Export
	
	If Document = Undefined Then
		Return;
	EndIf;
	
	DocumentPartner = Undefined;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		DocumentPartner = Document.Owner;
		
	Else
		
		If Document.Metadata().Attributes.Find("Customer") <> Undefined Then
			DocumentPartner = Document.Customer;
		ElsIf Document.Metadata().Attributes.Find("Supplier") <> Undefined Then
			DocumentPartner = Document.Supplier;
		ElsIf Document.Metadata().Attributes.Find("Partner") <> Undefined Then
			DocumentPartner = Document.Partner;
		EndIf;
		
	EndIf;
	
	If Partner <> DocumentPartner Then
		Document = Undefined;
	EndIf;
	
EndProcedure

Procedure CheckDocumentOnEmployeeChange(Employee, Document) Export
	
	If Document = Undefined Then
		Return;
	EndIf;
	
	DocumentEmployee = Undefined;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		DocumentEmployee = Document.Owner;
		
	Else
		
		If Document.Metadata().Attributes.Find("Employee") <> Undefined Then
			DocumentEmployee = Document.Employee;
		EndIf;
		
	EndIf;
	
	If Employee <> DocumentEmployee Then
		Document = Undefined;
	EndIf;
	
EndProcedure //CheckDocumentOnEmployeeChange()

Procedure DisplayInitialDocumentNumber(Column, Document, RowAppearance) Export
	
	If Column.Visible Then
		If ValueIsFilled(Document) And Document.Metadata().Attributes.Find("InitialDocumentNumber") <> Undefined Then
			RowAppearance.Cells.InitialDocumentNumber.SetText(Document.InitialDocumentNumber);
		Else
			RowAppearance.Cells.InitialDocumentNumber.SetText("");
		EndIf;
	EndIf;
	
EndProcedure

Function GetPartnersDocumentTypes(Partner,PrepaymentSettlement = Undefined,ExcludeInternalDocuments = False) Export
	
	TypesArray = New Array;
	
	If PrepaymentSettlement = Undefined OR 
		PrepaymentSettlement = Enums.PrepaymentSettlement.Settlement Then
		If TypeOf(Partner) = TypeOf(Catalogs.Customers.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.CustomerInternalDocuments"));
			EndIf;	
			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.SalesPrepaymentInvoice"));
			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.SalesInvoice"));
			TypesArray.Add(Type("DocumentRef.BookkeepingNote"));
			TypesArray.Add(Type("DocumentRef.InterestNote"));
			TypesArray.Add(Type("DocumentRef.SalesCreditNoteReturn"));
			TypesArray.Add(Type("DocumentRef.SalesCreditNotePriceCorrection"));
			TypesArray.Add(Type("DocumentRef.SalesRetail"));
			TypesArray.Add(Type("DocumentRef.SalesRetailReturn"));
		ElsIf TypeOf(Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.SupplierInternalDocuments"));
			EndIf;	
			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.PurchaseInvoice"));
			TypesArray.Add(Type("DocumentRef.PurchaseCreditNoteReturn"));
			TypesArray.Add(Type("DocumentRef.PurchaseCreditNotePriceCorrection"));
		Else
			TypesArray.Add(Type("Undefined"));
		EndIf;
	ElsIf PrepaymentSettlement = Enums.PrepaymentSettlement.Prepayment 
		OR PrepaymentSettlement = Enums.PrepaymentSettlement.PrepaymentSettlement Then
		If TypeOf(Partner) = TypeOf(Catalogs.Customers.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.CustomerInternalDocuments"));
			EndIf;	
			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.SalesOrder"));
			TypesArray.Add(Type("DocumentRef.SalesPrepaymentInvoice"));
			TypesArray.Add(Type("DocumentRef.SalesPrepaymentCreditNote"));
		ElsIf TypeOf(Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.SupplierInternalDocuments"));
			EndIf;	
			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
			TypesArray.Add(Type("DocumentRef.PurchaseOrder"));
			TypesArray.Add(Type("DocumentRef.PurchasePrepaymentInvoice"));
			TypesArray.Add(Type("DocumentRef.PurchasePrepaymentCreditNote"));
		Else
			TypesArray.Add(Type("Undefined"));
		EndIf;	
	Else
		TypesArray.Add(Type("Undefined"));
	EndIf;	
	
	Return New TypeDescription(TypesArray);
	
EndFunction // GetPartnersDocumentTypes()

// employee
Function GetEmployeesDocumentTypes(Employee,PrepaymentSettlement = Undefined,ExcludeInternalDocuments = False) Export
	
	TypesArray = New Array;
	
	If PrepaymentSettlement = Undefined OR 
		PrepaymentSettlement = Enums.PrepaymentSettlement.Settlement Then
		If TypeOf(Employee) = TypeOf(Catalogs.Employees.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.EmployeeInternalDocuments"));
			EndIf;
			// aim to be suppor in further versions
			//TypesArray.Add(Type("DocumentRef.CashOutgoingToEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.BankOutgoingToEmployee"));
			//TypesArray.Add(Type("DocumentRef.BankIncomingFromEmployee"));
			TypesArray.Add(Type("DocumentRef.SalesPrepaymentInvoice"));
			TypesArray.Add(Type("DocumentRef.PurchaseInvoice"));
			TypesArray.Add(Type("DocumentRef.SalesInvoice"));
			TypesArray.Add(Type("DocumentRef.SalesCreditNoteReturn"));
			TypesArray.Add(Type("DocumentRef.SalesCreditNotePriceCorrection"));
			TypesArray.Add(Type("DocumentRef.SalesRetail"));
			TypesArray.Add(Type("DocumentRef.SalesRetailReturn"));
			If SessionParameters.IsBookkeepingAvailable Then
				TypesArray.Add(Type("DocumentRef.Payroll"));
				TypesArray.Add(Type("CatalogRef.JobOrderContracts"));
			EndIf;	
		ElsIf TypeOf(Employee) = TypeOf(Catalogs.Employees.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.EmployeeInternalDocuments"));
			EndIf;
			// aim to be suppor in further versions
			//TypesArray.Add(Type("DocumentRef.BankIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.BankOutgoingToEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashOutgoingToEmployee"));
			TypesArray.Add(Type("DocumentRef.PurchaseInvoice"));
			TypesArray.Add(Type("DocumentRef.PurchaseCreditNoteReturn"));
			TypesArray.Add(Type("DocumentRef.PurchaseCreditNotePriceCorrection"));
		Else
			TypesArray.Add(Type("Undefined"));
		EndIf;
	ElsIf PrepaymentSettlement = Enums.PrepaymentSettlement.Prepayment 
		OR PrepaymentSettlement = Enums.PrepaymentSettlement.PrepaymentSettlement Then
		If TypeOf(Employee) = TypeOf(Catalogs.Employees.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.EmployeeInternalDocuments"));
			EndIf;
			// aim to be suppor in further versions
			//TypesArray.Add(Type("DocumentRef.BankIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.BankOutgoingToEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashOutgoingToEmployee"));
		ElsIf TypeOf(Employee) = TypeOf(Catalogs.Employees.EmptyRef()) Then
			If NOT ExcludeInternalDocuments Then
				TypesArray.Add(Type("CatalogRef.EmployeeInternalDocuments"));
			EndIf;
			// aim to be suppor in further versions
			//TypesArray.Add(Type("DocumentRef.BankIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashIncomingFromEmployee"));
			//TypesArray.Add(Type("DocumentRef.BankOutgoingToEmployee"));
			//TypesArray.Add(Type("DocumentRef.CashOutgoingToEmployee"));
		Else
			TypesArray.Add(Type("Undefined"));
		EndIf;	
	Else
		TypesArray.Add(Type("Undefined"));
	EndIf;	
	
	Return New TypeDescription(TypesArray);
	
EndFunction // GetEmployeesDocumentTypes()

Function GetDocumentAmountsStructureForPartner(Partner, Document, ReservationDocument = Undefined, Currency, Date = Undefined, Company) Export	
	
	Structure = New Structure("AmountDr, AmountCr, AmountDrNational, AmountCrNational", 0, 0, 0, 0);
	
	If ValueIsNotFilled(Document) Then
		Return Structure;
	EndIf;
	
	Query = New Query();
	Query.Text = "SELECT
	             |	PartnersSettlementsBalance.Partner,
	             |	PartnersSettlementsBalance.Document AS Document,
	             |	PartnersSettlementsBalance.AmountBalance AS GrossAmount,
	             |	PartnersSettlementsBalance.AmountNationalBalance AS GrossAmountNational
	             |FROM
	             |	AccumulationRegister.PartnersSettlements.Balance(
	             |			" + ?(Date = Undefined, "", "&Date") + ",
	             |				Document = &Document
	             |				AND Partner = &Partner
	             |				AND Company = &Company
	             |				AND ReservationDocument = &ReservationDocument) AS PartnersSettlementsBalance
	             |
	             |ORDER BY
	             |	PartnersSettlementsBalance.Document.Date";
	
	Query.SetParameter("Date",Date);
	Query.SetParameter("Partner",Partner);
	Query.SetParameter("Document",Document);
	Query.SetParameter("ReservationDocument", ReservationDocument);
	Query.SetParameter("Company",Company);
	Query.SetParameter("Currency",Currency);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return TransformateAmountToCrDr(Selection.GrossAmount, Selection.GrossAmountNational);
	Else
		Return Structure;
	EndIf;
	
EndFunction // GetDocumentAmountsStructureForPartner()

// employee
Function GetDocumentAmountsStructureForEmployee(Employee, Document, ReservationDocument = Undefined, Currency, Date = Undefined, Company) Export
	
	Structure = New Structure("AmountDr, AmountCr, AmountDrNational, AmountCrNational", 0, 0, 0, 0);
	
	If ValueIsNotFilled(Document) Then
		Return Structure;
	EndIf;
	
	Query = New Query();
	Query.Text = "SELECT
	             |	EmployeesSettlementsBalance.Employee,
	             |	EmployeesSettlementsBalance.Document AS Document,
	             |	EmployeesSettlementsBalance.AmountBalance AS GrossAmount,
	             |	EmployeesSettlementsBalance.AmountNationalBalance AS GrossAmountNational
	             |FROM
	             |	AccumulationRegister.EmployeesSettlements.Balance(
	             |			" + ?(Date = Undefined, "", "&Date") + ",
	             |				Document = &Document
	             |				AND Employee = &Employee
	             |				AND Company = &Company
				 |				AND ReservationDocument = &ReservationDocument) AS EmployeesSettlementsBalance
				 |
	             |ORDER BY
	             |	EmployeesSettlementsBalance.Document.Date";
	
	Query.SetParameter("Date",Date);
	Query.SetParameter("Employee",Employee);
	Query.SetParameter("Document",Document);
	Query.SetParameter("ReservationDocument",?(ReservationDocument=Undefined,Catalogs.EmployeeInternalDocuments.EmptyRef(),ReservationDocument));
	Query.SetParameter("Company",Company);
	Query.SetParameter("Currency",Currency);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return TransformateAmountToCrDr(Selection.GrossAmount, Selection.GrossAmountNational);
	Else
		Return Structure;
	EndIf;
	
EndFunction // GetDocumentAmountsStructureForEmployee()

Function GetPrepaymentsTable(Currency, Company,SettlementType, PartnersList, ReservationDocumentsArray = Undefined,FillByAllInternalDocuments = False,ExcludePrepaymentInvoices = False) Export
	
	If ReservationDocumentsArray = Undefined Then
		ReservationDocumentsArray = New Array;
		ReservationDocumentsArray.Add(Undefined);
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	             |	PartnersSettlementsBalance.Partner,
	             |	PartnersSettlementsBalance.Document,
	             |	PartnersSettlementsBalance.AmountBalance,
				 |	PartnersSettlementsBalance.AmountNationalBalance,
	             |	PartnersSettlementsBalance.ReservationDocument
	             |FROM
	             |	AccumulationRegister.PartnersSettlements.Balance(
	             |			,
	             |			Company = &Company
	             |				AND Currency = &Currency
	             |				AND Partner IN (&PartnersList)
				 |				AND SettlementType = &SettlementType " +?(ExcludePrepaymentInvoices," AND NOT (Document REFS Document.SalesPrepaymentInvoice) AND NOT (Document REFS Document.PurchasePrepaymentInvoice) ","")+ "
	             |				AND (ReservationDocument IN(&ReservationDocumentsList)" + ?(FillByAllInternalDocuments," 
				 |				OR ReservationDocument REFS Catalog.CustomerInternalDocuments OR ReservationDocument REFS Catalog.SupplierInternalDocuments)",")") + "
				 |) AS PartnersSettlementsBalance
				 |WHERE
	             |	PartnersSettlementsBalance.AmountBalance " +?(SettlementType = Enums.PartnerSettlementTypes.PrepaymentFromCustomer,"<",">")+" 0";
				 
	Query.SetParameter("Company", Company);
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("SettlementType", SettlementType);
	Query.SetParameter("PartnersList", PartnersList);
	Query.SetParameter("ReservationDocumentsList", ReservationDocumentsArray);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetPrepaymentsEmployeeTable(Currency, Company, SettlementType, EmployeesList = Undefined, ReservationDocumentsArray = Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	EmployeesSettlementsBalance.Employee,
	             |	EmployeesSettlementsBalance.Document,
	             |	NestedSelect.AmountBalance,
	             |	EmployeesSettlementsBalance.ReservationDocument,
				 |	EmployeesSettlementsBalance.PaymentMethod
	             |FROM
	             |	AccumulationRegister.EmployeesSettlements.Balance(
	             |			,
	             |			Company = &Company
	             |				AND Currency = &Currency
				 |				AND SettlementType = &SettlementType " + ?(EmployeesList <> Undefined AND EmployeesList.Count()>0," AND Employee IN (&EmployeesList) ","") + "
	             |				" + ?(ReservationDocumentsArray <> Undefined AND ReservationDocumentsArray.Count()>0," 
				 |				AND ReservationDocument IN(&ReservationDocumentsList)","") + "
				 |) AS EmployeesSettlementsBalance
				 | 	LEFT JOIN (SELECT
				 |					EmployeesSettlementsBalance.Document AS Document,
				 |					EmployeesSettlementsBalance.ReservationDocument AS ReservationDocument,
				 |					EmployeesSettlementsBalance.AmountBalance AS AmountBalance,
				 |					EmployeesSettlementsBalance.AmountNationalBalance AS AmountNationalBalance
				 |				FROM
				 | 					AccumulationRegister.EmployeesSettlements.Balance AS EmployeesSettlementsBalance) AS NestedSelect
				 |  ON EmployeesSettlementsBalance.Document = NestedSelect.Document
				 |  AND EmployeesSettlementsBalance.ReservationDocument = NestedSelect.ReservationDocument
	             |WHERE
				 | NestedSelect.AmountBalance > 0 AND
	             |	EmployeesSettlementsBalance.AmountBalance " +?(SettlementType = Enums.EmployeeSettlementTypes.PrepaymentFromEmployee,"<",">")+" 0";
				 
	Query.SetParameter("Company", Company);
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("SettlementType", SettlementType);
	Query.SetParameter("EmployeesList", EmployeesList);
	Query.SetParameter("ReservationDocumentsList", ReservationDocumentsArray);
	
	Return Query.Execute().Unload();
	
EndFunction

Function GetPrepaymentInvoicesTable(ReservationDocumentsArray, Partner,Company, PrepaymentInvoiceArray = Undefined, VATRatesArray = Undefined,Date = Undefined) Export
		
	Query = New Query;
	Query.Text = "SELECT
	             |	PrepaymentVATBalance.PrepaymentInvoice,
				 |	PrepaymentVATBalance.PrepaymentInvoice.DocumentBase AS ReservationDocument,
	             |	PrepaymentVATBalance.VATRate,
				 |	PrepaymentVATBalance.NetAmountBalance + PrepaymentVATBalance.VATBalance AS GrossAmount,
	             |	PrepaymentVATBalance.NetAmountBalance AS NetAmount,
	             |	PrepaymentVATBalance.VATBalance AS VAT
	             |FROM
	             |	AccumulationRegister.PrepaymentVAT.Balance(
	             |			 " + ?(Date = Undefined,"","&Date") +" ,
	             |			Company = &Company
	             |				AND Partner = &Partner
	             |				AND PrepaymentInvoice.DocumentBase IN (&ReservationDocumentsArray)
	             |				"+ ?(PrepaymentInvoiceArray= Undefined,""," AND PrepaymentInvoice IN (&PrepaymentInvoiceArray) ")+"
	             |				"+ ?(VATRatesArray= Undefined,"","AND VATRate IN (&VATRatesArray)")+") AS PrepaymentVATBalance";
					 					 
	Query.SetParameter("Date", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("Partner", Partner);
	Query.SetParameter("ReservationDocumentsArray", ReservationDocumentsArray);
	Query.SetParameter("PrepaymentInvoiceArray", PrepaymentInvoiceArray);
	Query.SetParameter("VATRatesArray", VATRatesArray);
	
	Return Query.Execute().Unload();	
	
EndFunction

Function GetOrdersAwaitedToPrepaymentInvoiceTable(DocumentArray,PartnerArray,Company,ReturnQueryResult = False) Export
	
	Query = New Query();
	Query.Text = "SELECT
	             |	OrdersAwaitedToPrepaymentInvoiceTurnovers.VATRate,
	             |	OrdersAwaitedToPrepaymentInvoiceTurnovers.GrossAmountTurnover AS GrossAmount,
	             |	OrdersAwaitedToPrepaymentInvoiceTurnovers.Document
	             |FROM
	             |	AccumulationRegister.OrdersAwaitedToPrepaymentInvoice.Turnovers(
				 |			,
				 |			,
	             |			,
	             |			Company = &Company
	             |				AND Partner IN (&PartnerArray)
	             |				AND Document IN (&DocumentArray)) AS OrdersAwaitedToPrepaymentInvoiceTurnovers
	             |
	             |ORDER BY
	             |	GrossAmount";
	
	Query.SetParameter("Company",Company);
	Query.SetParameter("PartnerArray",PartnerArray);
	Query.SetParameter("DocumentArray",DocumentArray);
	
	QueryResult = Query.Execute();
	If ReturnQueryResult Then
		Return QueryResult;
	Else
		Return QueryResult.Unload();
	EndIf;	
	
EndFunction	

Function GetSalesVATForPrepaymentInvoiceTable(PrepaymentInvoice,Customer,Company,BeginOfPeriod = Undefined) Export
	
	Query = New Query;
	
	Query.Text = "SELECT
	             |	SalesInvoicesVATTurnovers.NetAmountTurnover AS NetAmount,
	             |	SalesInvoicesVATTurnovers.VATTurnover AS VAT,
	             |	SalesInvoicesVATTurnovers.VATRate AS VATRate,
	             |	SalesInvoicesVATTurnovers.NetAmountTurnover + SalesInvoicesVATTurnovers.VATTurnover AS GrossAmount,
	             |	SalesInvoicesVATTurnovers.SalesInvoice AS Document
	             |FROM
	             |	AccumulationRegister.SalesInvoicesVAT.Turnovers(
	             |			&BeginPeriod,
	             |			,
	             |			,
	             |			Company = &Company
	             |				AND Customer IN (&Customer)
	             |				AND SalesInvoice IN (&SalesPrepaymentInvoice)) AS SalesInvoicesVATTurnovers";
	Query.SetParameter("Company",Company);
	Query.SetParameter("Customer",Customer);
	Query.SetParameter("SalesPrepaymentInvoice",PrepaymentInvoice);
	If BeginOfPeriod = Undefined Then
		If TypeOf(PrepaymentInvoice) <> Type("Array") Then	
			Query.SetParameter("BeginPeriod",PrepaymentInvoice.Date);
		EndIf;	
	Else
		Query.SetParameter("BeginPeriod",BeginOfPeriod);
	EndIf;	
	
	Return Query.Execute().Unload();

EndFunction	

Function GetPurchaseVATForPrepaymentInvoiceTable(PrepaymentInvoice,Supplier,Company,BeginOfPeriod = Undefined) Export
	
	Query = New Query;
	
	Query.Text = "SELECT
	             |	PurchaseInvoicesVATTurnovers.NetAmountTurnover AS NetAmount,
	             |	PurchaseInvoicesVATTurnovers.VATTurnover AS VAT,
	             |	PurchaseInvoicesVATTurnovers.VATRate AS VATRate,
	             |	PurchaseInvoicesVATTurnovers.NetAmountTurnover + PurchaseInvoicesVATTurnovers.VATTurnover AS GrossAmount,
	             |	PurchaseInvoicesVATTurnovers.PurchaseInvoice AS Document
	             |FROM
	             |	AccumulationRegister.PurchaseInvoicesVAT.Turnovers(
	             |			&BeginPeriod,
	             |			,
	             |			,
	             |			Company = &Company
	             |				AND Supplier IN (&Supplier)
	             |				AND PurchaseInvoice IN (&PurchasePrepaymentInvoice)) AS PurchaseInvoicesVATTurnovers";
	Query.SetParameter("Company",Company);
	Query.SetParameter("Supplier",Supplier);
	Query.SetParameter("PurchasePrepaymentInvoice",PrepaymentInvoice);
	If BeginOfPeriod = Undefined Then
		If TypeOf(PrepaymentInvoice) <> Type("Array") Then	
			Query.SetParameter("BeginPeriod",PrepaymentInvoice.Date);
		EndIf;	
	Else
		Query.SetParameter("BeginPeriod",BeginOfPeriod);
	EndIf;	
	
	Return Query.Execute().Unload();

EndFunction	

Function GetPrepaymentInvoiceAvailableBalanceTable(PrepaymentInvoice,Partner,Company,Date=Undefined) Export
	
	Query = New Query;
	Query.Text = "SELECT
	             |	PrepaymentVATBalance.VATRate AS VATRate,
	             |	PrepaymentVATBalance.PrepaymentInvoice,
	             |	PrepaymentVATBalance.NetAmountBalance,
	             |	PrepaymentVATBalance.VATBalance,
	             |	PrepaymentVATBalance.NetAmountNationalBalance,
	             |	PrepaymentVATBalance.VATNationalBalance
	             |FROM
	             |	AccumulationRegister.PrepaymentVAT.Balance("+?(Date = Undefined,"","&Date")+"
	             |			,
	             |			Company = &Company
	             |				AND Partner IN (&Partner)
	             |				AND PrepaymentInvoice IN (&PrepaymentInvoice)) AS PrepaymentVATBalance";
	Query.SetParameter("Company",Company);
	Query.SetParameter("Partner",Partner);
	Query.SetParameter("Date",Date);
	Query.SetParameter("PrepaymentInvoice",PrepaymentInvoice);
	Return Query.Execute().Unload();

EndFunction	

Function GetDocumentsCurrency(Document) Export
	
	Structure = GetDocumentsCurrencyAndExchangeRate(Document);
	If Structure.Currency = Undefined Then
		Return Catalogs.Currencies.EmptyRef();
	Else
		Return Structure.Currency;
	EndIf;
	
EndFunction

Function GetDocumentsCurrencyAndExchangeRate(Document) Export
	
	Structure = New Structure("Currency, ExchangeRate", Undefined, Undefined);
	
	If ValueIsNotFilled(Document) Then
		
		Return Structure;
		
	ElsIf Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		If CommonAtServer.IsDocumentAttribute("Currency", Document.Metadata()) Then
			Structure.Currency = Document.Currency;
			Structure.ExchangeRate = Document.ExchangeRate;
		EndIf;
		
	Else // documents
		
		If CommonAtServer.IsDocumentAttribute("SettlementCurrency", Document.Metadata()) Then
			Structure.Currency = Document.SettlementCurrency;
			Structure.ExchangeRate = Document.SettlementExchangeRate;
		ElsIf CommonAtServer.IsDocumentAttribute("Currency", Document.Metadata()) Then
			Structure.Currency = Document.Currency;
			Structure.ExchangeRate = Document.ExchangeRate;
		EndIf;
		
	EndIf;
	
	Return Structure;
	
EndFunction // GetDocumentsCurrencyAndExchangeRate()

Function GetDocumentsPartner(Document) Export
	
	If Document = Undefined Then
		Return Undefined;
	ElsIf Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		Return Document.Owner;
		
	Else // documents
		
		If CommonAtServer.IsDocumentAttribute("Customer", Document.Metadata()) Then
			Return Document.Customer;
		ElsIf CommonAtServer.IsDocumentAttribute("Supplier", Document.Metadata()) Then
			Return Document.Supplier;
		ElsIf CommonAtServer.IsDocumentAttribute("Partner", Document.Metadata()) Then
			Return Document.Partner;
		Else
			Return Undefined;
		EndIf;
		
	EndIf;
	
EndFunction

Function GetDocumentsEmployee(Document) Export
	
	If Document = Undefined Then
		Return Undefined;
	ElsIf Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		Return Document.Owner;
		
	Else // documents
		
		If CommonAtServer.IsDocumentAttribute("Employee", Document.Metadata()) Then
			Return Document.Employee;
		Else
			Return Undefined;
		EndIf;
		
	EndIf;
	
EndFunction

Function IsPrepaymentReservationDocument(DocumentRef) Export
	
	Return (TypeOf(DocumentRef) = TypeOf(Documents.SalesOrder.EmptyRef()) 
		OR TypeOf(DocumentRef) = TypeOf(Documents.PurchaseOrder.EmptyRef())
		OR TypeOf(DocumentRef) = TypeOf(Documents.SalesReturnOrder.EmptyRef())
		OR TypeOf(DocumentRef) = TypeOf(Documents.PurchaseReturnOrder.EmptyRef()));
	
EndFunction	

Function IsInternalPartnerDocument(DocumentRef) Export
	
	Return (TypeOf(DocumentRef) = TypeOf(Catalogs.CustomerInternalDocuments.EmptyRef()) 
		OR TypeOf(DocumentRef) = TypeOf(Catalogs.SupplierInternalDocuments.EmptyRef()));
	
EndFunction

Function IsInternalEmployeeDocument(DocumentRef) Export
	
	Return (TypeOf(DocumentRef) = TypeOf(Catalogs.EmployeeInternalDocuments.EmptyRef()));
		
EndFunction

// payment transaction
Function IsPaymentTransactionTypeWithPartner(PaymentTransactionType) Export
	
	Return (PaymentTransactionType = Enums.PaymentTransactionTypes.PaymentCard
		OR PaymentTransactionType = Enums.PaymentTransactionTypes.PaymentOnDelivery
		OR PaymentTransactionType = Enums.PaymentTransactionTypes.BankCredit
		OR PaymentTransactionType = Enums.PaymentTransactionTypes.Factoring);
	
EndFunction
	
Function GetPartnerForPaymentMethod(PaymentMethod,Partner) Export
	
	If IsPaymentMethodWithPartner(PaymentMethod) Then
		If PaymentMethod.TransactionType = Enums.PaymentTransactionTypes.PaymentOnDelivery 
			AND ValueIsNotFilled(PaymentMethod.Partner) Then
			Return Partner;
		Else
			Return PaymentMethod.Partner;
		EndIf;	
	Else
		Return Partner;
	EndIf;	
	
EndFunction	

Function IsPaymentMethodWithPartner(PaymentMethod) Export
	
	Return IsPaymentTransactionTypeWithPartner(PaymentMethod.TransactionType);
	
EndFunction	

// CR = -
// DR = + 
// Transformated for posting
Function TransformateAmountFromCrDr(AmountCr, AmountCrNational = 0,AmountDr, AmountDrNational = 0) Export
	
	Amount = 0;
	AmountNational = 0;
	If AmountCr <>0 AND AmountDr = 0 Then
		Amount = -AmountCr;
		AmountNational = -AmountCrNational;
	ElsIf AmountDr <>0 AND AmountCr = 0 Then
		Amount = AmountDr;
		AmountNational = AmountDrNational;
	ElsIf AmountDr = 0 AND 	AmountCr = 0 Then
		
		If AmountCrNational <>0 AND AmountDrNational = 0 Then
			
			AmountNational = -AmountCrNational;
			
		ElsIf AmountDrNational <>0 AND AmountCrNational = 0 Then
			
			AmountNational = AmountDrNational;
			
		EndIf;
		
	EndIf;	
		
	Return New Structure("Amount, AmountNational",Amount,AmountNational)
	
EndFunction

// - = DR
// + = CR
// Transformed for tabular part and futher posting
Function TransformateAmountToCrDr(Amount,AmountNational) Export
	
	AmountCr = 0;
	AmountDr = 0;
	AmountCrNational = 0;
	AmountDrNational = 0;
	If Amount >0 Then
		AmountCr = ABS(Amount);
		AmountCrNational = ABS(AmountNational);
	Elsif Amount <0 Then
		AmountDr = ABS(Amount);
		AmountDrNational = ABS(AmountNational);
	ElsIf Amount = 0 AND AmountNational<>0 Then
		
		If AmountNational >0 Then
			AmountCrNational = ABS(AmountNational);
		ElsIf AmountNational <0 Then
			AmountDrNational = ABS(AmountNational);
		EndIf;
		
	EndIf;	
	
	Return New Structure("AmountDr, AmountCr, AmountDrNational, AmountCrNational", AmountDr, AmountCr, AmountDrNational, AmountCrNational);
	
EndFunction	

Procedure PostSettlementDocuments(Document, Cancel,PostingMode,SkipChekForPrepayments = False) Export
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
	DocumentName = Document.Metadata().Name;
	
	Query = New Query();
	If PostingMode = DocumentPostingMode.Regular Then
		Query.Text = 
		"SELECT
		|	SettlementDocuments.LineNumber,
		|	SettlementDocuments.Document,
		|	SettlementDocuments.Partner,
		|	SettlementDocuments.ReservationDocument AS ReservationDocument,
		|	SettlementDocuments.AmountDr,
		|	SettlementDocuments.AmountDrNational,
		|	SettlementDocuments.AmountCr,
		|	SettlementDocuments.AmountCrNational,
		|	SettlementDocuments.Description,
		|	SettlementDocuments.Partner.CustomerType,
		|	SettlementDocuments.Partner.CanBePayer AS CanBePayer,
		|	SettlementDocuments.Document.ExchangeRate AS InternalDocumentExchangeRate,"+?(TypeOf(Document.Ref) = TypeOf(Documents.PartnersOffsettingOfDebts.EmptyRef()) AND Document.MultiCurrencySettlement ,"SettlementDocuments.DocumentSettlementCurrency AS DocumentSettlementCurrency,","SettlementDocuments.Ref.SettlementCurrency AS DocumentSettlementCurrency,")+"
		|	SettlementDocuments.PrepaymentSettlement
		|FROM
		|	Document." + DocumentName + ".SettlementDocuments AS SettlementDocuments
		|WHERE
		|	SettlementDocuments.Ref = &Ref";
		
	ElsIf PostingMode = DocumentPostingMode.RealTime Then
		
		Query.Text = 
		"SELECT
		|	SettlementDocuments.LineNumber,
		|	SettlementDocuments.Document,
		|	SettlementDocuments.Partner,
		|	SettlementDocuments.AmountDr,
		|	SettlementDocuments.AmountDrNational,
		|	SettlementDocuments.AmountCr,
		|	SettlementDocuments.AmountCrNational,
		|	SettlementDocuments.Description,
		|	SettlementDocuments.ReservationDocument AS ReservationDocument,
		|	SettlementDocuments.Partner.CustomerType,
		|	SettlementDocuments.Partner.CanBePayer AS CanBePayer,
		|	SettlementDocuments.Document.ExchangeRate AS InternalDocumentExchangeRate,
		|	SettlementDocuments.PrepaymentSettlement,
		|	PartnersSettlementsBalance.Currency AS Currency,"+?(TypeOf(Document.Ref) = TypeOf(Documents.PartnersOffsettingOfDebts.EmptyRef()) AND Document.MultiCurrencySettlement ,"SettlementDocuments.DocumentSettlementCurrency AS DocumentSettlementCurrency,","SettlementDocuments.Ref.SettlementCurrency AS DocumentSettlementCurrency,")+"
		|	CASE
		|		WHEN ISNULL(PartnersSettlementsBalance.AmountBalance, 0) < 0
		|			THEN -PartnersSettlementsBalance.AmountBalance
		|		ELSE 0
		|	END AS AmountDrBalance,
		|	CASE
		|		WHEN ISNULL(PartnersSettlementsBalance.AmountBalance, 0) > 0
		|			THEN PartnersSettlementsBalance.AmountBalance
		|		ELSE 0
		|	END AS AmountCrBalance,
		|	CASE
		|		WHEN ISNULL(PartnersSettlementsBalance.AmountNationalBalance, 0) < 0
		|			THEN -PartnersSettlementsBalance.AmountNationalBalance
		|		ELSE 0
		|	END AS AmountDrNationalBalance,
		|	CASE
		|		WHEN ISNULL(PartnersSettlementsBalance.AmountNationalBalance, 0) > 0
		|			THEN PartnersSettlementsBalance.AmountNationalBalance
		|		ELSE 0
		|	END AS AmountCrNationalBalance
		|FROM
		|	Document." + DocumentName + ".SettlementDocuments AS SettlementDocuments
		|		LEFT JOIN AccumulationRegister.PartnersSettlements.Balance(&Date, ) AS PartnersSettlementsBalance
		|		ON SettlementDocuments.Document = PartnersSettlementsBalance.Document
		|			AND SettlementDocuments.Ref.Company = PartnersSettlementsBalance.Company
		|			AND SettlementDocuments.Partner = PartnersSettlementsBalance.Partner
		|			AND SettlementDocuments."+?(TypeOf(Document.Ref) = TypeOf(Documents.PartnersOffsettingOfDebts.EmptyRef()) AND Document.MultiCurrencySettlement ,"DocumentSettlementCurrency","Ref.SettlementCurrency")+" = PartnersSettlementsBalance.Currency
		|			AND (CASE
		|				WHEN SettlementDocuments.PrepaymentSettlement = VALUE(Enum.PrepaymentSettlement.Settlement)
		|					THEN PartnersSettlementsBalance.SettlementType = VALUE(Enum.PartnerSettlementTypes.CustomerSettlement)
		|							OR PartnersSettlementsBalance.SettlementType = VALUE(Enum.PartnerSettlementTypes.SupplierSettlement)
		|				WHEN SettlementDocuments.PrepaymentSettlement = VALUE(Enum.PrepaymentSettlement.PrepaymentSettlement)
		|					THEN PartnersSettlementsBalance.SettlementType = VALUE(Enum.PartnerSettlementTypes.PrepaymentFromCustomer)
		|							OR PartnersSettlementsBalance.SettlementType = VALUE(Enum.PartnerSettlementTypes.PrepaymentToSupplier)
		|				ELSE FALSE
		|			END)
		|WHERE
		|	SettlementDocuments.Ref = &Ref";
		
	EndIf;	
	
	Query.SetParameter("Ref",Document.Ref);
	Query.SetParameter("Date",Document.Date);
	
	Selection = Query.Execute().Select();
	
	NationalCurrency = Constants.NationalCurrency.Get();
	IsNationalCurrency = (NationalCurrency = Document.SettlementCurrency);
	
	While Selection.Next() Do
		
		MessageTextBegin = Alerts.ParametrizeString(NStr("en = 'Settlement documents, line %P1.'; pl = 'Dokumenty rozrachunków, wiersz %P1.'"),New Structure("P1",TrimAll(Selection.LineNumber)));
		
		If PostingMode = DocumentPostingMode.RealTime
			AND Selection.PrepaymentSettlement <> Enums.PrepaymentSettlement.Prepayment Then 
			
			
			If Selection.AmountDr <> 0 
				AND Selection.AmountDrBalance<Selection.AmountDr Then
				
				Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Wn jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountDrBalance,Selection.Currency)),Enums.AlertType.Error,Cancel,Document);
				
			EndIf;	
			
			If Selection.AmountCr <> 0 
				AND Selection.AmountCrBalance<Selection.AmountCr Then
				
				Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Ma jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountCrBalance,Selection.Currency)),Enums.AlertType.Error,Cancel,Document);
				
			EndIf;				
			
			If NOT IsNationalCurrency Then
				
				If Selection.AmountDrNational <> 0 
					AND Selection.AmountDrNationalBalance<Selection.AmountDrNational Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount national you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Wn (kraj.) jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountDrNationalBalance,NationalCurrency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;	
				
				If Selection.AmountCrNational <> 0 
					AND Selection.AmountCrNationalBalance<Selection.AmountCrNational Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount national you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Ma (kraj.) jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountCrNationalBalance,NationalCurrency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;		
				
			EndIf;
			
		EndIf;	
		
		// RED ALERTS
		If TypeOf(Selection.Partner) = TypeOf(Catalogs.Customers.EmptyRef()) 
			AND Selection.PartnerCustomerType <> Enums.CustomerTypes.Independent
			AND ValueIsFilled(Selection.Partner) Then
			Alerts.AddAlert(NStr("en = 'Choosen customer could not be used as partner. Please, check attribute ''Customer type''. It should be set to ''Independent'''; pl = 'Nie można używać wybranego klienta jako kontrahenta. Sprawdź czy klient ma ustawiony atrubyt ''Typ klienta'' o wartości ''Niezależny'''"),Enums.AlertType.Error,Cancel,Document);
		EndIf;
		
		If TypeOf(Document.Ref) <> TypeOf(Documents.PartnersOffsettingOfDebts.EmptyRef()) OR NOT Document.MultiCurrencySettlement Then
			DocumentsCurrency = APAR.GetDocumentsCurrency(Selection.Document);
			If Alerts.IsNotEqualValue(Document.SettlementCurrency, DocumentsCurrency) Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s currency should be the same as settlement currency! Document''s currency:'; pl = 'Waluta dokumentu powinna być taka sama jak waluta rozrachunków! Waluta dokumentu:'") + " " + DocumentsCurrency, Enums.AlertType.Error, Cancel,Document);
			EndIf;
		EndIf;
		
		If Selection.AmountCr = 0 And Selection.AmountDr = 0 
			AND Selection.AmountCrNational=0 AND Selection.AmountDrNational = 0 Then
			Alerts.AddAlert(MessageTextBegin + NStr("en='At least one of the amounts should be non-zero!';pl='Co najmniej jedna z kwot powinna być nie zerowa!';ru='По крайней мере одна из сумм должна иметь ненулевое значение!'"), Enums.AlertType.Error, Cancel,Document);
		EndIf;
		
		DocumentsPartner = APAR.GetDocumentsPartner(Selection.Document);
		If Alerts.IsNotEqualValue(Selection.Partner, DocumentsPartner)
			AND Selection.CanBePayer = False
			Then
			// For example paying card the payer is processing center, but in document's customer is not payer.
			 Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s partner should be the same as the partner in the row! Document''s partner:'; pl = 'Kontrahent w dokumencie powinien być taki samy jak wybrany w wierszy! Kontrahent w dokumencie:'") + " " + DocumentsPartner, Enums.AlertType.Error, Cancel,Document);
		EndIf;
				
		AmountsStructure = TransformateAmountFromCrDr(Selection.AmountCr,Selection.AmountCrNational,Selection.AmountDr,Selection.AmountDrNational);
		If AmountsStructure.Amount = 0 Then
			AmountToCompare = AmountsStructure.AmountNational;
		Else
			AmountToCompare = AmountsStructure.Amount;
		EndIf;	
		If Selection.PrepaymentSettlement = Enums.PrepaymentSettlement.Settlement Then
						
			PostAccountPayableReceivable(ABS(AmountsStructure.Amount),
										ABS(AmountsStructure.AmountNational),
										Selection.Partner,
										?(AmountToCompare<0,AccumulationRecordType.Expense,AccumulationRecordType.Receipt),
										?(TypeOf(Selection.Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()),Enums.PartnerSettlementTypes.SupplierSettlement,Enums.PartnerSettlementTypes.CustomerSettlement),
										Selection.DocumentSettlementCurrency,
										,
										Selection.Document,
										Document,
										Cancel);
			
		ElsIf Selection.PrepaymentSettlement = Enums.PrepaymentSettlement.PrepaymentSettlement Then
			
			If NOT SkipChekForPrepayments Then
				
				If IsInternalPartnerDocument(Selection.Document) Then
					
					If CommonAtServer.IsDocumentAttribute("SettlementExchangeRate",Document.Metadata()) Then 
						
						If Alerts.IsNotEqualValue(Document.SettlementExchangeRate,Selection.InternalDocumentExchangeRate) Then
							
							MessageText = Alerts.ParametrizeString(Nstr("en=""Exchange rate in internal partner document %P1 for prepayment should be equal to document's exchange rate! Internal's document exchange rate: %P2 and document's exchange rate: %P3."";pl='Kurs wymiany wewnętrznego dokumentu kontrahenta %P1 powinnien zgadzać się z kursem na dokumencie! Kurs wewnętrznego dokumentu kontrahenta: %P2 oraz kurs na dokumencie: %P3.'"),New Structure("P1, P2, P3",Selection.Document,Selection.InternalDocumentExchangeRate,Document.SettlementExchangeRate));
							Alerts.AddAlert(MessageTextBegin + MessageText , Enums.AlertType.Error, Cancel,Document);
							
						EndIf;
						
					EndIf;	
					
				EndIf;	
				
			EndIf;
			
			PostAccountPayableReceivable(ABS(AmountsStructure.Amount),
										ABS(AmountsStructure.AmountNational),
										Selection.Partner,
										?(AmountToCompare<0,AccumulationRecordType.Expense,AccumulationRecordType.Receipt),
										?(TypeOf(Selection.Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()), Enums.PartnerSettlementTypes.PrepaymentToSupplier,Enums.PartnerSettlementTypes.PrepaymentFromCustomer),
										Selection.DocumentSettlementCurrency,
										Selection.ReservationDocument,
										Selection.Document,
										Document,
										Cancel);				
		EndIf;	
		
	EndDo;
	
EndProcedure

Procedure PostSettlementEmployeeDocuments(Document, Cancel, PostingMode, SkipChekForPrepayments = False) Export
	
	DocumentName = Document.Metadata().Name;
	
	Query = New Query();
	If PostingMode = DocumentPostingMode.Regular Then
		Query.Text = 
		"SELECT
		|	SettlementDocuments.LineNumber,
		|	SettlementDocuments.Document,";
		If Common.IsDocumentTabularPartAttribute("Employee", Document.Metadata(), "SettlementDocuments") Then
			Query.Text = Query.Text + "
			|	SettlementDocuments.Employee,";
		Else
			Query.Text = Query.Text + "
			|	SettlementDocuments.Partner AS Employee,";
		EndIf;
		Query.Text = Query.Text + "
		|	SettlementDocuments.ReservationDocument AS ReservationDocument,
		|	SettlementDocuments.AmountDr,
		|	SettlementDocuments.AmountDrNational,
		|	SettlementDocuments.AmountCr,
		|	SettlementDocuments.AmountCrNational,
		|	SettlementDocuments.Description,";
		
		If Common.IsDocumentTabularPartAttribute("Employee", Document.Metadata(), "SettlementDocuments") Then
			Query.Text = Query.Text + "
			|	SettlementDocuments.Employee.CollaborationType,";
		Else
			Query.Text = Query.Text + "
			|	SettlementDocuments.Partner.CollaborationType AS EmployeeCollaborationType,";
		EndIf;
		
		Query.Text = Query.Text + "
		|	SettlementDocuments.Document.ExchangeRate AS InternalDocumentExchangeRate,"+?(TypeOf(Document.Ref) = TypeOf(Documents.EmployeesOffsettingOfDebts.EmptyRef()) AND Document.MultiCurrencySettlement ,"SettlementDocuments.DocumentSettlementCurrency AS DocumentSettlementCurrency,","SettlementDocuments.Ref.SettlementCurrency AS DocumentSettlementCurrency,")+"
		|	SettlementDocuments.PrepaymentSettlement,
		|	SettlementDocuments.PaymentMethod,
		|	SettlementDocuments.PaymentMethod AS PaymentMethodBalance
		|FROM
		|	Document." + DocumentName + ".SettlementDocuments AS SettlementDocuments
		|WHERE
		|	SettlementDocuments.Ref = &Ref";
		
	ElsIf PostingMode = DocumentPostingMode.RealTime Then
		
		Query.Text = 
		"SELECT
		|	SettlementDocuments.LineNumber,
		|	SettlementDocuments.Document,";
		If Common.IsDocumentTabularPartAttribute("Employee", Document.Metadata(), "SettlementDocuments") Then
			Query.Text = Query.Text + "
			|	SettlementDocuments.Employee,";
		Else
			Query.Text = Query.Text + "
			|	SettlementDocuments.Partner AS Employee,";
		EndIf;
		Query.Text = Query.Text + "
		|	SettlementDocuments.AmountDr,
		|	SettlementDocuments.AmountDrNational,
		|	SettlementDocuments.AmountCr,
		|	SettlementDocuments.AmountCrNational,
		|	SettlementDocuments.Description,
		|	SettlementDocuments.ReservationDocument AS ReservationDocument,";
		If Common.IsDocumentTabularPartAttribute("Employee", Document.Metadata(), "SettlementDocuments") Then
			Query.Text = Query.Text + "
			|	SettlementDocuments.Employee.CollaborationType,";
		Else
			Query.Text = Query.Text + "
			|	SettlementDocuments.Partner.CollaborationType AS EmployeeCollaborationType,";
		EndIf;
		Query.Text = Query.Text + "
		|	
		|	SettlementDocuments.Document.ExchangeRate AS InternalDocumentExchangeRate,
		|	SettlementDocuments.PrepaymentSettlement,"+?(TypeOf(Document.Ref) = TypeOf(Documents.EmployeesOffsettingOfDebts.EmptyRef()) AND Document.MultiCurrencySettlement ,"SettlementDocuments.DocumentSettlementCurrency AS DocumentSettlementCurrency,","SettlementDocuments.Ref.SettlementCurrency AS DocumentSettlementCurrency,")+"
		|	SettlementDocuments.PaymentMethod,
		|	EmployeesSettlementsBalance.PaymentMethod AS PaymentMethodBalance,
		|	EmployeesSettlementsBalance.Currency AS Currency,
		|	CASE
		|		WHEN ISNULL(EmployeesSettlementsBalance.AmountBalance, 0) < 0
		|			THEN -EmployeesSettlementsBalance.AmountBalance
		|		ELSE 0
		|	END AS AmountDrBalance,
		|	CASE
		|		WHEN ISNULL(EmployeesSettlementsBalance.AmountBalance, 0) > 0
		|			THEN EmployeesSettlementsBalance.AmountBalance
		|		ELSE 0
		|	END AS AmountCrBalance,
		|	CASE
		|		WHEN ISNULL(EmployeesSettlementsBalance.AmountNationalBalance, 0) < 0
		|			THEN -EmployeesSettlementsBalance.AmountNationalBalance
		|		ELSE 0
		|	END AS AmountDrNationalBalance,
		|	CASE
		|		WHEN ISNULL(EmployeesSettlementsBalance.AmountNationalBalance, 0) > 0
		|			THEN EmployeesSettlementsBalance.AmountNationalBalance
		|		ELSE 0
		|	END AS AmountCrNationalBalance
		|FROM
		|	Document." + DocumentName + ".SettlementDocuments AS SettlementDocuments
		|		LEFT JOIN AccumulationRegister.EmployeesSettlements.Balance(&Date, ) AS EmployeesSettlementsBalance
		|		ON SettlementDocuments.Document = EmployeesSettlementsBalance.Document
		|			AND SettlementDocuments.Ref.Company = EmployeesSettlementsBalance.Company
		|			AND SettlementDocuments.Employee = EmployeesSettlementsBalance.Employee
		|			AND SettlementDocuments."+?(TypeOf(Document.Ref) = TypeOf(Documents.EmployeesOffsettingOfDebts.EmptyRef()) AND Document.MultiCurrencySettlement ,"DocumentSettlementCurrency","Ref.SettlementCurrency")+" = EmployeesSettlementsBalance.Currency
		|			AND (CASE
		|				WHEN SettlementDocuments.PrepaymentSettlement = VALUE(Enum.PrepaymentSettlement.Settlement)
		|					THEN EmployeesSettlementsBalance.SettlementType = VALUE(Enum.EmployeeSettlementTypes.EmployeeSettlement)
		|				WHEN SettlementDocuments.PrepaymentSettlement = VALUE(Enum.PrepaymentSettlement.PrepaymentSettlement)
		|					THEN EmployeesSettlementsBalance.SettlementType = VALUE(Enum.EmployeeSettlementTypes.PrepaymentFromEmployee)
		|							OR EmployeesSettlementsBalance.SettlementType = VALUE(Enum.EmployeeSettlementTypes.PrepaymentToEmployee)
		|				ELSE FALSE
		|			END)
		|WHERE
		|	SettlementDocuments.Ref = &Ref";
		
	EndIf;	
	
	Query.SetParameter("Ref",Document.Ref);
	Query.SetParameter("Date",Document.Date);
	
	Selection = Query.Execute().Select();
	
	NationalCurrency = Constants.NationalCurrency.Get();
	IsNationalCurrency = (NationalCurrency = Document.SettlementCurrency);
	
	While Selection.Next() Do
		
		MessageTextBegin = Alerts.ParametrizeString(NStr("en = 'Settlement documents, line %P1.'; pl = 'Dokumenty rozrachunków, wiersz %P1.'"),New Structure("P1",TrimAll(Selection.LineNumber)));
		
		If PostingMode = DocumentPostingMode.RealTime
			AND Selection.PrepaymentSettlement <> Enums.PrepaymentSettlement.Prepayment Then 
			
			
			If Selection.AmountDr <> 0 And Selection.AmountDrBalance < Selection.AmountDr Then
				
				Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Wn jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountDrBalance,Selection.Currency)),Enums.AlertType.Error,Cancel,Document);
				
			EndIf;
			
			If Selection.AmountCr <> 0 And Selection.AmountCrBalance < Selection.AmountCr Then
				
				Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Ma jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountCrBalance,Selection.Currency)),Enums.AlertType.Error,Cancel,Document);
				
			EndIf;
			
			If TypeOf(Selection.Document) = TypeOf(Documents.PurchaseInvoice.EmptyRef()) Then
				QueryPaymentMethod = New Query;
				QueryPaymentMethod.Text ="SELECT
				                         |	PurchaseInvoiceEmployeesLines.PaymentMethod AS PaymentMethod
				                         |FROM
				                         |	Document.PurchaseInvoice.EmployeesLines AS PurchaseInvoiceEmployeesLines
				                         |WHERE
				                         |	PurchaseInvoiceEmployeesLines.Ref = &Ref"; 
										 
				QueryPaymentMethod.SetParameter("Ref", Selection.Document);
				Select = QueryPaymentMethod.Execute().Select();
				IsPaymentMethodOk = False;
				While Select.Next() Do
					If Selection.PaymentMethod = Select.PaymentMethod Then
						IsPaymentMethodOk = True;
						Break;
					EndIf;
				EndDo;
				If Not IsPaymentMethodOk Then
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Payment method is different of payment on the document: %P1'; pl = 'Sposób płatności różni się od sposobu płatności na dokumencie: %P1'"),New Structure("P1",Selection.Document.PaymentMethod)),Enums.AlertType.Error,Cancel,Document);
				EndIf;
			ElsIf SessionParameters.IsBookkeepingAvailable 
				AND (TypeOf(Selection.Document) = TypeOf(Documents.Payroll.EmptyRef())
				OR TypeOf(Selection.Document) = TypeOf(Catalogs.JobOrderContracts.EmptyRef())) Then
				
			Else
				If Selection.PaymentMethod <> Selection.PaymentMethodBalance Then
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Payment method is different of payment on the document: %P1'; pl = 'Sposób płatności różni się od sposobu płatności na dokumencie: %P1'"),New Structure("P1",Selection.Document.PaymentMethod)),Enums.AlertType.Error,Cancel,Document);
				EndIf;
			EndIf;
						
			If NOT IsNationalCurrency Then
				
				If Selection.AmountDrNational <> 0 And Selection.AmountDrNationalBalance<Selection.AmountDrNational Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount national you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Wn (kraj.) jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountDrNationalBalance,Selection.Currency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;	
				
				If Selection.AmountCrNational <> 0 And Selection.AmountCrNationalBalance<Selection.AmountCrNational Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount national you are trying to settlement is greater than balance on this document. You can settlement only %P1 %P2'; pl = 'Rozliczana kwota Ma (kraj.) jest większa od dostępnego salda dokumentu. Możesz rozliczyć tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountCrNationalBalance,Selection.Currency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;		
				
			EndIf;
			
		EndIf;	
		
		If TypeOf(Document.Ref) <> TypeOf(Documents.EmployeesOffsettingOfDebts.EmptyRef()) OR NOT Document.MultiCurrencySettlement Then
			DocumentsCurrency = APAR.GetDocumentsCurrency(Selection.Document);
			If Alerts.IsNotEqualValue(Document.SettlementCurrency, DocumentsCurrency) Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s currency should be the same as settlement currency! Document''s currency:'; pl = 'Waluta dokumentu powinna być taka sama jak waluta rozrachunków! Waluta dokumentu:'") + " " + DocumentsCurrency, Enums.AlertType.Error, Cancel,Document);
			EndIf;
		EndIf;
		
		If Selection.AmountCr = 0 And Selection.AmountDr = 0
			AND Selection.AmountCrNational = 0 And Selection.AmountDrNational = 0 Then
			Alerts.AddAlert(MessageTextBegin + NStr("en='At least one of the amounts should be non-zero!';pl='Co najmniej jedna z kwot powinna być nie zerowa!';ru='По крайней мере одна из сумм должна иметь ненулевое значение!'"), Enums.AlertType.Error, Cancel,Document);
		EndIf;
		If CommonAtServer.IsDocumentAttribute("Employee", Document.Metadata()) Then
			DocumentsEmployee = Document.Employee;
		Else
			DocumentsEmployee = Document.Partner;
		EndIf;
		DocumentsEmployee = APAR.GetDocumentsEmployee(Selection.Document);
		If Alerts.IsNotEqualValue(Selection.Employee, DocumentsEmployee) Then
			// For example paying card the payer is processing center, but in document's customer is not payer.
			Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s employee should be the same as the employee in the row! Document''s employee:'; pl = 'Pracownik w dokumencie powinien być taki samy jak wybrany w wierszy! Pracownik w dokumencie:'") + " " + DocumentsEmployee, Enums.AlertType.Error, Cancel,Document);
		EndIf;
		
		AmountsStructure = TransformateAmountFromCrDr(Selection.AmountCr,Selection.AmountCrNational,Selection.AmountDr,Selection.AmountDrNational);
		If AmountsStructure.Amount = 0 Then
			AmountToCompare = AmountsStructure.AmountNational;
		Else
			AmountToCompare = AmountsStructure.Amount;
		EndIf;	
		If Selection.PrepaymentSettlement = Enums.PrepaymentSettlement.Settlement Then
			
			PostAccountPayableReceivable(abs(AmountsStructure.Amount),
										abs(AmountsStructure.AmountNational),
										Selection.Employee,
										?(AmountToCompare<0,AccumulationRecordType.Expense,AccumulationRecordType.Receipt),
										Enums.EmployeeSettlementTypes.EmployeeSettlement,
										Selection.DocumentSettlementCurrency,
										,
										Selection.Document,
										Document,
										Cancel,
										Selection.PaymentMethod);
			
		ElsIf Selection.PrepaymentSettlement = Enums.PrepaymentSettlement.PrepaymentSettlement Then
			
			If NOT SkipChekForPrepayments Then
				
				If IsInternalEmployeeDocument(Selection.Document) Then
					
					If CommonAtServer.IsDocumentAttribute("SettlementExchangeRate",Document.Metadata()) Then 
						
						If Alerts.IsNotEqualValue(Document.SettlementExchangeRate,Selection.InternalDocumentExchangeRate) Then
							
							MessageText = Alerts.ParametrizeString(Nstr("en=""Exchange rate in internal partner document %P1 for prepayment should be equal to document's exchange rate! Internal's document exchange rate: %P2 and document's exchange rate: %P3."";pl='Kurs wymiany wewnętrznego dokumentu kontrahenta %P1 powinnien zgadzać się z kursem na dokumencie! Kurs wewnętrznego dokumentu kontrahenta: %P2 oraz kurs na dokumencie: %P3.'"),New Structure("P1, P2, P3",Selection.Document,Selection.InternalDocumentExchangeRate,Document.SettlementExchangeRate));
							Alerts.AddAlert(MessageTextBegin + MessageText , Enums.AlertType.Error, Cancel,Document);
							
						EndIf;
						
					EndIf;	
					
				EndIf;	
				
			EndIf;
			
			SettlementType = Undefined;
			If TypeOf(Document) = Type("DocumentRef.EmployeesOffsettingOfDebts")
				OR TypeOf(Document) = Type("DocumentRef.BookkeepingOperation") Then
				SettlementType = ?(AmountToCompare>0, Enums.EmployeeSettlementTypes.PrepaymentToEmployee,Enums.EmployeeSettlementTypes.PrepaymentFromEmployee);
			Else
				SettlementType = ?(AmountToCompare<0, Enums.EmployeeSettlementTypes.PrepaymentToEmployee,Enums.EmployeeSettlementTypes.PrepaymentFromEmployee);
			EndIf;	
			
			PostAccountPayableReceivable(abs(AmountsStructure.Amount),
										abs(AmountsStructure.AmountNational),
										Selection.Employee,
										?(AmountToCompare<0,AccumulationRecordType.Expense,AccumulationRecordType.Receipt),
										SettlementType,
										Selection.DocumentSettlementCurrency,
										Selection.ReservationDocument,
										Selection.Document,
										Document,
										Cancel,
										Selection.PaymentMethod);

		EndIf;	
		
	EndDo;
	
EndProcedure

Procedure PostReservedPrepayments(Document, Cancel,PostingMode) Export
	
	DocumentName = Document.Metadata().Name;
	
	IsIncomingDocument = (TypeOf(Document.OperationType) = TypeOf(Enums.OperationTypesAccountsIncoming.EmptyRef()));
	
	Query = New Query();
	If PostingMode = DocumentPostingMode.Regular Then
		Query.Text = 
		"SELECT
		|	ReservedPrepayments.LineNumber,
		|	ReservedPrepayments.ReservationDocument,
		|	ReservedPrepayments.ReservationDocument.ExchangeRate AS InternalDocumentExchangeRate,
		|	ReservedPrepayments.Ref.Partner AS Partner,
		|	ReservedPrepayments.Ref.Partner.CustomerType AS PartnerCustomerType, " + ?(IsIncomingDocument,"
		|	ReservedPrepayments.AmountCr,
		|	ReservedPrepayments.AmountCrNational ","
		|	ReservedPrepayments.AmountDr,
		|	ReservedPrepayments.AmountDrNational")+"
		|FROM
		|	Document." + DocumentName + ".ReservedPrepayments AS ReservedPrepayments
		|WHERE
		|	ReservedPrepayments.Ref = &Ref";
		
	ElsIf PostingMode = DocumentPostingMode.RealTime Then
		
		Query.Text = "SELECT
		             |	ReservedPrepayments.LineNumber,
		             |	ReservedPrepayments.ReservationDocument,
		             |	ReservedPrepayments.ReservationDocument.ExchangeRate AS InternalDocumentExchangeRate,
		             |	ReservedPrepayments.Ref.Partner AS Partner,
		             |	ReservedPrepayments.Ref.Partner.CustomerType AS PartnerCustomerType, " + ?(IsIncomingDocument,"
					 |	ReservedPrepayments.AmountCr,
					 |	ReservedPrepayments.AmountCrNational ","
					 |	ReservedPrepayments.AmountDr,
					 |	ReservedPrepayments.AmountDrNational")+"
		             |	,CASE
		             |		WHEN ISNULL(OrdersAwaitedToPrepaymentInvoiceTurnovers.GrossAmountTurnover, 0) <= 0
		             |			THEN 0
		             |		ELSE OrdersAwaitedToPrepaymentInvoiceTurnovers.GrossAmountTurnover - CASE
		             |				WHEN PartnersSettlementsBalance.AmountBalance IS NULL 
		             |					THEN 0
		             |				WHEN PartnersSettlementsBalance.AmountBalance < 0
		             |					THEN -PartnersSettlementsBalance.AmountBalance
		             |				ELSE PartnersSettlementsBalance.AmountBalance
		             |			END
		             |	END AS Amount
		             |FROM
		             |	Document." + DocumentName + ".ReservedPrepayments AS ReservedPrepayments
		             |		LEFT JOIN AccumulationRegister.OrdersAwaitedToPrepaymentInvoice.Turnovers(
		             |				,
		             |				&Date,
		             |				,
		             |				Company = &Company
		             |					AND Document IN
		             |						(SELECT DISTINCT
		             |							DocumentNameReservedPrepayments.ReservationDocument
		             |						FROM
		             |							Document." + DocumentName + ".ReservedPrepayments AS DocumentNameReservedPrepayments
		             |						WHERE
		             |							(DocumentNameReservedPrepayments.ReservationDocument REFS Document.SalesOrder
		             |								OR DocumentNameReservedPrepayments.ReservationDocument REFS Document.PurchaseOrder)
		             |							AND DocumentNameReservedPrepayments.Ref = &Ref)) AS OrdersAwaitedToPrepaymentInvoiceTurnovers
		             |			LEFT JOIN AccumulationRegister.PartnersSettlements.Balance(
		             |					&Date,
		             |					Company = &Company
					 |					AND (NOT Document REFS Document.SalesPrepaymentInvoice)
	                 |					AND (NOT Document REFS Document.PurchasePrepaymentInvoice)
		             |						AND ReservationDocument IN
		             |							(SELECT DISTINCT
		             |								DocumentNameReservedPrepayments.ReservationDocument
		             |							FROM
		             |								Document." + DocumentName + ".ReservedPrepayments AS DocumentNameReservedPrepayments
		             |							WHERE
		             |								(DocumentNameReservedPrepayments.ReservationDocument REFS Document.SalesOrder
		             |									OR DocumentNameReservedPrepayments.ReservationDocument REFS Document.PurchaseOrder)
		             |								AND DocumentNameReservedPrepayments.Ref = &Ref)) AS PartnersSettlementsBalance
		             |			ON OrdersAwaitedToPrepaymentInvoiceTurnovers.Document = PartnersSettlementsBalance.ReservationDocument
		             |		ON ReservedPrepayments.ReservationDocument = OrdersAwaitedToPrepaymentInvoiceTurnovers.Document
		             |			AND ReservedPrepayments.Ref.Company = OrdersAwaitedToPrepaymentInvoiceTurnovers.Company
		             |			AND ReservedPrepayments.Ref.Partner = OrdersAwaitedToPrepaymentInvoiceTurnovers.Partner
		             |			AND ((NOT(ReservedPrepayments.ReservationDocument REFS Catalog.SupplierInternalDocuments
		             |					OR ReservedPrepayments.ReservationDocument REFS Catalog.CustomerInternalDocuments)))
		             |WHERE
		             |	ReservedPrepayments.Ref = &Ref";
	
	EndIf;	
	
	Query.SetParameter("Ref",Document.Ref);
	Query.SetParameter("Date",Document.Date);
	Query.SetParameter("Company",Document.Company);
	
	Selection = Query.Execute().Select();
	
	NationalCurrency = Constants.NationalCurrency.Get();
	IsNationalCurrency = (NationalCurrency = Document.SettlementCurrency);
	
	While Selection.Next() Do
		
		MessageTextBegin = Alerts.ParametrizeString(NStr("en = 'Reserved prepayments, line %P1.'; pl = 'Zarezerwowane zaliczki, wiersz %P1.'"),New Structure("P1",TrimAll(Selection.LineNumber)));
		
		If PostingMode = DocumentPostingMode.RealTime
			AND NOT IsInternalPartnerDocument(Selection.ReservationDocument) Then 
			
			If IsIncomingDocument Then
				
				If Selection.AmountCr <> 0 
					AND Selection.Amount<Selection.AmountCr Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount you are trying to reserve is greater than balance on this document. You can reserve only %P1 %P2'; pl = 'Rezerwowana kwota Ma jest większa od dostępnej do zarezerwowania kwoty dokumentu. Możesz zarezerwować tylko %P1 %P2'"),New Structure("P1, P2",Selection.Amount,Document.SettlementCurrency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;				
				
			Else
				
				If Selection.AmountDr <> 0 
					AND Selection.Amount<Selection.AmountDr Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount you are trying to reserve is greater than balance on this document. You can reserve only %P1 %P2'; pl = 'Rezerwowana kwota Wn jest większa od dostępnej do zarezerwowania kwoty dokumentu. Możesz zarezerwować tylko %P1 %P2'"),New Structure("P1, P2",Selection.Amount,Document.SettlementCurrency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;
				
			EndIf;	
			
		EndIf;	
		
		// RED ALERTS
		If TypeOf(Selection.Partner) = TypeOf(Catalogs.Customers.EmptyRef()) 
			AND Selection.PartnerCustomerType <> Enums.CustomerTypes.Independent
			AND ValueIsFilled(Selection.Partner) Then
			Alerts.AddAlert(NStr("en = 'Choosen customer could not be used as partner. Please, check attribute ''Customer type''. It should be set to ''Independent'''; pl = 'Nie można używać wybranego klienta jako kontrahenta. Sprawdź czy klient ma ustawiony atrubyt ''Typ klienta'' o wartości ''Niezależny'''"),Enums.AlertType.Error,Cancel,Document);
		EndIf;
		
		DocumentsCurrency = APAR.GetDocumentsCurrency(Selection.ReservationDocument);
		If Alerts.IsNotEqualValue(Document.SettlementCurrency, DocumentsCurrency) Then
			Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s currency should be the same as settlement currency! Document''s currency:'; pl = 'Waluta dokumentu powinna być taka sama jak waluta rozrachunków! Waluta dokumentu:'") + " " + DocumentsCurrency, Enums.AlertType.Error, Cancel,Document);
		EndIf;
		
		If IsIncomingDocument Then 
			
			If Selection.AmountCr = 0 Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Credit amount should be non-zero!'; pl = 'Kwota Ma powinna być nie zerowa!'"), Enums.AlertType.Error, Cancel,Document);
			EndIf;
			
		Else
			
			If Selection.AmountDr = 0 Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Debit amount should be non-zero!'; pl = 'Kwota Wn powinna być nie zerowa!'"), Enums.AlertType.Error, Cancel,Document);
			EndIf;
			
		EndIf;	
		
		DocumentsPartner = APAR.GetDocumentsPartner(Selection.ReservationDocument);
		If Alerts.IsNotEqualValue(Selection.Partner, DocumentsPartner)  Then
			Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s partner should be the same as the partner in the row! Document''s partner:'; pl = 'Kontrahent w dokumencie powinien być taki samy jak wybrany w wierszy! Kontrahent w dokumencie:'") + " " + DocumentsPartner, Enums.AlertType.Error, Cancel,Document);
		EndIf;
		
		If IsInternalPartnerDocument(Selection.ReservationDocument) Then
			
			If Alerts.IsNotEqualValue(Document.SettlementExchangeRate,Selection.InternalDocumentExchangeRate) Then
				
				MessageText = Alerts.ParametrizeString(Nstr("en=""Exchange rate in internal partner document %P1 for prepayment should be equal to document's exchange rate! Internal's document exchange rate: %P2 and document's exchange rate: %P3."";pl='Kurs wymiany wewnętrznego dokumentu kontrahenta %P1 powinnien zgadzać się z kursem na dokumencie! Kurs wewnętrznego dokumentu kontrahenta: %P2 oraz kurs na dokumencie: %P3.'"),New Structure("P1, P2, P3",Selection.ReservationDocument,Selection.InternalDocumentExchangeRate,Document.SettlementExchangeRate));
				Alerts.AddAlert(MessageTextBegin + MessageText , Enums.AlertType.Error, Cancel,Document);
				
			EndIf;
			
		EndIf;	

		If IsIncomingDocument Then 		
			AmountsStructure = TransformateAmountFromCrDr(Selection.AmountCr,Selection.AmountCrNational,0,0);
		Else
			AmountsStructure = TransformateAmountFromCrDr(0,0,Selection.AmountDr,Selection.AmountDrNational);
		EndIf;	
		If Document.OperationType = Enums.OperationTypesAccountsIncoming.FromEmployee Then
			SettelementType = Enums.EmployeeSettlementTypes.PrepaymentFromEmployee;
		Else
			SettelementType = ?(TypeOf(Selection.Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()),Enums.PartnerSettlementTypes.PrepaymentToSupplier,Enums.PartnerSettlementTypes.PrepaymentFromCustomer);
		EndIf;
		PostAccountPayableReceivable(ABS(AmountsStructure.Amount),
									ABS(AmountsStructure.AmountNational),
									Selection.Partner,
									?(IsIncomingDocument,AccumulationRecordType.Expense,AccumulationRecordType.Receipt),
									SettelementType,
									Document.SettlementCurrency,
									Selection.ReservationDocument,
									Document.Ref,
									Document,
									Cancel);
	
	EndDo;
	
EndProcedure

// Post Employee
Procedure PostEmployeeReservedPrepayments(Document, Cancel, PostingMode) Export
	
	DocumentName = Document.Metadata().Name;
	
	IsIncomingDocument = ( (TypeOf(Document.Ref) = TypeOf(Documents.BankIncomingFromEmployee.EmptyRef()))
							Or (TypeOf(Document.Ref) = TypeOf(Documents.CashIncomingFromEmployee.EmptyRef())));
	
	Query = New Query();
	If PostingMode = DocumentPostingMode.Regular Then
		Query.Text = 
		"SELECT
		|	ReservedPrepayments.LineNumber,
		|	ReservedPrepayments.ReservationDocument,
		|	ReservedPrepayments.ReservationDocument.ExchangeRate AS InternalDocumentExchangeRate,
		|	ReservedPrepayments.PaymentMethod,";
		If CommonAtServer.IsDocumentAttribute("Employee", Document.Metadata()) Then
			Query.Text = Query.Text + "
			|	ReservedPrepayments.Ref.Employee AS Employee, ";
		Else
			Query.Text = Query.Text + "
			|	ReservedPrepayments.Ref.Partner AS Employee, ";
		EndIf;
		
		Query.Text = Query.Text	+ ?(IsIncomingDocument,"
		|	ReservedPrepayments.AmountCr,
		|	ReservedPrepayments.AmountCrNational ","
		|	ReservedPrepayments.AmountDr,
		|	ReservedPrepayments.AmountDrNational")+"
		|FROM
		|	Document." + DocumentName + ".ReservedPrepayments AS ReservedPrepayments
		|WHERE
		|	ReservedPrepayments.Ref = &Ref";
		
	ElsIf PostingMode = DocumentPostingMode.RealTime Then
		
		Query.Text = "SELECT
		             |	ReservedPrepayments.LineNumber,
		             |	ReservedPrepayments.ReservationDocument,
		             |	ReservedPrepayments.ReservationDocument.ExchangeRate AS InternalDocumentExchangeRate,
					 |	ReservedPrepayments.PaymentMethod,";
					 
					If CommonAtServer.IsDocumentAttribute("Employee", Document.Metadata()) Then
						Query.Text = Query.Text + "
						|	ReservedPrepayments.Ref.Employee AS Employee, ";
					Else
						Query.Text = Query.Text + "
						|	ReservedPrepayments.Ref.Partner AS Employee, ";
					EndIf;
					 
					 Query.Text = Query.Text + ?(IsIncomingDocument,"
					 |	ReservedPrepayments.AmountCr,
					 |	ReservedPrepayments.AmountCrNational, ","
					 |	ReservedPrepayments.AmountDr,
					 |	ReservedPrepayments.AmountDrNational,")+"
		             |	AwaitedPrepayments.Amount AS Amount,
		             |	AwaitedPrepayments.AmountNational
		             |FROM
		             |	Document." + DocumentName + ".ReservedPrepayments AS ReservedPrepayments
		             |		LEFT JOIN InformationRegister.AwaitedPrepayments AS AwaitedPrepayments
		             |		ON ReservedPrepayments.ReservationDocument = AwaitedPrepayments.Document
		             |			AND ReservedPrepayments.Ref.Company = AwaitedPrepayments.Company
		             |WHERE
		             |	ReservedPrepayments.Ref = &Ref";
	
	EndIf;	
	
	Query.SetParameter("Ref",Document.Ref);
	Query.SetParameter("Date",Document.Date);
	
	Selection = Query.Execute().Select();
	
	NationalCurrency = Constants.NationalCurrency.Get();
	IsNationalCurrency = (NationalCurrency = Document.SettlementCurrency);
	
	While Selection.Next() Do
		
		MessageTextBegin = Alerts.ParametrizeString(NStr("en = 'Reserved prepayments, line %P1.'; pl = 'Zarezerwowane zaliczki, wiersz %P1.'"),New Structure("P1",TrimAll(Selection.LineNumber)));
		
		If PostingMode = DocumentPostingMode.RealTime
			AND NOT IsInternalEmployeeDocument(Selection.ReservationDocument) Then 
			
			If IsIncomingDocument Then
				
				If Selection.AmountCr <> 0 
					AND Selection.AmountCrBalance<Selection.AmountCr Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount you are trying to reserve is greater than balance on this document. You can reserve only %P1 %P2'; pl = 'Rezerwowana kwota Ma jest większa od dostępnej do zarezerwowania kwoty dokumentu. Możesz zarezerwować tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountCrBalance,Document.SettlementCurrency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;				
				
				If NOT IsNationalCurrency Then
					
					If Selection.AmountCrNational <> 0 
						AND Selection.AmountCrNationalBalance<Selection.AmountCrNational Then
						
						Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Credit amount national you are trying to reserve is greater than balance on this document. You can reserve only %P1 %P2'; pl = 'Rezerwowana kwota Ma (kraj.) jest większa od dostępnej do zarezerwowania kwoty dokumentu. Możesz zarezerwować tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountCrNationalBalance,Document.SettlementCurrency)),Enums.AlertType.Error,Cancel,Document);
						
					EndIf;		
					
				EndIf;
				
			Else
				
				If Selection.AmountDr <> 0 
					AND Selection.AmountDrBalance<Selection.AmountDr Then
					
					Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount you are trying to reserve is greater than balance on this document. You can reserve only %P1 %P2'; pl = 'Rezerwowana kwota Wn jest większa od dostępnej do zarezerwowania kwoty dokumentu. Możesz zarezerwować tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountDrBalance,Document.SettlementCurrency)),Enums.AlertType.Error,Cancel,Document);
					
				EndIf;
				
				If NOT IsNationalCurrency Then
					
					If Selection.AmountCrNational <> 0 
						AND Selection.AmountCrNationalBalance<Selection.AmountCrNational Then
						
						Alerts.AddAlert(MessageTextBegin + Alerts.ParametrizeString(NStr("en = 'Debit amount national you are trying to reserve is greater than balance on this document. You can reserve only %P1 %P2'; pl = 'Rezerwowana kwota Wn (kraj.) jest większa od dostępnej do zarezerwowania kwoty dokumentu. Możesz zarezerwować tylko %P1 %P2'"),New Structure("P1, P2",Selection.AmountDrNationalBalance,Document.SettlementCurrency)),Enums.AlertType.Error,Cancel,Document);
						
					EndIf;		
					
				EndIf;
				
			EndIf;	
			
		EndIf;	
		
		DocumentsCurrency = APAR.GetDocumentsCurrency(Selection.ReservationDocument);
		If Alerts.IsNotEqualValue(Document.SettlementCurrency, DocumentsCurrency) Then
			Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s currency should be the same as settlement currency! Document''s currency:'; pl = 'Waluta dokumentu powinna być taka sama jak waluta rozrachunków! Waluta dokumentu:'") + " " + DocumentsCurrency, Enums.AlertType.Error, Cancel,Document);
		EndIf;
		
		If IsIncomingDocument Then 
			
			If Selection.AmountCr = 0 Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Credit amount should be non-zero!'; pl = 'Kwota Ma powinna być nie zerowa!'"), Enums.AlertType.Error, Cancel,Document);
			EndIf;
			
		Else
			
			If Selection.AmountDr = 0 Then
				Alerts.AddAlert(MessageTextBegin + NStr("en = 'Debit amount should be non-zero!'; pl = 'Kwota Wn powinna być nie zerowa!'"), Enums.AlertType.Error, Cancel,Document);
			EndIf;
			
		EndIf;	
		
		DocumentsEmployee = APAR.GetDocumentsPartner(Selection.ReservationDocument);
		If Alerts.IsNotEqualValue(Selection.Employee, DocumentsEmployee) Then
			Alerts.AddAlert(MessageTextBegin + NStr("en = 'Document''s employee should be the same as the employee in the row! Document''s employee:'; pl = 'Pracownik w dokumencie powinien być taki samy jak wybrany w wierszy! Pracownik w dokumencie:'") + " " + DocumentsEmployee, Enums.AlertType.Error, Cancel,Document);
		EndIf;
		
		If IsInternalPartnerDocument(Selection.ReservationDocument) Then
			
			If Alerts.IsNotEqualValue(Document.SettlementExchangeRate,Selection.InternalDocumentExchangeRate) Then
				
				MessageText = Alerts.ParametrizeString(Nstr("en=""Exchange rate in internal employee document %P1 for prepayment should be equal to document's exchange rate! Internal's document exchange rate: %P2 and document's exchange rate: %P3."";pl='Kurs wymiany wewnętrznego dokumentu pracownika %P1 powinnien zgadzać się z kursem na dokumencie! Kurs wewnętrznego dokumentu pracownika: %P2 oraz kurs na dokumencie: %P3.'"),New Structure("P1, P2, P3",Selection.ReservationDocument,Selection.InternalDocumentExchangeRate,Document.SettlementExchangeRate));
				Alerts.AddAlert(MessageTextBegin + MessageText , Enums.AlertType.Error, Cancel,Document);
				
			EndIf;
			
		EndIf;	

		If IsIncomingDocument Then 		
			AmountsStructure = TransformateAmountFromCrDr(Selection.AmountCr,Selection.AmountCrNational,0,0);
		Else
			AmountsStructure = TransformateAmountFromCrDr(0,0,Selection.AmountDr,Selection.AmountDrNational);
		EndIf;	
		
		PostAccountPayableReceivable(ABS(AmountsStructure.Amount),
									ABS(AmountsStructure.AmountNational),
									Selection.Employee,
									?(IsIncomingDocument,AccumulationRecordType.Expense,AccumulationRecordType.Receipt),
									?(IsIncomingDocument,Enums.EmployeeSettlementTypes.PrepaymentFromEmployee,Enums.EmployeeSettlementTypes.PrepaymentToEmployee),
									Document.SettlementCurrency,
									Selection.ReservationDocument,
									Document.Ref,
									Document,
									Cancel,
									Selection.PaymentMethod);
		
		If NOT IsInternalEmployeeDocument(Selection.ReservationDocument) Then

			PostAwaitedPrepayments(ABS(AmountsStructure.Amount),
									ABS(AmountsStructure.AmountNational),
									Selection.Employee,
									?(IsIncomingDocument,AccumulationRecordType.Receipt,AccumulationRecordType.Expense),
									Selection.ReservationDocument,
									Document,
									Cancel);
		EndIf;
								
	EndDo;
	
EndProcedure

Procedure PostAccountPayableReceivable(GrossAmount,GrossAmountNational,PartnerOrEmployee,RecordType,SettlementType,Currency,ReservationDocument = Undefined,DocumentRef,Object,Cancel = False,PaymentMethod = Undefined) Export
	
	If GrossAmount<>0 OR GrossAmountNational<> 0 Then
		If TypeOf(PartnerOrEmployee) = TypeOf(Catalogs.Employees.EmptyRef()) Then
			Record = Object.RegisterRecords.EmployeesSettlements.Add();
			
			If TypeOf(Object.Ref) = TypeOf(Documents.EmployeesOffsettingOfDebts.EmptyRef()) Then
				If CommonAtServer.IsDocumentAttribute("PaymentMethod",DocumentRef.Metadata()) Then
					Record.PaymentMethod = DocumentRef.PaymentMethod;
				ElsIf SessionParameters.IsBookkeepingAvailable 
					AND (TypeOf(DocumentRef) = TypeOf(Documents.Payroll.EmptyRef())
					OR TypeOf(DocumentRef) = TypeOf(Catalogs.JobOrderContracts.EmptyRef())) Then	
					Record.PaymentMethod = Catalogs.PaymentMethods.EmptyRef();	
				Else
					If PaymentMethod <> Undefined Then
						Record.PaymentMethod = PaymentMethod;
					EndIf;
				EndIf;	
			ElsIf SessionParameters.IsBookkeepingAvailable 
				AND (TypeOf(Object.Ref) = TypeOf(Documents.Payroll.EmptyRef())
				OR TypeOf(Object.Ref) = TypeOf(Catalogs.JobOrderContracts.EmptyRef())) Then	
				Record.PaymentMethod = Catalogs.PaymentMethods.EmptyRef();
			Else
				If PaymentMethod <> Undefined Then
					Record.PaymentMethod = PaymentMethod;
				ElsIf CommonAtServer.IsDocumentAttribute("PaymentMethod", Object.Ref.Metadata()) Then
					Record.PaymentMethod = Object.Ref.PaymentMethod;
				EndIf;
			EndIf;
			
			Record.Employee = PartnerOrEmployee;
			
		ElsIf TypeOf(PartnerOrEmployee) = TypeOf(Catalogs.Suppliers.EmptyRef())
			OR TypeOf(PartnerOrEmployee) = TypeOf(Catalogs.Customers.EmptyRef()) Then
			Record = Object.RegisterRecords.PartnersSettlements.Add();
			Record.Partner = PartnerOrEmployee;
		Else
			Return;
		EndIf;
		Record.RecordType = RecordType;
		Record.Currency	  = Currency;
		Record.Company	  = Object.Company;
		Record.Period	  = Object.Date;
		Record.Document	  = DocumentRef;
		Record.Amount	  = GrossAmount;
		Record.AmountNational = GrossAmountNational;
		Record.SettlementType = SettlementType;
		
		If ReservationDocument <> Undefined And ValueIsFilled(ReservationDocument) Then
			Record.ReservationDocument = ReservationDocument;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure PostAwaitedPrepayments(GrossAmount,GrossAmountNational,Partner,RecordType,OrderRef,Object,Cancel = False, WriteAmountZero = False) Export
	
	If WriteAmountZero Or (GrossAmount<>0 OR GrossAmountNational<>0) Then
		
		Record = Object.RegisterRecords.AwaitedPrepayments.Add();
		Record.Company	= Object.Company;
		Record.Partner	= Partner;
		Record.Period	= Object.Date;
		Record.Document = OrderRef;
		Record.Amount	= GrossAmount;
		Record.AmountNational = GrossAmountNational;
		
	EndIf;
	
EndProcedure

Procedure PostCashFlowTurnovers(Amount, AmountNational, Currency, Object, RecordType, Cancel = False) Export
	
	If Amount <> 0 OR AmountNational <> 0 Then
		
		Record = Object.RegisterRecords.CashFlowTurnovers.Add();
		Record.Period	  = Object.Date;
		Record.Company	  = Object.Company;
		Record.Document	  = Object.Ref;
		Record.CashFlowDirection = Object.CashFlowDirection;
		
		If IsBank(Object.Ref) Then
			Record.BankCash	= Object.BankAccount;
		ElsIf IsCash(Object.Ref) Then
			Record.BankCash = Object.CashDesk;
		EndIf;
		
		Record.Currency = Currency;
		
		If RecordType = AccumulationRecordType.Receipt Then
			Record.Amount		  = Amount;
			Record.AmountNational = AmountNational;
		ElsIf RecordType = AccumulationRecordType.Expense Then
			Record.Amount		  = -Amount;
			Record.AmountNational = -AmountNational;
		EndIf;
		
	EndIf;
	
EndProcedure

Function IsBank(ObjectRef)
	
	If TypeOf(ObjectRef) = TypeOf(Documents.BankIncomingFromEmployee.EmptyRef())	 Or TypeOf(ObjectRef) = TypeOf(Documents.BankIncomingFromPartner.EmptyRef())
		Or TypeOf(ObjectRef) = TypeOf(Documents.BankOutgoingToEmployee.EmptyRef()) Or TypeOf(ObjectRef) = TypeOf(Documents.BankOutgoingOther.EmptyRef())
		Or TypeOf(ObjectRef) = TypeOf(Documents.BankOutgoingToPartner.EmptyRef())	 Or TypeOf(ObjectRef) = TypeOf(Documents.BankIncomingOther.EmptyRef()) Then
		
		Return True;
		
	Else
		Return False;	
		
	EndIf;
	
EndFunction

Function IsCash(ObjectRef)
	
	If TypeOf(ObjectRef) = TypeOf(Documents.CashIncomingFromEmployee.EmptyRef())	Or TypeOf(ObjectRef) = TypeOf(Documents.CashIncomingFromPartner.EmptyRef())
		Or TypeOf(ObjectRef) = TypeOf(Documents.CashOutgoingToEmployee.EmptyRef()) Or TypeOf(ObjectRef) = TypeOf(Documents.CashOutgoingToPartner.EmptyRef())
		Or TypeOf(ObjectRef) = TypeOf(Documents.CashIncomingOther.EmptyRef())		Or TypeOf(ObjectRef) = TypeOf(Documents.CashOutgoingOther.EmptyRef())
		Then
		
		Return True;
		
	Else
		Return False;
	EndIf;
	
EndFunction

Procedure PartnersDocumentStartChoice(Document, Partner, Currency, Control) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		ChoiceForm = Catalogs[Document.Metadata().Name].GetChoiceForm(, Control, Control);
		FilterStructure = New Structure("Owner",Partner);
		If ValueIsFilled(Currency) Then
			FilterStructure.Insert("Currency",Currency);
		EndIf;	
		ChoiceForm.SetFilter(Document,FilterStructure);
		ChoiceForm.Open();
	
	Else // documents
		
		ChoiceForm = Documents[Document.Metadata().Name].GetChoiceForm(, Control, Control);
		FilterStructure = New Structure("PartnersDocuments",Partner);
		ChoiceForm.Filter.PartnersDocuments.Set(Partner);
		If ValueIsFilled(Currency) Then
			If CommonAtServer.IsDocumentAttribute("Currency", Document.Metadata()) Then
				FilterStructure.Insert("Currency",Currency);
			ElsIf CommonAtServer.IsDocumentAttribute("SettlementCurrency", Document.Metadata()) Then
				FilterStructure.Insert("SettlementCurrency",Currency);
			EndIf;
		EndIf;
		ChoiceForm.SetFilter(Document,FilterStructure);
		ChoiceForm.Open();
		
	EndIf;
	
EndProcedure

// Employee
Procedure EmployeesDocumentStartChoice(Document, Employee, Currency, Control) Export
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
		
		ChoiceForm = Catalogs[Document.Metadata().Name].GetChoiceForm(, Control, Control);
		If TypeOf(Document) = TypeOf(Catalogs.JobOrderContracts.EmptyRef()) Then
			ChoiceForm.SetFilter(Document,New Structure("Employee",Employee));	
		Else	
			ChoiceForm.SetFilter(Document,New Structure("Owner, Currency",Employee,Currency));	
		EndIf;
		ChoiceForm.Open();
	Else //documents
		
		ChoiceForm = Documents[Document.Metadata().Name].GetChoiceForm(, Control, Control);
		FilterStructure = New Structure("EmployeesDocuments",Employee);
		ChoiceForm.Filter.EmployeesDocuments.Set(Employee);
		If ValueIsFilled(Currency) Then
			If CommonAtServer.IsDocumentAttribute("Currency", Document.Metadata()) Then
				FilterStructure.Insert("Currency",Currency);
			ElsIf CommonAtServer.IsDocumentAttribute("SettlementCurrency", Document.Metadata()) Then
				FilterStructure.Insert("SettlementCurrency",Currency);
			EndIf;
		EndIf;
		ChoiceForm.SetFilter(Document,FilterStructure);
		ChoiceForm.Open();
		
	EndIf;
	
EndProcedure //EmployeesDocumentStartChoice()

Function PickDocumentsRegularChoiceProcessing(ChoiceValue, Form) Export
	
	If Not Common.IsDocumentTabularPart(ChoiceValue.TabularPartName, Form.Metadata()) Then
		Return Undefined;
	EndIf;
	
	TabularSection = Form[ChoiceValue.TabularPartName];
	
	If ChoiceValue.SettlementType = Enums.PartnerSettlementTypes.SupplierSettlement
		OR ChoiceValue.SettlementType = Enums.PartnerSettlementTypes.CustomerSettlement Then
		
		TabularSectionRowPrepaymentSettlement = Enums.PrepaymentSettlement.Settlement;
		
	ElsIf ChoiceValue.SettlementType = Enums.PartnerSettlementTypes.PrepaymentFromCustomer
		OR ChoiceValue.SettlementType = Enums.PartnerSettlementTypes.PrepaymentToSupplier Then
		
		TabularSectionRowPrepaymentSettlement = Enums.PrepaymentSettlement.PrepaymentSettlement;
		
	ElsIf ChoiceValue.SettlementType = Enums.EmployeeSettlementTypes.EmployeeSettlement Then
		
		TabularSectionRowPrepaymentSettlement = Enums.PrepaymentSettlement.Settlement;
		
	ElsIf ChoiceValue.SettlementType = Enums.EmployeeSettlementTypes.PrepaymentFromEmployee
		OR ChoiceValue.SettlementType = Enums.EmployeeSettlementTypes.PrepaymentToEmployee Then
		
		TabularSectionRowPrepaymentSettlement = Enums.PrepaymentSettlement.PrepaymentSettlement;
		
	Endif;
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Document", ChoiceValue.Document);
	SearchStructure.Insert("ReservationDocument", ChoiceValue.ReservationDocument);
	SearchStructure.Insert("PrepaymentSettlement", TabularSectionRowPrepaymentSettlement);
	
	If ChoiceValue.PickType = "ByEmployees" Then
		SearchStructure.Insert("Employee", ChoiceValue.Employee);
		SearchStructure.Insert("PaymentMethod", ChoiceValue.PaymentMethod);
	Else
		SearchStructure.Insert("Partner", ChoiceValue.Partner);
	EndIf;

	TabularSectionRow = Common.FindTabularPartRow(TabularSection, SearchStructure);
	
	If TabularSectionRow = Undefined Then
		
		TabularSectionRow = TabularSection.Add();
		
		TabularSectionRow.Document = ChoiceValue.Document;
		
		If Common.IsDocumentTabularPartAttribute("Partner", Form.Metadata(), ChoiceValue.TabularPartName) Then
			TabularSectionRow.Partner = ChoiceValue.Partner;
			
			If ValueIsNotFilled(Form.Partner) Then
				Form.Partner = ChoiceValue.Partner;
			Else	
				If ValueIsFilled(ChoiceValue.Partner) AND Form.OtherPartnersList.FindByValue(ChoiceValue.Partner) = Undefined Then
					Form.OtherPartnersList.Add(ChoiceValue.Partner);
				EndIf;	
				
				If Form.OtherPartnersList.Count()>0 AND NOT Form.TakeIntoAccountOtherPartners Then
					Form.TakeIntoAccountOtherPartners = True;
					Form.UpdateDialog();
				EndIf;	
				
			EndIf;
			
		ElsIf Common.IsDocumentTabularPartAttribute("Employee", Form.Metadata(), ChoiceValue.TabularPartName) Then
			TabularSectionRow.Employee = ChoiceValue.Employee;
			TabularSectionRow.PaymentMethod = ChoiceValue.PaymentMethod;
		EndIf;
		
		If Common.IsDocumentTabularPartAttribute("DocumentSettlementCurrency", Form.Metadata(), ChoiceValue.TabularPartName) Then
			TabularSectionRow.DocumentSettlementCurrency = ChoiceValue.Currency;
		EndIf;
		
		TabularSectionRow.ReservationDocument = ChoiceValue.ReservationDocument;
		TabularSectionRow.AmountDr = ChoiceValue.AmountDr;
		TabularSectionRow.AmountCr = ChoiceValue.AmountCr;
		TabularSectionRow.AmountDrNational = ChoiceValue.AmountDrNational;
		TabularSectionRow.AmountCrNational = ChoiceValue.AmountCrNational;
		TabularSectionRow.PrepaymentSettlement = TabularSectionRowPrepaymentSettlement
		
	EndIf;
	
	Form.Controls[ChoiceValue.TabularPartName].CurrentColumn = Form.Controls[ChoiceValue.TabularPartName].Columns.Document;
	Form.Controls[ChoiceValue.TabularPartName].CurrentRow    = TabularSectionRow;
	
	Return TabularSectionRow;
	
EndFunction // PickDocumentsRegularChoiceProcessing()

Function PickDocumentsAwaitedDocumentsChoiceProcessing(ChoiceValue, Form) Export
	
	If Not Common.IsDocumentTabularPart(ChoiceValue.TabularPartName, Form.Metadata()) Then
		Return Undefined;
	EndIf;
	
	TabularSection = Form[ChoiceValue.TabularPartName];
	
	SearchStructure = New Structure;
	SearchStructure.Insert("ReservationDocument", ChoiceValue.Document);
	
	TabularSectionRow = Common.FindTabularPartRow(TabularSection, SearchStructure);
	
	If TabularSectionRow = Undefined Then
		
		TabularSectionRow = TabularSection.Add();
		
		TabularSectionRow.ReservationDocument = ChoiceValue.Document;
		If Common.IsDocumentTabularPartAttribute("AmountCr",Form.Metadata(),ChoiceValue.TabularPartName) Then
			TabularSectionRow.AmountCr = ChoiceValue.AmountCr;
			TabularSectionRow.AmountCrNational = ChoiceValue.AmountCrNational;
		ElsIf Common.IsDocumentTabularPartAttribute("AmountDr",Form.Metadata(),ChoiceValue.TabularPartName) Then
			TabularSectionRow.AmountDr = ChoiceValue.AmountDr;
			TabularSectionRow.AmountDrNational = ChoiceValue.AmountDrNational;
		EndIf;
		
		
	EndIf;
	
	Form.Controls[ChoiceValue.TabularPartName].CurrentColumn = Form.Controls[ChoiceValue.TabularPartName].Columns.ReservationDocument;
	Form.Controls[ChoiceValue.TabularPartName].CurrentRow    = TabularSectionRow;
	
	Return TabularSectionRow;
	
EndFunction // PickDocumentsAwaitedDocumentsChoiceProcessing()

// Always taken on current date
Function GetCustomerCommonDue(Company, Customer, OnlyQueryText = False) Export
	
	Query = New Query();
	Query.Text = "SELECT
	             |	ISNULL(PartnersSettlementsBalance.AmountNationalBalance, 0) AS Due
	             |FROM
	             |	AccumulationRegister.PartnersSettlements.Balance(
	             |			,
	             |			Company = &Company
	             |				AND Partner = &Customer) AS PartnersSettlementsBalance
	             |;
	             |
	             |////////////////////////////////////////////////////////////////////////////////
	             |SELECT
	             |	SUM((ISNULL(SalesOrdersBalance.NetAmountBalance, 0) + ISNULL(SalesOrdersBalance.VATBalance, 0)) * ISNULL(SalesOrdersBalance.SalesOrder.ExchangeRate, 0)) AS OpenedSalesOrderAmount
	             |FROM
	             |	AccumulationRegister.SalesOrders.Balance(
	             |			,
	             |			Company = &Company
	             |				AND Customer = &Customer) AS SalesOrdersBalance";
	If OnlyQueryText Then
		Return Query.Text;
	Else			
		If ValueIsNotFilled(Company)
			OR ValueIsNotFilled(Customer) Then
			Return 0;
		EndIf;	
		Query.SetParameter("Company",Company);
		Query.SetParameter("Customer",Customer);
		QueryResultArray = Query.ExecuteBatch();
		CommonDue = 0;
		Selection = QueryResultArray[0].Select();
		If Selection.Next() Then
			CommonDue = CommonDue + ?(Selection.Due = Null,0,Selection.Due);
		EndIf;	
		
		Selection = QueryResultArray[1].Select();
		If Selection.Next() Then
			CommonDue = CommonDue + ?(Selection.OpenedSalesOrderAmount = Null,0,Selection.OpenedSalesOrderAmount);
		EndIf;	
		
		Return CommonDue;
	Endif;
	
EndFunction	

Function GetCustomerOverdueDue(Company, Customer, OnlyQueryText = False) Export
	
	Query = New Query();
	Query.Text = "SELECT
	             |	SUM(IsNull(PartnersSettlementsBalance.AmountNationalBalance,0)) AS AmountNationalBalance
	             |FROM
	             |	AccumulationRegister.PartnersSettlements.Balance(
	             |			,
	             |			Company = &Company
	             |				AND Partner = &Customer) AS PartnersSettlementsBalance
	             |WHERE
	             |	CASE
	             |			WHEN (NOT PartnersSettlementsBalance.Document.PaymentDate IS NULL )
	             |					AND PartnersSettlementsBalance.Document.PaymentDate <> DATETIME(1, 1, 1)
	             |				THEN DATEDIFF(BEGINOFPERIOD(&CurrentDate, DAY), BEGINOFPERIOD(PartnersSettlementsBalance.Document.PaymentDate, DAY), DAY) < 0
	             |			ELSE FALSE
	             |		END";
	If OnlyQueryText Then
		Return Query.Text;
	Else
		If ValueIsNotFilled(Company)
			OR ValueIsNotFilled(Customer) Then
			Return 0;
		EndIf;	
		
		Query.SetParameter("Company",Company);
		Query.SetParameter("Customer",Customer);
		Query.SetParameter("CurrentDate",GetServerDate());
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Return ?(Selection.AmountNationalBalance = Null,0,Selection.AmountNationalBalance);
		Else	
			Return 0;
		EndIf;	
	EndIf;
	
EndFunction

Function GetFullPartnersList(Val OtherPartnersList, Partner,PrepaymentSettlement = Undefined) Export
	
	If TypeOf(OtherPartnersList) = Type("FormDataCollection") Then
		OtherPartnersList_temp = New ValueList;
		For Each OtherPartnersListRow In OtherPartnersList Do
			OtherPartnersList_temp.Add(OtherPartnersListRow.Partner); 
		EndDo;
		OtherPartnersList = OtherPartnersList_temp;
	EndIf;
	
	CustomerSynonym = Nstr("en='Customer';pl='Nabywca';ru='Покупатель'");
	SupplierSynonym = Nstr("en='Supplier';pl='Dostawca';ru='Поставщик'");
	
	If PrepaymentSettlement = Enums.PrepaymentSettlement.Prepayment Then
		
		ValueList = New ValueList;
		ValueList.Add(Partner,String(Partner) + " (" + ?(TypeOf(Partner) = Type("CatalogRef.Customers"),CustomerSynonym,SupplierSynonym) + ")");
		Return ValueList;
		
	Else
		ValueList = OtherPartnersList.Copy();
		ValueList.Insert(0, Partner,String(Partner) + " (" + ?(TypeOf(Partner) = Type("CatalogRef.Customers"),CustomerSynonym,SupplierSynonym) + ")");
		Return ValueList;
	EndIf;	
	
EndFunction

Function GetOtherPartnersList(SettlementDocuments, Partner) Export
	
	CustomerSynonym = Nstr("en='Customer';pl='Nabywca';ru='Покупатель'");
	SupplierSynonym = Nstr("en='Supplier';pl='Dostawca';ru='Поставщик'");
	
	OtherPartnersList = New ValueList;
	
	For Each SettlementDocumentsRow In SettlementDocuments Do
		If SettlementDocumentsRow.Partner <> Partner And OtherPartnersList.FindByValue(SettlementDocumentsRow.Partner) = Undefined Then
			OtherPartnersList.Add(SettlementDocumentsRow.Partner, String(SettlementDocumentsRow.Partner) + " (" + ?(TypeOf(SettlementDocumentsRow.Partner) = Type("CatalogRef.Customers"),CustomerSynonym,SupplierSynonym) + ")");
		EndIf;
	EndDo;
	
	If ValueIsFilled(Partner) Then
		If TypeOf(Partner) = Type("CatalogRef.Customers") AND ValueIsFilled(Partner.Supplier) Then
			
			If OtherPartnersList.FindByValue(Partner.Supplier) = Undefined Then
				OtherPartnersList.Add(Partner.Supplier, String(Partner.Supplier) + " (" + SupplierSynonym + ")");
			EndIf;	
			
		ElsIf TypeOf(Partner) = Type("CatalogRef.Suppliers") Then
			
			Query = New Query();
			Query.Text = "SELECT ALLOWED DISTINCT
			|	Customers.Ref AS Customer,
			|	Customers.Presentation
			|FROM
			|	Catalog.Customers AS Customers
			|WHERE
			|	Customers.Supplier = &Supplier";
			Query.SetParameter("Supplier",Partner);
			Selection = Query.Execute().Select();
			
			While Selection.Next() Do
				
				If OtherPartnersList.FindByValue(Selection.Customer) = Undefined Then
					OtherPartnersList.Add(Selection.Customer,Selection.Presentation + " (" +CustomerSynonym+ ")");
				EndIf;	
				
			EndDo;	
			
		EndIf;	
	EndIf;
	
	Return OtherPartnersList;
	
EndFunction // GetOtherPartnersList()

Procedure UpdateOtherPartnersList(Object,TabularPartName="SettlementDocuments",PartnerAttributeName = "Partner",Partner,OtherPartnersList,TakeIntoAccountOtherPartners) Export
	
	CustomerSynonym = Nstr("en='Customer';pl='Nabywca';ru='Покупатель'");
	SupplierSynonym = Nstr("en='Supplier';pl='Dostawca';ru='Поставщик'");
	
	ObjectMetadata = Object.Metadata();
	If Common.IsDocumentTabularPart(TabularPartName,ObjectMetadata) 
		AND Common.IsDocumentTabularPartAttribute(PartnerAttributeName,ObjectMetadata,TabularPartName) Then
		
		If Common.IsDocumentTabularPartAttribute("PrepaymentSettlement",ObjectMetadata,TabularPartName) Then
			
			TabularPart = Object[TabularPartName];
			PrepaymentRows = New Array();
			For Each TabularPartRow In TabularPart Do
				
				If TabularPartRow[PartnerAttributeName] <> Partner Then
					
					If OtherPartnersList.FindByValue(TabularPartRow[PartnerAttributeName]) = Undefined Then
						OtherPartnersList.Add(TabularPartRow[PartnerAttributeName]);
					EndIf;	
					
				EndIf;	
				
			EndDo;	
			
			If ValueIsFilled(Partner) Then
				If TypeOf(Partner) = Type("CatalogRef.Customers") AND ValueIsFilled(Partner.Supplier) Then
					
					If OtherPartnersList.FindByValue(Partner.Supplier) = Undefined Then
						OtherPartnersList.Add(Partner.Supplier, String(Partner.Supplier) + " (" + SupplierSynonym + ")");
					EndIf;	
					
				ElsIf TypeOf(Partner) = Type("CatalogRef.Suppliers") Then
					
					Query = New Query();
					Query.Text = "SELECT ALLOWED DISTINCT
					|	Customers.Ref AS Customer,
					|	Customers.Presentation
					|FROM
					|	Catalog.Customers AS Customers
					|WHERE
					|	Customers.Supplier = &Supplier";
					Query.SetParameter("Supplier",Partner);
					Selection = Query.Execute().Select();
					
					While Selection.Next() Do
						
						If OtherPartnersList.FindByValue(Selection.Customer) = Undefined Then
							OtherPartnersList.Add(Selection.Customer,Selection.Presentation + " (" +CustomerSynonym+ ")");
						EndIf;	
						
					EndDo;	
					
				EndIf;	
			EndIf;
			
			If NOT TakeIntoAccountOtherPartners 
				AND OtherPartnersList.Count()>0 Then
				TakeIntoAccountOtherPartners = True;
			EndIf;	
			
		Else
			Return;
		EndIf;	
		
	EndIf;	
	
EndProcedure	

Procedure UpdateSettlemenExchangeRate(Object,SettlementExchangeRate, TabularPartName="SettlementDocuments",ExchangeRateAttributeName = "ExchangeRate",PrepaymentSettlementAttributeName = "PrepaymentSettlement") Export
	
	ObjectMetadata = Object.Metadata();
	If Common.IsDocumentTabularPart(TabularPartName,ObjectMetadata) 
		AND Common.IsDocumentTabularPartAttribute(ExchangeRateAttributeName,ObjectMetadata,TabularPartName)
		AND Common.IsDocumentTabularPartAttribute(PrepaymentSettlementAttributeName,ObjectMetadata,TabularPartName) Then
		
		TabularPart = Object[TabularPartName];
		
		For Each TabularPartRow In TabularPart Do
			
			If TabularPartRow[PrepaymentSettlementAttributeName] = Enums.PrepaymentSettlement.Prepayment 
				AND TabularPartRow[ExchangeRateAttributeName] <> SettlementExchangeRate Then
				TabularPartRow[ExchangeRateAttributeName] = SettlementExchangeRate;
			EndIf;	
			
		EndDo;	
		
	EndIf;	
	
EndProcedure

Procedure UpdateOtherEmployeesList(Object,TabularPartName="SettlementDocuments",EmployeeAttributeName = "Employee",Employee,OtherEmployeesList,TakeIntoAccountOtherEmployees) Export
	
	ObjectMetadata = Object.Metadata();
	If Common.IsDocumentTabularPart(TabularPartName,ObjectMetadata) 
		AND Common.IsDocumentTabularPartAttribute(EmployeeAttributeName,ObjectMetadata,TabularPartName) Then
		
		If Common.IsDocumentTabularPartAttribute("PrepaymentSettlement",ObjectMetadata,TabularPartName) Then
			
			TabularPart = Object[TabularPartName];
			PrepaymentRows = New Array();
			For Each TabularPartRow In TabularPart Do
				
				If TabularPartRow[EmployeeAttributeName] <> Employee Then
					
					If OtherEmployeesList.FindByValue(TabularPartRow[EmployeeAttributeName]) = Undefined Then
						OtherEmployeesList.Add(TabularPartRow[EmployeeAttributeName]);
					EndIf;	
				
				EndIf;	
				
			EndDo;	
						
			If NOT TakeIntoAccountOtherEmployees 
				AND OtherEmployeesList.Count()>0 Then
				TakeIntoAccountOtherEmployees = True;
			EndIf;	
			
		Else
			Return;
		EndIf;	
		
	EndIf;	
	
EndProcedure

#If Client Then

Function GetExchangeRatesListForPartners(Company,Document,Partner,Currency,ReservationDocument = Undefined,Date = Undefined) Export
	
	Query = New Query();
	Query.Text = "SELECT DISTINCT
	             |	PartnersSettlementsBalance.ExchangeRate AS ExchangeRate
	             |FROM
	             |	AccumulationRegister.PartnersSettlements.Balance(
	             |			" + ?(Date = Undefined, "", "&Date") + ",
	             |			Company = &Company
	             |				AND Currency = &Currency
	             |				AND Document = &Document
	             |				AND Partner = &Partner
	             |				AND ReservationDocument = &ReservationDocument) AS PartnersSettlementsBalance";
					 
	Query.SetParameter("Date",Date);
	Query.SetParameter("Company",Company);
	Query.SetParameter("Document",Document);
	Query.SetParameter("Currency",Currency);
	Query.SetParameter("Partner",Partner);
	Query.SetParameter("ReservationDocument",ReservationDocument);
	ExchangeRateArray = Query.Execute().Unload().UnloadColumn("ExchangeRate");
	ValueList = New ValueList;
	ValueList.LoadValues(ExchangeRateArray);
	Return ValueList;
		
EndFunction	


Function GetOtherEmployeesList(SettlementDocuments, Employee = Undefined) Export
	
	OtherEmployeesList = New ValueList;
	
	For Each SettlementDocumentsRow In SettlementDocuments Do
		If SettlementDocumentsRow.Employee <> Undefined 
			AND SettlementDocumentsRow.Employee <> Employee 
			And OtherEmployeesList.FindByValue(SettlementDocumentsRow.Employee) = Undefined Then
			OtherEmployeesList.Add(SettlementDocumentsRow.Employee);
		EndIf;
	EndDo;
	
	Return OtherEmployeesList;
	
EndFunction // GetOtherEmployeesList()


Function GetFullEmployeesList(OtherEmployeesList, Employee = Undefined, PrepaymentSettlement = Undefined) Export
	
	If PrepaymentSettlement = Enums.PrepaymentSettlement.Prepayment Then
		
		ValueList = New ValueList;
		ValueList.Add(Employee);
		Return ValueList;
		
	Else
		
		ValueList = OtherEmployeesList.Copy();
		If Employee <> Undefined Then
			ValueList.Insert(0, Employee);
		EndIf;
		
		Return ValueList;
	EndIf;	
	
EndFunction

Function GetPrepaymentSettlementList() Export
		
	ValueList = New ValueList();
	ValueList.Add(Enums.PrepaymentSettlement.Settlement);
	ValueList.Add(Enums.PrepaymentSettlement.PrepaymentSettlement);
	
	Return ValueList;
	
EndFunction	

Function DeleteDocumentsRowsWithSuperfluousPartners(SettlementDocuments, FullPartnersList) Export
	
	RowsToDeleteArray = New Array;
	
	SettlementDocumentsCount = SettlementDocuments.Count();
	For x = 1 To SettlementDocumentsCount Do
		
		SettlementDocumentsRow = SettlementDocuments[SettlementDocumentsCount - x];
		If ValueIsFilled(SettlementDocumentsRow.Partner)
			And FullPartnersList.FindByValue(SettlementDocumentsRow.Partner) = Undefined Then
			RowsToDeleteArray.Add(SettlementDocumentsRow);
			//SettlementDocuments.Delete(SettlementDocumentsRow);
		EndIf;
		
	EndDo;
	
	If RowsToDeleteArray.Count() > 0 Then
		
		PartnersToDeleteList = New ValueList;
		PartnersToDeleteListStr = "";
		For Each RowToDelete In RowsToDeleteArray Do
			If PartnersToDeleteList.FindByValue(RowToDelete.Partner) = Undefined Then
				PartnersToDeleteList.Add(RowToDelete.Partner);
				PartnersToDeleteListStr = PartnersToDeleteListStr + Chars.LF + "- " + RowToDelete.Partner;
			EndIf;
		EndDo;
		
		QueryText = NStr("en = 'The rows with the partners below would be deleted from the document:%PartnersList
		                 |Do you want to continue?'; pl = 'Wierszy zawierające kontahentów z listy poniżej zostaną wykasowane:%PartnersList
		                 |Czy chcesz wykonać zmiany?'");
		
		QueryText = StrReplace(QueryText, "%PartnersList", PartnersToDeleteListStr);
		Answer = DoQueryBox(QueryText, QuestionDialogMode.YesNo);
		
		If Answer = DialogReturnCode.Yes Then
			
			For Each RowToDelete In RowsToDeleteArray Do
				SettlementDocuments.Delete(RowToDelete);
			EndDo;
			
			Return True;
			
		Else
			Return False;
		EndIf;
		
	Else
		Return True;
	EndIf;
	
EndFunction // ClearDocumentsRowsWithSuperfluousPartners()

Function DeleteDocumentsRowsWithSuperfluousEmployees(SettlementDocuments, FullEmployeesList) Export
	
	RowsToDeleteArray = New Array;
	
	SettlementDocumentsCount = SettlementDocuments.Count();
	For x = 1 To SettlementDocumentsCount Do
		
		SettlementDocumentsRow = SettlementDocuments[SettlementDocumentsCount - x];
		If ValueIsFilled(SettlementDocumentsRow.Employee)
			And FullEmployeesList.FindByValue(SettlementDocumentsRow.Employee) = Undefined Then
			RowsToDeleteArray.Add(SettlementDocumentsRow);
			//SettlementDocuments.Delete(SettlementDocumentsRow);
		EndIf;
		
	EndDo;
	
	If RowsToDeleteArray.Count() > 0 Then
		
		EmployeesToDeleteList = New ValueList;
		EmployeesToDeleteListStr = "";
		For Each RowToDelete In RowsToDeleteArray Do
			If EmployeesToDeleteList.FindByValue(RowToDelete.Employee) = Undefined Then
				EmployeesToDeleteList.Add(RowToDelete.Employee);
				EmployeesToDeleteListStr = EmployeesToDeleteListStr + Chars.LF + "- " + RowToDelete.Employee;
			EndIf;
		EndDo;
		
		QueryText = NStr("en='The rows with the employee below would be deleted from the document:%EmployeesList"
"Do you want to continue?';pl='Wierszy zawierające pracowników z listy poniżej zostaną wykasowane:%EmployeesList"
"Czy chcesz wykonać zmiany?';ru='Строки, с указанными ниже сотрудниками, будут удалены:%EmployeesList"
"Хотите провести изменения?'");
		
		QueryText = StrReplace(QueryText, "%EmployeesList", EmployeesToDeleteListStr);
		Answer = DoQueryBox(QueryText, QuestionDialogMode.YesNo);
		
		If Answer = DialogReturnCode.Yes Then
			
			For Each RowToDelete In RowsToDeleteArray Do
				SettlementDocuments.Delete(RowToDelete);
			EndDo;
			
			Return True;
			
		Else
			Return False;
		EndIf;
		
	Else
		Return True;
	EndIf;
	
EndFunction // ClearDocumentsRowsWithSuperfluousEmployees()

Function ChoosePartner(TakeIntoAccountOtherPartners, OtherPartnersList, Partner) Export
	
	If TakeIntoAccountOtherPartners Then
		
		ValueList = GetFullPartnersList(OtherPartnersList, Partner);
		ValueListItem = ValueList.ChooseItem();
		If ValueListItem = Undefined Then
			Return Undefined;
		Else
			Return ValueListItem.Value;
		EndIf;
		
	Else
		Return Partner;
	EndIf;
	
EndFunction // ChoosePartner()

Function ChooseEmployee(TakeIntoAccountOtherEmployees, OtherEmployeesList, Employee) Export
	
	If TakeIntoAccountOtherEmployees Then
		
		ValueList = GetFullEmployeesList(OtherEmployeesList, Employee);
		ValueListItem = ValueList.ChooseItem();
		If ValueListItem = Undefined Then
			Return Undefined;
		Else
			Return ValueListItem.Value;
		EndIf;
		
	Else
		Return Employee;
	EndIf;
	
EndFunction // ChooseEmployee()

Procedure UpdateRowsAfterLoadingFromSpreadsheet(NewRowsArray, ChoiceValue, Date, Currency,Object = Undefined, Form = Undefined) Export
	
	//TabularPartValueTable = ChoiceValue.TabularPartValueTable;
	//NotFoundValueTable = ChoiceValue.NotFoundTabularPartValueTable;
	//MultiplyTabularPartValueTable = ChoiceValue.MultiplyTabularPartValueTable;

	//AdditionalProperties = ChoiceValue.AdditionalProperties;
	//If AdditionalProperties = Undefined Then
	//	CurrentPartner = Undefined;
	//ElsIf TypeOf(AdditionalProperties) = Type("Structure") Then	
	//	If NOT AdditionalProperties.Property("Partner",CurrentPartner) Then
	//		CurrentPartner = Undefined;
	//	EndIf;	
	//EndIf;	
	//
	//If CurrentPartner = Undefined Then
	//	Return;
	//EndIf;	
	//
	//ItemsToCreateValueTable = New ValueTable();
	//ItemsToCreateValueTable.Columns.Add("RowRef");
	//ItemsToCreateValueTable.Columns.Add("Number");
	//
	//NationalCurrency = Constants.NationalCurrency.Get();
	//
	//i = 0;
	//For Each NewRow In NewRowsArray Do
	//	
	//	NewRow.Partner = CurrentPartner;
	//	
	//	If MultiplyTabularPartValueTable = Undefined OR MultiplyTabularPartValueTable.Count()<i+1 Then
	//		MultiplyTabularPartValueTableRow = Undefined;
	//	Else	
	//		MultiplyTabularPartValueTableRow = MultiplyTabularPartValueTable[i];
	//	EndIf;	
	//	
	//	If NotFoundValueTable = Undefined OR NotFoundValueTable.Count()<i+1 Then
	//		NotFoundValueTableRow = Undefined;
	//	Else
	//		NotFoundValueTableRow = NotFoundValueTable[i];
	//	EndIf;	
	//		
	//	If ValueIsFilled(NewRow.Document) 
	//		AND NewRow.Partner <> APAR.GetDocumentsPartner(NewRow.Document) Then
	//				
	//			If Upper(NotFoundValueTableRow.DocumentListValueAsString[0].Value) = Upper("Number") Then
	//				NotFoundValueTableRow.Document = NewRow.Document.Number;
	//			ElsIf Upper(NotFoundValueTableRow.DocumentListValueAsString[0].Value) = Upper("InitialDocumentNumber") Then	
	//				NotFoundValueTableRow.Document = NewRow.Document.InitialDocumentNumber;
	//			EndIf;
	//			NewRow.Document = Undefined;
	//	EndIf;		
	//				
	//	TabularPartValueTableRow = TabularPartValueTable[i];
	//	If TypeOf(NewRow.Partner) = TypeOf(Catalogs.Customers.EmptyRef()) Then
	//		If TabularPartValueTableRow.Amount > 0 Then
	//			NewRow.AmountCr = Abs(TabularPartValueTableRow.Amount);
	//			APAR.AmountOnChange(NewRow, "AmountCr");
	//		Else
	//			NewRow.AmountDr = Abs(TabularPartValueTableRow.Amount);
	//			APAR.AmountOnChange(NewRow, "AmountDr");
	//		EndIf;
	//	ElsIf TypeOf(NewRow.Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()) Then
	//		If TabularPartValueTableRow.Amount > 0 Then
	//			NewRow.AmountDr = Abs(TabularPartValueTableRow.Amount);
	//			APAR.AmountOnChange(NewRow, "AmountDr");
	//		Else
	//			NewRow.AmountCr = Abs(TabularPartValueTableRow.Amount);
	//			APAR.AmountOnChange(NewRow, "AmountCr");
	//		EndIf;
	//	EndIf;
	//			
	//	If MultiplyTabularPartValueTableRow <> Undefined  Then
	//			
	//		FiltredDocs = New Array();
	//		
	//		For Each FoundDoc In MultiplyTabularPartValueTableRow.Document Do
	//			
	//			If APAR.GetDocumentsPartner(FoundDoc) = NewRow.Partner Then
	//				
	//				FiltredDocs.Add(FoundDoc);
	//				
	//			EndIf;	
	//			
	//		EndDo;	
	//		
	//		If FiltredDocs.Count()>1 Then
	//			
	//			Str = Nstr("en = 'Loading from spreadsheet, %P1 column - multiply value found for row %P2'; pl = 'Ładowanie z arkusza, kolumna %P1 - wiele wartości znaleziono dla wiersza %P2'");
	//			Str = StrReplace(Str,"%P1",Nstr("en='Document';pl='Dokument';ru='Документ'"));
	//			Str = StrReplace(Str,"%P2",NewRow.LineNumber);
	//			Common.ErrorMessage(Str);
	//			WasMultipleValue = True;
	//			
	//		ElsIf FiltredDocs.Count()=1 Then	
	//			
	//			NewRow.Document = FiltredDocs[0];
	//			
	//		ElsIf FiltredDocs.Count()=0 
	//			AND MultiplyTabularPartValueTableRow.Document.Count()>0 Then
	//			
	//			If Upper(MultiplyTabularPartValueTableRow.DocumentListValueAsString[0].Value) = Upper("Number") Then
	//				NotFoundValueTableRow.Document = MultiplyTabularPartValueTableRow.Document[0].Number;
	//			ElsIf Upper(MultiplyTabularPartValueTableRow.DocumentListValueAsString[0].Value) = Upper("InitialDocumentNumber") Then	
	//				NotFoundValueTableRow.Document = MultiplyTabularPartValueTableRow.Document[0].InitialDocumentNumber;
	//			EndIf;
	//			
	//		EndIf;	
	//		
	//	EndIf;	
	//	
	//	If ValueIsFilled(NotFoundValueTableRow.Document) Then
	//		
	//		If TypeOf(NewRow.Partner) = TypeOf(Catalogs.Customers.EmptyRef()) Then
	//			ResCustomer = Catalogs.CustomerInternalDocuments.FindByAttribute("InitialDocumentNumber",TrimAll(NotFoundValueTableRow.Document),,NewRow.Partner);
	//			ResSupplier = Catalogs.SupplierInternalDocuments.EmptyRef();
	//		ElsIf TypeOf(NewRow.Partner) = TypeOf(Catalogs.Suppliers.EmptyRef()) Then
	//			ResCustomer = Catalogs.CustomerInternalDocuments.EmptyRef();
	//			ResSupplier = Catalogs.SupplierInternalDocuments.FindByAttribute("InitialDocumentNumber",TrimAll(NotFoundValueTableRow.Document),,NewRow.Partner);
	//		EndIf;
	//		
	//		If NOT ResCustomer.IsEmpty() AND  NOT ResSupplier.IsEmpty() Then
	//			Common.ErrorMessage(NStr("en='There are more than one document found with such codes: ';pl='Znaleziono więcej niż jeden dokument z takimi kodami: '") + NotFoundValueTableRow.Document);
	//		ElsIf ResCustomer.IsEmpty() AND  ResSupplier.IsEmpty() Then
	//			ItemsToCreateValueTableRow = ItemsToCreateValueTable.Add();
	//			ItemsToCreateValueTableRow.RowRef = NewRow;
	//			ItemsToCreateValueTableRow.Number = TrimAll(NotFoundValueTableRow.Document);
	//		ElsIf NOT ResCustomer.IsEmpty()	 Then
	//			NewRow.Document = ResCustomer;
	//		ElsIf NOT ResSupplier.IsEmpty()	 Then
	//			NewRow.Document = ResSupplier;
	//		EndIf;
	//		
	//			
	//	EndIf;
	//	
	//	If ValueIsNotFilled(NewRow.Account) Then
	//		NewRow.Account = APAR.GetDocumentAccount(NewRow.Partner, NewRow.Document);
	//	EndIf;
	//	
	//	i = i+1;
	//	
	//EndDo;
		
EndProcedure

#EndIf
