#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
//
// This module contains export procedures of conversion event handlers and is intended for exchange rule debugging. 
// After debugging it is recommended to
// make corresponding handler corrections in the base "Data conversion 2.0» and generate the rule file once again.
//
// /////////////////////////////////////////////////////////////////////////////
// USED SHORT NAMES VARIABLES (ABBREVIATIONS)
//
//  OCR  - object conversion rule
//  PCR  - object property conversion rule 
//  PGCR - object properties group conversion
//  VCR  - object values conversion rule 
//  DDR  - data export rule 
//  DCR  - data clearing rule


////////////////////////////////////////////////////////////////////////////////
// DATA PROCESSOR VARIABLES


////////////////////////////////////////////////////////////////////////////////
// HELPER MODULE VARIABLES FOR ALGORITHMS WRITING (COMMON FOR EXPORT AND UPLOAD)

Var Parameters;
Var Rules;
Var Algorithms;
Var Queries;
Var UnloadRulesTable;
Var ParametersSettingsTable;
Var NodeForExchange; // only for online exchange
Var CommonProcedureFunctions;
Var StartDate;
Var EndDate;
Var DataExportDate; // only for online exchange
Var CommentDuringDataExport;
Var CommentDuringDataImport;


////////////////////////////////////////////////////////////////////////////////
// VARIABLES THAT ARE USED IN EXCHANGE HANDLERS (BOTH FOR IMPORT AND EXPORT)

Var deStringType;                 // Type("String")
Var deBooleanType;                // Type("Boolean")
Var deNumberType;                 // Type("Number")
Var deDateType;                   // Type("Date")
Var deValueStorageType;           // Type("ValueStorage")
Var deBinaryDataType;             // Type("BinaryData")
Var deAccumulationRecordTypeType; // Type("AccrualMovementKind")
Var deObjectDeletionType;         // Type("ObjectRemoval")
Var deAccountTypeType;			       // Type("AccountType")
Var deTypeType;			  		         // Type("Type")
Var deMapType;		                 // Type("Map")

Var odNodeTypeXML_EndElement;
Var odNodeTypeXML_StartElement;
Var odNodeTypeXML_Text;

Var EmptyDateValue;


////////////////////////////////////////////////////////////////////////////////
// CONVERSION HANDLERS (GLOBAL)

Procedure Conversion_BeforeDataImport(ExchangeFile, Cancel) Export

	Query = New Query();
	Query.Text = 
	"SELECT TOP 1
	|	CustomerOrderStates.Ref AS OrdersState
	|FROM
	|	Catalog.CustomerOrderStates AS CustomerOrderStates
	|WHERE
	|	CustomerOrderStates.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Parameters.Insert("StateOrdersOfCustomers", QuerySelection.OrdersState);
	EndIf;
	
	Query = New Query();
	Query.Text = 
	"SELECT TOP 1
	|	PurchaseOrderStates.Ref AS OrdersState
	|FROM
	|	Catalog.PurchaseOrderStates AS PurchaseOrderStates
	|WHERE
	|	PurchaseOrderStates.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Parameters.Insert("StateOrdersToSuppliers", QuerySelection.OrdersState);
	EndIf;
	
	// Currency
	Parameters.Insert("NationalCurrency", Constants.NationalCurrency.Get());

EndProcedure

Procedure Conversion_AfterDataImport() Export

	
	Var KDObject;
	
	KDObject = DataProcessors.InfobaseObjectsConversion.Create();
	
	Query = New Query(
	"SELECT
	|	TableProductsAndServices.ProductsAndServices AS ProductsAndServices
	|FROM
	|	(SELECT
	|		EnterOpeningBalanceInventoryReceived.ProductsAndServices AS ProductsAndServices
	|	FROM
	|		Document.EnterOpeningBalance.InventoryReceived AS EnterOpeningBalanceInventoryReceived
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		EnterOpeningBalanceInventoryTransferred.ProductsAndServices
	|	FROM
	|		Document.EnterOpeningBalance.InventoryTransferred AS EnterOpeningBalanceInventoryTransferred) AS TableProductsAndServices
	|
	|GROUP BY
	|	TableProductsAndServices.ProductsAndServices");
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Count() > 0 Then
		Constants.FunctionalOptionUseBatches.Set(True);
	EndIf;
	
	While QuerySelection.Next() Do
		CatalogObject = QuerySelection.ProductsAndServices.GetObject();
		If Not CatalogObject.UseBatches Then
			CatalogObject.UseBatches = True;
			CatalogObject.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);
			KDObject.WriteObjectToIB(CatalogObject, TypeOf(CatalogObject));
		EndIf;
	EndDo;
	
	Query = New Query(
	"SELECT
	|	TableProductsAndServices.ProductsAndServices AS ProductsAndServices
	|FROM
	|	(SELECT
	|		EnterOpeningBalanceInventory.ProductsAndServices AS ProductsAndServices
	|	FROM
	|		Document.EnterOpeningBalance.Inventory AS EnterOpeningBalanceInventory
	|	WHERE
	|		EnterOpeningBalanceInventory.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		OpeningBalancesForInventoryByEnteringCCD.ProductsAndServices
	|	FROM
	|		Document.EnterOpeningBalance.InventoryByCCD AS OpeningBalancesForInventoryByEnteringCCD
	|	WHERE
	|		OpeningBalancesForInventoryByEnteringCCD.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		EnterOpeningBalanceInventoryTransferred.ProductsAndServices
	|	FROM
	|		Document.EnterOpeningBalance.InventoryTransferred AS EnterOpeningBalanceInventoryTransferred
	|	WHERE
	|		EnterOpeningBalanceInventoryTransferred.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		EnterOpeningBalanceInventoryReceived.ProductsAndServices
	|	FROM
	|		Document.EnterOpeningBalance.InventoryReceived AS EnterOpeningBalanceInventoryReceived
	|	WHERE
	|		EnterOpeningBalanceInventoryReceived.Characteristic <> VALUE(Catalog.ProductsAndServicesCharacteristics.EmptyRef)) AS TableProductsAndServices
	|
	|GROUP BY
	|	TableProductsAndServices.ProductsAndServices");
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Count() > 0 Then
		Constants.FunctionalOptionUseCharacteristics.Set(True);
	EndIf;
	
	While QuerySelection.Next() Do
		CatalogObject = QuerySelection.ProductsAndServices.GetObject();
		If Not CatalogObject.UseCharacteristics Then
			CatalogObject.UseCharacteristics = True;
			CatalogObject.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);
			KDObject.WriteObjectToIB(CatalogObject, TypeOf(CatalogObject));
		EndIf;
	EndDo;
	
	UsersService.UpdateUsersGroupsContents(Catalogs.UsersGroups.AllUsers);
	
	// Update of the counterparty attribute sets.
	CommonProperties = Catalogs.AdditionalAttributesAndInformationSets.Catalog_Counterparties.GetObject();
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CounterpartiesAdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.Counterparties.AdditionalAttributes AS CounterpartiesAdditionalAttributes
	|WHERE
	|	(NOT CounterpartiesAdditionalAttributes.Property.ThisIsAdditionalInformation)";
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		If CommonProperties.AdditionalAttributes.Find(Selection.Property, "Property") = Undefined Then
			NewProperty = CommonProperties.AdditionalAttributes.Add();
			NewProperty.Property = Selection.Property;
		EndIf;
	EndDo;
	CommonProperties.Write();
	
	// Update of the individual attribute sets.
	CommonProperties = Catalogs.AdditionalAttributesAndInformationSets.Catalog_Individuals.GetObject();
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	IndividualsAdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.Individuals.AdditionalAttributes AS IndividualsAdditionalAttributes
	|WHERE
	|	(NOT IndividualsAdditionalAttributes.Property.ThisIsAdditionalInformation)";
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		If CommonProperties.AdditionalAttributes.Find(Selection.Property, "Property") = Undefined Then
			NewProperty = CommonProperties.AdditionalAttributes.Add();
			NewProperty.Property = Selection.Property;
		EndIf;
	EndDo;
	CommonProperties.Write();
	
	// Update of the contract attribute sets.
	CommonProperties = Catalogs.AdditionalAttributesAndInformationSets.Catalog_CounterpartyContracts.GetObject();
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	CounterpartyContractsAdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.CounterpartyContracts.AdditionalAttributes AS CounterpartyContractsAdditionalAttributes
	|WHERE
	|	(NOT CounterpartyContractsAdditionalAttributes.Property.ThisIsAdditionalInformation)";
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		If CommonProperties.AdditionalAttributes.Find(Selection.Property, "Property") = Undefined Then
			NewProperty = CommonProperties.AdditionalAttributes.Add();
			NewProperty.Property = Selection.Property;
		EndIf;
	EndDo;
	CommonProperties.Write();
	
	// Update of the ProductsAndServices attribute sets.
	CommonProperties = Catalogs.AdditionalAttributesAndInformationSets.Catalog_ProductsAndServices.GetObject();
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	ProductsAndServicesAdditionalAttributes.Property
	|FROM
	|	Catalog.ProductsAndServices.AdditionalAttributes AS ProductsAndServicesAdditionalAttributes
	|WHERE
	|	(NOT ProductsAndServicesAdditionalAttributes.Property.ThisIsAdditionalInformation)";
	
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		If CommonProperties.AdditionalAttributes.Find(Selection.Property, "Property") = Undefined Then
			NewProperty = CommonProperties.AdditionalAttributes.Add();
			NewProperty.Property = Selection.Property;
		EndIf;
	EndDo;
	CommonProperties.Write();
	
	// Setting the FunctionalOptionAccountingByMultipleCompanies constant. It
	// is running here as probably the companies will not be mapped.
	Query = New Query();
	Query.Text = 
	"SELECT
	|	COUNT(DISTINCT Companies.Ref) AS Quantity
	|FROM
	|	Catalog.Companies AS Companies";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If ValueIsFilled(Selection.Quantity)
			AND Selection.Quantity > 1 Then
			Constants.FunctionalOptionAccountingByMultipleCompanies.Set(True);
		EndIf;
	EndIf;
	
	Query = New Query();
	Query.Text = 
	"SELECT
	|	StructuralUnits.Ref AS Ref
	|FROM
	|	Catalog.StructuralUnits AS StructuralUnits
	|WHERE
	|	StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)";
	Selection = Query.Execute().Select();
	
	RetailPoint = Undefined;
	If Selection.Next() Then
		RetailPoint = Selection.Ref;
	EndIf;
	
	If ValueIsFilled(RetailPoint) Then
		CatalogCashRegisters = Catalogs.CashRegisters.Select();
		While CatalogCashRegisters.Next() Do
			CatalogObject = CatalogCashRegisters.GetObject();
			If Not ValueIsFilled(CatalogObject.StructuralUnit) Then
				CatalogObject.StructuralUnit = RetailPoint;
				KDObject.WriteObjectToIB(CatalogObject, TypeOf(CatalogObject));
			EndIf;
		EndDo;
	EndIf;
	
	// Setting the correct Service type of products and services.
	
	Query = New Query;
	
	// The service is available in the customer orders and supplier orders.
	Query.Text = 
	"SELECT DISTINCT
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServices,
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.Ref AS PurchaseOrder
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		LEFT JOIN Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|		ON PurchaseOrderInventory.ProductsAndServices = CustomerOrderInventory.ProductsAndServices
	|WHERE
	|	PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
	|	AND ISNULL(CustomerOrderInventory.Ref, 0) <> 0
	|
	|ORDER BY
	|	ProductsAndServices,
	|	PurchaseOrder,
	|	LineNumber
	|TOTALS BY
	|	ProductsAndServices,
	|	PurchaseOrder,
	|	LineNumber";
	
	SelectionByProductsAndServices = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While SelectionByProductsAndServices.Next() Do
		
		NewProductsAndServices = Catalogs.ProductsAndServices.CreateItem();
		
		FillPropertyValues(
		NewProductsAndServices,
		SelectionByProductsAndServices.ProductsAndServices,
		"Parent, Description, SKU, MeasurementUnit, WriteOffMethod,
		|DescriptionFull, BusinessActivity, ProductsAndServicesCategory, Warehouse,
		|Specification, ReplenishmentMethod, VATRate, InventoryGLAccount, ExpensesGLAccount,
		|Cell, PriceGroup, UseCharacteristics, UseBatches, PictureFile, OrderCompletionDeadline, TimeNorm, FixedCost"
		);
		
		NewProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service;
		NewProductsAndServices.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);	
		KDObject.WriteObjectToIB(NewProductsAndServices, TypeOf(NewProductsAndServices));
		
		SelectionOfOrders = SelectionByProductsAndServices.Select(QueryResultIteration.ByGroups);
		
		While SelectionOfOrders.Next() Do
			
			DocumentObject = SelectionOfOrders.PurchaseOrder.GetObject();
			
			SelectionByRows = SelectionOfOrders.Select(QueryResultIteration.ByGroups);
			
			While SelectionByRows.Next() Do
				DocumentObject.Inventory[SelectionByRows.LineNumber - 1].ProductsAndServices = NewProductsAndServices.Ref;
				If ValueIsFilled(DocumentObject.Inventory[SelectionByRows.LineNumber - 1].Characteristic) Then
					CharacteristicObject = DocumentObject.Inventory[SelectionByRows.LineNumber - 1].Characteristic.GetObject();
					NewCharacteristic = Catalogs.ProductsAndServicesCharacteristics.CreateItem();
					NewCharacteristic.Owner = NewProductsAndServices.Ref;
					NewCharacteristic.Description = CharacteristicObject.Description;
					NewCharacteristic.AdditionalAttributes.Load(CharacteristicObject.AdditionalAttributes.Unload());
					KDObject.WriteObjectToIB(NewCharacteristic, TypeOf(NewCharacteristic));
				EndIf;
			EndDo;
			
			DocumentObject.Write();
			
		EndDo;
		
	EndDo;
	
	// Service is only in supplier orders.
	Query.Text =
	"SELECT DISTINCT
	|	PurchaseOrderInventory.ProductsAndServices AS ProductsAndServicesOrderToSupplier
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		LEFT JOIN Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|		ON PurchaseOrderInventory.ProductsAndServices = CustomerOrderInventory.ProductsAndServices
	|WHERE
	|	PurchaseOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.Service)
	|	AND ISNULL(CustomerOrderInventory.ProductsAndServices, 0) = 0";
	
	SelectionByProductsAndServices = Query.Execute().Select();
	
	While SelectionByProductsAndServices.Next() Do
		
		ProductsAndServicesObject = SelectionByProductsAndServices.ProductsAndServicesOrderToSupplier.GetObject();
		ProductsAndServicesObject.ProductsAndServicesType = Enums.ProductsAndServicesTypes.Service;
		ProductsAndServicesObject.AdditionalProperties.Insert("DisableObjectChangeRecordMechanism", True);	
		KDObject.WriteObjectToIB(ProductsAndServicesObject, TypeOf(ProductsAndServicesObject));
		
	EndDo;

EndProcedure


////////////////////////////////////////////////////////////////////////////////
// OBJECT CONVERSION HANDLERS

Procedure OCR_AfterImport_Companies(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	VATRates.Ref AS VATRate
	|FROM
	|	Catalog.VATRates AS VATRates
	|WHERE
	|	VATRates.Rate = 18
	|	AND Not VATRates.NotTaxable
	|	AND Not VATRates.Calculated";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Object.DefaultVATRate = Selection.VATRate;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_ProductsAndServices(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not Object.IsFolder Then
		If Not ValueIsFilled(Object.InventoryGLAccount) Then
			Object.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
		EndIf;
		If Not ValueIsFilled(Object.ExpensesGLAccount) Then
			Object.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
		EndIf;
		If Not ValueIsFilled(Object.BusinessActivity) Then
			Object.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
		EndIf;
			
			
			//============================ {BEGINNING ALGORITHM} "FillInVatRateCaps" ============================
			
			If ObjectParameters <> Undefined Then
				
				Query = New Query;
				Query.Text = ObjectParameters["QueryTextVATRate"];
				
				Selection = Query.Execute().Select();
				
				If Selection.Next() Then
					Object.VATRate = Selection.VATRate;
				EndIf;
				
			EndIf;
			
			//============================ {END ALGORITHM} "FillInVatRateCaps" ============================
	
		If Not ValueIsFilled(Object.ProductsAndServicesCategory) Then
			Object.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
		EndIf;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_PettyCashes(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.GLAccount) Then
		Object.GLAccount = ChartsOfAccounts.Managerial.PettyCash;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_Counterparties(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not Object.IsFolder Then
		If Not ValueIsFilled(Object.CustomerAdvancesGLAccount) Then
			Object.CustomerAdvancesGLAccount = ChartsOfAccounts.Managerial.AccountsByAdvancesReceived;
		EndIf;
		If Not ValueIsFilled(Object.VendorAdvancesGLAccount) Then
			Object.VendorAdvancesGLAccount = ChartsOfAccounts.Managerial.SettlementsByAdvancesIssued;
		EndIf;
		If Not ValueIsFilled(Object.GLAccountCustomerSettlements) Then
			Object.GLAccountCustomerSettlements = ChartsOfAccounts.Managerial.AccountsReceivable;
		EndIf;
		If Not ValueIsFilled(Object.GLAccountVendorSettlements) Then
			Object.GLAccountVendorSettlements = ChartsOfAccounts.Managerial.AccountsPayable;
		EndIf;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_BankAccounts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.AccountType) Then
		Object.AccountType = "Transactional";
	EndIf;
	
	If Not ValueIsFilled(Object.GLAccount) Then
		Object.GLAccount = ChartsOfAccounts.Managerial.Bank;
	EndIf;
	
	If Not ValueIsFilled(Object.KPPIndicationVersion) Then
		Object.KPPIndicationVersion = Enums.KPPIndicationVariants.OnTransferOfTaxes;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_CashRegisters(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.GLAccount) Then
		Object.GLAccount = ChartsOfAccounts.Managerial.PettyCash;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCurrency) Then
		//Object.CashCurrency = Catalogs.Currencies.NationalCurrency;
		Object.CashCurrency = Parameters.NationalCurrency;
	EndIf;
	
	If Not ValueIsFilled(Object.CashCRType) Then
		Object.CashCRType = Enums.CashCRTypes.AutonomousCashRegister;
	EndIf;
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Query = New Query();
		Query.Text = 
		"SELECT
		|	StructuralUnits.Ref AS Ref
		|FROM
		|	Catalog.StructuralUnits AS StructuralUnits
		|WHERE
		|	StructuralUnits.StructuralUnitType = VALUE(Enum.StructuralUnitsTypes.Retail)";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Object.StructuralUnit = Selection.Ref;	
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.Division) Then
		Object.Division = Catalogs.StructuralUnits.MainDivision;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_Files(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.Description) Then
		Object.Description = "Picture";
	EndIf;
	If Not ValueIsFilled(Object.FullDescr) Then
		Object.FullDescr = "Picture";
	EndIf;
	Object.Author = SessionParameters.CurrentUser;

EndProcedure

Procedure OCR_AfterImport_FileVersions(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.Description) Then
		Object.Description = "Picture";
	EndIf;
	If Not ValueIsFilled(Object.FullDescr) Then
		Object.FullDescr = "Picture";
	EndIf;
	Object.Author = SessionParameters.CurrentUser;
	Object.DataExchange.Load = True;
	Object.Write();
	
	NewRecord = InformationRegisters.VersionStoredFiles.CreateRecordManager();
	NewRecord.FileVersion = Object.Ref;
	NewRecord.StoredFile = Object.FileStorage;
	NewRecord.Write();

EndProcedure

Procedure OCR_AfterImport_AdditionalAttributesAndInformationSets(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// When recording, the DB recording operations necessary for the correct work are performed
	Object.DataExchange.Load = False;
	Object.Write();

EndProcedure

Procedure OCR_AfterImport_StructuralUnits(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.Company) Then
		Object.Company = Catalogs.Companies.MainCompany;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_Divisions(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not ValueIsFilled(Object.Company) Then
		Object.Company = Catalogs.Companies.MainCompany;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_Employees(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If Not Object.IsFolder Then
		If Not ValueIsFilled(Object.OverrunGLAccount) Then
			Object.OverrunGLAccount = ChartsOfAccounts.Managerial.OverrunOfAdvanceHolders;
		EndIf;
		If Not ValueIsFilled(Object.SettlementsHumanResourcesGLAccount) Then
			Object.SettlementsHumanResourcesGLAccount = ChartsOfAccounts.Managerial.PayrollPaymentsOnPay;
		EndIf;
		If Not ValueIsFilled(Object.AdvanceHoldersGLAccount) Then
			Object.AdvanceHoldersGLAccount = ChartsOfAccounts.Managerial.AdvanceHolderPayments;
		EndIf;
	EndIf;

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOwnedProductsOnWarehouses(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_ProductBalanceEnteringPerCCD(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryGoodsAcceptedForCommission(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in InventoryReceived tabular sections of the document
	For Each CurRow IN Object.InventoryReceived Do
		
		// We fill the batch.
			
			
			//============================ {BEGINNING ALGORITHM} "FillBatch" ============================
			
			
			KDObject = DataProcessors.InfobaseObjectsConversion.Create();
			
			// Define the batch status based on the operation kind.
			Status = Enums.BatchStatuses.ProductsOnCommission;
			Description = "Products on commission";
			
			// Searching the batch using ProductsAndServices and counterparty.
			Query = New Query;
			Query.Text = 
			"SELECT
			|	ProductsAndServicesBatches.Ref AS Batch
			|FROM
			|	Catalog.ProductsAndServicesBatches AS ProductsAndServicesBatches
			|WHERE
			|	ProductsAndServicesBatches.Owner = &Owner
			|	AND ProductsAndServicesBatches.BatchOwner = &BatchOwner
			|	AND ProductsAndServicesBatches.Status = &Status";
			
			Query.SetParameter("Owner", CurRow.ProductsAndServices);
			Query.SetParameter("BatchOwner", CurRow.Counterparty);
			Query.SetParameter("Status", Status);
			
			Selection = Query.Execute().Select();
			
			If Selection.Next() Then
				CurRow.Batch = Selection.Batch;
			Else
				
				// Searching the batch by products and services.
				Query = New Query;
				Query.Text =
				"SELECT
				|	ProductsAndServicesBatches.Ref AS Batch
				|FROM
				|	Catalog.ProductsAndServicesBatches AS ProductsAndServicesBatches
				|WHERE
				|	ProductsAndServicesBatches.Owner = &Owner
				|	AND ProductsAndServicesBatches.Status = &Status";
				
				Query.SetParameter("Owner", CurRow.ProductsAndServices);
				Query.SetParameter("Status", Status);
				
				Selection = Query.Execute().Select();
				
				If Selection.Next() Then
					CurRow.Batch = Selection.Batch;
				Else
					
					// If nothing is found, we create a new one.
					NewItem = Catalogs.ProductsAndServicesBatches.CreateItem();
					NewItem.Description = Description;
					NewItem.Owner = CurRow.ProductsAndServices;
					NewItem.Status = Status;
					NewItem.SetNewCode();
					KDObject.WriteObjectToIB(NewItem, TypeOf(NewItem));
					
					CurRow.Batch = NewItem.Ref;
					
				EndIf;
				
			EndIf;
			
			//============================ {END ALGORITHM} "FillBatch" ============================
	
		
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryCashOnHands(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_EnteringCashInBankAccountsBalance(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryProductsSubmittedToCommission(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryAdvanceHolderCashDebts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AdvanceHolderPayments tabular section.
	For Each String IN Object.AdvanceHolderPayments Do
		If Not ValueIsFilled(String.Document) Then
			If String.Overrun Then
				NewDocument = Documents.ExpenseReport.CreateDocument();
				NewDocument.Employee = String.Employee;
			Else
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.ToAdvanceHolder;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.AdvanceHolder = String.Employee;
				NewDocument.CashCurrency = String.Currency;
				NewDocument.DocumentAmount = String.AmountCur;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryAdvanceHolderCashlessDebts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AdvanceHolderPayments tabular section.
	For Each String IN Object.AdvanceHolderPayments Do
		If Not ValueIsFilled(String.Document) Then
			If String.Overrun Then
				NewDocument = Documents.ExpenseReport.CreateDocument();
				NewDocument.Employee = String.Employee;
			Else
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.ToAdvanceHolder;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.AdvanceHolder = String.Employee;
				NewDocument.CashCurrency = String.Currency;
				NewDocument.DocumentAmount = String.AmountCur;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryImprestAmountCalculation(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AdvanceHolderPayments tabular section.
	For Each String IN Object.AdvanceHolderPayments Do
		If Not ValueIsFilled(String.Document) Then
			If String.Overrun Then
				NewDocument = Documents.ExpenseReport.CreateDocument();
				NewDocument.Employee = String.Employee;
			Else
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.ToAdvanceHolder;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.AdvanceHolder = String.Employee;
				NewDocument.CashCurrency = String.Currency;
				NewDocument.DocumentAmount = String.AmountCur;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryClientDebtsForOrders(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN Object.AccountsReceivable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryClientRealizationDebts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN Object.AccountsReceivable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryAgentDebtsForSoldProducts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN Object.AccountsReceivable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOtherAccountsDueToCustomers(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN Object.AccountsReceivable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOrderAdvancesReceivedFromCustomers(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN Object.AccountsReceivable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOtherAdvancesReceivedFromCustomers(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsReceivable tabular section.
	For Each String IN Object.AccountsReceivable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashReceipt.FromCustomer;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.CustomerInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCustomerInvoice.SaleToCustomer;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntrySupplierDebtsForOrders(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN Object.AccountsPayable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntrySupplierIncomeDebts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN Object.AccountsPayable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryPrincipalDebtsForSoldProducts(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN Object.AccountsPayable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOtherAccountsPayableToSuppliers(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN Object.AccountsPayable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOrderAdvancesPaidToSuppliers(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN Object.AccountsPayable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOtherAdvancesPaidToSuppliers(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Generating the documents for the AccountsPayable tabular section.
	For Each String IN Object.AccountsPayable Do
		If Not ValueIsFilled(String.Document) Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashPayment.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsCashPayment.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Object.Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.OperationKind = Enums.OperationKindsSupplierInvoice.ReceiptFromVendor;
				NewDocument.Contract = String.Counterparty.ContractByDefault;
				NewDocument.StructuralUnit = Catalogs.StructuralUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Object.Date;
			NewDocument.Company = Object.Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en='It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Object.Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Object.Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOtherAccountsReceivable(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	For Each CurRow IN Object.OtherSections Do
		If Not ValueIsFilled(CurRow.Account) Then
			CurRow.Account = ChartsOfAccounts.Managerial.ProfitsAndLossesWithoutProfitTax;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_BalanceEntryOtherAccountsPayable(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	For Each CurRow IN Object.OtherSections Do
		If Not ValueIsFilled(CurRow.Account) Then
			CurRow.Account = ChartsOfAccounts.Managerial.ProfitsAndLossesWithoutProfitTax;
		EndIf;
	EndDo;
	
	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	// Document posting.
		
		
		//============================ {BEGINNING ALGORITHM} "SetPostingMode" ============================
		
		If Object.Posted Then
			WriteMode = "Posting";
		EndIf;
		
		//============================ {END ALGORITHM} "SetPostingMode" ============================
	

EndProcedure

Procedure OCR_AfterImport_Event(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	

EndProcedure

Procedure OCR_AfterImport_CustomerOrder(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, , Object.Date);
	
	If ObjectParameters <> Undefined Then
		ParametersOfTP = ObjectParameters.Get("InventoryTabularSection");	
	EndIf;
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsCustomerOrder.OrderForSale;
	EndIf;
	
	If Not ValueIsFilled(Object.OrderState) Then
		If ValueIsFilled(Parameters.StateOrdersOfCustomers) Then
			Object.OrderState = Parameters.StateOrdersOfCustomers;
		Else
			Object.OrderState = Catalogs.CustomerOrderStates.Open;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.SalesStructuralUnit) Then
		Object.SalesStructuralUnit = Catalogs.StructuralUnits.MainDivision; 
	EndIf;
	
	If Not ValueIsFilled(Object.ShipmentDate) Then
		Object.ShipmentDate = Object.Date; 
	EndIf;  
	
	// Fill in the Inventory tabular section of the document with the default values.
	For Each CurRow IN Object.Inventory Do
		
		If ValueIsFilled(Object.ShipmentDate) Then
			CurRow.ShipmentDate = Object.ShipmentDate;
		Else
			CurRow.ShipmentDate = Object.Date;
		EndIf;
		
		// Fill in the measurement unit
			
			
			//============================ {BEGINNING ALGORITHM} "FillUnitDimensions" ============================
			
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				CurRow.MeasurementUnit = CurRow.ProductsAndServices.MeasurementUnit;
			EndIf;
			
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				CurRow.MeasurementUnit = Catalogs.UOMClassifier.Pcs;
			EndIf;
			
			//============================ {END ALGORITHM} "FillUnitDimensions" ============================
	
		
		// Fill in VAT rate.
			
			
			//============================ {BEGINNING ALGORITHM} "FillVATRateByRow" ============================
			
			If ObjectParameters <> Undefined
			   AND ParametersOfTP.Count() > 0 Then
				
				Query = New Query();
				Query.Text = ParametersOfTP[CurRow.LineNumber - 1].QueryTextVATRate;
				
				Selection = Query.Execute().Select();
				
				If Selection.Next() Then
					CurRow.VATRate = Selection.VATRate;
				EndIf;
				
			EndIf;
			
			//============================ {END ALGORITHM} "FillVATRateByRow" ============================
	
		
		CurRow.Amount = CurRow.Quantity * CurRow.Price;
	
		If CurRow.DiscountMarkupPercent = 100 Then
			CurRow.Amount = 0;
		ElsIf CurRow.DiscountMarkupPercent <> 0 AND CurRow.Quantity <> 0 Then
			CurRow.Amount = CurRow.Amount * (1 - CurRow.DiscountMarkupPercent / 100);
		EndIf;
		
		// Fill in VAT amount.
		CurRow.VATAmount = ?(Object.AmountIncludesVAT, 
			CurRow.Amount - (CurRow.Amount) / ((CurRow.VATRate.Rate + 100) / 100),
			CurRow.Amount * CurRow.VATRate.Rate / 100
		);
		
		// Fill in the line total amount.
		CurRow.Total = CurRow.Amount + ?(Object.AmountIncludesVAT, 0, CurRow.VATAmount);
		
	EndDo;

EndProcedure

Procedure OCR_AfterImport_PurchaseOrder(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	// Fill in the document author.
		
		
		//============================ {BEGINNING ALGORITHM} "FillAuthor" ============================
		
		If Not ValueIsFilled(Object.Author) Then
			Object.Author = Users.CurrentUser();
		EndIf;
		
		//============================ {END ALGORITHM} "FillAuthor" ============================
	
	
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, , Object.Date);
	
	If ObjectParameters <> Undefined Then
		ParametersOfTP = ObjectParameters.Get("InventoryTabularSection");	
	EndIf;
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Enums.OperationKindsPurchaseOrder.OrderForPurchase;
	EndIf;
	
	If Not ValueIsFilled(Object.OrderState) Then
		If ValueIsFilled(Parameters.StateOrdersOfCustomers) Then
			Object.OrderState = Parameters.StateOrdersToSuppliers;
		Else
			Object.OrderState = Catalogs.CustomerOrderStates.Open;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Object.ReceiptDate) Then
		Object.ReceiptDate = Object.Date; 
	EndIf;  
	
	// Fill in the Inventory tabular section of the document with the default values.
	For Each CurRow IN Object.Inventory Do
		
		If ValueIsFilled(Object.ReceiptDate) Then
			CurRow.ReceiptDate = Object.ReceiptDate;
		Else
			CurRow.ReceiptDate = Object.Date;
		EndIf;
		
		// Fill in the measurement unit.
			
			
			//============================ {BEGINNING ALGORITHM} "FillUnitDimensions" ============================
			
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				CurRow.MeasurementUnit = CurRow.ProductsAndServices.MeasurementUnit;
			EndIf;
			
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				CurRow.MeasurementUnit = Catalogs.UOMClassifier.Pcs;
			EndIf;
			
			//============================ {END ALGORITHM} "FillUnitDimensions" ============================
	
		
		// Fill in VAT rate.
			
			
			//============================ {BEGINNING ALGORITHM} "FillVATRateByRow" ============================
			
			If ObjectParameters <> Undefined
			   AND ParametersOfTP.Count() > 0 Then
				
				Query = New Query();
				Query.Text = ParametersOfTP[CurRow.LineNumber - 1].QueryTextVATRate;
				
				Selection = Query.Execute().Select();
				
				If Selection.Next() Then
					CurRow.VATRate = Selection.VATRate;
				EndIf;
				
			EndIf;
			
			//============================ {END ALGORITHM} "FillVATRateByRow" ============================
	
		
		CurRow.Amount = CurRow.Quantity * CurRow.Price;
		
		// Fill in VAT amount.
		CurRow.VATAmount = ?(Object.AmountIncludesVAT, 
			CurRow.Amount - (CurRow.Amount) / ((CurRow.VATRate.Rate + 100) / 100),
			CurRow.Amount * CurRow.VATRate.Rate / 100
		);
		
		// Fill in the line total amount.
		CurRow.Total = CurRow.Amount + ?(Object.AmountIncludesVAT, 0, CurRow.VATAmount);
		
	EndDo;

EndProcedure

Procedure OCR_AfterImport_IndividualsDocuments(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	
	// ...From the UT 11 object module
	TextSeries				= NStr("en = ', series: %1'");
	TextNumber				= NStr("en = ',  %No'");
	TextIssuanceDate			= NStr("en = ', issued: %1 year'");
	TextValidityPeriod		= NStr("en = ', valid till: %1 year'");
	TextDivisionCode	= NStr("en = ', div. No.%1'");
	
	If Object.DocumentKind.IsEmpty() Then
		Object.Presentation = "";
		
	Else
		Object.Presentation = ""
			+ Object.DocumentKind
			+ ?(ValueIsFilled(Object.Series), StringFunctionsClientServer.PlaceParametersIntoString(TextSeries, Object.Series), "")
			+ ?(ValueIsFilled(Object.Number), StringFunctionsClientServer.PlaceParametersIntoString(TextNumber, Object.Number), "")
			+ ?(ValueIsFilled(Object.IssueDate), StringFunctionsClientServer.PlaceParametersIntoString(TextIssuanceDate, Format(Object.IssueDate,"DF=dd MMMM yyyy'")), "")
			+ ?(ValueIsFilled(Object.ValidityPeriod), StringFunctionsClientServer.PlaceParametersIntoString(TextValidityPeriod, Format(Object.ValidityPeriod,"DF=dd MMMM yyyy'")), "")
			+ ?(ValueIsFilled(Object.WhoIssued), ", " + Object.WhoIssued, "")
			+ ?(ValueIsFilled(Object.DivisionCode) AND Object.DocumentKind = Catalogs.IndividualsDocumentsKinds.LocalPassport, StringFunctionsClientServer.PlaceParametersIntoString(TextDivisionCode, Object.DivisionCode), "");
		
	EndIf;

EndProcedure

Procedure OCR_AfterImport_AdditionalAttributesAndInformation(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified, 
                                           ObjectTypeName, ObjectFound, RecordSet) Export

	If ObjectParameters <> Undefined Then
		
		ArrayOfTypesAtRowIns = ObjectParameters.Get("Type");
		If ArrayOfTypesAtRowIns <> Undefined Then
			
			TypeDescriptionArray = ValueFromStringInternal(ArrayOfTypesAtRowIns);
			
			TypeArray = New Array;
			For Each DescriptionType IN TypeDescriptionArray Do
				TypeArray.Add(Type(DescriptionType));
			EndDo;
			
			Try
				Object.ValueType = New TypeDescription(TypeArray);
			Except
			EndTry;
			
		EndIf;
		
	EndIf;

EndProcedure


////////////////////////////////////////////////////////////////////////////////
// CONVERSION HANDLERS OF PROPERTIES AND OBJECT PROPERTY GROUPS


////////////////////////////////////////////////////////////////////////////////
//                          !!!ATTENTION!!! 
//            IT IS PROHIBITED TO CHANGE THE CODE IN THIS SECTION (BELOW)!
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// CALL OF OVERALL PROCEDURES AND FUNCTIONS


// Exports object according to the specified conversion rule
//
// Parameters:
//  Source				 - arbitrary
//  data source Receiver				 - xml-node of
//  the IncomingData receiver object			 - arbitrary supporting data
//                             passed to rule
//  for conversion IncomingData			 - arbitrary supporting data
//                             passed by
//  property conversion rules OCRName					 - conversion rule name according to
//  which export RefNode is executed				 - XML-node of
//  the JustGetRefNode receiver object ref - If True then object export will not be
//                             executed, xml-node
//  of ref OCR is formed only                      - ref to the conversion rule.
//
// Returns:
//  ref xml-node or receiver value
//
Function DumpByRule(Source					= Undefined,
						   Receiver					= Undefined,
						   IncomingData			= Undefined,
						   OutgoingData			= Undefined,
						   OCRName					= "") Export
						   
	Return CommonProcedureFunctions.DumpByRule(Source, Receiver, IncomingData, OutgoingData, OCRName);
	
EndFunction

// Creates
// new xml-node Function can be used in the events handlers
// application code of which is stored in the data exchange rules. It is called by method Execute()
//
// Parameters: 
//  Name            - Node name
//
// Returns:
//  New xml-node object
//
Function CreateNode(Name) Export

	Return CommonProcedureFunctions.CreateNode(Name); 

EndFunction

// Adds a new xml-node to
// the specified parent node Function can be used in event
// handlers the application code of which is stored in the data exchange rules. It is
// called by method Execute() During the check of configuration the
// message "Refs to the function are not found" is not the error of the configuration check
//
// Parameters: 
//  ParentNode   - XML-node-parent
//  Name            - added node name.
//
// Returns:
//  New xml-node added to the specified parent node
//
Function AddNode(ParentNode, Name) Export

	Return CommonProcedureFunctions.AddNode(ParentNode, Name); 

EndFunction

// Copies the
// specified xml-node Function can be used in the event
// handlers the application code of which is stored in the data exchange rules. It is
// called by method Execute() During the check of configuration the
// message "Refs to the function are not found" is not the error of the configuration check
//
// Parameters: 
//  Node           - node being copied.
//
// Returns:
//  New xml - specified node copy
//
Function CopyNode(Node) Export

	Return CommonProcedureFunctions.CopyNode(Node); 
	
EndFunction 

// Sets a value of the Import parameter for a property of the DataExchange object.
//
// Parameters:
//  Object   - object for which
//  the property Value is set - set property value "Import"
// 
Procedure SetDataExchangeImport(Object, Value = True) Export

	CommonProcedureFunctions.SetDataExchangeImport(Object, Value);
	
EndProcedure

// Sets attribute of the specified xml-node
//
// Parameters: 
//  Node           - xml-node
//  Name            - attribute
//  name Value       - setting value
//
Procedure SetAttribute(Node, Name, Value) Export
	
	CommonProcedureFunctions.SetAttribute(Node, Name, Value);
	
EndProcedure

// Subordinates xml-node to the specified parent node
//
// Parameters: 
//  ParentNode   - XML-node-parent
//  Node           - subordinate node. 
//
Procedure AddSubordinate(ParentNode, Node) Export

	CommonProcedureFunctions.AddSubordinate(ParentNode, Node);
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORK WITH OBJECT XMLReading

// Writes item and its value to the specified object
//
// Parameters:
//  Object         - type object
//  XMLWrite Name            - String. Item
//  name Value       - Item value
// 
Procedure deWriteItem(Object, Name, Value="") Export

	CommonProcedureFunctions.deWriteItem(Object, Name, Value);
	
EndProcedure

// Reads attribute value by the name from the
// specified object, gives value to the specified primitive type
//
// Parameters:
//  Object      - type object XMLRead positioned on item
//                beginning, attribute of which
//  it is required to get Type         - Value of the Type type. Attribute
//  type Name         - String. Attribute name
//
// Returns:
//  Attribute value received by the name and subjected to the specified type
// 
Function deAttribute(Object, Type, Name) Export
	
	Return CommonProcedureFunctions.deAttribute(Object, Type, Name);
		
EndFunction
 
// Skips xml nodes up to the end of specified item (current default)
//
// Parameters:
//  Object   - type object
//  XMLRead Name      - node name, up to the end of which you should skip items
// 
Procedure deIgnore(Object, Name = "") Export
	
	CommonProcedureFunctions.deIgnore(Object, Name);
	
EndProcedure

// Reads item text and provides value to the specified type
//
// Parameters:
//  Object           - object of XMLReading type used
//  to read Type              - received value
//  type SearchByProperty - for reference types you can specify the property
//                     by which an object should be searched: "Code", "Description" <AttributeName>, "Name" (predefined value)
//
// Returns:
//  Xml-item value, given to the corresponding type
//
Function deItemValue(Object, Type, SearchByProperty = "", CutStringRight = True) Export

	Return CommonProcedureFunctions.deItemValue(Object, Type, SearchByProperty, CutStringRight);

EndFunction

////////////////////////////////////////////////////////////////////////////////
// WORK WITH DATA

// Returns string - name of the passed enumeration value.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. It is
// called by method Execute() During the check of configuration the
// message "Refs to the function are not found" is not the error of the configuration check
//
// Parameters:
//  Value     - enum value
//
// Returns:
//  String       - name of the passed enumeration value.
//
Function deEnumValueName(Value) Export

    Return CommonProcedureFunctions.deEnumValueName(Value);
	
EndFunction

// Defines whether the passed value is filled
//
// Parameters: 
//  Value       - value which filling shall be checked
//
// Returns:
//  True         - value is not filled in, false - else.
//
Function deBlank(Value, IsNULL=False) Export
	
	Return CommonProcedureFunctions.deBlank(Value, IsNULL);
	
EndFunction

// Returns TypeDescription object containing the specified type.
//  
// Parameters:
//  TypeValue - srtring with type name or value of the Type type.
//  
// Returns:
//  TypeDescription
//
Function deDescriptionType(TypeValue) Export
	
	Return CommonProcedureFunctions.deDescriptionType(TypeValue);

EndFunction

// Returns empty (default) value of the specified type
//
// Parameters:
//  Type          - srtring with type name or value of the Type type.
//
// Returns:
//  Empty value of the specified type.
// 
Function deGetBlankValue(Type) Export

    Return CommonProcedureFunctions.deGetBlankValue(Type);
	
EndFunction

// Executes simple search for infobase object by the specified property.
//
// Parameters:
//  Manager       - searched object manager;
//  Property       - property according to which search is
// executed: Name, Code, Name or Indexed attribute name;
//  Value       - property value according to which you should search for object.
//
// Returns:
//  Found infobase object.
//
Function deFindObjectByProperty(Manager, Property, Value, 
	                        FoundByUUIDObject = Undefined, 
	                        CommonPropertyStructure = Undefined, CommonSearchProperties = Undefined, 
	                        MainObjectSearchMode = True, SearchByUUIDQueryString = "") Export

	Return CommonProcedureFunctions.deFindObjectByProperty(Manager, Property, Value, 
	                                               FoundByUUIDObject,	
	                                               CommonPropertyStructure, CommonSearchProperties, 
	                                               MainObjectSearchMode, SearchByUUIDQueryString);
	
EndFunction

// Executes simple search for infobase object by the specified property.
//
// Parameters:
//  Str            - String - property value according to
// which search is executed object;
//  Type            - searched oject type;
//  Property       - String - property name according to which you should search for object.
//
// Returns:
//  Found infobase object
//
Function deGetValueByString(Str, Type, Property = "") Export

	Return CommonProcedureFunctions.deGetValueByString(Str, Type, Property);

EndFunction

// Returns row presentation of the value type 
//
// Parameters: 
//  ValueOrType - arbitrary value or type value type
//
// Returns:
//  String - String presentation of the value type
//
Function deValueTypeAsString(ValueOrType) Export

	Return CommonProcedureFunctions.deValueTypeAsString(ValueOrType);
	
EndFunction

// Returns XML object
// presentation TypeDescription Function can be used in the event
// handlers, application code of which is stored in the data exchange rules. It is
// called by method Execute() During the check of configuration the
// message "Refs to the function are not found" is not the error of the configuration check
//
// Parameters:
//  TypeDescription  - TypeDescription object, XML presentation of which should be received
//
// Returns:
//  String - XML presentation of the transferred object TypeDescription
//
Function deGetXMLPresentationDescriptionTypes(TypeDescription) Export

	Return CommonProcedureFunctions.deGetXMLPresentationDescriptionTypes(TypeDescription);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// WORK WITH STRINGS

// Breaks a row into two parts: up to subrow and after.
//
// Parameters:
//  Str          - parsed row;
//  Delimiter  - subrow-separator:
//  Mode        - 0 - a separator in the returned subrows is not included;
//                 1 - separator is included into a left subrow;
//                 2 - separator is included to a right subrow.
//
// Returns:
//  Right part of the row - up to delimiter character
// 
Function SeparateBySeparator(Str, Val Delimiter, Mode=0) Export

    Return CommonProcedureFunctions.SeparateBySeparator(Str, Delimiter, Mode);
	
EndFunction

// Converts values from string to array by specified delimiter
//
// Parameters:
//  Str            - Parsed
//  string Delimiter    - substring delimiter
//
// Returns:
//  Array of values
// 
Function ArrayFromString(Val Str, Delimiter=",") Export

	Return CommonProcedureFunctions.ArrayFromString(Str, Delimiter);

EndFunction

Function GetStringNumberWithoutPrefixes(Number) Export
	
	Return CommonProcedureFunctions.GetStringNumberWithoutPrefixes(Number);
	
EndFunction

// Parses string excluding prefix and numeric part from it.
//
// Parameters:
//  Str            - String. Parsed string;
//  NumericalPart  - Number. Variable to which string numeric part is returned;
//  Mode          - String. If there is "Number", then it returns a numeric part, otherwise, - Prefix.
//
// Returns:
//  String prefix
//
Function GetPrefixNumberOfNumber(Val Str, NumericalPart = "", Mode = "") Export

	Return CommonProcedureFunctions.GetPrefixNumberOfNumber(Str, NumericalPart, Mode);

EndFunction

// Reduces number (code) to the required length. Prefix and
// number numeric part are excluded, the rest of the
// space between the prefix and the number is filled in with zeros.
// Function can be used in the event handlers application code of which is stored in the data exchange rules. It is
// called by method Execute() During the check of configuration the
// message "Refs to the function are not found" is not the error of the configuration check
//
// Parameters:
//  Str          - converted string;
//  Length        - required string length.
//
// Returns:
//  String       - code or number reduced to the required length.
// 
Function CastNumberToLength(Val Str, Length, AddZerosIfLengthNotLessCurrentNumberLength = True, Prefix = "") Export

	Return CommonProcedureFunctions.CastNumberToLength(Str, Length, AddZerosIfLengthNotLessCurrentNumberLength, Prefix);

EndFunction

// Adds substring to the prefix
// of number or code Function can be used in the
// event handlers the application code of which is stored in the data exchange rules. It is
// called by method Execute() During the check of configuration the
// message "Refs to the function are not found" is not the error of the configuration check
//
// Parameters:
//  Str          - String. Number or code;
//  Additive      - substring added to the prefix;
//  Length        - required resulting length of the string;
//  Mode        - "Left" - substring is added left to the prefix, otherwise, - right.
//
// Returns:
//  String       - number or code to the prefix of which the specified substring is added.
//
Function AddToPrefix(Val Str, Additive = "", Length = "", Mode = "Left") Export

	Return CommonProcedureFunctions.AddToPrefix(Str, Additive, Length, Mode); 

EndFunction

// Expands string with the specified character up to the specified length.
//
// Parameters: 
//  Str          - expanded string;
//  Length        - required length of the resulting string;
//  Than          - character which expands string.
//
// Returns:
//  String expanded with the specified character up to the specified length.
//
Function deAddToString(Str, Length, Than = " ") Export
	
	Return CommonProcedureFunctions.deAddToString(Str, Length, Than);

EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH EXCHANGE FILE

// Saves to the file specified xml-node.
//
// Parameters:
//  Node           - xml-node saved to the file
//
Procedure WriteToFile(Node) Export

	CommonProcedureFunctions.WriteToFile(Node);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF WORK WITH EXCHANGE RULES

// Searches the conversion rule by name or according
// to the type of passed object
//
// Parameters:
//  Object         - Source object for which
//  we are searching the conversion rule RuleName     - conversion rule name
//
// Returns:
//  Ref to conversion rule (row in rule table)
// 
Function FindRule(Object, Rulename="") Export

	Return CommonProcedureFunctions.FindRule(Object, Rulename);

EndFunction


////////////////////////////////////////////////////////////////////////////////
//

Procedure PassInformationAboutRecordsToReceiver(InformationToWriteToFile, ErrorStringInTargetInfobase = "") Export
	
	CommonProcedureFunctions.PassInformationAboutRecordsToReceiver(InformationToWriteToFile, ErrorStringInTargetInfobase);
	
EndProcedure

Procedure PassOneParameterToReceiver(Name, InitialParameterValue, ConversionRule = "") Export
	
	CommonProcedureFunctions.PassOneParameterToReceiver(Name, InitialParameterValue, ConversionRule);
	
EndProcedure

Procedure PassAdditionalParametersToReceiver() Export
	
	CommonProcedureFunctions.PassAdditionalParametersToReceiver();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// DATA PROCESSOR CONSTRUCTOR AND DESTRUCTOR

Procedure Assistant(Owner) Export

	CommonProcedureFunctions      = Owner;
	Parameters                  = Owner.Parameters;
	Queries                    = Owner.Queries;
	Rules                    = Owner.Rules;
	UnloadRulesTable      = Owner.UnloadRulesTable;
	ParametersSettingsTable = Owner.ParametersSettingsTable;
	
	CommentDuringDataExport = Owner.CommentDuringDataExport;
	CommentDuringDataImport = Owner.CommentDuringDataImport;
	
	
	//variable for universal exchange
	Try
		StartDate = Owner.StartDate;
	Except
	EndTry;
	
	//variable for universal exchange
	Try
		EndDate = Owner.EndDate;
	Except
	EndTry;
	
	//variable for online exchange
	Try
		DataExportDate = Owner.DataExportDate;
	Except
	EndTry;
	
	//variable for online exchange
	Try
		NodeForExchange = Owner.NodeForExchange;
	Except
	EndTry;
	
	// Types
	deStringType                = Type("String");
	deBooleanType                = Type("Boolean");
	deNumberType                 = Type("Number");
	deDateType                  = Type("Date");
	deValueStorageType     = Type("ValueStorage");
	deBinaryDataType        = Type("BinaryData");
	deAccumulationRecordTypeType = Type("AccumulationRecordType");
	deObjectDeletionType       = Type("ObjectDeletion");
	deAccountTypeType			   = Type("AccountType");
	deTypeType                   = Type("Type");
	deMapType          = Type("Map");
	
	EmptyDateValue		   = Date('00010101');
	
	// Xml node types
	odNodeTypeXML_EndElement  = XMLNodeType.EndElement;
	odNodeTypeXML_StartElement = XMLNodeType.StartElement;
	odNodeTypeXML_Text          = XMLNodeType.Text;
	
	Algorithms = Owner.Algorithms;
	

EndProcedure


Procedure Destructor() Export
	
	CommonProcedureFunctions = Undefined;
	
EndProcedure

#EndIf