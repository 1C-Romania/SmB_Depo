//Function GetDocumentAmountsStructureForPartner(Val Partner, Val Document, Val ReservationDocument = Undefined, Val Currency, Val Date = Undefined, Val Company) Export	
//	
//	Structure = New Structure("AmountDr, AmountCr, AmountDrNational, AmountCrNational", 0, 0, 0, 0);
//	
//	If ValueIsNotFilled(Document) Then
//		Return Structure;
//	EndIf;
//	
//	Query = New Query();
//	Query.Text = "SELECT
//	             |	PartnersSettlementsBalance.Partner,
//	             |	PartnersSettlementsBalance.Document AS Document,
//	             |	PartnersSettlementsBalance.AmountBalance AS GrossAmount,
//	             |	PartnersSettlementsBalance.AmountNationalBalance AS GrossAmountNational
//	             |FROM
//	             |	AccumulationRegister.PartnersSettlements.Balance(
//	             |			" + ?(Date = Undefined, "", "&Date") + ",
//	             |				Document = &Document
//	             |				AND Partner = &Partner
//	             |				AND Company = &Company
//	             |				AND ReservationDocument = &ReservationDocument) AS PartnersSettlementsBalance
//	             |
//	             |ORDER BY
//	             |	PartnersSettlementsBalance.Document.Date";
//	
//	Query.SetParameter("Date",Date);
//	Query.SetParameter("Partner",Partner);
//	Query.SetParameter("Document",Document);
//	Query.SetParameter("ReservationDocument",ReservationDocument);
//	Query.SetParameter("Company",Company);
//	Query.SetParameter("Currency",Currency);
//	
//	Selection = Query.Execute().Select();
//	If Selection.Next() Then
//		Return APARAtClientAtServer.TransformateAmountToCrDr(Selection.GrossAmount, Selection.GrossAmountNational);
//	Else
//		Return Structure;
//	EndIf;
//	
//EndFunction // GetDocumentAmountsStructureForPartner()

//Function PartnersDocumentStartChoiceAtServer(Val Document, Val Partner, Val Currency) Export
//	
//	If TypeOf(Document) = Type("Type") Then
//		DocumentType = Document;
//		CurrentRow = Undefined;
//	Else
//		DocumentType = TypeOf(Document);
//		CurrentRow = Document;
//	EndIf;
//	
//	ObjectMetdata = ObjectsExtensionsAtServer.GetMetadataByType(DocumentType);
//	MetadataName = ObjectMetdata.Name; 
//	MetadataClassName = ObjectsExtensionsAtServer.GetMetadataClassName(DocumentType);
//	ParametersStructure = Undefined;
//	
//	If MetadataClassName = ObjectsExtensionsAtClientAtServerCached.GetCatalogMetadataClassName()  Then // first check catalogs
//		FilterStructure = New Structure("Owner",Partner);
//		If ValueIsFilled(Currency) Then
//			FilterStructure.Insert("Currency",Currency);
//		EndIf;
//	ElsIf MetadataClassName = ObjectsExtensionsAtClientAtServerCached.GetDocumentMetadataClassName() Then
//		
//		FilterStructure = New Structure;
//		For Each FilterCriteriaItem In Metadata.FilterCriteria.PartnersDocuments.Content Do
//			If FilterCriteriaItem.Parent() = ObjectMetdata Then
//				FilterStructure.Insert(FilterCriteriaItem.Name,Partner);
//				Break;
//			EndIf;	
//		EndDo;	

//		If ValueIsFilled(Currency) Then
//			If ObjectsExtensionsAtServer.IsDocumentAttribute("Currency", ObjectMetdata) Then
//				FilterStructure.Insert("Currency",Currency);
//			ElsIf ObjectsExtensionsAtServer.IsDocumentAttribute("SettlementCurrency", ObjectMetdata) Then
//				FilterStructure.Insert("SettlementCurrency",Currency);
//			EndIf;
//		EndIf;	
//	Else
//		Return Undefined;	
//	EndIf;

//	ParametersStructure = New Structure("Filter, ChoiceMode, CurrentRow",FilterStructure,True,CurrentRow);
//	Return New Structure("FormName, ParametersStructure",MetadataClassName+"."+MetadataName+".ChoiceForm",ParametersStructure);
//	
//EndFunction

//Procedure CheckDocumentOnPartnerChange(Val Partner, Document) Export
//	
//	If Document = Undefined Then
//		Return;
//	EndIf;
//	
//	DocumentPartner = Undefined;
//	
//	If Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
//		
//		DocumentPartner = Document.Owner;
//		
//	Else
//		
//		If Document.Metadata().Attributes.Find("Customer") <> Undefined Then
//			DocumentPartner = Document.Customer;
//		ElsIf Document.Metadata().Attributes.Find("Supplier") <> Undefined Then
//			DocumentPartner = Document.Supplier;
//		ElsIf Document.Metadata().Attributes.Find("Partner") <> Undefined Then
//			DocumentPartner = Document.Partner;
//		EndIf;
//		
//	EndIf;
//	
//	If Partner <> DocumentPartner Then
//		Document = Undefined;
//	EndIf;
//	
//EndProcedure

//Function GetOtherPartnersList(Val SettlementDocuments, Val Partner) Export
//	
//	CustomerSynonym = Nstr("en='Customer';pl='Nabywca';ru='Покупатель'");
//	SupplierSynonym = Nstr("en='Supplier';pl='Dostawca';ru='Поставщик'");
//	
//	OtherPartnersList = New ValueList;
//	
//	For Each SettlementDocumentsRow In SettlementDocuments Do
//		If ValueIsFilled(SettlementDocumentsRow.Partner) AND SettlementDocumentsRow.Partner <> Partner And OtherPartnersList.FindByValue(SettlementDocumentsRow.Partner) = Undefined Then
//			OtherPartnersList.Add(SettlementDocumentsRow.Partner, String(SettlementDocumentsRow.Partner) + " (" + ?(TypeOf(SettlementDocumentsRow.Partner) = Type("CatalogRef.Customers"),CustomerSynonym,SupplierSynonym) + ")");
//		EndIf;
//	EndDo;
//	
//	If ValueIsFilled(Partner) Then
//		If TypeOf(Partner) = Type("CatalogRef.Customers") AND ValueIsFilled(Partner.Supplier) Then
//			
//			If OtherPartnersList.FindByValue(Partner.Supplier) = Undefined Then
//				OtherPartnersList.Add(Partner.Supplier, String(Partner.Supplier) + " (" + SupplierSynonym + ")");
//			EndIf;	
//			
//		ElsIf TypeOf(Partner) = Type("CatalogRef.Suppliers") Then
//			
//			Query = New Query();
//			Query.Text = "SELECT ALLOWED DISTINCT
//			|	Customers.Ref AS Customer,
//			|	Customers.Presentation
//			|FROM
//			|	Catalog.Customers AS Customers
//			|WHERE
//			|	Customers.Supplier = &Supplier";
//			Query.SetParameter("Supplier",Partner);
//			Selection = Query.Execute().Select();
//			
//			While Selection.Next() Do
//				
//				If OtherPartnersList.FindByValue(Selection.Customer) = Undefined Then
//					OtherPartnersList.Add(Selection.Customer,Selection.Presentation + " (" +CustomerSynonym+ ")");
//				EndIf;	
//				
//			EndDo;	
//			
//		EndIf;	
//	EndIf;
//	
//	Return OtherPartnersList;
//	
//EndFunction // GetOtherPartnersList()

//Function GetOtherEmployeesList(SettlementDocuments, Employee = Undefined) Export
//	
//	OtherEmployeesList = New ValueList;
//	
//	For Each SettlementDocumentsRow In SettlementDocuments Do
//		If SettlementDocumentsRow.Employee <> Undefined 
//			AND SettlementDocumentsRow.Employee <> Employee 
//			And OtherEmployeesList.FindByValue(SettlementDocumentsRow.Employee) = Undefined Then
//			OtherEmployeesList.Add(SettlementDocumentsRow.Employee);
//		EndIf;
//	EndDo;
//	
//	Return OtherEmployeesList;
//	
//EndFunction // GetOtherEmployeesList()

//Procedure UpdateOtherEmployeesList(Object, TabularPartName = "SettlementDocuments", EmployeeAttributeName = "Employee", Employee, OtherEmployeesList, TakeIntoAccountOtherEmployees) Export
//	
//	ObjectMetadata = Object.Metadata();
//	
//	If Common.IsDocumentTabularPart(TabularPartName, ObjectMetadata) 
//		AND Common.IsDocumentTabularPartAttribute(EmployeeAttributeName, ObjectMetadata, TabularPartName) Then
//		
//		If Common.IsDocumentTabularPartAttribute("PrepaymentSettlement", ObjectMetadata, TabularPartName) Then
//			
//			TabularPart = Object[TabularPartName];
//			PrepaymentRows = New Array();
//			For Each TabularPartRow In TabularPart Do
//				
//				If TabularPartRow[EmployeeAttributeName] <> Employee Then
//					
//					If OtherEmployeesList.FindByValue(TabularPartRow[EmployeeAttributeName]) = Undefined Then
//						OtherEmployeesList.Add(TabularPartRow[EmployeeAttributeName]);
//					EndIf;	
//				
//				EndIf;	
//				
//			EndDo;	
//						
//			If NOT TakeIntoAccountOtherEmployees 
//				AND OtherEmployeesList.Count() > 0 Then
//				TakeIntoAccountOtherEmployees = True;
//			EndIf;	
//			
//		Else
//			Return;
//		EndIf;	
//		
//	EndIf;	
//	
//EndProcedure

//Function GetDocumentsCurrencyAndExchangeRate(Document) Export
//	
//	Structure = New Structure("Currency, ExchangeRate", Undefined, Undefined);
//	
//	If ValueIsNotFilled(Document) Then
//		
//		Return Structure;
//		
//	ElsIf Catalogs.AllRefsType().ContainsType(TypeOf(Document)) Then // first check catalogs
//		
//		If CommonAtServer.IsDocumentAttribute("Currency", Document.Metadata()) Then
//			Structure.Currency = Document.Currency;
//			Structure.ExchangeRate = Document.ExchangeRate;
//		EndIf;
//		
//	Else // documents
//		
//		If CommonAtServer.IsDocumentAttribute("SettlementCurrency", Document.Metadata()) Then
//			Structure.Currency = Document.SettlementCurrency;
//			Structure.ExchangeRate = Document.SettlementExchangeRate;
//		ElsIf CommonAtServer.IsDocumentAttribute("Currency", Document.Metadata()) Then
//			Structure.Currency = Document.Currency;
//			Structure.ExchangeRate = Document.ExchangeRate;
//		EndIf;
//		
//	EndIf;
//	
//	Return Structure;
//	
//EndFunction // GetDocumentsCurrencyAndExchangeRate()

//Function GetFullEmployeesList(OtherEmployeesList, Employee = Undefined, PrepaymentSettlement = Undefined) Export
//	
//	If PrepaymentSettlement = Enums.PrepaymentSettlement.Prepayment Then
//		
//		ValueList = New ValueList;
//		ValueList.Add(Employee);
//		Return ValueList;
//		
//	Else
//		
//		ValueList = OtherEmployeesList.Copy();
//		If Employee <> Undefined Then
//			ValueList.Insert(0, Employee);
//		EndIf;
//		
//		Return ValueList;
//	EndIf;	
//	
//EndFunction