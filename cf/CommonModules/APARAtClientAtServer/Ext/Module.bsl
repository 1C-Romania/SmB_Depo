//Function GetDocumentsRowsWithSuperfluousPartners(Val SettlementDocuments, Val FullPartnersList) Export
//	
//	RowsWithSuperfluousPartnersArray = New Array;
//	For Each SettlementDocumentsRow In SettlementDocuments Do
//		
//		If ValueIsFilled(SettlementDocumentsRow.Partner)
//			And FullPartnersList.FindByValue(SettlementDocumentsRow.Partner) = Undefined Then
//			RowsWithSuperfluousPartnersArray.Add(SettlementDocumentsRow.GetId());
//		EndIf;
//		
//	EndDo;
//	
//	Return RowsWithSuperfluousPartnersArray;
//	
//EndFunction // GetDocumentsRowsWithSuperfluousPartners()

//Function GetPartnersDocumentTypes(Val Partner,Val PrepaymentSettlement = Undefined,Val ExcludeInternalDocuments = False) Export
//	
//	TypesArray = New Array;
//	
//	If PrepaymentSettlement = Undefined OR 
//		PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.Settlement") Then
//		If TypeOf(Partner) = Type("CatalogRef.Customers") Then
//			If NOT ExcludeInternalDocuments Then
//				TypesArray.Add(Type("CatalogRef.CustomerInternalDocuments"));
//			EndIf;	
//			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.SalesPrepaymentInvoice"));
//			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.SalesInvoice"));
//			TypesArray.Add(Type("DocumentRef.BookkeepingNote"));
//			TypesArray.Add(Type("DocumentRef.InterestNote"));
//			TypesArray.Add(Type("DocumentRef.SalesCreditNoteReturn"));
//			TypesArray.Add(Type("DocumentRef.SalesCreditNotePriceCorrection"));
//			TypesArray.Add(Type("DocumentRef.SalesRetail"));
//			TypesArray.Add(Type("DocumentRef.SalesRetailReturn"));
//		ElsIf TypeOf(Partner) = Type("CatalogRef.Suppliers") Then
//			If NOT ExcludeInternalDocuments Then
//				TypesArray.Add(Type("CatalogRef.SupplierInternalDocuments"));
//			EndIf;	
//			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.PurchaseInvoice"));
//			TypesArray.Add(Type("DocumentRef.PurchaseCreditNoteReturn"));
//			TypesArray.Add(Type("DocumentRef.PurchaseCreditNotePriceCorrection"));
//		Else
//			TypesArray.Add(Type("Undefined"));
//		EndIf;
//	ElsIf PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.Prepayment") 
//		OR PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.PrepaymentSettlement") Then
//		If TypeOf(Partner) = Type("CatalogRef.Customers") Then
//			If NOT ExcludeInternalDocuments Then
//				TypesArray.Add(Type("CatalogRef.CustomerInternalDocuments"));
//			EndIf;	
//			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.SalesOrder"));
//			TypesArray.Add(Type("DocumentRef.SalesPrepaymentInvoice"));
//			TypesArray.Add(Type("DocumentRef.SalesPrepaymentCreditNote"));
//		ElsIf TypeOf(Partner) = Type("CatalogRef.Suppliers") Then
//			If NOT ExcludeInternalDocuments Then
//				TypesArray.Add(Type("CatalogRef.SupplierInternalDocuments"));
//			EndIf;	
//			TypesArray.Add(Type("DocumentRef.BankIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.CashIncomingFromPartner"));
//			TypesArray.Add(Type("DocumentRef.BankOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.CashOutgoingToPartner"));
//			TypesArray.Add(Type("DocumentRef.PurchaseOrder"));
//			TypesArray.Add(Type("DocumentRef.PurchasePrepaymentInvoice"));
//			TypesArray.Add(Type("DocumentRef.PurchasePrepaymentCreditNote"));
//		Else
//			TypesArray.Add(Type("Undefined"));
//		EndIf;	
//	Else
//		TypesArray.Add(Type("Undefined"));
//	EndIf;	
//	
//	Return New TypeDescription(TypesArray);
//	
//EndFunction // GetPartnersDocumentTypes()

//Function GetFullPartnersList(Val OtherPartnersList, Val Partner,Val PrepaymentSettlement = Undefined) Export
//	
//	CustomerSynonym = Nstr("en='Customer';pl='Nabywca';ru='Покупатель'");
//	SupplierSynonym = Nstr("en='Supplier';pl='Dostawca';ru='Поставщик'");
//	
//	If PrepaymentSettlement = PredefinedValue("Enum.PrepaymentSettlement.Prepayment") Then
//		
//		ValueList = New ValueList;
//		ValueList.Add(Partner,String(Partner) + " (" + ?(TypeOf(Partner) = Type("CatalogRef.Customers"),CustomerSynonym,SupplierSynonym) + ")");
//		Return ValueList;
//		
//	Else
//		ValueList = OtherPartnersList.Copy();
//		ValueList.Insert(0, Partner,String(Partner) + " (" + ?(TypeOf(Partner) = Type("CatalogRef.Customers"),CustomerSynonym,SupplierSynonym) + ")");
//		Return ValueList;
//	EndIf;	
//	
//EndFunction

//// CR = -
//// DR = + 
//// Transformated for posting
//Function TransformateAmountFromCrDr(Val AmountCr, Val AmountCrNational = 0,Val AmountDr, Val AmountDrNational = 0) Export
//	
//	Amount = 0;
//	AmountNational = 0;
//	If AmountCr <>0 AND AmountDr = 0 Then
//		Amount = -AmountCr;
//		AmountNational = -AmountCrNational;
//	ElsIf AmountDr <>0 AND AmountCr = 0 Then
//		Amount = AmountDr;
//		AmountNational = AmountDrNational;
//	ElsIf AmountDr = 0 AND 	AmountCr = 0 Then
//		
//		If AmountCrNational <>0 AND AmountDrNational = 0 Then
//			
//			AmountNational = -AmountCrNational;
//			
//		ElsIf AmountDrNational <>0 AND AmountCrNational = 0 Then
//			
//			AmountNational = AmountDrNational;
//			
//		EndIf;
//		
//	EndIf;	
//		
//	Return New Structure("Amount, AmountNational",Amount,AmountNational)
//	
//EndFunction

//// - = DR
//// + = CR
//// Transformed for tabular part and futher posting
//Function TransformateAmountToCrDr(Val Amount,Val AmountNational) Export
//	
//	AmountCr = 0;
//	AmountDr = 0;
//	AmountCrNational = 0;
//	AmountDrNational = 0;
//	If Amount >0 Then
//		AmountCr = abs(Amount);
//		AmountCrNational = abs(AmountNational);
//	Elsif Amount <0 Then
//		AmountDr = abs(Amount);
//		AmountDrNational = abs(AmountNational);
//	ElsIf Amount = 0 AND AmountNational<>0 Then
//		
//		If AmountNational >0 Then
//			AmountCrNational = abs(AmountNational);
//		ElsIf AmountNational <0 Then
//			AmountDrNational = abs(AmountNational);
//		EndIf;
//		
//	EndIf;	
//	
//	Return New Structure("AmountDr, AmountCr, AmountDrNational, AmountCrNational", AmountDr, AmountCr, AmountDrNational, AmountCrNational);
//	
//EndFunction	

//Function GetDocumentsRowsWithSuperfluousEmployees(SettlementDocuments, FullEmployeesList) Export
//	
//	RowsToDeleteArray = New Array;
//	
//	SettlementDocumentsCount = SettlementDocuments.Count();
//	For x = 1 To SettlementDocumentsCount Do
//		
//		SettlementDocumentsRow = SettlementDocuments[SettlementDocumentsCount - x];
//		If ValueIsFilled(SettlementDocumentsRow.Employee)
//			And FullEmployeesList.Find(SettlementDocumentsRow.Employee) = Undefined Then
//			RowsToDeleteArray.Add(SettlementDocumentsRow);
//		EndIf;
//		
//	EndDo;
//	Return RowsToDeleteArray; 

//EndFunction

//Function GetEmployeesToDeleteListStr(RowsToDeleteArray) Export
//	
//	EmployeesToDeleteList = New ValueList;
//	EmployeesToDeleteListStr = "";
//	For Each RowToDelete In RowsToDeleteArray Do
//		If EmployeesToDeleteList.FindByValue(RowToDelete.Employee) = Undefined Then
//			EmployeesToDeleteList.Add(RowToDelete.Employee);
//			EmployeesToDeleteListStr = EmployeesToDeleteListStr + Chars.LF + "- " + RowToDelete.Employee;
//		EndIf;
//	EndDo;

//	Return EmployeesToDeleteListStr; 

//EndFunction
