////////////////////////////////////////////////////////////////////////////////
// ElectronicDocumentsOverridable: mechanism for the electronic documents exchange.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROGRAMMING INTERFACE

// It fills the array with the current kinds of electronic documents for application solutions.
//
// Parameters:
//  Array - kinds of current ED.
//
Procedure GetEDActualKinds(Array) Export
	
	Array.Add(Enums.EDKinds.ActPerformer);
	Array.Add(Enums.EDKinds.ActCustomer);
	Array.Add(Enums.EDKinds.TORG12Seller);
	Array.Add(Enums.EDKinds.TORG12Customer);
	Array.Add(Enums.EDKinds.ProductOrder);
	Array.Add(Enums.EDKinds.ResponseToOrder);
	Array.Add(Enums.EDKinds.ProductsDirectory);
	Array.Add(Enums.EDKinds.RightsDelegationAct);
	
	Array.Add(Enums.EDKinds.PaymentOrder);
	Array.Add(Enums.EDKinds.QueryStatement);
	Array.Add(Enums.EDKinds.BankStatement);
	
EndProcedure

// It determines electronic document parameters by the owner type.
//
// Parameters:
//  Source - object or the document/catalog-source reference.
//  EDParameters - structure of the source parameters
//                required to specify the ED exchange settings. Required parameters: EDDirection,
//                EDKind, Counterparty, EDAgreement or Company.
//  FormatCML - Boolean if it is True, then CML (not FTS) diagrams will
//    be used for ED creation, the corresponding ED kinds shall be specified in the parameters.
//
Procedure FillEDParametersBySource(Source, EDParameters, FormatCML = False) Export
	
	SourceType = TypeOf(Source);
	
	If SourceType = Type("DocumentRef.RandomED")
		OR SourceType = Type("DocumentObject.RandomED") Then
		
		EDParameters.EDKind = Enums.EDKinds.RandomED;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		
	ElsIf SourceType = Type("DocumentRef.CustomerInvoice") 
		OR SourceType = Type("DocumentObject.CustomerInvoice") Then
		
		If FormatCML Then
			EDParameters.EDKind = Enums.EDKinds.TORG12;
		ElsIf SourceType = Type("DocumentRef.CustomerInvoice") Then
			EDKind = CommonUse.ObjectAttributeValue(Source.Ref, "ElectronicDocumentKind");
			If Not ValueIsFilled(EDKind) Then
				EDKind = Enums.EDKinds.TORG12;
			EndIf;
			EDParameters.EDKind = EDKind;
		Else
			EDParameters.EDKind = Source.ElectronicDocumentKind;
		EndIf;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		
	ElsIf SourceType = Type("DocumentRef.SupplierInvoice")
		OR SourceType = Type("DocumentObject.SupplierInvoice") Then
		
		If Not ValueIsFilled(EDParameters.EDKind) Then
			If FormatCML Then
				If Source.Inventory.Count() > 0 Then
					EDParameters.EDKind = Enums.EDKinds.TORG12;
				Else
					EDParameters.EDKind = Enums.EDKinds.AcceptanceCertificate;
				EndIf;
			Else
				If Source.Inventory.Count() > 0 Then
					EDParameters.EDKind = Enums.EDKinds.TORG12Seller;
				Else
					EDParameters.EDKind = Enums.EDKinds.ActPerformer;
				EndIf;
			EndIf;
		EndIf;
		
		If EDParameters.EDKind = Enums.EDKinds.TORG12Customer
			OR EDParameters.EDKind = Enums.EDKinds.ActCustomer Then
			EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		Else
			EDParameters.EDDirection = Enums.EDDirections.Incoming;
		EndIf;
		
	ElsIf SourceType = Type("DocumentRef.PurchaseOrder")
		OR SourceType = Type("DocumentObject.PurchaseOrder") Then 
		
		EDParameters.EDKind =  Enums.EDKinds.ProductOrder;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		
	ElsIf SourceType = Type("DocumentRef.CustomerOrder")
		OR SourceType = Type("DocumentObject.CustomerOrder") Then
		
		EDParameters.EDKind =  Enums.EDKinds.ResponseToOrder;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
	
	ElsIf SourceType = Type("CatalogRef.EDUsageAgreements")
		OR SourceType = Type("CatalogObject.EDUsageAgreements") Then
		
		EDParameters.EDKind =  Enums.EDKinds.ProductsDirectory;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		
	ElsIf SourceType = Type("DocumentRef.AcceptanceCertificate") 
		OR SourceType = Type("DocumentObject.AcceptanceCertificate") Then
		
		EDParameters.EDKind =  Enums.EDKinds.ActPerformer;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		
	ElsIf SourceType = Type("DocumentRef.PaymentOrder")
		OR SourceType = Type("DocumentObject.PaymentOrder") Then
		
		EDParameters.EDKind = Enums.EDKinds.PaymentOrder;
		EDParameters.EDDirection = Enums.EDDirections.Outgoing;
		AccountOfCompany = Source.BankAccount;
		If ValueIsFilled(AccountOfCompany) Then
			EDParameters.Counterparty = CommonUse.ObjectAttributeValue(AccountOfCompany, "Bank");
		EndIf;
		
	EndIf;
	
	EDParameters.Company = Source.Company;
	If Not EDParameters.EDKind = Enums.EDKinds.PaymentOrder Then
		EDParameters.Counterparty  = Source.Counterparty;
		EDParameters.CounterpartyContract = Source.Contract;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Definition of ED library objects and applied solution matching

// It specifies the attribute name of SupplierProductsAndServices catalog owner.
//
// Parameters:
//  OwnerAttributeName - String - Owner attribute name.
//
Procedure DetermineSuppliersProductsAndServicesOwnerAttributeName(OwnerAttributeName) Export
	
	OwnerAttributeName = "Counterparty";
	
EndProcedure

// Defines the matching of the library
// and application solution catalogs in case the catalog names differ.
//
// Parameters:
//  AccordanceCatalogs - Map - catalog list.
//
Procedure GetCatalogCorrespondence(AccordanceCatalogs) Export
	
	// Electronic documents
	AccordanceCatalogs.Insert("Companies", "Companies");
	AccordanceCatalogs.Insert("Counterparties", "Counterparties");
	AccordanceCatalogs.Insert("partners",    "");
	AccordanceCatalogs.Insert("Banks",       "RFBankClassifier");
	// End of electronic documents
	
	AccordanceCatalogs.Insert("CounterpartyContracts",        "CounterpartyContracts");
	AccordanceCatalogs.Insert("ProductsAndServices",                "ProductsAndServices");
	AccordanceCatalogs.Insert("ProductsAndServicesCharacteristics",  "ProductsAndServicesCharacteristics");
	AccordanceCatalogs.Insert("UOM",            "UOM");
	AccordanceCatalogs.Insert("SuppliersProductsAndServices",     "SuppliersProductsAndServices");
	AccordanceCatalogs.Insert("Currencies",                      "Currencies");
	AccordanceCatalogs.Insert("Banks", "Banks");
	AccordanceCatalogs.Insert("BankAccountsOfTheCompany",  "BankAccounts");
	AccordanceCatalogs.Insert("BankAccountsOfCounterparties", "BankAccounts");
	AccordanceCatalogs.Insert("ProductsAndServicesPacking",        "UOM");
	
EndProcedure

// It receives the enumeration value by metadata object names.
// 
// Parameters:
//  AccordanceEnum - Matching library and applied enumerations.
//
Procedure GetEnumerationsCorrespondence(AccordanceEnum) Export
	
	AccordanceEnum.Insert("LegalEntityIndividual", "LegalEntityIndividual");
	
EndProcedure

// The function contains the structure of mapping
// the library variable names with the object and attribute names of the applied solution metadata.
// 
// Parameters:
//  Correspondence key - name of the variable used in the library code;
//  Matching value - the metadata object name or
//  object attribute in the applied solution.
//
Procedure GetMapOfNamesObjectsMDAndAttributes(ObjectAttributesMap) Export
	
	ObjectAttributesMap.Insert("ReceiveDateInInvoiceReceived", "Date");
	ObjectAttributesMap.Insert("AccountNo",                           "AccountNo");
	
	ObjectAttributesMap.Insert("CounterpartyTIN",                       "TIN");
	ObjectAttributesMap.Insert("CounterpartyDescription",              "Description");
	ObjectAttributesMap.Insert("CounterpartyNameForMessageToUser", "Description");
	ObjectAttributesMap.Insert("ExternalCounterpartyCode",                "Code");
	ObjectAttributesMap.Insert("CounterpartyPartner",                   Undefined);
	
	ObjectAttributesMap.Insert("CompanyTIN",                       "TIN");
	ObjectAttributesMap.Insert("CompanyDescription",              "Description");
	ObjectAttributesMap.Insert("ShortDescriptionOfTheCompany",   "Description");
	
EndProcedure

// Defines the matching of the library and
// application solution functional options in case the names differ.
//
// Parameters:
//  CorrespondenceFO - Map - list of functional options.
//
Procedure GetFunctionalOptionsCorrespondence(CorrespondenceFO) Export
	
	// Electronic documents
	CorrespondenceFO.Insert("UseEDExchange",                    "UseEDExchange");
	CorrespondenceFO.Insert("UseDigitalSignatures", 		  "UseDigitalSignatures");
	CorrespondenceFO.Insert("UseDigitalSignatures", "UseDigitalSignatures");
	CorrespondenceFO.Insert("UseEDExchangeBetweenCompanies",  "UseEDExchangeBetweenCompanies");
	CorrespondenceFO.Insert("UseEDExchangeWithBanks",            "UseEDExchangeWithBanks");
	// End of electronic documents
	
EndProcedure

// Fill in the matching of the VAT rates and amount
//
Procedure GetCorrespondingVATRates(AccordanceOfRatesVAT) Export
	
	AccordanceOfRatesVAT = New Map();
	
	Query = New Query("SELECT * FROM Catalog.VATRates AS VATRates");
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		AccordanceOfRatesVAT.Insert(Selection.Ref, Selection.Rate);
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exchange setup

Procedure AdditionalAnalyticsOfCompaniesCatalogPartners(InUseCatalogPartners) Export
	
	InUseCatalogPartners = False;
	
EndProcedure

// The obsolete procedure will be deleted when changing to a new BED revision.
// Receives query text by exchange settings.
//
// Returns:
//  QueryText - query text.
//
Function GetExchangeByAgreementSettingsText() Export
	
	QueryText = "";
	
EndFunction

// The obsolete procedure will be deleted when changing to a new BED revision.
// It receives a query text by exchange settings with the priorities.
//
// Returns:
//  QueryText - query text.
//
Function GetExchangeWithPrioritiesSettingsQueryText() Export
	
	QueryText = "";
	
EndFunction

// The function generates a proxy by the proxy settings (passed parameter)
//
// Parameters:
//  ProxyServerSetting - Map:
//  UseProxy - whether the proxy server shall be used
//  DoNotUseProxyForLocalAddresses - whether a proxy server shall be used for the local addresses
//  UseSystemSettings - whether the proxy server system settings are used
//  Server       - proxy server address
//  Port         - proxy server port
//  User         - user name for authorization on the proxy server
//  Password     - user's password
//
Function GetProxyServerSettings(ProxyServerSetting) Export
	
	ProxyServerSetting = GetFilesFromInternet.GetProxySettingsAt1CEnterpriseServer();
	
	If ProxyServerSetting = Undefined Then
		
		ProxyServerSetting = New Map();
		ProxyServerSetting.Insert("UseProxy", True);
		ProxyServerSetting.Insert("UseSystemSettings", True);
		ProxyServerSetting.Insert("BypassProxyOnLocal", False);
		ProxyServerSetting.Insert("Server", "");
		ProxyServerSetting.Insert("Port", "");
		ProxyServerSetting.Insert("User", "");
		ProxyServerSetting.Insert("Password", "");
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Definition of the object key attributes to record changes

// It receives object key attributes by the text presentation.
//
// Parameters:
//  ObjectName - String, text presentation of the object which key attributes shall be received.
//
// Returns:
//  KeyAttributesStructure - object parameter list.
//
Procedure GetObjectKeyAttributesStructure(ObjectName, KeyAttributesStructure) Export
	
	If ObjectName = "Document.CustomerInvoice" Then
		// header
		ObjectAttributesString = ("Date, Number, Company, Counterparty, DeletionMark");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
		// CWT
		ObjectAttributesString = ("ProductsAndServices, Quantity, Price, Amount, VATRate");
		KeyAttributesStructure.Insert("Inventory", ObjectAttributesString);
		
	ElsIf ObjectName = "Document.RandomED" Then
		// header
		ObjectAttributesString = ("Date, Number, Company, Counterparty, Text");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
	ElsIf ObjectName = "Document.SupplierInvoice" Then
		// header
		ObjectAttributesString = ("Company, Counterparty");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
		// CWT
		ObjectAttributesString = ("ProductsAndServices, Quantity, Price, Amount, VATRate");
		KeyAttributesStructure.Insert("Inventory", ObjectAttributesString);
		
	ElsIf ObjectName = "Document.PurchaseOrder" Then
		// header
		ObjectAttributesString = ("Date, Number, Company, Counterparty, DeletionMark");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
		// CWT
		ObjectAttributesString = ("ProductsAndServices, Quantity, Price, Amount, VATRate");
		KeyAttributesStructure.Insert("Inventory", ObjectAttributesString);
		
	ElsIf ObjectName = "Document.CustomerOrder" Then
		// header
		ObjectAttributesString = ("Company, Counterparty");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
		// CWT
		ObjectAttributesString = ("ProductsAndServices, Quantity, Price, Amount, VATRate");
		KeyAttributesStructure.Insert("Inventory", ObjectAttributesString);
		
	ElsIf ObjectName = "Document.AcceptanceCertificate" Then
		// header
		ObjectAttributesString = ("Date, Number, Company, Counterparty, DeletionMark");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
		// TS
		ObjectAttributesString = ("ProductsAndServices, Quantity, Price, Amount, VATRate");
		KeyAttributesStructure.Insert("WorksAndServices", ObjectAttributesString);
		
	ElsIf ObjectName = "Document.PaymentOrder" Then
		
		ObjectAttributesString = ("Date, Number, Company, BankAccount, Counterparty, CounterpartyAccount, DocumentAmount, DeletionMark");
		KeyAttributesStructure.Insert("Header", ObjectAttributesString);
		
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Generating data for electronic documents

// Work with tree

// It prepares data for the electronic document of the ProductsCatalogue type.
//
// Parameters:
//  Company - CatalogRef, reference to the infobase object used to create an electronic document.
//  ProductsDirectory - Array, product list for the directory filling.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataByProductCatalogCML(Company, ProductsDirectory, DataTree) Export
	
	CommonUseED.FillTreeAttributeValue(DataTree, "ContainsChangesOnly", True);
	
	InfoAboutCompany = GetDataLegalIndividual(Company);
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutCompany, "Owner", "Arbitrary");
	
	CommonUseED.ImportingTableToTree(DataTree, ProductsDirectory, "Products");
	
EndProcedure

// It fills data for the electronic document of the Right Transfer Act type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataByAssignmentDeed(ObjectReference, EDStructure, DataTree) Export
	
	If ObjectReference.OperationKind <> Enums.OperationKindsCustomerInvoice.SaleToCustomer Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot create an electronic document for operation kind ""%1"".';ru='Нельзя создать электронный документ для вида операции ""%1""!'"), ObjectReference.OperationKind);
		
		Raise MessageText;
		
	EndIf;
	
	DataForPrint = SmallBusinessManagementElectronicDocumentsServer.GetDataForTrade12(ObjectReference);
	
	HeaderAttributes = DataForPrint.HeaderData;
	DocumentTable = DataForPrint.DocumentTable;
	
	ProductsTable = New ValueTable();	
	ProductsTable.Columns.Add("SKU");   
	ProductsTable.Columns.Add("Description");
	ProductsTable.Columns.Add("ProductsAndServices");
	ProductsTable.Columns.Add("Characteristic");
	ProductsTable.Columns.Add("Package");
	ProductsTable.Columns.Add("Barcode");
	ProductsTable.Columns.Add("ProductIdOfCounterparty");
	ProductsTable.Columns.Add("BaseUnitCode");
	ProductsTable.Columns.Add("BaseUnitDescription");
	ProductsTable.Columns.Add("BaseUnitDescriptionFull");
	ProductsTable.Columns.Add("BaseUnitInternationalAbbreviation");
	ProductsTable.Columns.Add("Price");
	ProductsTable.Columns.Add("Quantity");
	ProductsTable.Columns.Add("Amount");
	ProductsTable.Columns.Add("VATIncludedInAmount");
	ProductsTable.Columns.Add("VATAmount");
	ProductsTable.Columns.Add("VATRate");
	
	For Each RowData IN DocumentTable Do
		
		ProductsTableRow = ProductsTable.Add();
		
		ProductsTableRow.SKU 					= RowData.ProductCode;
		ProductsTableRow.Description				= RowData.ProductsAndServicesDescription;
		ProductsTableRow.ProductsAndServices 				= RowData.ProductsAndServices;
		ProductsTableRow.Package 					= RowData.MeasurementUnitDocument;
		ProductsTableRow.BaseUnitCode 			= TrimAll(RowData.BaseUnitCode);
		ProductsTableRow.BaseUnitDescription = RowData.BaseUnitDescription;
		ProductsTableRow.BaseUnitDescriptionFull = RowData.BaseUnitDescription;
		ProductsTableRow.BaseUnitInternationalAbbreviation = "-";
		
		ProductsTableRow.Quantity 		= RowData.Quantity;
		ProductsTableRow.VATIncludedInAmount 	= HeaderAttributes.AmountIncludesVAT;
		
		If HeaderAttributes.AmountIncludesVAT Then
			ProductsTableRow.Amount = RowData.SumWithVAT;
			ProductsTableRow.Price = ?(RowData.Quantity = 0, RowData.SumWithVAT, RowData.SumWithVAT / RowData.Quantity);
		Else
			AmountWithoutVAT = RowData.Amount - ?(HeaderAttributes.AmountIncludesVAT, RowData.VATAmount, 0);
			ProductsTableRow.Amount = AmountWithoutVAT;
			ProductsTableRow.Price = ?(RowData.Quantity = 0, AmountWithoutVAT, AmountWithoutVAT / RowData.Quantity);
		EndIf;
		
		ProductsTableRow.VATAmount = RowData.VATAmount;
		ProductsTableRow.VATRate = RowData.VATRate;
			
	EndDo;
	
	CommonUseED.FillTreeAttributeValue(DataTree, "Currency", HeaderAttributes.CurrencyCode);
	CommonUseED.FillTreeAttributeValue(DataTree, "ExchangeRate", "1");
	CommonUseED.FillTreeAttributeValue(DataTree, "Amount", DocumentTable.Total("SumWithVAT"));
	
	If ValueIsFilled(HeaderAttributes.Basis) Then
		CommonUseED.FillTreeAttributeValue(
			DataTree, 
			"BasisDocuments", 
			HeaderAttributes.Basis);
	EndIf;
	
	InfoAboutLicensor = GetDataLegalIndividual(HeaderAttributes.Consignor, HeaderAttributes.DocumentDate);
	InfoAboutLicensee = GetDataLegalIndividual(HeaderAttributes.Consignee, HeaderAttributes.DocumentDate);
	InfoAboutPayer = GetDataLegalIndividual(HeaderAttributes.Counterparty, HeaderAttributes.DocumentDate);
	
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutLicensor, "Licensor",  "Fact");
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutLicensee, "Licensee",  "Fact");
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutPayer, "Payer", "Legal");
	
	CommonUseED.ImportingTableToTree(DataTree, ProductsTable, "Products");
	
	EDStructure.Insert("DocumentAmount", DocumentTable.Total("SumWithVAT"));

EndProcedure

// It fills data for the electronic document of CostChangeAgreementSender type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataByCorrectingDocument(ObjectReference, EDStructure, DataTree) Export
	
	

EndProcedure

// It prepares data for the electronic document of the Torg12 customer title type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure, parameters to be filled.
//
Procedure FillDataByCorrectingDocumentRecipient(ObjectReference, EDStructure, DataTree) Export
	
	ThisIsInd = ThisIsInd(EDStructure.Company);
	DataLegalIndividual = GetDataLegalIndividual(EDStructure.Company);
	
	If ThisIsInd Then
		Initials = DataLegalIndividual.FullDescr;
		
		LicenceData = "";
		CertificateAboutRegistrationIPData(EDStructure.Company, LicenceData);
		CommonUseED.FillTreeAttributeValue(
									DataTree,
									"Signer.CO.CertificateAboutRegistrationIP",
									LicenceData);
		CommonUseED.FillTreeAttributeValue(DataTree, "Signer.CO.TIN", DataLegalIndividual.TIN);
		SmallBusinessManagementElectronicDocumentsServer.FillFirstAndLastNameOfSignatoryAtTree(DataTree, "CO", Initials);
	Else
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(EDStructure.Company, EDStructure.EDDate);
		Initials = Heads.HeadDescriptionFull;
		CommonUseED.FillTreeAttributeValue(DataTree, "Signer.LegalEntity.Position", String(Heads.HeadPosition));
		CommonUseED.FillTreeAttributeValue(DataTree, "Signer.LegalEntity.TIN", DataLegalIndividual.TIN);
		SmallBusinessManagementElectronicDocumentsServer.FillFirstAndLastNameOfSignatoryAtTree(DataTree, "LegalEntity", Initials);
	EndIf;
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CargoDateReceived", CurrentSessionDate());
	
EndProcedure

// Work with the FTS data structure

// It prepares data for the electronic document of the Torg12 seller title type.
//
// Parameters:
//  ObjectReference - documentRef - reference to
//  the infobase object used to create an electronic document.
//  EDStructure - structure - data structure for generating an electronic document.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataOnTrad21SellerFTS(ObjectReference, EDStructure, DataTree) Export
	
	If ObjectReference.OperationKind <> Enums.OperationKindsCustomerInvoice.SaleToCustomer Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot create an electronic document for operation kind ""%1"".';ru='Нельзя создать электронный документ для вида операции ""%1""!'"), ObjectReference.OperationKind);
		
		Raise MessageText;
		
	EndIf;
	
	DataForPrint = SmallBusinessManagementElectronicDocumentsServer.GetDataForTrade12(ObjectReference);
	
	HeaderAttributes = DataForPrint.HeaderData;
	TabularSection = DataForPrint.DocumentTable;
	
	OperationKind = Enums.EDOperationsKinds.RetailComission;
	
	CommonUseED.FillTreeAttributeValue(DataTree, "ConsignmentNoteNumber", ObjectPrefixationClientServer.GetNumberForPrinting(HeaderAttributes.Number));
	CommonUseED.FillTreeAttributeValue(DataTree, "DateOfInvoice",  HeaderAttributes.DocumentDate);
	
	// Displaying common header attributes
	InfoAboutVendor       = GetDataLegalIndividual(HeaderAttributes.Company, HeaderAttributes.DocumentDate, HeaderAttributes.BankAccount);
	InfoAboutShipper = GetDataLegalIndividual(HeaderAttributes.Consignor, HeaderAttributes.DocumentDate);
	InfoAboutCustomer       = GetDataLegalIndividual(HeaderAttributes.Counterparty, HeaderAttributes.DocumentDate);
	InfoAboutConsignee  = GetDataLegalIndividual(HeaderAttributes.Consignee,  HeaderAttributes.DocumentDate);
	
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutVendor,       "Vendor");
	If HeaderAttributes.Company <> HeaderAttributes.Consignor Then
		SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutShipper, "Consignor");
	EndIf;
	
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutCustomer,       "Payer");
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutConsignee,  "Consignee");
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CurrencyCode", HeaderAttributes.CurrencyCode);
	CommonUseED.FillTreeAttributeValue(DataTree, "OperationKind", OperationKind);
	
	If ValueIsFilled(HeaderAttributes.Basis) Then
		CommonUseED.FillTreeAttributeValue(
										DataTree,
										"DocBasisDescription",
										HeaderAttributes.Basis);
	EndIf;
	CommonUseED.FillTreeAttributeValue(
									DataTree,
									"DocBasisDate",
									HeaderAttributes.BasisDate);
	CommonUseED.FillTreeAttributeValue(
									DataTree,
									"DocBasisNumber",
									HeaderAttributes.BasisNumber);
	
	ProductsTable = New ValueTable();
	ProductsTable.Columns.Add("ProductsAndServices");
	ProductsTable.Columns.Add("ProductsAndServicesDescription");
	ProductsTable.Columns.Add("CharacteristicDescription");
	ProductsTable.Columns.Add("Kind");
	ProductsTable.Columns.Add("SKU");
	ProductsTable.Columns.Add("ProductCode");
	ProductsTable.Columns.Add("MeasurementUnit");
	ProductsTable.Columns.Add("BaseUnitCode");
	ProductsTable.Columns.Add("PackagingKind");
	ProductsTable.Columns.Add("QuantityInOnePlace");
	ProductsTable.Columns.Add("PlacesQuantity");
	ProductsTable.Columns.Add("GrossWeight");
	ProductsTable.Columns.Add("NetWeight");
	ProductsTable.Columns.Add("Price");
	ProductsTable.Columns.Add("AmountWithoutVAT");
	ProductsTable.Columns.Add("VATRate");
	ProductsTable.Columns.Add("VATAmount");
	ProductsTable.Columns.Add("SumWithVAT");
	ProductsTable.Columns.Add("BasisDocument");
	ProductsTable.Columns.Add("Characteristic");
	ProductsTable.Columns.Add("Package");
	ProductsTable.Columns.Add("AdditionalInformationDigitallySigned");
	ProductsTable.Columns.Add("AdditionalInformationIsNotDigitallySigned");
	ProductsTable.Columns.Add("Definition");
	
	For Each String IN TabularSection Do
		
		NewRow = ProductsTable.Add();
		FillPropertyValues(NewRow, String);
		
		Factor = 1;
		If TypeOf(String.MeasurementUnitDocument) = Type("CatalogRef.UOM") Then
			Factor = String.MeasurementUnitDocument.Factor;
		EndIf;
		
		NewRow.NetWeight = Round(String.Quantity * Factor, 3);
		NewRow.Price = Round(String.Amount / ?(NewRow.NetWeight = 0, 1, NewRow.NetWeight), 2);
		NewRow.AmountWithoutVAT = String.Amount - ?(HeaderAttributes.AmountIncludesVAT, String.VATAmount, 0);
		
	EndDo;
	
	CommonUseED.ImportingTableToTree(DataTree, ProductsTable, "ProductsTable");
	
	// Initialization of results by the document
	TotalAmounts = New Structure;
	
	TotalAmounts.Insert("TotalPlaces", 0);
	TotalAmounts.Insert("TotalAmountWithVAT", 0);
	TotalAmounts.Insert("TotalAmountWithoutVAT", 0);
	TotalAmounts.Insert("TotalVAT", 0);
	TotalAmounts.Insert("TotalVATAmountBeforeCorrection", 0);
	TotalAmounts.Insert("TotalAmountBeforeCorrection", 0);
	TotalAmounts.Insert("TotalVATBeforeCorrection", 0);
	TotalAmounts.Insert("TotalGrossWeight", 0);
	TotalAmounts.Insert("TotalNetWeight", 0);
	TotalAmounts.Insert("SequentialRecordsNumbersQuantity", 0);
	TotalAmounts.Insert("AmountInWords", "");
	
	For Each String IN ProductsTable Do
		
		TotalAmounts.TotalPlaces        = TotalAmounts.TotalPlaces        + ?(ValueIsFilled(String.PlacesQuantity),String.PlacesQuantity, 0);
		TotalAmounts.TotalAmountWithoutVAT = TotalAmounts.TotalAmountWithoutVAT + String.AmountWithoutVAT;
		TotalAmounts.TotalVAT         = TotalAmounts.TotalVAT         + String.VATAmount;
		TotalAmounts.TotalAmountWithVAT   = TotalAmounts.TotalAmountWithVAT   + String.AmountWithoutVAT + String.VATAmount;
		
	EndDo;
	
	TotalAmounts.SequentialRecordsNumbersQuantity = ProductsTable.Count();
	
	CommonUseED.FillTreeAttributeValue(DataTree, "InformationOnCargoRelease.ReleasedForAmount",
			TotalAmounts.TotalAmountWithVAT);
			
	CommonUseED.FillTreeAttributeValue(DataTree, "InformationOnCargoRelease.DateReleased",
			HeaderAttributes.DocumentDate);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CommonInformationAboutConsignmentNote.SequentialRecordsNumbersQuantity",
			TotalAmounts.SequentialRecordsNumbersQuantity);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CommonInformationAboutConsignmentNote.TotalPlaces",
			TotalAmounts.TotalPlaces);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CommonInformationAboutConsignmentNote.CargoNetWeight",
			TotalAmounts.TotalNetWeight);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CommonInformationAboutConsignmentNote.CargoGrossWeight",
			TotalAmounts.TotalGrossWeight);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "TotalByInvoice.CargoItem",
			TotalAmounts.TotalPlaces);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "TotalByInvoice.GrossWeight",
			TotalAmounts.TotalGrossWeight);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "TotalByInvoice.NetWeight",
			TotalAmounts.TotalNetWeight);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "TotalByInvoice.AmountWithoutVAT",
			TotalAmounts.TotalAmountWithoutVAT);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "TotalInInvoice.VATAmount",
			TotalAmounts.TotalVAT);
	
	CommonUseED.FillTreeAttributeValue(DataTree, "TotalInInvoice.AmountWithVAT",
			TotalAmounts.TotalAmountWithVAT);
	
EndProcedure

// It prepares data for the electronic document of the Torg12 customer title type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataByTRAD12CustomerFTS(ObjectReference, EDStructure, DataTree) Export
	
	CommonUseED.FillTreeAttributeValue(DataTree, "CargoDateReceived", CurrentSessionDate());
	
EndProcedure

// Prepares contractor title data for the electronic document of
// the Services acceptance certificate type of 5 format.01.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataByAct501PerformerFTS(ObjectReference, EDStructure, DataTree) Export
	
	DocumentData = SmallBusinessManagementElectronicDocumentsServer.GetDataAcceptanceCertificate(ObjectReference);
	
	HeaderAttributes  = DocumentData.HeaderAttributes;
	TabularSection = DocumentData.WorkTable;
	
	If TabularSection.Count() = 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The document does not contain data to generate ED ""%1""';ru='Документ не содержит данных для формирования ЭД ""%1""'"),
			EDStructure.EDKind);
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	CommonUseED.FillTreeAttributeValue(DataTree, "ActNumber",   HeaderAttributes.DocumentNumber);
	CommonUseED.FillTreeAttributeValue(DataTree, "DateOfAct",    HeaderAttributes.DocumentDate);
	
	OperationKind = Enums.EDOperationsKinds.RetailComission;
	CommonUseED.FillTreeAttributeValue(DataTree, "OperationKind", OperationKind);
	If ValueIsFilled(HeaderAttributes.CurrencyCode) Then
		CommonUseED.FillTreeAttributeValue(DataTree, "CurrencyCode", HeaderAttributes.CurrencyCode);
	EndIf;
	
	HeaderText = "We the undersigned CONTRACTOR representative from one side and CUSTOMER representative from the other"
		+ " side have drawn up this Certificate to cerify that the CONTRACTOR performed and the CUSTOMER accepted the work (services) as follows.";
	CommonUseED.FillTreeAttributeValue(DataTree, "Title", HeaderText);
	
	// Displaying general header attributes
	InfoAboutVendor       = GetDataLegalIndividual(HeaderAttributes.Company,  HeaderAttributes.DocumentDate);
	InfoAboutCustomer       = GetDataLegalIndividual(HeaderAttributes.Counterparty, HeaderAttributes.DocumentDate);
	
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutVendor, "Performer");
	SmallBusinessManagementElectronicDocumentsServer.ParticipantDataFill(DataTree, InfoAboutCustomer, "Customer");
	
	ServicesTable = New ValueTable();
	ServicesTable.Columns.Add("ProductsAndServices");
	ServicesTable.Columns.Add("ProductsAndServicesDescription");
	ServicesTable.Columns.Add("MeasurementUnitDescription");
	ServicesTable.Columns.Add("MeasurementUnitCode");
	ServicesTable.Columns.Add("Quantity");
	ServicesTable.Columns.Add("Price");
	ServicesTable.Columns.Add("AmountWithoutVAT");
	ServicesTable.Columns.Add("VATRate");
	ServicesTable.Columns.Add("VATAmount");
	ServicesTable.Columns.Add("SumWithVAT");
	ServicesTable.Columns.Add("Definition");
	ServicesTable.Columns.Add("BasisDocument");
	ServicesTable.Columns.Add("AdditionalInformationDigitallySigned");
	ServicesTable.Columns.Add("AdditionalInformationIsNotDigitallySigned");
	
	For Each String IN TabularSection Do
		
		If Not ValueIsFilled(String.ProductsAndServices) Then
			MessageText = NStr("en='Products and services are not populated in row %1 of the %2 tabular section. To transfer an electronic document, it is necessary to fill in products and services.';ru='В строке %1 табличной части %2 не заполнена номенклатура. Для передачи электронного документа заполнение номенклатуры обязательно.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessageText, String.LineNumber, String.TabularSectionName);
			CommonUseClientServer.MessageToUser(MessageText, ObjectReference);
			Continue;
		EndIf;
		
		If String.Amount + String.VATAmount = 0 Then
			Continue;
		EndIf;
		
		Factor = 1;
		If TypeOf(String.MeasurementUnitDocument) = Type("CatalogRef.UOM") Then
			Factor = String.MeasurementUnitDocument.Factor;
		EndIf;
		
		DocumentTableString = ServicesTable.Add();
	
		DocumentTableString.ProductsAndServices                 = String.ProductsAndServices;
		DocumentTableString.ProductsAndServicesDescription     = String.ProductsAndServicesDescription;
		DocumentTableString.MeasurementUnitCode          = ?(ValueIsFilled(String.MeasurementUnit),String.MeasurementUnitCode, "796");
		DocumentTableString.MeasurementUnitDescription = String.MeasurementUnitDescription;
		DocumentTableString.Quantity                   = String.Quantity * Factor;
		DocumentTableString.Definition                     = String.ProductsAndServicesDescription;
		
		DocumentTableString.AmountWithoutVAT     = String.Amount - ?(HeaderAttributes.AmountIncludesVAT, String.VATAmount, 0);
		DocumentTableString.SumWithVAT       = String.Total;
		DocumentTableString.VATRate       = String.VATRate;
		DocumentTableString.VATAmount        = String.VATAmount;
		DocumentTableString.Price            = ?(DocumentTableString.Quantity = 0, DocumentTableString.AmountWithoutVAT, Round(String.Amount/DocumentTableString.Quantity,2));
		
	EndDo;
	
	CommonUseED.ImportingTableToTree(DataTree, ServicesTable, "ServicesTable");
	
	CommonUseED.FillTreeAttributeValue(DataTree, "ServiceDescription.JobStart", HeaderAttributes.DocumentDate);
	CommonUseED.FillTreeAttributeValue(DataTree, "ServiceDescription.JobCompletion",  HeaderAttributes.DocumentDate);
	CommonUseED.FillTreeAttributeValue(DataTree, "ServiceDescription.AmountWithoutVATTotal",
		ServicesTable.Total("AmountWithoutVAT"));
	CommonUseED.FillTreeAttributeValue(DataTree, "ServiceDescription.VATAmountTotal",
		ServicesTable.Total("VATAmount"));
	CommonUseED.FillTreeAttributeValue(DataTree, "ServiceDescription.AmountWithVATTotal",
		ServicesTable.Total("SumWithVAT"));
	
	CommonUseED.FillTreeAttributeValue(DataTree, "InformationAboutServicesExecution.CompletionDate",
		HeaderAttributes.DocumentDate);

EndProcedure

// Prepares customer title data for the electronic document of
// the Services acceptance certificate type of 5 format.01.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DataTree - value tree, data tree for filling an electronic document.
//
Procedure FillDataOnTheAct150CustomerFTS(ObjectReference, EDStructure, DataTree) Export
	
	CommonUseED.FillTreeAttributeValue(DataTree, "InformationOnServicesExecution.OrderDate",
		CurrentSessionDate());
	
EndProcedure

// Work with the FTS data structure

// It prepares data for the electronic document of the Torg12 seller title type.
//
// Parameters:
//  ObjectReference - documentRef - reference to
//  the infobase object used to create an electronic document.
//  EDStructure - structure - data structure for generating an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByTorg12(ObjectReference, EDStructure, ParametersStructure) Export
	
	If ObjectReference.OperationKind <> Enums.OperationKindsCustomerInvoice.SaleToCustomer Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot create an electronic document for operation kind ""%1"".';ru='Нельзя создать электронный документ для вида операции ""%1""!'"), ObjectReference.OperationKind);
		
		Raise MessageText;
		
	EndIf;
	
	DocumentData = SmallBusinessManagementElectronicDocumentsServer.GetDataSellingProductsAndServices(ObjectReference);
	HeaderAttributes  = DocumentData.HeaderAttributes;
	
	If DocumentData.ProductsTable.Count() = 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The document does not contain data to generate ED ""%1""';ru='Документ не содержит данных для формирования ЭД ""%1""'"),
			EDStructure.EDKind);
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
	EndIf;
	
	// Generate the product table
	For Each ProductsRowData IN DocumentData.ProductsTable Do
		
		SmallBusinessManagementElectronicDocumentsServer.AddDataTableString(ParametersStructure.ProductsTable, ProductsRowData, ParametersStructure, "Products");
		
	EndDo;
		
	// Calculate totals
	TotalAmounts = SmallBusinessManagementElectronicDocumentsServer.StructureTotalAmounts(ParametersStructure.ProductsTable);
	
	FillPropertyValues(ParametersStructure.TotalByBill, 
		SmallBusinessManagementElectronicDocumentsServer.StructureTotalAmounts(ParametersStructure.ProductsTable));
	
	ParametersStructure.ConsignmentNoteNumber	= GetDocumentPrintNumber(ObjectReference);
	ParametersStructure.DateOfInvoice	= HeaderAttributes.DocumentDate;
	ParametersStructure.DocBasisDescription = HeaderAttributes.DocBasisDescription;
	ParametersStructure.DocBasisNumber		= HeaderAttributes.DocBasisNumber;
	ParametersStructure.DocBasisDate		= HeaderAttributes.DocBasisDate;
	
	SmallBusinessManagementElectronicDocumentsServer.FillParticipantsAttributesTORG12(HeaderAttributes, ParametersStructure);
	
	Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(HeaderAttributes.Company, HeaderAttributes.DocumentDate);
	
	// Fill in the signatory data
	ThisIsInd		= ThisIsInd(EDStructure.Company);
	DataLegalIndividual = GetDataLegalIndividual(EDStructure.Company);
	Initials				= "";
	Position		= Undefined;
	
	If ThisIsInd Then
		
		Initials			= DataLegalIndividual.FullDescr;
		CertificateAboutRegistrationIPData(EDStructure.Company, ParametersStructure.Signer.CertificateAboutRegistrationIP);
		
	Else
		
		Initials			= Heads.HeadDescriptionFull;
		Position	= Heads.HeadPosition;
		
	EndIf;
	
	ParametersStructure.Signer.ThisIsInd = ThisIsInd;
	SmallBusinessManagementElectronicDocumentsServer.FillSNPAndPosition(ParametersStructure.Signer, Initials, Position);
	ParametersStructure.Signer.TIN = DataLegalIndividual.TIN;
	
	// Fill in data of the product release
	InformationByCargoRelease = ParametersStructure.InformationByCargoRelease;
	InformationByCargoRelease.DateReleased		= HeaderAttributes.DocumentDate;
	InformationByCargoRelease.AmountReleased	= TotalAmounts.SumWithVAT;
	InformationByCargoRelease.AmountReleasedInWords = SmallBusinessServer.GenerateAmountInWords(TotalAmounts.SumWithVAT, HeaderAttributes.DocumentCurrency);
	
	// Chief accountant
	SmallBusinessManagementElectronicDocumentsServer.FillSNPAndPosition(InformationByCargoRelease.Accountant, Heads.ChiefAccountantNameAndSurname, "Chief accountant");
	// Release authorized by
	SmallBusinessManagementElectronicDocumentsServer.FillSNPAndPosition(InformationByCargoRelease.ReleasePermitted, Heads.HeadDescriptionFull, Heads.HeadPosition);
	// Release is made by
	SmallBusinessManagementElectronicDocumentsServer.FillSNPAndPosition(InformationByCargoRelease.ReleaseMade, Heads.WarehouseManSNP, Heads.WarehouseMan_Position);
	
EndProcedure

// It prepares data for the electronic document of the Torg12 customer title type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByTorg12Buyer(ObjectReference, EDStructure, ParametersStructure) Export
	
	// Fill in the signatory data
	ThisIsInd = ThisIsInd(EDStructure.Company);
	
	DataLegalIndividual = GetDataLegalIndividual(EDStructure.Company);
	Initials			= "";
	Position	= Undefined;
	
	If ThisIsInd Then
		
		Initials = DataLegalIndividual.FullDescr;
		CertificateAboutRegistrationIPData(EDStructure.Company, ParametersStructure.Signer.CertificateAboutRegistrationIP);
		
	Else
		
		Heads = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(EDStructure.Company, EDStructure.EDDate);
		
		Initials = Heads.HeadDescriptionFull;
		Position = Heads.HeadPosition;
		
	EndIf;
	
	ParametersStructure.Signer.ThisIsInd = ThisIsInd;
	SmallBusinessManagementElectronicDocumentsServer.FillSNPAndPosition(ParametersStructure.Signer, Initials, Position);
	ParametersStructure.Signer.TIN = DataLegalIndividual.TIN;
	
EndProcedure

// Prepares contractor title data for the electronic document of
// the Services acceptance certificate type of 5 format.01.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByAct501(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// Prepares customer title data for the electronic document of
// the Services acceptance certificate type of 5 format.01.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByAct501Customer(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// Work with the CML data structure

// It fills the storage address with the value table - products directory
//
// Parameters:
//  AddressInTemporaryStorage - product catalog storage address;
//  FormID - unique  identifier of the form that called the function.
//
Procedure PutGoodsCatalogIntoTemporaryStorage(AddressInTemporaryStorage, FormID) Export
	
	
	
EndProcedure

// OBSOLETE It prepares data for the electronic document of ProductsCatalogue type.
//
// Parameters: 
// ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
// ProductsDirectory - Array, product list for the directory filling.
// EDStructure - Structure, data structure to generate an electronic document.
// ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByProductsDirectory(ObjectReference, ProductsDirectory, EDStructure, ParametersStructure) Export
	
	ProductsTable = ParametersStructure.ProductsTable;
	For Each String IN ProductsDirectory Do
		NewRow = ProductsTable.Add();
		FillPropertyValues(NewRow, String);
	EndDo;
	
	ParametersStructure.Insert("Performer", 		EDStructure.Sender);
	ParametersStructure.Insert("SchemaVersion", 		"4.02");
	ParametersStructure.Insert("ProductsTable", 		ProductsTable);
	ParametersStructure.Insert("Company", 		EDStructure.Company);
	ParametersStructure.Insert("Counterparty", 			EDStructure.Counterparty);
	ParametersStructure.Insert("ID", 					EDStructure.EDNumber);
	ParametersStructure.Insert("GeneratingDate",	CurrentSessionDate());
	ParametersStructure.Insert("EDKind", 				EDStructure.EDKind);
	ParametersStructure.Insert("EDDirection", 		EDStructure.EDDirection);
	
	ParametersStructure.Insert("MandatoryFields", 				"Company, ID, GenerationDate, ProductsTable");
	ParametersStructure.Insert("ValueTableRequiredFields", "Name, ProductsAndServices, BaseUnitCode");
	
EndProcedure

// It prepares data for the electronic document of PriceList type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByPriceList(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// It prepares data for the electronic document of ConsignmentNote type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByConsignment(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// It prepares data for the electronic document of WorksExecutionAct type.
//
// Parameters: 
// ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
// EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByAcceptanceCertificate(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// It prepares data for the electronic document of Account type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByBill(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// It prepares data for the electronic document of GoodsOrder type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByProductsOrder(ObjectReference, EDStructure, ParametersStructure) Export
	
	If ObjectReference.OperationKind <> Enums.OperationKindsPurchaseOrder.OrderForPurchase Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot create an electronic document for operation kind ""%1"".';ru='Нельзя создать электронный документ для вида операции ""%1""!'"), ObjectReference.OperationKind);
		
		Raise MessageText;
		
	EndIf;
	
	ParametersStructure = New Structure;
	
	TypeDescriptionQuantity = New TypeDescription("Number", , , New NumberQualifiers(0, 4));
	TypeDescriptionAmount		= New TypeDescription("Number", , , New NumberQualifiers(18, 2));
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("ID");
	ProductsTable.Columns.Add("SKU");
	ProductsTable.Columns.Add("Description");
	ProductsTable.Columns.Add("BaseUnit");
	ProductsTable.Columns.Add("BaseUnitCode");
	ProductsTable.Columns.Add("BaseUnitDescription");
	ProductsTable.Columns.Add("BaseUnitDescriptionFull");
	ProductsTable.Columns.Add("BaseUnitInternationalAbbreviation");
	ProductsTable.Columns.Add("Quantity", TypeDescriptionQuantity);
	ProductsTable.Columns.Add("PackageCode");
	ProductsTable.Columns.Add("PackageDescription");
	ProductsTable.Columns.Add("Factor");
	ProductsTable.Columns.Add("SumWithVAT", TypeDescriptionAmount);
	ProductsTable.Columns.Add("VATRate");
	ProductsTable.Columns.Add("VATAmount", TypeDescriptionAmount);
	ProductsTable.Columns.Add("Price", TypeDescriptionAmount);
	ProductsTable.Columns.Add("DiscountAmount");
	ProductsTable.Columns.Add("Amount", TypeDescriptionAmount);
	ProductsTable.Columns.Add("Definition");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ISNULL(SuppliersProductsAndServices.ID, UNDEFINED) AS ID,
	|	ISNULL(SuppliersProductsAndServices.SKU, """") AS SKU,
	|	ISNULL(SuppliersProductsAndServices.Description, """") AS Description,
	|	PurchaseOrder.ProductsAndServices AS ProductsAndServices,
	|	PurchaseOrder.Characteristic AS Characteristic,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit AS BaseUnit,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit.Code AS BaseUnitCode,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit.Description AS BaseUnitDescription,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit.DescriptionFull AS BaseUnitDescriptionFull,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit.InternationalAbbreviation AS BaseUnitInternationalAbbreviation,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit.Code AS PackageCode,
	|	PurchaseOrder.ProductsAndServices.MeasurementUnit.Description AS PackageDescription,
	|	UNDEFINED AS Factor,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrder.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrder.Quantity
	|		ELSE PurchaseOrder.Quantity * PurchaseOrder.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrder.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN PurchaseOrder.Price
	|		WHEN PurchaseOrder.Quantity * PurchaseOrder.MeasurementUnit.Factor <> 0
	|			THEN PurchaseOrder.Amount / (PurchaseOrder.Quantity * PurchaseOrder.MeasurementUnit.Factor)
	|		ELSE 0
	|	END AS Price,
	|	PurchaseOrder.Amount AS Amount,
	|	PurchaseOrder.VATRate AS VATRate,
	|	PurchaseOrder.VATAmount AS VATAmount,
	|	0 AS DiscountAmount,
	|	PurchaseOrder.Amount AS SumWithVAT,
	|	PurchaseOrder.ReceiptDate AS ReceiptDate,
	|	PurchaseOrder.ProductsAndServices.Comment AS Definition
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrder
	|		LEFT JOIN Catalog.SuppliersProductsAndServices AS SuppliersProductsAndServices
	|		ON (SuppliersProductsAndServices.Owner = PurchaseOrder.Ref.Counterparty)
	|			AND (SuppliersProductsAndServices.ProductsAndServices = PurchaseOrder.ProductsAndServices)
	|			AND (SuppliersProductsAndServices.Characteristic = PurchaseOrder.Characteristic)
	|WHERE
	|	PurchaseOrder.Ref = &Ref";
	
	Query.SetParameter("Ref", ObjectReference);
	
	UnableToMatchProductsAndServices = False;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		If Selection.ID = Undefined Then
			
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en='Cannot map the ""%1"" products and services with products and services of the supplier';ru='Не удалось сопоставить номенклатуру ""%1"" с номенклатурой поставщика'"),
					String(Selection.ProductsAndServices) + ?(ValueIsFilled(Selection.Characteristic), "(" + Selection.Characteristic + ")", "") 
																		)
				);
				
			UnableToMatchProductsAndServices = True;
		EndIf;
			
		NewRow = ProductsTable.Add();
		FillPropertyValues(NewRow, Selection);
		
		If ValueIsFilled(NewRow.PackageCode) Then
			NewRow.PackageCode = Right(NewRow.PackageCode, 3);
			If StrLen(NewRow.PackageCode) < 3 Then
				NewRow.PackageCode = StringFunctionsClientServer.SupplementString(NewRow.PackageCode, 3, "0", "Left");
			EndIf;
		EndIf;
		
	EndDo;
	
	If UnableToMatchProductsAndServices Then
		
		ParametersStructure.Insert("DataPrepared", False);
		CommonUseClientServer.MessageToUser(NStr("en='Electronic document generation has been canceled.';ru='Формирование электронного документа отменено.'"));
		
		Return ;
	EndIf;
	
	ParametersStructure.Insert("Performer",				EDStructure.Sender);
	ParametersStructure.Insert("SchemaVersion", 			"4.02");
	ParametersStructure.Insert("Role", 					"Customer");
	ParametersStructure.Insert("ProductsTable", 			ProductsTable);
	ParametersStructure.Insert("Company", 			EDStructure.Company);
	ParametersStructure.Insert("Counterparty", 				EDStructure.Counterparty);
	ParametersStructure.Insert("ID", 						EDStructure.EDNumber);
	ParametersStructure.Insert("GeneratingDate",		CurrentSessionDate());
	ParametersStructure.Insert("Number", 					EDStructure.SenderDocumentNumber);
	ParametersStructure.Insert("Date", 					EDStructure.SenderDocumentDate);
	ParametersStructure.Insert("Currency",					ObjectReference.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", 					ObjectReference.ExchangeRate);
	ParametersStructure.Insert("Amount",					ObjectReference.DocumentAmount);
	ParametersStructure.Insert("PriceIncludesVAT",			ObjectReference.AmountIncludesVAT);
	ParametersStructure.Insert("VATAmount", 				ObjectReference.Inventory.Total("VATAmount"));
	ParametersStructure.Insert("EDKind", 					EDStructure.EDKind);
	ParametersStructure.Insert("EDDirection",			EDStructure.EDDirection);
	ParametersStructure.Insert("Comment",				ObjectReference.Comment);
	ParametersStructure.Insert("NumberByCustomerData",	ObjectReference.Number);
	ParametersStructure.Insert("DateByCustomerData",		ObjectReference.Date);
	ShippingAddress = SmallBusinessManagementElectronicDocumentsServer.GetDeliveryAddress(EDStructure.Counterparty);
	ParametersStructure.Insert("ShippingAddress", 			ShippingAddress);
	
	If ValueIsFilled(ObjectReference.IncomingDocumentNumber) Then
		
		ParametersStructure.Insert("NumberBySupplierData",	ObjectReference.IncomingDocumentNumber);
		ParametersStructure.Insert("DateBySupplierData",	ObjectReference.IncomingDocumentDate);
		
	EndIf;
	
	TotalRow = NStr("en='Total number of names %Quantity% in the amount of %Amount%';ru='Всего наименований %Количество%, на сумму %Сумма%'");
	TotalRow = StrReplace(TotalRow, "%Quantity%", ProductsTable.Count());
	TotalRow = StrReplace(TotalRow, "%Amount%",		 SmallBusinessServer.AmountsFormat(ObjectReference.DocumentAmount, ObjectReference.DocumentCurrency));
	AmountInWords  = SmallBusinessServer.GenerateAmountInWords(ObjectReference.DocumentAmount, ObjectReference.DocumentCurrency);
	TotalRow = TotalRow + Chars.LF + AmountInWords;
	ParametersStructure.Insert("TotalsInWords", TotalRow);
	
	ParametersStructure.Insert("MandatoryFields", "Company, Counterparty,
		|ID, GenerationDate, Number, Date, EDKind, EDDirection, ProductsTable");
	ParametersStructure.Insert("ValueTableRequiredFields", "Id, Name, BasicUnitCode");
	
EndProcedure

// It prepares data for the electronic document of OrderResponse type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure - parameters for electronic document filling.
//
Procedure PrepareDataByOnOrderResponce(ObjectReference, EDStructure, ParametersStructure) Export
	
	If ObjectReference.OperationKind <> Enums.OperationKindsCustomerOrder.OrderForSale Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Cannot create an electronic document for operation kind ""%1"".';ru='Нельзя создать электронный документ для вида операции ""%1""!'"), ObjectReference.OperationKind);
		
		Raise MessageText;
		
	EndIf;
	
	ParametersStructure = New Structure;
	
	TypeDescriptionQuantity = New TypeDescription("Number", , , New NumberQualifiers(0, 4));
	TypeDescriptionAmount 		= New TypeDescription("Number", , , New NumberQualifiers(18, 2));
	TypeDescriptionDate		= New TypeDescription("Date");
	
	ProductsTable = New ValueTable;
	ProductsTable.Columns.Add("ID");
	ProductsTable.Columns.Add("SKU");
	ProductsTable.Columns.Add("Description");
	ProductsTable.Columns.Add("ProductsAndServices");
	ProductsTable.Columns.Add("Characteristic");
	ProductsTable.Columns.Add("BaseUnit");
	ProductsTable.Columns.Add("BaseUnitCode");
	ProductsTable.Columns.Add("BaseUnitDescription");
	ProductsTable.Columns.Add("BaseUnitDescriptionFull");
	ProductsTable.Columns.Add("BaseUnitInternationalAbbreviation");
	ProductsTable.Columns.Add("Quantity", TypeDescriptionQuantity);
	ProductsTable.Columns.Add("PackageCode");
	ProductsTable.Columns.Add("PackageDescription");
	ProductsTable.Columns.Add("Factor");
	ProductsTable.Columns.Add("SumWithVAT", TypeDescriptionAmount);
	ProductsTable.Columns.Add("VATRate");
	ProductsTable.Columns.Add("VATAmount", TypeDescriptionAmount);
	ProductsTable.Columns.Add("Price", TypeDescriptionAmount);
	ProductsTable.Columns.Add("DiscountAmount");
	ProductsTable.Columns.Add("Amount", TypeDescriptionAmount);
	ProductsTable.Columns.Add("ReceiptDate", TypeDescriptionDate);
	ProductsTable.Columns.Add("AdditionalAttributes");
	ProductsTable.Columns.Add("Definition");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CustomerOrder.ProductsAndServices.Code AS ProductCode,
	|	CustomerOrder.ProductsAndServices.SKU AS SKU,
	|	CustomerOrder.ProductsAndServices.DescriptionFull AS Description,
	|	CustomerOrder.ProductsAndServices AS ProductsAndServices,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrder.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN CustomerOrder.Quantity
	|		ELSE CustomerOrder.Quantity * CustomerOrder.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrder.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN CustomerOrder.Price
	|		WHEN CustomerOrder.Quantity * CustomerOrder.MeasurementUnit.Factor <> 0
	|			THEN CustomerOrder.Amount / (CustomerOrder.Quantity * CustomerOrder.MeasurementUnit.Factor)
	|		ELSE 0
	|	END AS Price,
	|	CustomerOrder.Amount AS Amount,
	|	CustomerOrder.Characteristic AS Characteristic,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit AS BaseUnit,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit.Code AS BaseUnitCode,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit.Description AS BaseUnitDescription,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit.DescriptionFull AS BaseUnitDescriptionFull,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit.InternationalAbbreviation AS BaseUnitInternationalAbbreviation,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit.Code AS PackageCode,
	|	CustomerOrder.ProductsAndServices.MeasurementUnit.Description AS PackageDescription,
	|	CustomerOrder.VATRate AS VATRate,
	|	CustomerOrder.VATAmount AS VATAmount,
	|	0 AS DiscountAmount,
	|	CustomerOrder.Amount AS SumWithVAT,
	|	CustomerOrder.ShipmentDate AS ReceiptDate,
	|	CustomerOrder.ProductsAndServices.Comment AS Definition
	|FROM
	|	Document.CustomerOrder.Inventory AS CustomerOrder
	|WHERE
	|	CustomerOrder.Ref = &Ref";
	
	Query.SetParameter("Ref", ObjectReference);
	
	SmallBusinessManagementElectronicDocumentsServer.ImportIntoValueTable(Query.Execute().Unload(), ProductsTable);
	SmallBusinessManagementElectronicDocumentsServer.ProcessProductsTable(ProductsTable);
	
	For Each String in ProductsTable Do
		
		AdditionalAttributes = New Structure;
		AddValuesArray 		= New Array();
		AddValuesArray.Add(String.ReceiptDate);
		AdditionalAttributes.Insert("ReceiptDate", AddValuesArray);
		String.AdditionalAttributes = AdditionalAttributes;
		
	EndDo;
	
	ParametersStructure.Insert("Performer",				EDStructure.Sender);
	ParametersStructure.Insert("SchemaVersion", 			"4.02");
	ParametersStructure.Insert("Role", 					"Seller");
	ParametersStructure.Insert("NumberBySupplierData",	ObjectReference.Number);
	ParametersStructure.Insert("DateBySupplierData",	ObjectReference.Date);
	ParametersStructure.Insert("ProductsTable", 			ProductsTable);
	ParametersStructure.Insert("Company", 			EDStructure.Company);
	ParametersStructure.Insert("Counterparty", 				EDStructure.Counterparty);
	ParametersStructure.Insert("ID", 						EDStructure.EDNumber);
	ParametersStructure.Insert("GeneratingDate",		CurrentSessionDate());
	ParametersStructure.Insert("Number", 					GetDocumentPrintNumber(ObjectReference));
	ParametersStructure.Insert("Date", 					ObjectReference.Date);
	ParametersStructure.Insert("Currency",					ObjectReference.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", 					ObjectReference.ExchangeRate);
	ParametersStructure.Insert("Amount",					ObjectReference.DocumentAmount);
	ParametersStructure.Insert("PriceIncludesVAT",			ObjectReference.AmountIncludesVAT);
	ParametersStructure.Insert("VATAmount", 				ObjectReference.Inventory.Total("VATAmount"));
	ParametersStructure.Insert("EDKind", 					EDStructure.EDKind);
	ParametersStructure.Insert("EDDirection",			EDStructure.EDDirection);
	ParametersStructure.Insert("Comment", 			ObjectReference.Comment);
	ShippingAddress = SmallBusinessManagementElectronicDocumentsServer.GetDeliveryAddress(EDStructure.Counterparty);
	ParametersStructure.Insert("ShippingAddress", 			ShippingAddress);
	
	TotalRow = NStr("en='Total number of names %Quantity% in the amount of %Amount%';ru='Всего наименований %Количество%, на сумму %Сумма%'");
	TotalRow = StrReplace(TotalRow, "%Quantity%", ProductsTable.Count());
	TotalRow = StrReplace(TotalRow, "%Amount%",		 SmallBusinessServer.AmountsFormat(ObjectReference.DocumentAmount, ObjectReference.DocumentCurrency));
	AmountInWords  = SmallBusinessServer.GenerateAmountInWords(ObjectReference.DocumentAmount, ObjectReference.DocumentCurrency);
	TotalRow = TotalRow + Chars.LF + AmountInWords;
	ParametersStructure.Insert("TotalsInWords", TotalRow);
	
	ParametersStructure.Insert("MandatoryFields", "Company, Counterparty,
		|ID, GeneratingDate, EDKind, EDDirection, ProductsTable");
	ParametersStructure.Insert("ValueTableRequiredFields", "Id, Name, BasicUnitCode");
	
EndProcedure

// It prepares data for the electronic document of ReportToPrincipal type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure, parameters to be filled.
//
// Feature:
//  Parameter AdditionalAttributesForTablesProducts in the common parameter structure
//  is intended for the AdditionalAttributes column filling the product table.
//
Procedure PrepareDataByReportAboutComissionGoodsSales(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// It prepares data for the electronic document of WriteOffReportToPrincipal type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure, parameters to be filled.
//
Procedure PrepareDataByComissionGoodsWriteOffReport(ObjectReference, EDStructure, ParametersStructure) Export
	
	
	
EndProcedure

// It prepares data for the electronic document of GoodsTransferBetweenCompanies type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure, parameters to be filled.
//
Procedure PrepareDataByGoodsTransferBetweenCompanies(ObjectReference, EDStructure, ParametersStructure) Export
	
	
		
EndProcedure

// It prepares data for the electronic document of ProductsReturnBetweenCompanies type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersStructure - structure, parameters to be filled.
//
Procedure PrepareDataByGoodsReturnBetweenCompanies(ObjectReference, EDStructure, ParametersStructure) Export
	
	
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Search and create documents

// It saves data from the electronic document to the IB object.
//
// Parameters:
//  StringForImport - parameter string
//  for loading, AnalysisTree     - ValueTree, IB document parameter structure.
//  RefToOwner - Ref to IB object, owner of the electronic document.
//
// Returns:
//  FoundObject - object reference.
//
Function SaveVBDObjectData(StringForImport, ParseTree, RefToOwner = Undefined, Write = True) Export
	
	FoundObject = RefToOwner;
	
	If StringForImport.EDKind = Enums.EDKinds.TORG12 
		OR StringForImport.EDKind = Enums.EDKinds.TORG12Seller
		OR StringForImport.EDKind = Enums.EDKinds.ActPerformer
		OR StringForImport.EDKind = Enums.EDKinds.RightsDelegationAct Then
		
		ThisIsAct = StringForImport.EDKind = Enums.EDKinds.ActPerformer;
		FoundObject = SmallBusinessManagementElectronicDocumentsServer.FoundCreateProductsServicesReceipt(StringForImport, ParseTree, RefToOwner, ThisIsAct);
		
	ElsIf StringForImport.EDKind = Enums.EDKinds.ProductOrder Then
		
		FoundObject = SmallBusinessManagementElectronicDocumentsServer.FoundCreateCustomerOrder(StringForImport, ParseTree, RefToOwner);
		
	ElsIf StringForImport.EDKind = Enums.EDKinds.ResponseToOrder Then
		
		FoundObject = SmallBusinessManagementElectronicDocumentsServer.FoundCreatePurchaseOrder(StringForImport, ParseTree, RefToOwner);
		
	ElsIf StringForImport.EDKind = Enums.EDKinds.ProductsDirectory Then
		
		SmallBusinessManagementElectronicDocumentsServer.SaveProductCatalogData(StringForImport, ParseTree, RefToOwner);
		
	EndIf;
	
	Return FoundObject;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Creating catalog items

// Creates an object in the IB by the parameter tree.
//
// Parameters:
//  ObjectString - Parameter structure of
//  the recorded object, AnalisysTree - ValueTree, electronic document analysis result.
//
// Returns:
//  NewItem - reference to a new item in the infobase.
//
Function CreateObjectVBD(ObjectString, ParseTree) Export
	
	NewEl = Undefined;
	If ObjectString.DescriptionOfType = "CatalogRef.SuppliersProductsAndServices" Then
		NewEl = SmallBusinessManagementElectronicDocumentsServer.CreateRefillVendorsProductsAndServices(ObjectString, ParseTree);
	EndIf;
	
	Return NewEl;
	
EndFunction

// It finds a reference to IB object by the type, ID and additional attributes
// 
// Parameters:
//  ObjectType - String, identifier of the object
//  type to be found, ObjectID - String, object identifier of
//  the specified type, AdditionalAttributes - Structure, set of object additional fields for searching.
//
Function FindRefToObject(ObjectType, IDObject = "", AdditionalAttributes = Undefined, IDED = Undefined) Export
	
	Parameter = "";
	Result = Undefined;
	
	If ObjectType = "Currencies" 
		OR ObjectType = "Banks" Then
		Result = FindRefToObjectByAttribute(ObjectType, "Code", IDObject);
		
	ElsIf ObjectType = "UOM" Then
		Result = FindRefToObjectByAttribute("UOMClassifier", "Code", IDObject);
		
	ElsIf (ObjectType = "Counterparties" 
		OR ObjectType = "Companies") 
		AND ValueIsFilled(AdditionalAttributes) Then
		
		TIN = ""; 
		AdditionalAttributes.Property("TIN", TIN);
		
		If ValueIsFilled(TIN) Then 
			
			Result = ObjectRefOnTIN(ObjectType, TIN); 
			
		EndIf;
		
		If Not ValueIsFilled(Result) 
			AND AdditionalAttributes.Property("Description", Parameter) Then // by Description
			
			Result = FindRefToObjectByAttribute(ObjectType, "Description", Parameter); 
			
		EndIf;
		
	ElsIf ObjectType = "SuppliersProductsAndServices" AND ValueIsFilled(AdditionalAttributes) Then
		Counterparty = "";
		SearchParameter = "";
		If AdditionalAttributes.Property("ID", SearchParameter)
			AND AdditionalAttributes.Property("Owner", Counterparty) Then // there is ID
			Result = SmallBusinessManagementElectronicDocumentsServer.FindLinkToVendorsProductsAndServicesIdIdentificator(SearchParameter, Counterparty, "SupplierProductsAndServices");
		EndIf;
		
	ElsIf ObjectType = "ProductsAndServicesCharacteristic" 
		AND ValueIsFilled(AdditionalAttributes)
		AND AdditionalAttributes.Property("ID", Parameter) Then
		
		Try
			IdentifierString = Mid(Parameter, Find(Parameter, "#")-1);
			CharacteristicRef = Catalogs.ProductsAndServicesCharacteristics.GetRef(New UUID(IdentifierString));
			If ValueIsFilled(CharacteristicRef) Then
				Result = CharacteristicRef;
			EndIf;
		Except
		EndTry;
		
	ElsIf ObjectType = "ProductsAndServices" Then
		
		If ValueIsFilled(IDObject) Then
			// If Id is defined, we will search by the code
			Result = FindRefToObjectByAttribute(ObjectType, "Code", IDObject);
			
		ElsIf ValueIsFilled(AdditionalAttributes) AND AdditionalAttributes.Property("ID", Parameter) Then
			
			Try
				IdentifierString = Left(Parameter, Find(Parameter, "#")-1);
				ProductsAndServicesRef = Catalogs.ProductsAndServices.GetRef(New UUID(IdentifierString));
				If ValueIsFilled(ProductsAndServicesRef) Then
					Result = ProductsAndServicesRef;
				EndIf;
			Except
			EndTry;
			
		ElsIf ValueIsFilled(AdditionalAttributes) AND AdditionalAttributes.Property("Code", Parameter) Then
			
			Result = FindRefToObjectByAttribute(ObjectType, "Code", Parameter);
			
		EndIf;
		
	ElsIf ObjectType = "ContactInformationKinds" Then
		
		Try 
			Result = Catalogs.ContactInformationKinds[IDObject];
		Except
			Result = Undefined;
		EndTry;
		
	ElsIf (ObjectType = "BankAccountsOfTheCompany" Or ObjectType = "BankAccountsOfCounterparties") AND ValueIsFilled(AdditionalAttributes)Then
		
		Owner = "";
		If AdditionalAttributes.Property("Owner", Owner) Then
			AppliedCatalogName = ElectronicDocumentsServiceCallServer.GetAppliedCatalogName(ObjectType);
			Result = FindRefToObjectByAttribute(AppliedCatalogName, "AccountNo", IDObject, Owner);
		EndIf;
		
	ElsIf ObjectType = "WorldCountries" Then
		
		Result = FindRefToObjectByAttribute("WorldCountries", "Code", IDObject);
		
	EndIf;
		
	Return Result;
	
EndFunction

// It finds a reference to the catalog by the passed attribute.
//
// Parameters:
//  CatalogName - String, catalog name which object shall be found
//  AttributeName - String, attribute name used for searching
//  AttributeVal - arbitrary value, attribute value used for searching
//  Owner - Ref to the owner for searching in the hierarchical directory.
//
Function FindRefToObjectByAttribute(CatalogName, AttributeName, AttributeVal, Owner = Undefined) Export
	
	Result = Undefined;
	
	MetadataObject = Metadata.Catalogs[CatalogName];
	If Not CommonUse.ThisIsStandardAttribute(MetadataObject.StandardAttributes, AttributeName)
		AND Not MetadataObject.Attributes.Find(AttributeName) <> Undefined Then
		
		Return Result;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CatalogToFind.Ref AS Ref
	|FROM
	|	Catalog." + CatalogName + " AS
	|RequiredCatalog
	|	WHERE RequiredCatalog." + AttributeName + " = &AttributeVal";
	
	If ValueIsFilled(Owner) Then
		Query.Text = Query.Text + " AND RequiredCatalog.Owner = &Owner";
		Query.SetParameter("Owner", Owner);
	EndIf;
	Query.SetParameter("AttributeVal", AttributeVal);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.Ref;
	EndIf;
	
	Return Result;
	
EndFunction

// Finds the catalog item by TIN attributes. 
// If the item is not found, we return Undefined
// Parameters:
//  ObjectType - String, catalog name in metadata;
//  TIN - String;
//  Company - Company, reference to the company catalog item
//
// Returns:
//  Result - references to the catalog or undefined
//
Function ObjectRefOnTIN(ObjectType, TIN, Company = Undefined) Export
	
	Result = Undefined;
	
	If IsBlankString(TIN) Then
		
		Return Result;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Catalog.Ref AS Ref
	|FROM
	|	&CatalogType AS Catalog
	|WHERE
	|	&SearchConditionByTIN";
	
	Query.Text = StrReplace(Query.Text, "&CatalogType", "Catalog." + ObjectType); 
	
	If Not IsBlankString(TIN) Then
		
		Query.Text = StrReplace(Query.Text, "&SearchConditionByTIN", "Catalog.TIN LIKE (&TIN)");
		Query.SetParameter("TIN", TIN);
		
	Else
		
		Query.SetParameter("SearchConditionByTIN", True);
		
	EndIf;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Result = Selection.Ref;
		
	EndIf;
	
	Return Result;
	
EndFunction

// It fills object attributes by the data from attribute structure.
//
// Parameters:
//  AttributesStructure - structure - list of attribute values
//
// Returns:
//  Counterparty.Ref - ref to counterparty catalog
//
Function FillCounterpartyAttributes(AttributesStructure) Export
	
	BeginTransaction();
	
	If ValueIsFilled(AttributesStructure.Counterparty) Then
		
		Counterparty = AttributesStructure.Counterparty.GetObject();
		RefNew = Undefined;
		
	Else
		
		Counterparty = Catalogs.Counterparties.CreateItem();
		RefNew = AccessManagementService.ObjectRef(Counterparty, True);
		
	EndIf;
	
	TIN_KPP = AttributesStructure.TIN_KPP;
	
	Counterparty.Description = AttributesStructure.Description;
	Counterparty.TIN = Mid(TIN_KPP, 1, Find(TIN_KPP,"/")-1);
	
	// Contact information
	
	If Not IsBlankString(AttributesStructure.AddressOfRepresentation) Then
		
		CIKind = Catalogs.ContactInformationKinds.CounterpartyFactAddress;
		CIPhysicalAddress = Counterparty.ContactInformation.Find(CIKind, "Kind");
		
		If CIPhysicalAddress = Undefined Then
			
			CIPhysicalAddress = Counterparty.ContactInformation.Add();
			CIPhysicalAddress.Type = CIKind;
			CIPhysicalAddress.Type = Enums.ContactInformationTypes.Address;
			
		EndIf;
			
		CIPhysicalAddress.Presentation = AttributesStructure.AddressOfRepresentation;
		CIPhysicalAddress.FieldsValues = AttributesStructure.AddressFieldValues;
		
	EndIf;
	
	If Not IsBlankString(AttributesStructure.LegalAddressRepresentation) Then
		
		CIKind = Catalogs.ContactInformationKinds.CounterpartyLegalAddress;
		CILegalAddress = Counterparty.ContactInformation.Find(CIKind, "Kind");
		
		If CILegalAddress = Undefined Then
			
			CILegalAddress = Counterparty.ContactInformation.Add();
			CILegalAddress.Type = CIKind;
			CILegalAddress.Type = Enums.ContactInformationTypes.Address;
			
		EndIf;
		
		CILegalAddress.Presentation = AttributesStructure.LegalAddressRepresentation;
		CILegalAddress.FieldsValues = AttributesStructure.LegalAddressFieldValues;
		
	EndIf;
	
	If Not IsBlankString(AttributesStructure.Phone) Then
		
		CIKind = Catalogs.ContactInformationKinds.CounterpartyPhone;
		CIPhones = Counterparty.ContactInformation.Find(CIKind, "Kind");
		
		If CIPhones = Undefined Then
			
			CIPhones = Counterparty.ContactInformation.Add();
			CIPhones.Type = CIKind;
			CIPhones.Type = Enums.ContactInformationTypes.Phone;
			
		EndIf;
		
		CIPhones.Presentation = AttributesStructure.Phone;
		CIPhones.FieldsValues = "PhoneNumber=" + TrimAll(AttributesStructure.Phone);
		
	EndIf;
	
	// Bank account
	
	If ValueIsFilled(AttributesStructure.BIN)
		AND ValueIsFilled(AttributesStructure.BankAccount) Then
		
		Banks = Catalogs.Banks.GetBanksTableByAttributes("Code", AttributesStructure.BIN);
		
		If Banks.Count() = 0 Then
				
			CounterpartyBank = Catalogs.Banks.CreateItem();
			CounterpartyBank.Code = AttributesStructure.BIN;
			CounterpartyBank.CorrAccount = AttributesStructure.CorrespondentAccount;
			CounterpartyBank.Description = AttributesStructure.Bank;
			CounterpartyBank.Write();
			
		Else
			
			CounterpartyBank = Banks[0].Ref;
			
		EndIf;
		
		CounterpartyBankAcc = Catalogs.BankAccounts.FindByCode(AttributesStructure.BankAccount);
		If Not ValueIsFilled(CounterpartyBankAcc) Then
			
			CounterpartyBankAcc = Catalogs.BankAccounts.CreateItem();
			
			If RefNew = Undefined Then
				CounterpartyBankAcc.Owner = Counterparty.Ref;
			Else
				CounterpartyBankAcc.Owner = RefNew;
			EndIf;
			
			CounterpartyBankAcc.Bank = CounterpartyBank;
			CounterpartyBankAcc.CashCurrency = Constants.NationalCurrency.Get();
			CounterpartyBankAcc.AccountNo = AttributesStructure.BankAccount;
			CounterpartyBankAcc.Description = AttributesStructure.BankAccount + ", in " + CounterpartyBank.Description;
			CounterpartyBankAcc.DataExchange.Load = True;
			CounterpartyBankAcc.Write();
			
		EndIf;
		
		Counterparty.BankAccountByDefault = CounterpartyBankAcc;
		
	EndIf;
	
	Try
		
		Counterparty.Write();
		CommitTransaction();
		
		Message = New UserMessage();
		
		If RefNew <> Undefined Then
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='New counterparty ""%1"" was successfully created.';ru='Новый контрагент ""%1"" был успешно создан.'"),
				Counterparty.Description);
		Else
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Data of the ""%1"" counterparty is repopulated.';ru='Данные контрагента ""%1"" перезаполнены.'"),
				Counterparty.Description);
		EndIf;
		
		Message.Message();
		
		Return Counterparty.Ref;
		
	Except
		
		RollbackTransaction();
		MessageText = BriefErrorDescription(ErrorInfo()) + NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo());
		ElectronicDocuments.ProcessExceptionByEDOnServer(NStr("en='Import counterparty attributes';ru='Загрузка реквизитов контрагента'"), ErrorText, MessageText);
		Return Undefined;
		
	EndTry;
	
EndFunction

// It fills in product attribute structure
//
// Parameters:
//  ProductsAndServicesAttributes - The structure containing ReturnStructure
//  searching parameters -Structure containing references to the ProductsAndServices,
//  characteristics, packaging of ID - ED exchange identifier
//
Procedure GetProductAttributes(ProductsAndServicesAttributes, ReturnStructure, ID = Undefined) Export
	
	SearchParameter = "";
	SupplierProductsAndServices = Undefined;
	If ProductsAndServicesAttributes.Property("SupplierProductsAndServices", SupplierProductsAndServices) Then
		ReturnStructure.ProductsAndServices = SupplierProductsAndServices.ProductsAndServices;
		ReturnStructure.Characteristic = SupplierProductsAndServices.Characteristic;
	Else
		ReturnStructure.ProductsAndServices = Undefined;
		ReturnStructure.Characteristic = Undefined;
	EndIf;
	
	ReturnStructure.Package = Undefined;
	
EndProcedure

// It returns the counterparty ID.
//
// Parameters
//  Counterparty - ref to the
//  counterparty (Company or Counterparty) CounterpartyKind - String specifying the counterparty kind
//
// Returns:
// CounterpartyId - String - CounterpartyId value
//
Function GetCounterpartyId(Counterparty, CounterpartyKind) Export
	
	CounterpartyId = "";
	If Upper(CounterpartyKind) = Upper("Company") Then
		CounterpartyId = Counterparty.TIN;
	ElsIf Upper(CounterpartyKind) = Upper("Counterparty") Then
		CounterpartyId = Counterparty.TIN;
	EndIf;
	
	Return CounterpartyId;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Products and services mapping

// It generates the query text to receive the products and services mapping table
//
// Parameters:
//  QueryText - String - query text
//
Procedure ProductsAndServicesCorrespondenceQueryText(QueryText) Export
	
	QueryText = 
	"SELECT
	|	TableInformationAboutProduct.ID AS ID,
	|	TableInformationAboutProduct.SKU AS CounterpartyProductsAndServicesSKU,
	|	TableInformationAboutProduct.Description AS CounterpartyProductsAndServicesDescription,
	|	TableInformationAboutProduct.BaseUnitCode AS BaseUnitCode,
	|	TableInformationAboutProduct.Definition AS Definition
	|INTO TableInformationAboutProduct
	|FROM
	|	&TableInformationAboutProduct AS TableInformationAboutProduct
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInformationAboutProduct.ID,
	|	TableInformationAboutProduct.CounterpartyProductsAndServicesSKU,
	|	TableInformationAboutProduct.CounterpartyProductsAndServicesDescription,
	|	ISNULL(UOM.Ref, UNDEFINED) AS CounterpartyProductsAndServicesUnit,
	|	TableInformationAboutProduct.Definition
	|FROM
	|	TableInformationAboutProduct AS TableInformationAboutProduct
	|		LEFT JOIN Catalog.SuppliersProductsAndServices AS SuppliersProductsAndServices
	|		ON TableInformationAboutProduct.ID = SuppliersProductsAndServices.ID
	|			AND (SuppliersProductsAndServices.Owner = &Counterparty)
	|		LEFT JOIN Catalog.UOMClassifier AS UOM
	|		ON TableInformationAboutProduct.BaseUnitCode = UOM.Code
	|WHERE
	|	(SuppliersProductsAndServices.ProductsAndServices = VALUE(Catalog.ProductsAndServices.EmptyRef)
	|			OR SuppliersProductsAndServices.ProductsAndServices IS NULL )";
	
EndProcedure

// It saves the result of the products and services manual mapping in DB
//
// Parameters:
//  MappingTable-ValueTable containing
//  the Counterparty mapping data - CatalogRef.Counterparties
//  Denial - Boolean, flag of error
//
Procedure WriteProductsAndServicesComparison(MappingTable, Counterparty, Cancel) Export
	
	For Each Record in MappingTable Do
		If ValueIsFilled(Record.ProductsAndServices) Then
			CatRef = SmallBusinessManagementElectronicDocumentsServer.FindLinkToVendorsProductsAndServicesIdIdentificator(Record.ID, Counterparty, "SupplierProductsAndServices");
			If ValueIsFilled(CatRef) Then
				CatObject = CatRef.GetObject();
			Else
				CatObject = Catalogs.SuppliersProductsAndServices.CreateItem();
				CatObject.Description  = Record.CounterpartyProductsAndServicesDescription;
				CatObject.Owner      = Counterparty;
				CatObject.SKU       = Record.CounterpartyProductsAndServicesSKU;
				CatObject.ID = Record.ID;
			EndIf;
			CatObject.ProductsAndServices   = Record.ProductsAndServices;
			CatObject.Characteristic = Record.ProductsAndServicesCharacteristic;
			Try
				CatObject.Write();
			Except
				CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,,,Cancel);
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure

// It returns the structure for opening the form of ProductsAndServices matching
//
// Parameters:
//  LinkToED - CatalogRef.EDAttachedFiles
//
// Returns:
//  Structure containing FormName and FormOpenParameters
//
Function GetProductsAndServicesComparingFormParameters(LinkToED) Export
	
	ParametersStructure = Undefined;
	
	// Products and services matching is called 
	// 	- for incoming documents of kinds:
	// 		- TORG12
	// 		- TORG12Seller
	// 		- ResponseToOrder
	// 		- ProductsDirectory
	// 		- ActPerformer
	// 	- for the outgoing document 
	//		- TORG12Customer 
	If (LinkToED.EDDirection = Enums.EDDirections.Incoming 
		    AND (LinkToED.EDKind = Enums.EDKinds.TORG12
				OR LinkToED.EDKind = Enums.EDKinds.TORG12Seller
				OR LinkToED.EDKind = Enums.EDKinds.ProductOrder
				OR LinkToED.EDKind = Enums.EDKinds.ResponseToOrder
				OR LinkToED.EDKind = Enums.EDKinds.ProductsDirectory
				OR LinkToED.EDKind = Enums.EDKinds.ActPerformer
				OR LinkToED.EDKind = Enums.EDKinds.RightsDelegationAct)) 
		 OR (LinkToED.EDDirection = Enums.EDDirections.Outgoing
			AND LinkToED.EDKind = Enums.EDKinds.TORG12Customer) Then
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("FormName", "CommonForm.DataMatchingByProductsAndServices");
		FormOpenParameters = New Structure("ElectronicDocument, DoNotOpenFormIfUnmatchedProductsAndServicesAreAbsent", LinkToED, True);
		ParametersStructure.Insert("FormOpenParameters", FormOpenParameters);
		
	EndIf;
	
	Return ParametersStructure;
	
EndFunction

// It fills the form attributes by the passed values 
//
// Parameters:
//  FormData - Managed form data;
//  FillValue - references for the data in a temporary storage.
//
Procedure FillSource(FormData, FillValue) Export
	
	FormData.FillGoodsFromTemporaryStorageServer(FillValue);
	FormData.RefreshDataRepresentation();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data receiving for generating electronic documents

// It receives enumeration value by the enum name and presentation in the library.
// 
// Parameters:
//  EnumerationName - String, enumeration description.
//  EnumerationPresentation - String, enumeration value description.
//  FoundValue - value of the required enumeration.
//
Procedure GetEnumerationValue(EnumerationName, EnumerationPresentation, FoundValue) Export
	
	If EnumerationName = "VATRates" Then
		
		FoundValue = EnumerationValueVATRate(EnumerationPresentation);
		
	Else
		
		For Each EnumerationEl IN Metadata.Enums[EnumerationName].EnumValues Do
			If Find(Upper(EnumerationEl.Synonym), Upper(EnumerationPresentation)) > 0
				OR Find(Upper(EnumerationEl.Name), Upper(EnumerationPresentation)) > 0 Then
				FoundValue = Enums[EnumerationName][EnumerationEl.Name];
				Break;
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

// It fills the counterparty attribute table for invitation to exchange.
//
// Parameters:
//  AttributesTable - value table with the fields: Party, Description, TIN,
//  EmailAddress, ExternalCode, DescriptionForUserMessage.
//    Description - it is
//    passed to EDF operator, NameForUserMessage - displays in the message to IB user.
//  CounterpartiesArray - array of references to parties-counterparties.
//
Procedure FillCounterpartiesAttributesForInvitationToExchange(AttributesTable, CounterpartiesArray, EDAgreement) Export
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	Counterparties.Ref AS Participant,
		|	Counterparties.Description AS Description,
		|	Counterparties.TIN AS TIN,
		|	Counterparties.Code AS ExternalCode,
		|	DeleteEDExchangeMembersThroughEDFOperators.EMail_Address AS EMail_Address,
		|	Counterparties.Description AS DescriptionForUserMessage
		|FROM
		|	InformationRegister.DeleteEDExchangeMembersThroughEDFOperators AS DeleteEDExchangeMembersThroughEDFOperators
		|		LEFT JOIN Catalog.Counterparties AS Counterparties
		|		ON DeleteEDExchangeMembersThroughEDFOperators.Participant = Counterparties.Ref
		|WHERE
		|	DeleteEDExchangeMembersThroughEDFOperators.Participant IN(&MembersList)
		|	AND DeleteEDExchangeMembersThroughEDFOperators.AgreementAboutEDUsage = &EDAgreement";
	Query.SetParameter("MembersList", CounterpartiesArray);
	Query.SetParameter("EDAgreement", EDAgreement);
	
	VT = Query.Execute().Unload();
	
	AttributesTable = VT.Copy();
	
EndProcedure

// It receives data of the individual (legal entity) by the reference.
//
// Parameters:
//  LegalEntityIndividual - Ref to the catalog item which data shall be received.
//
Function GetDataLegalIndividual(LegalEntityIndividual, InformationData = Undefined, BankAccount = Undefined) Export
	
	Date = ?(InformationData = Undefined, CurrentSessionDate(), InformationData);
	Information = SmallBusinessServer.InfoAboutLegalEntityIndividual(LegalEntityIndividual, Date,, BankAccount);
	 
	If TypeOf(LegalEntityIndividual) = Type("CatalogRef.Companies") Then
		
		If LegalEntityIndividual.LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
			 
			Information.Insert("FullDescr", 
				CommonUse.ObjectAttributeValue(LegalEntityIndividual, "Description"));
			
			Surname		= "";
			Name			= "";
			Patronymic	= "";
			
			IndividualsClientServer.SurnameInitialsOfIndividual(Information.FullDescr, Surname, Name, Patronymic);
			
			Information.Insert("Surname",	Surname);
			Information.Insert("Name",		Name);
			Information.Insert("Patronymic",	Patronymic);
			
		EndIf;
		
	EndIf;
	
	Information.Insert("Ref",    LegalEntityIndividual);
	Information.Insert("LegalEntityIndividual", LegalEntityIndividual.LegalEntityIndividual);
	Information.Insert("OfficialName", Information.FullDescr);
	
	Return Information
	
EndFunction

// It receives data of IE registration certificate by the reference.
//
// Parameters:
//  CO - Reference to catalog item - which data shall be received.;
//  Information - String - information of the individual entrepreneur registration.
//
Procedure CertificateAboutRegistrationIPData(CO, Information) Export
	
	If TypeOf(CO) = Type("CatalogRef.Companies") Then
		
		Information = "Certificate No " + CommonUse.ObjectAttributeValue(CO, "CertificateSeriesNumber") 
								+ " dated " + CommonUse.ObjectAttributeValue(CO, "CertificateIssueDate");
		
	EndIf;
	
EndProcedure

// It receives the signatory position by initials.
//
// Parameters:
//  Initials - String - signatory surname,
//  name and patronym, Company - ref - reference to the
//  company catalog item, Position - String - signatory position.
//
Procedure PositionOfSignatory(Initials, Company, Position) Export
	
	
	
EndProcedure

// Receives the company contact information by ref
//
// Parameters:
//  Company - reference to the Companies catalog item organization used to receive data.
//
Function GetContactInformation(Company) Export
	
	//In the query the Value field is assigned the Presentation attribute, i.e. in the XDTO
	//diagram the Value field shall be filled and the Value attribute is empty for the email address
	
	Query = New Query;
	
	Query.Text =
	"SELECT ALLOWED
	|	CompaniesContactInformation.Type,
	|	CAST(CompaniesContactInformation.Presentation AS String(1000)) AS Value,
	|	CAST(CompaniesContactInformation.Presentation AS String(1000)) AS Comment
	|FROM
	|	Catalog.Companies.ContactInformation AS CompaniesContactInformation
	|WHERE
	|	CompaniesContactInformation.Ref = &Object
	|	AND (CompaniesContactInformation.Type = VALUE(Catalog.ContactInformationKinds.CompanyEmail)
	|			OR CompaniesContactInformation.Type = VALUE(Catalog.ContactInformationKinds.CompanyPhone)
	|			OR CompaniesContactInformation.Type = VALUE(Catalog.ContactInformationKinds.CounterpartyFax))";
	
	Query.SetParameter("Object", Company);
	
	ValTbl = Query.Execute().Unload();
	For Each str IN ValTbl Do
		str.Value    = TrimR(str.Value);
		str.Comment = TrimR(str.Comment);
	EndDo;
	
	Return ValTbl;
	
EndFunction

// It returns the state name by the code
//
// Parameters:
//  StateCode - String containing the two-character state code
//
// Returns:
//  String - state name.
//
Function StateName(StateCode) Export
	
	If IsBlankString(StateCode) Then
		
		Return "";
		
	EndIf;
	
	StateCodeNumber = Number(StateCode);
	Return AddressClassifier.StateNameByCode(StateCodeNumber);
	
EndFunction

// It receives the structure containing the info of the counterparty legal address.
//
// Parameters:
//  StructureOfAddress     - structure - contains references to catalog items.;
//  ParametersStructure - structure - contains references to catalog items.;
//  CounterpartyKind      - String - Catalog metadata name;
//  AddressKind           - String - Fact or Legal;
//  ErrorText         - String - error description;
//
Procedure GetAddressAsStructure(StructureOfAddress, ParametersStructure, CounterpartyKind, AddressKind, ErrorText) Export
	
	StructureOfAddress.Insert("AddressRF", True);
	StructureOfAddress.Insert("StrCode", "");
	StructureOfAddress.Insert("IndexOf", "");
	StructureOfAddress.Insert("CodeState", "");
	StructureOfAddress.Insert("District", "");
	StructureOfAddress.Insert("City", "");
	StructureOfAddress.Insert("Settlement", "");
	StructureOfAddress.Insert("Street", "");
	StructureOfAddress.Insert("Building", "");
	StructureOfAddress.Insert("Section", "");
	StructureOfAddress.Insert("Qart", "");
	StructureOfAddress.Insert("AdrText", "");
	
	If Not ValueIsFilled(ParametersStructure[CounterpartyKind]) Then
		Return;
	EndIf; 
	If TypeOf(ParametersStructure[CounterpartyKind]) = Type("CatalogRef.Companies") Then
		If CommonUse.GetAttributeValue(ParametersStructure[CounterpartyKind], "LegalEntityIndividual") = Enums.CounterpartyKinds.LegalEntity Then
			Object = ParametersStructure[CounterpartyKind];
			ContactInformationKind = ?(AddressKind = "Legal", Catalogs.ContactInformationKinds.CompanyLegalAddress, Catalogs.ContactInformationKinds.CompanyActualAddress);
			CatalogName = "Companies";
		Else
			Object = CommonUse.GetAttributeValue(ParametersStructure[CounterpartyKind], "Individual");
			ContactInformationKind = ?(AddressKind = "Legal", Catalogs.ContactInformationKinds.IndividualAddressByRegistration, Catalogs.ContactInformationKinds.IndividualPlaceOfResidence);
			CatalogName = "Individuals";
		EndIf;
	Else
		Object = ParametersStructure[CounterpartyKind];
		ContactInformationKind = ?(AddressKind = "Legal", Catalogs.ContactInformationKinds.CounterpartyLegalAddress, Catalogs.ContactInformationKinds.CounterpartyFactAddress);
		CatalogName = "Counterparties";
	EndIf;
	
	QueryText =
		"SELECT ALLOWED
		|	ContactInformation.FieldsValues
		|FROM
		|	Catalog." + CatalogName + ".ContactInformation
		|AS
		|ContactInformation WHERE ContactInformation.Ref
		|	= &Ref AND ContactInformation.Type = &Kind";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Ref", Object);
	Query.SetParameter("Kind",    ContactInformationKind);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		AddressStructure = ContactInformationManagement.PreviousStructureOfContactInformationXML(Selection.FieldsValues);
		
		Country = ?(AddressStructure.Property("Country") AND ValueIsFilled(AddressStructure.Country), Catalogs.WorldCountries.FindByDescription(AddressStructure.Country), Catalogs.WorldCountries.Russia);
		If Country <> Catalogs.WorldCountries.EmptyRef() Then
			StructureOfAddress.Insert("StrCode", CommonUse.GetAttributeValue(Country, "Code"));
			StructureOfAddress.Insert("AddressRF", Country = Catalogs.WorldCountries.Russia);
		Else
			StructureOfAddress.Insert("StrCode", "");
			StructureOfAddress.Insert("AddressRF", False);
		EndIf;
		
		If Not StructureOfAddress.AddressRF Then
			StructureOfAddress.Insert("AddressByString", AddressStructure.Presentation);
		EndIf;
		
		StateCode = Undefined;
		AddressStructure.Property("StateCode", StateCode);
		If Not ValueIsFilled(StateCode)
			AND AddressStructure.Property("Region") Then
			AddressStructure.Insert("StateCode", SmallBusinessManagementElectronicDocumentsServer.StateCodeByName(AddressStructure.Region));
		EndIf;
		
		AddressStructure.Property("IndexOf",          StructureOfAddress.IndexOf);
		AddressStructure.Property("StateCode",      StructureOfAddress.CodeState);
		AddressStructure.Property("District",           StructureOfAddress.District);
		AddressStructure.Property("City",           StructureOfAddress.City);
		AddressStructure.Property("Settlement", StructureOfAddress.Settlement);
		AddressStructure.Property("Street",           StructureOfAddress.Street);
		AddressStructure.Property("Building",             StructureOfAddress.Building);
		AddressStructure.Property("Section",          StructureOfAddress.Section);
		AddressStructure.Property("Apartment",        StructureOfAddress.Qart);
	EndIf;
	
EndProcedure

// It receives the counterparty email address.
//
// Parameters:
//  Counterparty - catalog - reference to counterparty
//                            catalog item which address shall be received.
//
// Returns:
//  EMail_Address - email address.
//
Function CounterpartyEMailAddress(Counterparty) Export
	
	EMail_Address = "";
	
	If ValueIsFilled(Counterparty) Then
		
		Recipients = New ValueList;
		Recipients.Add(Counterparty);
		
		RecipientsEmailAddresses = SmallBusinessContactInformationServer.PrepareRecipientsEmailAddresses(Recipients, False);
		
		If RecipientsEmailAddresses.Count() > 0 Then
			
			EMail_Address = RecipientsEmailAddresses[0].Address;
			
		EndIf;
		
	EndIf;
	
	Return EMail_Address;
	
EndFunction

// It receives a printed document number.
//
// Parameters:
//  ObjectReference - DocumentRef - ref to the infobase document.
//
// Returns:
//  ObjectNumber - document number.
//
Function GetDocumentPrintNumber(ObjectReference) Export
	
	If ValueIsFilled(ObjectReference) Then
	
		If ObjectReference.Date < Date('20110101') Then
			
			DocumentNumber = SmallBusinessServer.GetNumberForPrinting(ObjectReference.Number, ObjectReference.Company.Prefix);
			
		Else
			
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(ObjectReference.Number, True, True);
			
		EndIf;
		
	EndIf;
	
	Return DocumentNumber;
	
EndFunction

// It receives banking accounts.
//
// Parameters:
//  Company - CatalogRef.Company - ref to the company.
//  Bank - CatalogRef - reference to catalog item with banks
//
// Returns:
//  Table - value table with a list of bank accounts.
//
Function GetBankAccounts(Company, Bank = Undefined) Export
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED
	|	BankAccounts.Ref AS BankAccount
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|WHERE
	|	BankAccounts.Owner = &Company
	|	AND &FilterConditionByBank";
	
	Query.SetParameter("Company", Company);
	
	If ValueIsFilled(Bank) Then
		
		Query.Text = StrReplace(Query.Text, "&FilterByBankConditions", "BankAccounts.Bank = &Bank");
		Query.SetParameter("Bank", Bank);
		
	Else
		
		Query.SetParameter("FilterConditionByBank", True);
		
	EndIf;
	
	Return Query.Execute().Unload();
	
EndFunction

// It receives banking details.
//
// Parameters:
//  AccountsArray - array - list of bank accounts.
//
// Returns:
//  Table - list of bank details.
//
Function GetBankAttributes(AccountsArray) Export
	
	Table = New ValueTable;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	BankAccounts.Ref AS Ref,
	|	BankAccounts.AccountNo AS BankAccount,
	|	ISNULL(BankAccounts.Bank.CorrAccount, """") AS CorrespondentAccount,
	|	ISNULL(BankAccounts.Bank.Code, """") AS BIN,
	|	ISNULL(BankAccounts.Bank.Description, """") AS Bank,
	|	ISNULL(BankAccounts.AccountsBank.Description, """") AS SettlementBank,
	|	ISNULL(BankAccounts.AccountsBank.Code, """") AS AccountingBankBIC,
	|	ISNULL(BankAccounts.AccountsBank.CorrAccount, """") AS SettlementsCorrespondentAccountBank
	|FROM
	|	Catalog.BankAccounts AS BankAccounts
	|WHERE
	|	BankAccounts.Ref IN(&AccountsArray)";
	Query.SetParameter("AccountsArray", AccountsArray);
	
	Table = Query.Execute().Unload();
	
	Return Table;
	
EndFunction

// Fills the signatory parameter structure for ED of the Receipt Note type.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  ParametersOfStructureToSeller - structure - parameters for filling signatory of the electronic document.
//
Procedure FillSignerDataStructure(ObjectReference, EDStructure, ParametersOfStructureToSeller) Export
	
	
	
EndProcedure

// The invoice document attributes are filled in the
// procedure (issue date, issue flag, receipt date, receipt flag)
// based on the key events described in the Decree No. 50n from April 25, 2011.: getting DTP, SDO, FE, PDOIP.
//
// Parameters:
//  EDOwner - document-ref, reference to IB document Invoice issued/received.
//  ED - catalog-ref, reference to EDAttachedFiles catalog item.
//
Procedure FillESFAttributes(EDOwner, ED) Export
	
	If ED.VersionPointTypeED = Enums.EDVersionElementTypes.EIRDC Then
		
		//  The date of customer invoice note issue in
		// electronic form through the telecommunication links is considered to be the date
		// of receiving the invoice note file by the EDF Operator from the seller as specified in the confirmation (CEINRD) of this EDF Operator.  DECREE No. 50n from April 25, 2011
		
		ESF = EDOwner.GetObject();
		ESF.DataExchange.Load = True; 
		ESF.DateOfExtension = ED.SenderDocumentDate;
		ESF.Write();
		
	ElsIf ED.VersionPointTypeED = Enums.EDVersionElementTypes.EISDC Then
		
		//  The date of the customer invoice note reception in electronic form by telecommunication links is considered to be the date of forwarding the seller invoice note file to the the customer by the EDF Operator as specified in the  confirmation (CEINSD) of the EDF operator.  DECREE No. 50n from April 25, 2011
		
		ESF = EDOwner.GetObject();
		ESF.DataExchange.Load = True; 
		ESF.Date = ED.SenderDocumentDate;
		ESF.Write();
		
	ElsIf ED.VersionPointTypeED = Enums.EDVersionElementTypes.NAREI Then
		
		//  Customer invoice note in electronic form is considered to be issued if the seller received the corresponding Confirmation (CEINRD) of EDF operator in case the seller has the customer notification of the invoice note receipt (NEINR) signed by the customer DS and received by the EDF operator.
		// DECREE No. 50n from April 25, 2011
		
		ESF = EDOwner.GetObject();
		ESF.DataExchange.Load = True; 
		// It is decided not to add Issued and
		// IssuingMethodCode attributes to the configuration in order to simplify the interface.
		ESF.Write();
		
	ElsIf ED.VersionPointTypeED = Enums.EDVersionElementTypes.SDANAREIC Then
		
		//  Customer invoice note in electronic form is considered to
		// be received by the customer if the customer received the
		// corresponding confirmation (CEINSD) of the EDF operator in case the
		// customer notified of the invoice note receipt (NEINR) signed by the customer DS and confirmed by the EDF Operator (CNEINRSD).  DECREE No. 50n from April 25, 2011
		
		ESF = EDOwner.GetObject();
		ESF.DataExchange.Load = True; 
		// It is decided not to add
		// the ReceivingMethodCode attribute to the configuration in order to simplify the interface.
		ESF.Write();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// View of electronic documents

// It returns a company text description.
//
// Parameters:
//  InfoAboutCounterparty - Structure, information of the company to be made a description.
//  List - String, list of requested company parameters.
//  WithPrefix - Boolean, flag of the company parameter prefix output.
//
Function CompaniesDescriptionFull(InfoAboutCounterparty, List = "", WithPrefix = True) Export
	
	Return SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCounterparty, List, WithPrefix);
	
EndFunction

// It generates VAT text for the payment step
//
// Parameters:
//  AccordanceOfRatesVAT - Map - matching received using the
//  function GetVATRatesMatching() PaymentPercent       - Number - Step payment percentage
//
// Returns:
//  TextVAT - String - VAT rate description
//
Function GenerateTextVATPaymentStage(AccordanceOfRatesVAT, PaymentPercent) Export
	
	TextVAT = "";
	
	If AccordanceOfRatesVAT.Count() > 0 Then
		
		For Each CurVATRate IN AccordanceOfRatesVAT Do
			
			If CurVATRate.Value <> 0 Then
				
				TextVAT = TextVAT + ?(IsBlankString(TextVAT), NStr("en='VAT(%VATRate%) %VATAmount%';ru='НДС(%VATRate%) %VATAmount%'"), NStr("en=', VAT(%VATRate%) %VATAmount%';ru=', НДС(%СтавкаНДС%) %СуммаНДС%'"));
				TextVAT = StrReplace(TextVAT, "%VATRate%", CurVATRate.Key);
				TextVAT = StrReplace(TextVAT, "%VATAmount%",  Format(CurVATRate.Value / 100 * PaymentPercent, "ND=15; NFD=2"));
			
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(TextVAT) Then
		TextVAT = NStr("en='including ';ru='в т.ч. '") + TextVAT;
	Else
		TextVAT = NStr("en='Without tax (VAT)';ru='Без налога (НДС)'");
	EndIf;
	
	Return TextVAT;	
EndFunction

// It returns the amount text presentation.
//
// Parameters:
//  AmountToBeWrittenInWords - Number, amount for which you shall receive presentation.
//  CurrencyCode - Number, code of the currency.
//  NZ - String, parameter of the number zero value.
//  NGS - String, group separator of the number integral part.
//
Function AmountsFormat(AmountToBeWrittenInWords, CurrencyCode = Undefined, NZ = "", NGS = "") Export
	
	Currency = FindRefToObject("Currencies",CurrencyCode);
	
	Return SmallBusinessServer.AmountsFormat(AmountToBeWrittenInWords, Currency,  NZ, NGS);
	
EndFunction

// It returns the amount in words.
//
// Parameters:
//  AmountAsNumber - Number, converted amount.
//  CurrencyCode - Number, code of the currency.
//
Function AmountInWords(AmountAsNumber, CurrencyCode) Export
	
	Currency = ?(IsBlankString(CurrencyCode), Constants.NationalCurrency.Get(), FindRefToObject("Currencies", CurrencyCode));
	
	Return SmallBusinessServer.GenerateAmountInWords(AmountAsNumber, Currency);
	
EndFunction

// It generates VAT rate text for the printed form of an account and order
//
// Parameters:
//  VATRate       - EnumRef.VATRates - VAT rate for which it is
//  necessary to generate PriceIncludesVAT text - Boolean - Sign of VAT inclusion to the price
//
// Returns:
//  String
//
Function TextVATByRate(VATRate, PriceIncludesVAT) Export
	
	TextVATByRate = ?(PriceIncludesVAT, NStr("en='Including VAT (%VATRate%):';ru='В т.ч. НДС (%СтавкаНДС%):'"), NStr("en='VAT (%VATRate%):';ru='НДС (%СтавкаНДС%):'"));
	TextVATByRate = StrReplace(TextVATByRate, "%VATRate%", VATRate);
	
	Return TextVATByRate;
	
EndFunction

// It returns the numeric value of the VAT rate by the enum value
//
// Parameters:
//  VATRate - EnumRef.VATRates - VATRate enumeration value
//
// Returns:
//  Number - VAT rate value
//  by number If VATRate = 0% then the number = 0;
//  If VATRate = WithoutVAT then the number = Undefined.
//
Function GetVATRateAsNumber(Val VATRate) Export
	
	If TypeOf(VATRate) = Type("CatalogRef.VATRates") Then
		Return VATRate.Rate;
	Else
		Return 0;
	EndIf;
	
EndFunction

// The function converts VAT rate numeric presentation to the enumeration value.
//
// Parameters:
//  RateAsNumber - Number - VAT number rate.
//
// Returns:
//  VATRate - Enum
//  value If RateNumber = 0 then VATRate = 0%;
//  If RateByNumber = Undefined then VATRate = WithoutVAT.
//
Function EnumerationValueVATRate(RateAsNumber) Export
	
	If TypeOf(RateAsNumber) = Type("String") Then
		VATRatePresentation = RateAsNumber;
	ElsIf TypeOf(RateAsNumber) = Type("Number") Then 
		VATRatePresentation = String(RateAsNumber);
	Else // Wrong type
		VATRatePresentation = Undefined;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Description LIKE &CatalogItemDescription
	|	AND VATRates.NotTaxable = &NotTaxable
	|	AND VATRates.Calculated = &Calculated");
	
	//In case it is not possible to define the VAT rate, leave the field blank
	CatalogItemDescription = Undefined;
	NotTaxable 					= Undefined;
	Calculated 						= Undefined;
	
	If VATRatePresentation = Undefined OR UPPER(VATRatePresentation) = UPPER("Without VAT") Then
		
		CatalogItemDescription = "Without VAT";
		NotTaxable 					= True;
		Calculated 						= False;
		
	ElsIf VATRatePresentation = "0" Then
		
		CatalogItemDescription = "0%";
		NotTaxable 					= False;
		Calculated 						= False;
		
	ElsIf Find("10#0.1#0,1#0.10#0,10", VATRatePresentation) > 0 Then
		
		CatalogItemDescription = "10%";
		NotTaxable 					= False;
		Calculated 						= False;
		
	ElsIf Find("18#0.18#0,18#0.18#0,18", VATRatePresentation) > 0 Then
		
		CatalogItemDescription = "18%";
		NotTaxable 					= False;
		Calculated 						= False;

	ElsIf Find("10/110#10% / 110%#10%/110%", VATRatePresentation) > 0 Then
		
		CatalogItemDescription = "10% / 110%";
		NotTaxable 					= False;
		Calculated 						= True;
		
	ElsIf Find("18/118#18% / 118%#18%/118%", VATRatePresentation) > 0 Then
		
		CatalogItemDescription = "18% / 118%";
		NotTaxable 					= False;
		Calculated 						= True;
		
	EndIf;
	
	Query.SetParameter("CatalogItemDescription", CatalogItemDescription);
	Query.SetParameter("NotTaxable", 					NotTaxable);
	Query.SetParameter("Calculated", 						Calculated);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
	
		Return Selection.Ref;
	
	EndIf;
		
	Return Undefined;
	
EndFunction

// Returns the person responsible for the electronic document flow according to the agreement
//
// Parameters:
//  Counterparty - CatalogRef.Counterparties, reference to the counterparty for which you shall receive the responsible person.
//  Agreement - CatalogRef.EDUsageAgreement, reference to the agreement used to find the responsible person.
//
Function GetResponsibleByED(Counterparty, Agreement) Export
	
	ResponsibleByED = Users.CurrentUser();
	Return ResponsibleByED;
	
EndFunction

// Returns the flag of ind. person.
//
// Parameters:
//  CounterpartyData - Reference to catalog item.
//
Function ThisIsInd(CounterpartyData) Export
	
	If CounterpartyData.Metadata().Attributes.Find("LegalEntityIndividual") = Undefined Then
		Return False;
	EndIf;
	
	LegalEntityIndividual = CounterpartyData.LegalEntityIndividual;
	
	If TypeOf(LegalEntityIndividual) <> Type("EnumRef.LegalEntityIndividual") Then
		Return False;
	EndIf;
		
	ThisIsInd = False;
	If LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
		ThisIsInd = True;
	EndIf;
	
	Return ThisIsInd;
	
EndFunction

// The function returns whether it is required to print discount data to the document printed form
//
Function NeedToOutputDiscounts(Val Products, UseDiscounts) Export
	
	
	
	Return False;
	
EndFunction

// It receives the name of additional column.
//
// Returns:
//  ColumnName - column string.
//
Function AdditionalColumnName() Export
	
	Return "SKU";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Overriding electronic document performance

// This event occurs at EDAttachedFiles catalog
// item changing It is intended for overriding or adding changed attributes of the electronic document
//
// Parameters:
//  Object - CatalogRef.EDAttachedFiles - ParametersStructure
//  object to be changed - Structure, contains the structure of the changing attributes
//
Procedure OnChangeOfAttachedFile(Object, ParametersStructure) Export
	
	If Not ParametersStructure.Property("Responsible") Then
		ParametersStructure.Insert("Responsible", Users.AuthorizedUser());
	EndIf;
	
EndProcedure

// Performs additional processing of the electronic document with the appointed Approved status.
// 
// Parameters:
//  ElectronicDocument - references to attached file.
//
Procedure ConfirmedStatusApplied(ElectronicDocument) Export
	
	Try
		FileObject = ElectronicDocument.GetObject();
		FileObject.Changed = SessionParameters.CurrentUser;
		FileObject.Write();
	Except
		MessageText = BriefErrorDescription(ErrorInfo()) + NStr("en=' (see details in Event log monitor).';ru=' (подробности см. в Журнале регистрации).'");
		ErrorText = DetailErrorDescription(ErrorInfo());
		ElectronicDocuments.ProcessExceptionByEDOnServer(NStr("en='ED Approval';ru='утверждение ЭД'"), ErrorText, MessageText);
	EndTry;
	
EndProcedure

// Performs additional processing of the electronic document with the appointed Signed status.
// 
// Parameters:
//  ElectronicDocument - references to attached file.
//
Procedure AssignedStatusDigitallySigned(ElectronicDocument) Export
	
EndProcedure

// Checks the IB document readiness for ED creation and removes the documents that are not ready from the array
//
// DocumentsArray
//  parameters - Array   - references to documents to be checked before the ED generation.
//
Procedure CheckSourcesReadiness(DocumentsArray, FormSource = Undefined) Export
	
	CommonUseClientServer.DeleteAllTypeOccurrencesFromArray(DocumentsArray, Type("DynamicalListGroupRow"));
	
	// It is not necessary to generate ED based on the invoices with the InvoiceIsNotIssued flag
	NotIssuedInvoicesArray = New Array();
	
	MessagePattern = NStr("en='The ""%1"" document is not issued.';ru='Документ ""%1"" не выставляется.'");
	For Each Document IN NotIssuedInvoicesArray Do
		Found = DocumentsArray.Find(Document);
		If Found <> Undefined Then
			DocumentsArray.Delete(Found);
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(Document)), 
				Document);
		EndIf;
	EndDo;
	
	// Before ED generating IB documents shall be posted
	ArrayOfUnpostedDocuments = CommonUseServerCall.CheckThatDocumentsArePosted(DocumentsArray);
	UnpostedDocumentsCount = ArrayOfUnpostedDocuments.Count();
	
	If UnpostedDocumentsCount = 0 Then
		Return;
	Else
		If UnpostedDocumentsCount = 1 Then
			Text = NStr("en='Post the document before generating ED.';ru='Перед формированием ЭД документ необходимо провести.'");
		Else
			Text = NStr("en='Post documents before generating ED.';ru='Перед формированием ЭД документы необходимо провести.'");
		EndIf;
	EndIf;
	CommonUseClientServer.MessageToUser(Text);
	
	MessagePattern = NStr("en='Document %1 is not posted.';ru='Документ %1 не проведен.'");
	For Each UnpostedDocument IN ArrayOfUnpostedDocuments Do
		Found = DocumentsArray.Find(UnpostedDocument.Ref);
		If Found <> Undefined Then
			DocumentsArray.Delete(Found);
			CommonUseClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(UnpostedDocument.Ref)), 
																		UnpostedDocument.Ref);
		EndIf;
	EndDo;
	
EndProcedure

// Checks whether all necessary signatures are set before sending to counterparty.
// 
// Parameters:
//  ElectronicDocument - references to attached file.
//  FlagFullyDigitallySigned - Boolean - flag of a completely signed document.
//
Procedure ElectronicDocumentFullyDigitallySigned(ElectronicDocument, FlagFullyDigitallySigned) Export
	
EndProcedure

// Checks whether all necessary automatic conditions for the document approval are fulfilled.
//
// Parameters:
//  ElectronicDocument - references to attached file.
//
Function ElectronicDocumentReadyToBeConfirmed(ElectronicDocument) Export
	
	Return True;
EndFunction

// It defines whether it is possible to edit the infobase object
//
// Parameters
//  <ObjectRef>  - <any ref> - ref to
//  the checked object <EditingIsAllowed> - <Boolean>   - returns allowed or no editing
//
Function CheckObjectEditingPossibility(ObjectReference, EditAllowed) Export

	
	
EndFunction

// Checking the possibility of ED Package correct reading is running.
// The need for this check appears while working with external infobase data (via the com-connection).
//
// Parameters:
//  EDPackage - DocumentRef.EDPackage - reviewed package of electronic documents.
//  PackageReadingPossible - Boolean/undefined - False - the package will not be read, in
//    all other cases (including the empty value) the package will be read.
//
Procedure DetermineEDPackageBinaryDataReadingPossibility(EDPackage, PackageReadingPossible) Export
	
	
	
EndProcedure

// It checks the correctness of the electronic document parameter filling.
//
// Parameters:
//  EDParameters - structure - ED parameter list.
//
// Returns:
//  Boolean - True if the export object is properly filled
//
Function CheckFillingObjectCorrectness(EDParameters) Export
	
	
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with rights

// It checks the availability of rights to handle electronic documents.
//
// Returns:
//  Boolean - true or false depending on the specified rights.
//
Function IsRightToProcessED() Export
	
	Result = Users.RolesAvailable("EDExchangeExecution, FullRights");
	
	Return Result;
	
EndFunction

// Checks the availability of the rights to read electronic documents.
//
// Returns:
//  Boolean - true or false depending on the specified rights.
//
Function IsRightToReadED() Export
	
	Result = Users.RolesAvailable("EDExchangeExecution, EDReading, FullRights");
	
	Return Result;
	
EndFunction

// It checks the availability of rights to open the event log.
//
// Returns:
//  Boolean - true or false depending on the specified rights.
//
Function HasRightToOpenEventLogMonitor() Export
	
	Result = Users.InfobaseUserWithFullAccess();
	
	Return Result;
	
EndFunction

// It checks the availability of rights to configure electronic document settings.
//
// Returns:
//  Boolean - true or false depending on the specified rights.
//
Function HasRightSettingsSettingsED() Export
	
	Result = Users.RolesAvailable("EDParametersSetting") OR Users.InfobaseUserWithFullAccess();
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with the form items

// It changes the behavior of the controlled or standard form items.
//
// Parameters:
//  Form - <Managed or standard form> - managed or standard form to be changed.
//  ParametersStructure - <Structure> - procedure parameters
//
Procedure ChangeFormItemsProperties(Form, ParametersStructure) Export
	
	If ParametersStructure.Property("OperationKind")
		AND ParametersStructure.Property("ParameterValue") Then
		
		If Upper(ParametersStructure.OperationKind) = Upper("HyperlinkSetting")
			AND ParametersStructure.Property("EDStateText") Then
			
			// Set special conditions.
			If Find(ParametersStructure.EDStateText, "Not formed") > 0 Then
				
				ParametersStructure.ParameterValue = False;
				
			EndIf;
			
			// Define the form item.
			FoundFormItem = Undefined;
			If TypeOf(Form) = Type("ManagedForm") Then // only for the managed form
				
				If Not Form.Items.Find("EDStatus") = Undefined Then
					
					FoundFormItem = Form.Items.EDStatus;
					
				EndIf;
				
				// Fill in the property of the found item.
				If Not FoundFormItem = Undefined
					AND FoundFormItem.Type = FormFieldType.LabelField Then
					
					FoundFormItem.Hyperlink = ParametersStructure.ParameterValue;
					
				EndIf;
				
			Else // for a standard form
				
				If Not Form.FormItems.Find("EDStateText") = Undefined Then
					
					FoundFormItem = Form.FormItems.EDStateText;
					
				EndIf;
				
				// Fill in the property of the found item.
				If Not FoundFormItem = Undefined
					AND TypeOf(FoundFormItem) = Type("Label") Then
					
					FoundFormItem.Hyperlink = ParametersStructure.ParameterValue;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If TypeOf(Form) = Type("ManagedForm") Then // only for the managed form
		
		If Not IsRightToReadED() Then
			
			If Not Form.Items.Find("GroupEDState") = Undefined Then
				
				Form.Items.GroupEDState.Visible = False;
				
			ElsIf Not Form.Items.Find("EDStatus") = Undefined Then
				
				Form.Items.EDStatus.Visible = False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// IN the procedure you can create a list of users
// whom you can redirect electronic documents (EDArray) for review. If the list of users is defined in
// the procedure, it will be used as the dropdown list in the DataProcessor form.ElectronicDocuments.RedirectED.
//
// Parameters:
//    EDKindsArray           - Array - array items - references to electronic documents
//                       to be redirected for review to the user specified in the ED redirection form.
//    UserArray - Array - returned array of users for the dropdown recipient selection list.
//
Procedure UsersListForQuickSelectionWhenRedirectingToReviewED(
	EDKindsArray, UserArray) Export
	
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Non-recurring transaction mechanism

// It fills the document list by the electronic document kind.
//
// Parameters:
//  EDKind           - Enums   - Electronic document kind;
//  ReturnList  - ValueList - list of references to the infobase documents.
//
Procedure DocumentsKindsListByEDKind(EDKind, ReturnList) Export
	
	If EDKind = Enums.EDKinds.TORG12 OR EDKind = Enums.EDKinds.TORG12Seller Then
		ReturnList.Add(Documents.SupplierInvoice.EmptyRef(),
			Metadata.Documents.SupplierInvoice.Presentation());
	EndIf;
	
EndProcedure

// Specifies the default attachment file name and proposes the user
// to the save ED with this name at exporting using the Single Transaction script.
//
// Parameters:
//  EDOwner - reference to the IB document based on which ED
//  is formed and exported, FileDescription - String - attachment file name.
//
Procedure AssignSavedFileNameOnQuickExchange(EDOwner, FileDescription) Export
	
EndProcedure

// It receives the attributes of Companies catalog item for exporting to xml file.
//
// Parameters:
//  Company - CatalogRef.Companies - Company catalog item;
//  ReturnStructure - structure - company parameter list.
//
Procedure GetCompanyAttributesForExportToFile(Company, ReturnStructure) Export
	
	CompanyAttributes = CommonUse.ObjectAttributesValues(Company, 
		"Description, DescriptionFull, TIN, LegalEntityIndividual, CertificateSeriesNumber, CertificateIssueDate");
		
	FillPropertyValues(ReturnStructure, CompanyAttributes);
	
	CompanyLegalAddress = SmallBusinessManagementElectronicDocumentsServer.GetAddressOfContactInformation(Company, "Legal");
	ReturnStructure.LegalAddress     = CompanyLegalAddress.Presentation;
	ReturnStructure.FieldsValuesLegAddress = CompanyLegalAddress.FieldsValues;
	
	CounterpartyFactAddress = SmallBusinessManagementElectronicDocumentsServer.GetAddressOfContactInformation(Company, "Fact");
	ReturnStructure.ActualAddress       = CounterpartyFactAddress.Presentation;
	ReturnStructure.FieldsValuesFactAddress = CounterpartyFactAddress.FieldsValues;
	
	ReturnStructure.Phone = SmallBusinessManagementElectronicDocumentsServer.GetPhoneFromContactInformation(Company);
	
	If ReturnStructure.LegalEntityIndividual = Enums.CounterpartyKinds.LegalEntity Then
		StructureOfResponsible = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Company, CurrentSessionDate());
		ReturnStructure.Head          = StructureOfResponsible.HeadDescriptionFull;
		ReturnStructure.HeadPost = StructureOfResponsible.HeadPosition;
	Else
		ReturnStructure.CertificateNumber = CompanyAttributes.CertificateSeriesNumber;
		ReturnStructure.CertificateDate  = CompanyAttributes.CertificateIssueDate;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Overriding messages to the user

// It overrides the displayed
// error message ErrorCode - ErrorText
// string - String
Procedure ChangeMessageAboutError(ErrorCode, ErrorText) Export
	
	If ErrorCode = "100" OR ErrorCode = "110" Then
		ErrorText = "Check common cryptography settings."
	EndIf;
	
EndProcedure

// Defines the message text of the system configuration necessity depending on the operation kind.
//
// Parameters:
//  OperationKind    - String - sign of the performed operation;
//  MessageText - String - message type.
//
Procedure MessageTextAboutSystemSettingRequirement(OperationKind, MessageText) Export
	
	If Upper(OperationKind) = "WorkWithED" Then
		MessageText = NStr("en='To work with electronic documents,
		|it is required to enable elecronic documents exchange in the system settings.';ru='Для работы с электронными
		|документами необходимо в настройках системы включить использование обмена электронными документами.'");
	ElsIf Upper(OperationKind) = "SigningOfED" Then
		MessageText = NStr("en='To sign ED, it
		|is required to enable option of using electronic digital signatures in the system settings.';ru='Для возможности
		|подписания ЭД необходимо в настройках системы включить опцию использования электронных цифровых подписей.'");
	ElsIf Upper(OperationKind) = "SettingCryptography" Then
		MessageText = NStr("en='To configure cryptography, enable the option of digital signature usage in the application settings.';ru='Для возможности настройки криптографии необходимо в настройках системы включить опцию использования электронных цифровых подписей.'");
	ElsIf Upper(OperationKind) = "BANKOPERATIONS" Then
			MessageText = NStr("en='To exchange ED with banks, select the option of direct exchange with banks in the application settings.';ru='Для возможности обмена ЭД с банками необходимо в настройках программы включить опцию использования прямого обмена с банками.'");
	Else
		MessageText = NStr("en='Operation cannot be executed. The required application settings are not configured.';ru='Операция не может быть выполнена. Не выполнены необходимые настройки программы.'");
	EndIf;
	
EndProcedure

// It overrides the message about the limitation of the access rights
//
// Parameters:
//  MessageText - Message string
//
Procedure PrepareMessageTextAboutAccessRightsViolation(MessageText) Export
	
	// If necessary you can override or add the message text
	
EndProcedure

// Gets a parameter match table for metadata types and their user presentations.
//
// Parameters:
//  MapTable - table - matching of parameter for metadata types
//  and their user presentations contains the following columns: SourceType, Parameter, Presentation.
//
Procedure GetCorrespondenceTableParametersToUserPresentations(MapTable) Export
	
	Template			    = DataProcessors.ElectronicDocuments.GetTemplate("UserPresentationOfMandatoryFields");
	DocumentsArea	  = Template.GetArea("MandatoryFields");
	DocumentsAreaHeight = DocumentsArea.TableHeight;

	For NStr = 1 To DocumentsAreaHeight Do
		
		NewRow = MapTable.Add();
		NewRow.SourceType  = Type(TrimAll(DocumentsArea.Area(NStr, 1).Text));
		NewRow.Parameter	 = TrimAll(DocumentsArea.Area(NStr, 2).Text);
		NewRow.Presentation = TrimAll(DocumentsArea.Area(NStr, 3).Text);
	EndDo;
	
EndProcedure

// Fills in the matching of the ED diagram attribute codes and their user presentation.
//
// Parameters:
//  ConformityOfReturn - Map, the original matching for filling.
//
Procedure MapOfAttributesAndPresentationsCodes(ConformityOfReturn) Export
	
	Template = DataProcessors.ElectronicDocuments.GetTemplate("ApplicationAttributePresentations");
	TableHeight = Template.TableHeight;
	For NStr = 1 To TableHeight Do
		ConformityOfReturn.Insert(TrimAll(Template.Area(NStr, 1).Text), TrimAll(Template.Area(NStr,2).Text));
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common procedures and functions

// It creates a table of a type creation order when exporting the electronic document.
//
// Returns:
//  Table - values table.
//
Function FillObjectTypesCreationOrderTable() Export
	
	Table = New ValueTable;
	
	Table.Columns.Add("ObjectType");
	Table.Columns.Add("Order");
	
	NewRow = Table.Add();
	NewRow.ObjectType = "SuppliersProductsAndServices";
	NewRow.Order    = 2;
	
	Return Table;
	
EndFunction

// If necessary, in the fuction you can define a
// directory for temporary files that differs from the default one in the ED library.
//
// Parameters:
//  GetCurrentDirectory - path to the temporary file folder.
//
Procedure TemporaryFilesCurrentDirectory(GetCurrentDirectory) Export
	
	GetCurrentDirectory = TempFilesDir();
	
EndProcedure

// It receives temp attachment file name.
//
// Parameters:
//  TempFileName - String - Temp attachment file name;
//  Extension - String - extension for temporary file.
//
Procedure TemporaryFileCurrentName(TempFileName, Extension = "") Export
	
	TempFileName = GetTempFileName(Extension);
	
EndProcedure

// It finds surname, name and patronymic in the passed string.
//
// Parameters
//  FullDescr - String with the description;
//  Surname - String with the surname;
//  Name - String with the name;
//  Patronymic - String with patronymic.
//
Procedure ParseIndividualDescription(FullDescr, Surname = " ", Name = " ", Patronymic = " ") Export
	
	IndividualsClientServer.SurnameInitialsOfIndividual(FullDescr, Surname, Name, Patronymic);
	
EndProcedure

// Parses the file with
// counterparty details, it is possible to change the structure of the returned data
//
// Parameters:
//  FileReference - address of file storage with counterparty details;
//  ReturnStructure - Structure - parameter list;
//  ParseError - text, error description.
//
// Returns:
//  ParcingResult - Boolean - True - file review is not performed; False - the file was not parsed.
//
Procedure ParseCounterpartyAttributesFile(FileReference, ReturnStructure, ParcingResult, ParseError) Export
	
	
EndProcedure

// It returns a structure containing attribute values read
// from the infobase by the object link.
// 
// If the alternate algorithm for attribute value receiving is not specified (empty procedure), we use SSL function:
// CommonUse.ObjectAttributesValues(Refs, AttributeNames).
// 
// Parameters:
//  Ref       - ref to object, - catalog item, document, ...
//  AttributeNames - String or Structure - if String, the attribute names
// listed comma separated in the format of requirements to structure attributes.
//               For example, "Code, Name, Parent".
//               If it is Structure, the field alias is transferred
//               as the key for the returned structure with the result and as the value (optional) 
//               - actual field name in the table. 
//               If the value is not specified, then the field name is taken from the key.
//  DataStructure - contains the list of attributes as
//                 the list of names in
//                 AttributeNames string with attribute values read from the infobases.
// 
Procedure GetAttributesValuesStructure(Ref, AttributeNames, DataStructure) Export
	
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Exchange with bank

// It is used to include Sberbank subsystem to the applied solution.
//
// Parameters:
//  UsageFlag - <Boolean> - Set True if Sberbank subsystem is used.
//
Procedure ValidateUseSubsystemsSberbank(UsageFlag) Export
	
	UsageFlag = False;
	
EndProcedure

// It is used to receive account numbers in the string array form
//
// Parameters:
//  Company - <CatalogRef.Companies> - filter by the company.
//  Bank - <CatalogRef.RFBankClassifier> - filter by the bank.
//  BankAccountNumbersArray - return array, in the string items with the account numbers
//
Procedure GetBankAccountNumbers(Company, Bank, BankAccountNumbersArray) Export
	
	Query = New Query;
	Query.Text = "SELECT
	               |	BankAccounts.AccountNo
	               |FROM
	               |	Catalog.BankAccounts AS BankAccounts
	               |WHERE
	               |	BankAccounts.Bank = &Bank
	               |	AND BankAccounts.Owner = &Company
	               |	AND Not BankAccounts.DeletionMark";
	Query.SetParameter("Bank", Bank);
	Query.SetParameter("Company", Company);
	TabRez = Query.Execute().Unload();
	BankAccountNumbersArray = TabRez.UnloadColumn("AccountNo");
	
EndProcedure

// The matching of VAT rate (used in EDB) string representations
// and the applied values of the rates are specified in the procedure.
//
// Parameters:
//   Map - Map - VAT rate matching to be filled.
//
// Example:
//   Matching.Insert("0",       Enums.VATRates.VAT0);
//   Matching.Insert("10",      Enums.VATRates.VAT10);
//   Matching.Insert("18",      Enums.VATRates.VAT18);
//   Matching.Insert("10/110",  Enums.VATRates.VAT10_110);
//   Matching.Insert("18/118",  Enums.VATRates.VAT18_118);
//   Matching.Insert("without VAT", Enums.VATRates.WithoutVAT);
//
Procedure FillVATRateMatching(Map) Export
	
	Map.Insert("0",       Catalogs.VATRates.EmptyRef());
	Map.Insert("10",      Catalogs.VATRates.EmptyRef());
	Map.Insert("18",      Catalogs.VATRates.EmptyRef());
	Map.Insert("20",      Catalogs.VATRates.EmptyRef());
	Map.Insert("10/110",  Catalogs.VATRates.EmptyRef());
	Map.Insert("18/118",  Catalogs.VATRates.EmptyRef());
	Map.Insert("20/120",  Catalogs.VATRates.EmptyRef());
	Map.Insert("Without VAT", Catalogs.VATRates.EmptyRef());
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	""0"" AS Rate,
	|	VATRates.Ref AS Value
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""10"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 10
	|	AND Not VATRates.Calculated
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""18"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 18
	|	AND Not VATRates.Calculated
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""20"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 20
	|	AND Not VATRates.Calculated
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""10/110"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 10
	|	AND VATRates.Calculated
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""18/118"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 18
	|	AND VATRates.Calculated
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""20/120"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 20
	|	AND VATRates.Calculated
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	""Without VAT"",
	|	VATRates.Ref
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 0
	|	AND VATRates.NotTaxable";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Map.Insert(Selection.Rate, Selection.Value);
	EndDo;
	
EndProcedure

// The procedure returns the usage flag of the
// catalog "Products and services characteristics" as an additional analytic tool to the Products and services catalog.
//
// Parameters:
//  ProductsAndServicesCharacteristicsCatalogIsUsed - Boolean - flag showing the usage in the library of catalog "Products and services characteristics".
//
Procedure AdditionalAnalyticsCatalogProductsAndServicesCharacteristics(ProductsAndServicesCharacteristicsCatalogIsUsed) Export
	
	ProductsAndServicesCharacteristicsCatalogIsUsed = GetFunctionalOption("UseCharacteristics");
	
EndProcedure

// It prepares data for the electronic document of Company Details type of CML 2 format.
//
// Parameters: 
// ObjectReference - CatalogRef, reference to the infobase object used to create an electronic document.
// EDStructure - Structure, data structure to generate an electronic document.
//  DocumentTree - values tree - value tree corresponding CompanyAttributes layout of ElectronicDocuments DataProcessor.
//
Procedure FillInDataCompanyDetails(ObjectReference, EDStructure, DataTree) Export


EndProcedure

// It prepares data for the electronic document of PriceList type of CML 2 format.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DocumentTree - Value tree - Value tree corresponding to the PriceList layout of ElectronicDocuments DataProcessor.
//
Procedure FillInDataByPriceList(ObjectReference, EDStructure, DocumentTree) Export
		
EndProcedure

// It prepares data for the electronic document of Invoice type of CML 2 format.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  Document tree - values tree - value tree corresponding to the InvoiceForPayment layout of ElectronicDocuments DataProcessor.
//
Procedure FillInAccountData(ObjectReference, EDStructure, DocumentTree) Export
		
EndProcedure

// Prepares data for the electronic document of GoodsOrder type of CML 2 format.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DocumentTree - values tree - value tree corresponding to the ProductOrder layout of ElectronicDocuments DataProcessor.
//
Procedure FillInProductsOrderData(ObjectReference, EDStructure, DocumentTree) Export
	
EndProcedure

// It prepares data for the electronic document of ResponseToOrder type of CML 2 format.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DocumentTree - values tree - value tree corresponding to the ResponseToOrder layout of ElectronicDocuments DataProcessor.
//
Procedure FillInDataInResponseToOrder(ObjectReference, EDStructure, DocumentTree) Export
		
EndProcedure

// It prepares data for the electronic document of ReportToPrincipal type of CML 2 format.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DocumentTree - values tree - value tree corresponding to the AgentSalesReport layout of the ElectronicDocuments DataProcessor.
//
// Feature:
//  Parameter AdditionalAttributesForTablesProducts in the common parameter structure
//  is intended for the AdditionalAttributes column filling the product table.
//
Procedure FillInDataOnCommissionGoodsSalesReport(ObjectReference, EDStructure, DocumentTree) Export
		
EndProcedure

// Prepares data for the electronic document of the WriteOffReportToPrincipal type of the CML 2 format.
//
// Parameters:
//  ObjectReference - DocumentRef, reference to the infobase object used to create an electronic document.
//  EDStructure - Structure, data structure to generate an electronic document.
//  DocumentTree - values tree - value tree corresponding to the AgentReportOnWriteOff layout of the ElectronicDocuments DataProcessor.
//
Procedure FillInDataFromComissionGoodsWriteOffReport(ObjectReference, EDStructure, DocumentTree) Export
 
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ED exporting mechanism to the files for sending to FTS using 1C-Reporting service

// The function shall return the date and number of approval documents (contracts) by the reference array.
// Function parameters:
// Parameter 1 -  array of refs to
// IB documents (you shall take the types of the
// documents based on which the electronic document of the Work (Service) Services acceptance certificate kind is created in this applied solution as possible values)
//
// Parameters:
//  RefArray - array of references to IB documents;
//  ReturnedMap - Matching with the following properties:
//    correspondence key - ref to the IB imported document taken
//    from the mapping value incoming parameter - Structure, with fields:
//    ContractNumber,
//    type: String ContractDate,
// type: Date in case the required attributes of the contract is not filled or it is not possible to receive attribute data, you shall use empty values of the specified types.
//
Procedure GetNumberDateContractDocuments(RefArray, ReturnedMap) Export
	
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

/////////////////////////////////////////////////////////////////////////////////
// Other functions

Function GetCMLObjectType(Type, SchemaVersion = "4.01") Export
	
	If TypeOf(Type) = Type("String") Then
		ObjectType = GetObjectTypeCML(Type, SchemaVersion);
	Else
		ObjectType = Type;
	EndIf;
	
	If ObjectType = Undefined Then
		Return Undefined;
	EndIf;
	
	NewObject = XDTOFactory.Create(ObjectType);
	
	Return NewObject;
	
EndFunction

Function GetObjectTypeCML(Type, SchemaVersion)
	
	PathArray = StrSeparate(Type, ".");
	
	FirstItem = PathArray[0];
	If Left(FirstItem,1) = "{" AND Right(FirstItem,1) = "}" Then
		PackageName = Mid(FirstItem, 2, StrLen(FirstItem) - 2);
		Collection = XDTOFactory.packages.Get(PackageName).RootProperties;
	ElsIf SchemaVersion <> "4.02" Then
		ObjectType = XDTOFactory.Type(SchemaVersion, FirstItem);
		Collection = ObjectType.Properties;
	Else
		ObjectType = XDTOFactory.Type("http://v8.1c.ru/edi/edi_stnd", FirstItem);
		Collection = ObjectType.Properties;
	EndIf;
	
	PathArray.Delete(0);
	While PathArray.Count() > 0 Do
		
		If Collection = Undefined Then
			Return Undefined;
		EndIf;
		
		Property = Collection.Get(PathArray[0]);
		If Property = Undefined Then
			Return Undefined;
		EndIf;
		
		ObjectType = Property.Type;
		PathArray.Delete(0);
		Try
			Collection = ObjectType.Properties;
		Except
			Collection = Undefined;
		EndTry;
		
	EndDo;
	
	Return ObjectType;
	
EndFunction

Function StrSeparate(Val String, Delimiter)
	
	Result = New Array;
	If IsBlankString(String) Then
		Return Result;
	EndIf;
	
	FirstItemBegPosition = Find(String, "{");
	FirstItemEndPosition = Find(String, "}");
	If FirstItemBegPosition > 0 AND FirstItemEndPosition > 0 Then
		FirstItem = Mid(String, FirstItemBegPosition, FirstItemEndPosition);
		Result.Add(TrimAll(FirstItem));
		String = TrimAll(Mid(String,FirstItemEndPosition + 2));
	EndIf;
	
	While True Do
		Position = Find(String,Delimiter);
		If Position = 0 Then
			Break;
		EndIf;
		
		Result.Add(TrimAll(Left(String,Position - 1)));
		String = TrimAll(Mid(String,Position + 1));
	EndDo;
	
	Result.Add(TrimAll(String));
	
	Return Result;
	
EndFunction 

// It prepares data for the electronic document of Payment Order type.
//
// Parameters:
// ObjectReference - DocumentRef, reference to
//                  the infobase object used to create an electronic document.
// EDStructure - Structure, data structure to generate an electronic document.
// DocumentTree - ValueTree - corresponds to PaymentOrder template of ElectronicDocuments DataProcessor.
//
Procedure FillInDataInTransferOrder(ObjectReference, EDStructure, DocumentTree) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PaymentOrder.Date,
	|	PaymentOrder.DocumentAmount AS Amount,
	|	PaymentOrder.Counterparty.DescriptionFull AS RecipientAttributes_Description,
	|	PaymentOrder.Counterparty.TIN AS RecipientAttributes_TIN,
	|	PaymentOrder.CounterpartyAccount.AccountNo AS RecipientAttributes_BankAccount,
	|	PaymentOrder.CounterpartyAccount.Bank.Code AS RecipientAttributes_Bank_BIN,
	|	PaymentOrder.CounterpartyAccount.Bank.Description AS RecipientAttributes_Bank_Description,
	|	PaymentOrder.CounterpartyAccount.Bank.City AS RecipientAttributes_Bank_City,
	|	PaymentOrder.CounterpartyAccount.Bank.CorrAccount AS RecipientAttributes_Bank_CorrAccount,
	|	PaymentOrder.Company.Description AS PayerAttributes_Description,
	|	PaymentOrder.Company.TIN AS PayerAttributes_TIN,
	|	PaymentOrder.BankAccount.AccountNo AS PayerAttributes_BankAccount,
	|	PaymentOrder.BankAccount.Bank.Code AS PayerAttributes_Bank_BIN,
	|	PaymentOrder.BankAccount.Bank.Description AS PayerAttributes_Bank_Description,
	|	PaymentOrder.BankAccount.Bank.City AS PayerAttributes_Bank_City,
	|	PaymentOrder.BankAccount.Bank.CorrAccount AS PayerAttributes_Bank_CorrAccount,
	|	""Urgently"" AS PaymentAttributes_PaymentKind,
	|	""01"" AS PaymentAttributes_PayKind,
	|	PaymentOrder.PaymentPriority AS PaymentAttributes_OrderOfPriority,
	|	PaymentOrder.PaymentIdentifier AS PaymentAttributes_Code,
	|	PaymentOrder.PaymentDestination AS PaymentAttributes_PaymentDestination,
	|	CASE
	|		WHEN PaymentOrder.OperationKind = VALUE(Enum.OperationKindsPaymentOrder.TaxTransfer)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS PaymentToBudget,
	|	PaymentOrder.AuthorStatus AS PaymentsToBudget_AuthorStatus,
	|	PaymentOrder.BasisIndicator AS PaymentsToBudget_BasisIndicator,
	|	CASE
	|		WHEN PaymentOrder.PeriodIndicator = """"
	|			THEN ""0""
	|		ELSE PaymentOrder.PeriodIndicator
	|	END AS PaymentsToBudget_PeriodIndicator,
	|	CASE
	|		WHEN PaymentOrder.NumberIndicator = """"
	|			THEN ""0""
	|		ELSE PaymentOrder.NumberIndicator
	|	END AS PaymentsToBudget_NumberIndicator,
	|	CASE
	|		WHEN PaymentOrder.DateIndicator = """"
	|			THEN ""0""
	|		ELSE PaymentOrder.DateIndicator
	|	END AS PaymentsToBudget_DateIndicator,
	|	PaymentOrder.TypeIndicator AS PaymentsToBudget_TypeIndicator,
	|	CASE
	|		WHEN PaymentOrder.BankAccount.AccountsBank = VALUE(Catalog.Banks.EmptyRef)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS PayerIndirectPayments,
	|	PaymentOrder.BankAccount.AccountsBank.Code AS PayerBankForIndirectPayments_BIN,
	|	PaymentOrder.BankAccount.AccountsBank.Description AS PayerBankForIndirectPayments_Description,
	|	PaymentOrder.BankAccount.AccountsBank.City AS PayerBankForIndirectPayments_City,
	|	PaymentOrder.BankAccount.AccountsBank.CorrAccount AS PayerBankForIndirectPayments_CorrAccount,
	|	CASE
	|		WHEN PaymentOrder.CounterpartyAccount.AccountsBank = VALUE(Catalog.Banks.EmptyRef)
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS RecipientIndirectSettlements,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.Code AS RecipientBankForIndirectCalculations_BIN,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.Description AS RecipientBankForIndirectCalculations_Description,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.City AS RecipientBankForIndirectCalculations_City,
	|	PaymentOrder.CounterpartyAccount.AccountsBank.CorrAccount AS RecipientBankForIndirectCalculations_CorrAccount,
	|	PaymentOrder.Counterparty AS Recipient
	|FROM
	|	Document.PaymentOrder AS PaymentOrder
	|WHERE
	|	PaymentOrder.Ref = &Ref";
	
	Query.SetParameter("Ref", ObjectReference);
	DocumentDataTable = Query.Execute().Unload();
	
	DataRow = DocumentDataTable[0];
	IndexOf = 0;
	
	For IndexOf = 0 To 22 Do
		Path = StrReplace(DocumentDataTable.Columns[IndexOf].Name, "_", ".");
		CommonUseED.FillTreeAttributeValue(DocumentTree, Path, DataRow[IndexOf]);
	EndDo;
	
	If DataRow.PaymentToBudget Then
		For IndexOf = 24 To 31 Do
			Path = StrReplace(DocumentDataTable.Columns[IndexOf].Name, "_", ".");
			CommonUseED.FillTreeAttributeValue(DocumentTree, Path, DataRow[IndexOf]);
		EndDo;
	EndIf;

	If DataRow.PayerIndirectPayments Then
		For IndexOf = 33 To 36 Do
			Path = StrReplace(DocumentDataTable.Columns[IndexOf].Name, "_", ".");
			CommonUseED.FillTreeAttributeValue(DocumentTree, Path, DataRow[IndexOf]);
		EndDo;
	EndIf;

	If DataRow.RecipientIndirectSettlements Then
		For IndexOf = 38 To 41 Do
			Path = StrReplace(DocumentDataTable.Columns[IndexOf].Name, "_", ".");
			CommonUseED.FillTreeAttributeValue(DocumentTree, Path, DataRow[IndexOf]);
		EndDo;
	EndIf;
	
	CommonUseED.FillTreeAttributeValue(DocumentTree, "Recipient", DataRow.Recipient);
	
EndProcedure





