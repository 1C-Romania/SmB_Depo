
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure generates selection list for the accounting section.
//
&AtServer
Procedure GenerateAccountingSectionsList()
	
	// FO Use Payroll subsystem.
	If Constants.FunctionalOptionUseSubsystemPayroll.Get()
		OR Object.AccountingSection = "Personnel settlements" Then
		Items.AccountingSection.ChoiceList.Add("Personnel settlements", "Personnel settlements");
	EndIf;
	
	// FD Use Belongings.
	If Constants.FunctionalOptionAccountingFixedAssets.Get()
		OR Object.AccountingSection = "Assets" Then
		Items.AccountingSection.ChoiceList.Add("Assets", "Assets");
	EndIf;
	
	// Other.
	Items.AccountingSection.ChoiceList.Add("Other sections", "Other sections");
	
EndProcedure // GenerateAccountingSectionsList()

// Function receives page name for the document accounting section.
//
// Parameters:
// AccountingSection - EnumRef.AccountingSections - Accounting section
//
// Returns:
// String - Page name corresponding to the accounting sections
//
&AtClient
Function GetPageName(AccountingSection)

	Map = New Map;
	Map.Insert("Assets", "FolderFixedAssets");
	Map.Insert("Inventory", "GroupInventory");
	Map.Insert("Cash assets", "FolderBanking");
	Map.Insert("Settlements with suppliers and customers", "GroupSettlementsWithCounterparties");
	Map.Insert("Tax settlements", "FolderTaxesSettlements");
	Map.Insert("Personnel settlements", "GroupSettlementsWithHPersonnel");
	Map.Insert("Settlements with advance holders", "GroupAdvanceHolderPayments");
	Map.Insert("Other sections", "GroupOtherSections");
	
	PageName = Map.Get(AccountingSection);
	
	Return PageName;

EndFunction // GetPageName()

// Procedure sets the current page depending on the accounting section.
//
&AtClient
Procedure SetCurrentPage()
	
	Item = Items.Find(GetPageName(Object.AccountingSection));
	
	If Item <> Undefined Then
		ThisForm.Items.Pages.CurrentPage = Item;
	EndIf;
	
EndProcedure // SetCurrentPage()

// Procedure is forming the mapping of operation kinds.
//
&AtServer
Procedure GetOperationKindsStructure()
	
	If Constants.FunctionalOptionReceiveGoodsOnCommission.Get() Then
		Items.InventoryReceived.ChildItems.InventoryReceiveedOperationKind.ChoiceList.Add(Enums.OperationKindsSupplierInvoice.ReceptionForCommission);
	EndIf;
	
	If Constants.FunctionalOptionTolling.Get() Then
		Items.InventoryReceived.ChildItems.InventoryReceiveedOperationKind.ChoiceList.Add(Enums.OperationKindsSupplierInvoice.ReceptionIntoProcessing);
	EndIf;
	
	If Constants.FunctionalOptionTransferInventoryOnSafeCustody.Get() Then
		Items.InventoryReceived.ChildItems.InventoryReceiveedOperationKind.ChoiceList.Add(Enums.OperationKindsSupplierInvoice.ReceptionForSafeCustody);
	EndIf;
	
	If Constants.FunctionalOptionTransferGoodsOnCommission.Get() Then
		Items.InventoryTransferred.ChildItems.InventoryTransferredOperationKind.ChoiceList.Add(Enums.OperationKindsCustomerInvoice.TransferForCommission);
	EndIf;
	
	If Constants.FunctionalOptionTransferRawMaterialsForProcessing.Get() Then
		Items.InventoryTransferred.ChildItems.InventoryTransferredOperationKind.ChoiceList.Add(Enums.OperationKindsCustomerInvoice.TransferToProcessing);
	EndIf;
	
	If Constants.FunctionalOptionTransferInventoryOnSafeCustody.Get() Then
		Items.InventoryTransferred.ChildItems.InventoryTransferredOperationKind.ChoiceList.Add(Enums.OperationKindsCustomerInvoice.TransferForSafeCustody);
	EndIf;
	
EndProcedure // GetOperationKindsStructure()

// Procedure sets items visible and availability.
//
&AtServer
Procedure SetItemsVisibleEnabled()
	
	If Object.AccountingSection = "Settlements with suppliers and customers"
		OR Object.AccountingSection = "Settlements with advance holders" Then
		
		Items.Autogeneration.Visible = True;
		
	Else
		
		Items.Autogeneration.Visible = False;
		Object.Autogeneration = False;
		
	EndIf;
	
EndProcedure // SetItemsAvailibilityVisible()

///////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert(
		"Counterparty",
		SmallBusinessServer.GetCompany(Company)		
	);
	
	Return StructureData;
	
EndFunction // GetCompanyDataOnChange()

// Receives data set from server for the AccountOnChange procedure.
//
// Parameters:
//  Account         - AccountsChart, account according to which you should receive structure.
//
// Returns:
//  Account structure.
//
&AtServerNoContext
Function GetDataAccountOnChange(Account) Export
	
	StructureData = New Structure();
	
	StructureData.Insert("Currency", Account.Currency);
	
	Return StructureData;
	
EndFunction // GetDataAccountOnChange()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataFixedAsset(FixedAsset)
	
	StructureData = New Structure();
	
	StructureData.Insert("MethodOfDepreciationProportionallyProductsAmount", FixedAsset.DepreciationMethod = Enums.FixedAssetsDepreciationMethods.ProportionallyToProductsVolume);
	
	Return StructureData;
	
EndFunction // ReceiveDataFixedAsset()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	StructureData.Insert("CountryOfOrigin", StructureData.ProductsAndServices.CountryOfOrigin);
	
	If StructureData.Property("PriceKind") Then
		
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;	
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", StructureData.DiscountMarkupKind.Percent);
	Else	
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// It receives data set from the server for the CashAssetsBankAccountPettyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataCashAssetsBankAccountPettyCashOnChange(BankAccountPettyCash)

	StructureData = New Structure();

	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.PettyCashes") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CurrencyByDefault);
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		StructureData.Insert("Currency", BankAccountPettyCash.CashCurrency);
	Else
		StructureData.Insert("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataCashAssetsBankAccountPettyCashOnChange()

// Receives data set from server for the CashAssetsCashAssetsCurrencyStartChoice procedure.
//
&AtServerNoContext
Function GetDataCashAssetsCashAssetsCurrencyStartChoice(BankAccountPettyCash)

	StructureData = New Structure();

	If TypeOf(BankAccountPettyCash) = Type("CatalogRef.PettyCashes") Then
		StructureData.Insert("CashAssetsType", Enums.CashAssetTypes.Cash);
	ElsIf TypeOf(BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		StructureData.Insert("CashAssetsType", Enums.CashAssetTypes.Noncash);
	Else
		StructureData.Insert("CashAssetsType", Undefined);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataCashAssetsCashAssetsCurrencyStartChoice()

// Gets the default contract depending on the settlements method.
//
&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	If (TabularSectionName = "InventoryTransferred"
		OR TabularSectionName = "InventoryReceived")
		AND Not ValueIsFilled(OperationKind) Then
		
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind, TabularSectionName);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, TabularSectionName, OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
	
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByDocuments", Counterparty.DoOperationsByDocuments);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	StructureData.Insert("TrackPaymentsByBills", Counterparty.TrackPaymentsByBills);
	
	SetAccountsAttributesVisible(
		Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByDocuments,
		Counterparty.DoOperationsByOrders,
		Counterparty.TrackPaymentsByBills,
		TabularSectionName
	);
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
&AtServer
Procedure SetAccountsAttributesVisible(Val DoOperationsByContracts = False, Val DoOperationsByDocuments = False, Val DoOperationsByOrders = False, Val TrackPaymentsByBills = False, TabularSectionName)
	
	FillServiceAttributesByCounterpartyInCollection(Object[TabularSectionName]);
	
	For Each CurRow IN Object[TabularSectionName] Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByDocuments Then
			DoOperationsByDocuments = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
		If CurRow.TrackPaymentsByBills Then
			TrackPaymentsByBills = True;
		EndIf;
	EndDo;
	
	If TabularSectionName = "AccountsPayable" Then
		Items.AccountsPayableContract.Visible = DoOperationsByContracts;
		Items.AccountsPayableDocument.Visible = DoOperationsByDocuments;
		Items.AccountsPayablePurchaseOrder.Visible = DoOperationsByOrders;
		Items.AccountsPayableInvoiceForPayment.Visible = TrackPaymentsByBills;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		Items.AccountsReceivableAgreement.Visible = DoOperationsByContracts;
		Items.AccountsReceivableDocument.Visible = DoOperationsByDocuments;
		Items.AccountsReceivableCustomersOrder.Visible = DoOperationsByOrders;
		Items.AccountsReceivableInvoiceForPayment.Visible = TrackPaymentsByBills;
	ElsIf TabularSectionName = "InventoryTransferred" Then
		Items.InventoryTransferredContract.Visible = DoOperationsByContracts;
	ElsIf TabularSectionName = "InventoryReceived" Then
		Items.InventoryReceivedContract.Visible = DoOperationsByContracts;
	EndIf;
	
EndProcedure // SetAccountsAttributesVisible()

// Procedure fills out the service attributes.
//
&AtServerNoContext
Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	TableOfCounterparty.Counterparty.TrackPaymentsByBills AS TrackPaymentsByBills
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByDocuments, DoOperationsByOrders, TrackPaymentsByBills");
	EndDo;
	
EndProcedure // FillServiceAttributesByCounterpartyInCollection()

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataContractOnChange(Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

// Function converts the amount from specified currency to the currency of man. accounting.
//
// Parameters:      
// AmountCur  - Number                    - Currency amount that shall be recalculated.
// Currency    - Catalog.Ref.Currencies - currency from which it is required to recalculate.
// 	ExchangeRateDate - Date                     - exchange rate date.
//
// Returns: 
//  Number - Amount in the currency of management. accounting.
//
&AtServerNoContext
Function RecalculateFromCurrencyToAccountingCurrency(AmountCur, Currency, ExchangeRateDate) Export

    Amount = 0;

	If ValueIsFilled(Currency) Then

		AccountingCurrency = Constants.AccountingCurrency.Get();

		CurrencyRatesStructure = SmallBusinessServer.GetCurrencyRates(Currency, AccountingCurrency, ExchangeRateDate);

		Amount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(AmountCur,
	                                                           CurrencyRatesStructure.InitRate,
	                                                           CurrencyRatesStructure.ExchangeRate,
	                                                           CurrencyRatesStructure.RepetitionBeg,
	                                                           CurrencyRatesStructure.Multiplicity);

	EndIf;

	Return Amount;

EndFunction // RecalculateFromCurrencies()

// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
&AtServer
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.FunctionalOptionUseSubsystemProduction.Get() Then
		
		// Setting the method of structural unit selection depending on FO.
		If Not Constants.FunctionalOptionAccountingByMultipleDivisions.Get()
			AND Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			Items.InventoryStructuralUnit.ListChoiceMode = True;
			If ValueIsFilled(MainWarehouse) Then
				Items.InventoryStructuralUnit.ChoiceList.Add(MainWarehouse);
			EndIf;
			Items.InventoryStructuralUnit.ChoiceList.Add(MainDivision);
			
		EndIf;
		
	Else
		
		If Constants.FunctionalOptionAccountingByMultipleWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.StructuralUnitsTypes.Warehouse);
			NewArray.Add(Enums.StructuralUnitsTypes.Retail);
			ArrayTypesOfStructuralUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfStructuralUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.InventoryStructuralUnit.ChoiceParameters = NewParameters;
			
		Else
			
			Items.InventoryStructuralUnit.Visible = False;
			
		EndIf;
		
		Items.DirectExpencesGroup.Visible = False;
		
	EndIf;
	
EndProcedure // SetVisibleByFDUseProductionSubsystem()

// It gets counterparty contract selection form parameter structure.
//
&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind, TabularSectionName)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind, TabularSectionName);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - form attribute initialization,
// - set parameters of the functional form options,
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed
	);
	
	GenerateAccountingSectionsList();
	
	DocumentObject = FormAttributeToValue("Object");
	If DocumentObject.IsNew() 
	   AND Parameters.Property("BasisDocument") 
	   AND ValueIsFilled(Parameters.BasisDocument) Then
		DocumentObject.Fill(Parameters.BasisDocument);
		ValueToFormAttribute(DocumentObject, "Object");
	EndIf;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Cash = Enums.CashAssetTypes.Cash;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	CurrencyByDefault = Constants.NationalCurrency.Get();
	
	GetOperationKindsStructure();
	SetItemsVisibleEnabled();
	
	If Not Constants.FunctionalOptionUseJobSharing.Get() Then
		If Items.Find("PayrollPaymentsEmployeeCode") <> Undefined Then
			Items.PayrollPaymentsEmployeeCode.Visible = False;
		EndIf;
		If Items.Find("SettlementsWithAdvanceHoldersEmployeeCode") <> Undefined Then
			Items.SettlementsWithAdvanceHoldersEmployeeCode.Visible = False;
		EndIf;
	EndIf;
	
	User = Users.CurrentUser();
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainWarehouse");
	Warehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainWarehouse);
	MainWarehouse = ?(Warehouse.OrderWarehouse, Undefined, Warehouse);
	
	If Not Constants.FunctionalOptionAccountingByMultipleWarehouses.Get()
		AND MainWarehouse <> Undefined Then
		
		Items.InventoryReceivedStructuralUnit.Visible = False;
		
	EndIf;
	
	SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDivision");
	MainDivision = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDivision);
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , , "AccountsReceivable");
	SetAccountsAttributesVisible(, , , , "InventoryTransferred");
	SetAccountsAttributesVisible(, , , , "InventoryReceived");
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.EnterOpeningBalance.TabularSections.Inventory, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)

	SetCurrentPage();
	
EndProcedure // OnOpen()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			For Each CurRow IN Object.InventoryTransferred Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , , "InventoryTransferred");
					Return;
				EndIf;
			EndDo;
			For Each CurRow IN Object.InventoryReceived Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , , "InventoryReceived");
					Return;
				EndIf;
			EndDo;
			For Each CurRow IN Object.AccountsReceivable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , , "AccountsReceivable");
					Return;
				EndIf;
			EndDo;
			For Each CurRow IN Object.AccountsPayable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , , "AccountsPayable");
					Return;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure // NotificationProcessing()


////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - OnChange event handler of the document date input field.
// IN procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure // DateOnChange()

// Procedure - OnChange event handler of the company input field.
// IN procedure is executed document
// number clearing and also make parameter set of the form functional options.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure // CompanyOnChange()

// Procedure - OnChange event handler of the AccountingSection input field.
// Current form page is set in the procedure
// depending on the accounting section.
//
&AtClient
Procedure AccountingSectionOnChange(Item)
	
	// Current form page setting.
	SetCurrentPage();
	SetItemsVisibleEnabled();
	
	Object.FixedAssets.Clear();
	Object.Inventory.Clear();
	Object.DirectCost.Clear();
	Object.InventoryReceived.Clear();
	Object.InventoryTransferred.Clear();
	Object.CashAssets.Clear();
	Object.AccountsReceivable.Clear();
	Object.AccountsPayable.Clear();
	Object.TaxesSettlements.Clear();
	Object.PayrollPayments.Clear();
	Object.AdvanceHolderPayments.Clear();
	Object.OtherSections.Clear();
	
EndProcedure // AccountingSectionOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - BELONGINGS TS EVENT HANDLERS

// Procedure - OnStartEdit event handler of the FixedAssets tabular section.
//
&AtClient
Procedure FixedAssetsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.FixedAssets.CurrentData;
		TabularSectionRow.StructuralUnit = MainDivision;
		
	EndIf;
	
EndProcedure // FixedAssetsOnStartEdit()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PROPERTY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of
// input field WorksProductsVolumeForDepreciationCalculation in
// string of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Volume of Production Work for calculating depreciation ""can not be filled with for the specified depreciation accrual method!'"));
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsVolumeProductsWorksForDepreciationCalculationOnChange()

// Procedure - event handler OnChange of
// input field UsagePeriodForDepreciationCalculation in string
// of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsUsagePeriodForDepreciationCalculationOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = 'The useful life of the asset can not be filled for the specified method of calculating depreciation!'"));
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	EndIf;
	
EndProcedure // FixedAssetsUsagePeriodForDepreciationCalculationOnChange()

// Procedure - event handler OnChange of
// input field FixedAsset in string of tabular section FixedAssets.
//
&AtClient
Procedure FixedAssetsFixedAssetOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		TabularSectionRow.UsagePeriodForDepreciationCalculation = 0;
	Else
		TabularSectionRow.AmountOfProductsServicesForDepreciationCalculation = 0;
		TabularSectionRow.CurrentOutputQuantity = 0;
	EndIf;
	
EndProcedure // FixedAssetsFixedAssetOnChange()

// Procedure - OnChange event handler
// of the OutputQuantity edit box in the FixedAssets tabular section string.
//
&AtClient
Procedure FixedAssetsCurrentOutputQuantityOnChange(Item)
	
	TabularSectionRow = Items.FixedAssets.CurrentData;
	StructureData = GetDataFixedAsset(TabularSectionRow.FixedAsset);
	
	If Not StructureData.MethodOfDepreciationProportionallyProductsAmount Then
		ShowMessageBox(Undefined,NStr("en = '""Volume of Production Work for calculating depreciation ""can not be filled with for the specified depreciation accrual method!'"));
		TabularSectionRow.CurrentOutputQuantity = 0;
	EndIf;

EndProcedure // FixedAssetsCurrentOutputQuantityOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - DIRECT COSTS TS EVENT HANDLERS

// Procedure - OnStartEdit event handler of the DirectCosts tabular section.
//
&AtClient
Procedure DirectCostOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
 
		TabularSectionRow = Items.DirectCost.CurrentData;
		TabularSectionRow.StructuralUnit = MainDivision;
		
	EndIf;
	
EndProcedure // DirectCostsOnStartEdit()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - INVENTORY TS EVENT HANDLERS

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow
	   AND Not Copy Then
		TabularSectionRow = Items.Inventory.CurrentData;
		If ValueIsFilled(MainWarehouse) Then
			TabularSectionRow.StructuralUnit = MainWarehouse;
		Else
			TabularSectionRow.StructuralUnit = MainDivision;
		EndIf;
	EndIf;
	
EndProcedure // InventoryOnStartEdit()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure // InventoryProductsAndServicesOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION ATTRIBUTES PASSED INVENTORY

// Procedure - OnActivateCell event handler of the InventoryPassed tabular field.
//
&AtClient
Procedure InventoryTransferredOnActivateCell(Item)
	
	// Order types availability.
	
	If Item.CurrentItem.Name = "InventoryTransferredOrder" Then
		
		TabularSectionRow = Items.InventoryTransferred.CurrentData;
			
		If TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing") Then
			
			ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder");
			
			NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsPurchaseOrder.OrderForProcessing"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
		ElsIf TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission") Then
			
			NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForSale"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
			ValidTypes = New TypeDescription("DocumentRef.CustomerOrder");
			
		Else
			
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.PurchaseOrder"));
			FilterArray.Add(Type("DocumentRef.CustomerOrder"));
			ValidTypes = New TypeDescription(FilterArray);	
			
		EndIf;
		
		Item.CurrentItem.TypeRestriction = ValidTypes;
		
	EndIf;
	
EndProcedure // InventoryPassedOnActivateCell()

// Procedure - AfterDeletion event handler of the InventoryPassed tabular section.
//
&AtClient
Procedure InventoryTransferredAfterDeleteRow(Item)
	
	SetAccountsAttributesVisible(, , , , "InventoryTransferred");
	
EndProcedure // InventoryPassedAfterDelete()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure InventoryTransferredOperationKindOnChange(Item)
	
	TabularSectionRow = Items.InventoryTransferred.CurrentData;
	
	TabularSectionRow.Contract = GetContractByDefault(
		Object.Ref, TabularSectionRow.Counterparty, Object.Company, "InventoryTransferred", TabularSectionRow.OperationKind);
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure InventoryTransferredCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.InventoryTransferred.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(
		TabularSectionRow.Counterparty, Object.Company, "InventoryTransferred", TabularSectionRow.OperationKind);
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
	
	TabularSectionRow.Contract = StructureData.Contract;
	
EndProcedure // InventoryPassedCounterpartyOnChange()

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure InventoryTransferredContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.InventoryTransferred.CurrentData;
	If Not ValueIsFilled(TabularSectionRow.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, 
		Object.Company, 
		TabularSectionRow.Counterparty, 
		TabularSectionRow.Contract, 
		TabularSectionRow.OperationKind, 
		"InventoryTransferred"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryTransferredProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.InventoryTransferred.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure // InventoryPassedProductsAndServicesOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - RECEIVED INVENTORY TS EVENT HANDLERS

// Procedure - OnStartEdit event handler of the InventoryReceived tabular field.
//
&AtClient
Procedure InventoryReceivedOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.InventoryReceived.CurrentData;
		TabularSectionRow.StructuralUnit = MainWarehouse;
		
	EndIf;
	
EndProcedure // InventoryReceivedOnStartEdit()

// Procedure - AfterDeletion event handler of the InventoryReceived tabular field.
//
&AtClient
Procedure InventoryReceivedAfterDeleteRow(Item)
	
	SetAccountsAttributesVisible(, , , , "InventoryReceived");
	
EndProcedure // InventoryReceivedAfterDeletion()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION ATTRIBUTES RECEIVED INVENTORY

// Procedure - OnActivateCell event handler of the InventoryReceived tabular field.
//
&AtClient
Procedure InventoryReceivedOnActivateCell(Item)
	
	// Order types availability.
	If Item.CurrentItem.Name = "InventoryReceivedOrder" Then
		
		TabularSectionRow = Items.InventoryReceived.CurrentData;
			
		If TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForCommission") Then
			
			ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder");
			
			NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsPurchaseOrder.OrderForPurchase"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
		ElsIf TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionIntoProcessing") Then
			
			NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForProcessing"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
			ValidTypes = New TypeDescription("DocumentRef.CustomerOrder");
			
		Else
			
			FilterArray = New Array;
			FilterArray.Add(Type("DocumentRef.PurchaseOrder"));
			FilterArray.Add(Type("DocumentRef.CustomerOrder"));
			ValidTypes = New TypeDescription(FilterArray);	
			
		EndIf;
		
		Item.CurrentItem.TypeRestriction = ValidTypes;
		
	// Batches.
	ElsIf Item.CurrentItem.Name = "InventoryReceivedBatch" Then	
		
		TabularSectionRow = Items.InventoryReceived.CurrentData;
		
		If TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForCommission") Then
			
			NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.ProductsOnCommission"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
		ElsIf TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionIntoProcessing") Then
			
			NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.CommissionMaterials"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
		ElsIf TabularSectionRow.OperationKind = PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForSafeCustody") Then
			
			NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.SafeCustody"));
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			Item.CurrentItem.ChoiceParameters = NewParameters;
			
		EndIf;
		
	EndIf;
	
EndProcedure // InventoryReceivedOnActivateCell()

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure InventoryReceivedOperationKindOnChange(Item)
	
	TabularSectionRow = Items.InventoryReceived.CurrentData;
	
	TabularSectionRow.Contract = GetContractByDefault(
		Object.Ref, TabularSectionRow.Counterparty, Object.Company, "InventoryReceived", TabularSectionRow.OperationKind);
	
EndProcedure

// Procedure - event handler OnChange of the Counterparty input field.
//
&AtClient
Procedure InventoryReceivedCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.InventoryReceived.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Object.Company, "InventoryReceived", TabularSectionRow.OperationKind);
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
	
	TabularSectionRow.Contract = StructureData.Contract;
	
EndProcedure // InventoryReceivedCounterpartyOnChange()

// Procedure - event handler StartChoice of the Contract input field.
//
&AtClient
Procedure InventoryReceivedContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.InventoryReceived.CurrentData;
	If Not ValueIsFilled(TabularSectionRow.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, 
		Object.Company, 
		TabularSectionRow.Counterparty,
		TabularSectionRow.Contract, 
		TabularSectionRow.OperationKind,
		"InventoryReceived"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryReceivedProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.InventoryReceived.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure // InventoryPassedProductsAndServicesOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF TABULAR SECTION ATTRIBUTES IN CCD PROFILE

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryByCCDProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.InventoryByCCD.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.CountryOfOrigin = StructureData.CountryOfOrigin;
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
	ClearCCDNomberOnChangeCountry();
	
EndProcedure // InventoryInCCDProfileProductsAndServicesOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TS ATTRIBUTES EVENT HANDLERS CASH ASSETS

// Procedure - OnStartEdit event handler of the tabular section.
//
&AtClient
Procedure CashAssetsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionRow = Items.CashAssets.CurrentData;
	
EndProcedure // CashAssetsOnStartEdit()

// Procedure - OnChange event handler of the BankAccountPettyCash input field.
//
&AtClient
Procedure CashAssetsBankAccountPettyCashOnChange(Item)

	TabularSectionRow = Items.CashAssets.CurrentData;

	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		Object.Date
	);

EndProcedure // CashAssetsBankAccountPettyCashOnChange()

// Procedure - OnChange event handler of
// the CashAssetsCurrency edit box in the CashAssets tabular section.
// Recalculates amount by amount (curr.) in the tabular section string.
//
&AtClient
Procedure CashAssetsCashAssetsCurrencyOnChange(Item)
	
	TabularSectionRow = Items.CashAssets.CurrentData;

	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 TabularSectionRow.CashCurrency,
																 Object.Date);
EndProcedure

// Procedure - OnChange event handler of
// the AmountCurr edit box in the CashAssest tabular section string.
// Recalculates amount by amount (curr.) in the tabular section string.
//
&AtClient
Procedure CashAssetsAmountCurOnChange(Item)
	
	TabularSectionRow = Items.CashAssets.CurrentData;

	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 TabularSectionRow.CashCurrency,
																 Object.Date);

EndProcedure // CashAssetsAmountCurrOnChange()

// Procedure - SelectionStart event handler of the CashAssestCurrency input field.
// Tabular section CashAssets.
//
&AtClient
Procedure CashAssetsCashAssetsCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.CashAssets.CurrentData;
	StructureData = GetDataCashAssetsCashAssetsCurrencyStartChoice(TabularSectionRow.BankAccountPettyCash);
	
	// If type of cash assets is changed, appropriate actions are required.
	If ValueIsFilled(StructureData.CashAssetsType)
	   AND StructureData.CashAssetsType <> Cash Then
		ShowMessageBox(Undefined,NStr("en='It is prohibited to change currency of the bank account!'"));
		StandardProcessing = False;
	EndIf;

EndProcedure // CashAssetsCashAssetsCurrencySelectStart()

//////////////////////////////////////////////////////////////////////////////////
//// PROCEDURE - TS ATTRIBUTES EVENT HANDLERS ACCOUNTS RECEIVABLE

// Procedure - OnChange event handler of the
// Counterparty edit box in the AccountsReceivable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableCounterpartyOnChange(Item)

	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Object.Company, "AccountsReceivable");
		
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 StructureData.SettlementsCurrency,
																 Object.Date);

EndProcedure // AccountsReceivableCounterpartyOnChange()

// Procedure - OnChange event handler of the
// Contract edit box in the AccountsReceivable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableContractOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 StructureData.SettlementsCurrency,
																 Object.Date);

EndProcedure // AccountsReceivableContractOnChange()

// Procedure - SelectionStart event handler of
// the Contract edit box in the AccountsReceivable tabular section string.
//
&AtClient
Procedure AccountsReceivableAccountsContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, 
		Object.Company, 
		TabularSectionRow.Counterparty, 
		TabularSectionRow.Contract, 
		Undefined, 
		"AccountsReceivable"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the
// AmountsCurr edit box in the AccountsReceivable tabular section string.
// recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsReceivableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 StructureData.SettlementsCurrency,
																 Object.Date);

EndProcedure // AccountsReceivableAmountCurrOnChange()

// Procedure - AfterDeletion event handler of the AccountsReceivable tabular section.
//
&AtClient
Procedure AccountsReceivableAfterDeleteRow(Item)
	
	SetAccountsAttributesVisible(, , , , "AccountsReceivable");
	
EndProcedure // AccountsReceivableAfterDeletion()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TS ATTRIBUTES EVENT HANDLERS ACCOUNTS PAYABLE

// Procedure - OnChange event handler of
// the Counterparty edit box in the AccountsPayable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableCounterpartyOnChange(Item)

	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Object.Company, "AccountsPayable");
		
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
		
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 StructureData.SettlementsCurrency,
																 Object.Date);

EndProcedure // AccountsPayableCounterpartyOnChange()

// Procedure - OnChange event handler of
// the Contract edit box in the AccountsPayable tabular section string.
// Generates the Contract
// column value, recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableContractOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 StructureData.SettlementsCurrency,
																 Object.Date);

EndProcedure // AccountsPayableContractOnChange()

// Procedure - SelectionStart event handler of
// the Contract edit box in the AccountsPayable tabular section string.
//
&AtClient
Procedure AccountsPayableContractBeginChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	FormParameters = GetChoiceFormParameters(Object.Ref,
		Object.Company,
		TabularSectionRow.Counterparty,
		TabularSectionRow.Contract, 
		Undefined,
		"AccountsPayable"
	);
	
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of
// the AmountCurr edit box in the AccountsPayable tabular section string.
// recalculates amount in the man. currency. account from the amount in the document currency.
//
&AtClient
Procedure AccountsPayableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	StructureData = GetDataContractOnChange(TabularSectionRow.Contract);

	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 StructureData.SettlementsCurrency,
																 Object.Date);

EndProcedure // AccountsPayableAmountCurrOnChange()

// Procedure - AfterDeletion event handler of the AccountsPayable tabular section.
//
&AtClient
Procedure AccountsPayableAfterDeleteRow(Item)
	
	SetAccountsAttributesVisible(, , , , "AccountsPayable");
	
EndProcedure // AccountsPayableAfterDeletion()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TS ATTRIBUTES EVENT HANDLERS PAYROLL PAYMENTS

// Procedure - OnStartEdit event handler of the PayrollPayments tabular section.
//
&AtClient
Procedure PayrollPaymentsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.PayrollPayments.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		
		TabularSectionRow.StructuralUnit = MainDivision;
		
	EndIf;
	
EndProcedure // PayrollPaymentsOnStartEdit()

// Procedure - OnChange event handler of the
// Currency edit box in the PayrollPayments tabular section string.
// recalculates amount in the man. currency. account from amount in the settlements currency.
//
&AtClient
Procedure PayrollPaymentsCurrencyOnChange(Item)
	
	TabularSectionRow = Items.PayrollPayments.CurrentData;
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 TabularSectionRow.Currency,
																 Object.Date);

EndProcedure // PayrollPaymentsCurrencyOnChange()

// Procedure - OnChange event handler of the
// AmountCurr edit box in the PayrollPayments tabular section string.
// recalculates amount in the man. currency. account from amount in the settlements currency.
//
&AtClient
Procedure PayrollPaymentsAmountCurOnChange(Item)
	
	TabularSectionRow = Items.PayrollPayments.CurrentData;

	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 TabularSectionRow.Currency,
																 Object.Date);

EndProcedure // PayrollPaymentsAmountCurrOnChange()

// Procedure - OnChange event handler of
// the RegistrationPeriod edit box in the PayrollPayments tabular section string.
// Aligns registration period on the month start.
//
&AtClient
Procedure RegisterRecordsPayrollPaymentsPeriodOnChange(Item)
	
	CurRow = Items.PayrollPayments.CurrentData;
	CurRow.RegistrationPeriod = BegOfMonth(CurRow.RegistrationPeriod);
	
EndProcedure // RegisterRecordsPayrollPaymentsPeriodOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TS ATTRIBUTES EVENT HANDLERS ADVANCE HOLDER PAYMENTS

// Procedure - OnStartEdit event handler of the AdvanceHolderPayments tabular section.
//
&AtClient
Procedure AdvanceHolderPaymentsOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.AdvanceHolderPayments.CurrentData;
		TabularSectionRow.Currency = CurrencyByDefault;
		
	EndIf;
	
EndProcedure // AdvanceHolderPaymentsOnStartEdit()

// Procedure - OnChange event handler of the
// Currency edit box in the AdvanceHolderPayments tabular section string.
// recalculates amount in the man. currency. account from amount in the settlements currency.
//
&AtClient
Procedure AdvanceHolderPaymentsCurrencyOnChange(Item)
	
	TabularSectionRow = Items.AdvanceHolderPayments.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 TabularSectionRow.Currency,
																 Object.Date);

EndProcedure // AdvanceHolderPaymentsCurrencyOnChange()

// Procedure - OnChange event handler of the
// AmountCurr edit box in the AdvanceHolderPayments tabular section string.
// recalculates amount in the man. currency. account from amount in the settlements currency.
//
&AtClient
Procedure AdvanceHolderPaymentsAmountCurOnChange(Item)
	
	TabularSectionRow = Items.AdvanceHolderPayments.CurrentData;

	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(TabularSectionRow.AmountCur,
																 TabularSectionRow.Currency,
																 Object.Date);

EndProcedure // AdvanceHolderPaymentsAmountCurrOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TS ATTRIBUTES EVENT HANDLERS OTHER SECTIONS

// Procedure - OnChange event handler of the Account input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAccountOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.Currency = Undefined;
		CurrentRow.AmountCur = Undefined;
	EndIf;
	
EndProcedure // OtherSectionsAccountOnChange()

// Procedure - SelectionStart event handler of the Currency input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'For the selected account the currency flag is not set!'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure // OtherSectionsCurrencySelectionStart()

// Procedure - event handler OnChange of the Currency input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsCurrencyOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.Currency = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'For the selected account the currency flag is not set!'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure // OtherSectionsCurrencyOnChange()

// Procedure - SelectionStart event handler of the AmountCurr input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAmountCurStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'For the selected account the currency flag is not set!'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure // OtherSectionsAmountCurrSelectionStart()

// Procedure - OnChange event handler of the AmountCurr input field.
// Transactions tabular section.
//
&AtClient
Procedure OtherSectionsAmountCurOnChange(Item)
	
	CurrentRow = Items.OtherSections.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.Account);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCur = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.Account) Then
			ShowMessageBox(Undefined,NStr("en = 'For the selected account the currency flag is not set!'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the account first.'"));
		EndIf;
	EndIf;
	
EndProcedure // OtherSectionsAmountCurrOnChange()

// Procedure - event handler AfterWriteAtServer form.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , , "AccountsReceivable");
	SetAccountsAttributesVisible(, , , , "InventoryTransferred");
	SetAccountsAttributesVisible(, , , , "InventoryReceived");
	
EndProcedure // AfterWriteAtServer

// Procedure - OnChange event handler of the AdvanceFlag box of the AccountsPayable table.
//
&AtClient
Procedure AccountsPayableAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.Netting") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashPayment")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentExpense")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure // AccountsPayableAdvanceFlagOnChange()

// Procedure - OnChange event handler of the Document box of the AccountsPayable table.
//
&AtClient
Procedure AccountsPayableDocumentOnChange(Item)
	
	TabularSectionRow = Items.AccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.Netting") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure // AccountsPayableDocumentOnChange()

// Procedure - OnChange event handler of the AdvanceFlag box of the AccountsReceivable table.
//
&AtClient
Procedure AccountsReceivableAdvanceFlagPaymentOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.Netting") Then
		Return;
	EndIf;
	
	If TabularSectionRow.AdvanceFlag Then
		
		If TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.CashReceipt")
			AND TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	Else
		
		If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
		 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
			TabularSectionRow.Document = Undefined;
		EndIf;
		
	EndIf;
	
EndProcedure // AccountsReceivableAdvanceFlagOnChange()

// Procedure - OnChange event handler of the Document box of the AccountsReceivable table.
//
&AtClient
Procedure AccountsReceivableDocumentOnChange(Item)
	
	TabularSectionRow = Items.AccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.Netting") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure // AccountsReceivableDocumentOnChange()

// Procedure - OnChange event handler of the Autogenerate box.
//
&AtClient
Procedure AutogenerationOnChange(Item)
	
	If Object.Autogeneration Then
		For Each TSRow IN Object.AccountsReceivable Do
			TSRow.Document = Undefined;
		EndDo;
		
		For Each TSRow IN Object.AccountsPayable Do
			TSRow.Document = Undefined;
		EndDo;
		
		For Each TSRow IN Object.AdvanceHolderPayments Do
			TSRow.Document = Undefined;
		EndDo;
	EndIf;
	
EndProcedure // AutogenerationOnChange()

// Function checks products and services by type
//
&AtServerNoContext
Function ProductsAndServicesTypeInventory(ProductsAndServicesRef)
	
	Return ProductsAndServicesRef.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
	
EndFunction // ProductsAndServicesInventory()

// Procedure - SelectionStart event handler of the CCDNumber box of the Inventory tabular section
//
&AtClient
Procedure InventoryByCCDDStartRMNumberChoice(Item, ChoiceData, StandardProcessing)
	
	DataCurrentRows = Items.InventoryByCCD.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		MessageText = "";
		
		If Not ValueIsFilled(DataCurrentRows.CountryOfOrigin) Then
			
			MessageText = NStr("en = 'Country of origin is not filled!'");
			CommonUseClientServer.MessageToUser(MessageText);
			
			StandardProcessing = False;
			
		EndIf;
		
		If ValueIsFilled(DataCurrentRows.CountryOfOrigin)
		   AND DataCurrentRows.CountryOfOrigin = PredefinedValue("Catalog.WorldCountries.Russia") Then
			
			MessageText = NStr("en = 'CCD accounting for the native products is not kept!'");
			CommonUseClientServer.MessageToUser(MessageText);
			
			StandardProcessing = False;
			
		EndIf;
		
		If (ValueIsFilled(DataCurrentRows.ProductsAndServices)
			AND Not ProductsAndServicesTypeInventory(DataCurrentRows.ProductsAndServices)) Then
			
			MessageText = NStr("en = 'CCD account is kept only for products and services with the ""Inventory"" type.'");
			CommonUseClientServer.MessageToUser(MessageText);
			StandardProcessing = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure // InventoryInCCDProfileCCDNumberSelectionStart()

// Procedure - OnChange event handler of the InventoryInCCDProfileOriginCountry box of the Inventory tabular section
//
&AtClient
Procedure InventoryByCCDCountryOfOriginOnChange(Item)
	
	ClearCCDNomberOnChangeCountry();

EndProcedure // InventoryInCCDProfileOriginCountryOnChange()

// The procedure clears CCD number while changing origin country.
//
&AtClient
Procedure ClearCCDNomberOnChangeCountry()
	
	DataCurrentRows = Items.InventoryByCCD.CurrentData;
	
	If DataCurrentRows <> Undefined Then
		
		If Not ValueIsFilled(DataCurrentRows.CountryOfOrigin)
			OR DataCurrentRows.CountryOfOrigin = PredefinedValue("Catalog.WorldCountries.Russia") Then
			DataCurrentRows.CCDNo = Undefined;
		EndIf;
		
	EndIf;

EndProcedure // ClearCCDNumberOnCountryChange()

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure ImportDataFromExternalSourceInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceAccountsReceivable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceAccountsPayable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable";
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		FillingObjectFullName = AdditionalParameters.FillingObjectFullName;
		If ImportResult.ActionsDetails = "ChangeDataImportFromExternalSourcesMethod" Then
		
			DataImportFromExternalSources.ChangeDataImportFromExternalSourcesMethod(DataLoadSettings.DataImportFormNameFromExternalSources);
			
			NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
			DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
			
		ElsIf ImportResult.ActionsDetails = "ProcessPreparedData" Then
			
			If FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory" Then
				
				ProcessPreparedDataInventory(ImportResult);
				
			ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable" Then
				
				ProcessPreparedDataAccountsReceivable(ImportResult);
				
			ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable" Then
				
				ProcessPreparedDataAccountsPayable(ImportResult);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedDataInventory(ImportResult)
	
	Try
		
		BeginTransaction();
		
		DataMatchingTable = ImportResult.DataMatchingTable;
		For Each TableRow IN DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			If ImportToApplicationIsPossible Then
				
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, TableRow);
				
				NewRow.Amount = TableRow.Price * TableRow.Quantity;
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.Documents.EnterOpeningBalance, , NStr("en ='Inventory: '") + ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure

&AtServer
Procedure ProcessPreparedDataAccountsReceivable(ImportResult)
	
	Try
		
		BeginTransaction();
		
		DataMatchingTable = ImportResult.DataMatchingTable;
		For Each TableRow IN DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			If ImportToApplicationIsPossible Then
				
				NewRow = Object.AccountsReceivable.Add();
				FillPropertyValues(NewRow, TableRow, "Counterparty, Contract, AdvanceFlag, AmountCur, Amount", );
				
				StructureData = GetDataCounterpartyOnChange(NewRow.Counterparty, Object.Company, "AccountsReceivable");
				If Not ValueIsFilled(NewRow.Contract) Then
					
					NewRow.Contract = StructureData.Contract;
					
				EndIf;
				
				NewRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
				NewRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
				NewRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
				NewRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
				
				NewRow.Amount = RecalculateFromCurrencyToAccountingCurrency(NewRow.AmountCur, StructureData.SettlementsCurrency, Object.Date);
				
				If NewRow.DoOperationsByOrders Then
					
					NewRow.CustomerOrder = TableRow.Order;
					
				EndIf;
				
				If NewRow.DoOperationsByDocuments Then
					
					NewRow.Document = TableRow.Document;
					
				EndIf;
				
				If NewRow.TrackPaymentsByBills Then
					
					NewRow.InvoiceForPayment = TableRow.Account;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.Documents.EnterOpeningBalance, , NStr("en ='Accounts receivable: '") + ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure

&AtServer
Procedure ProcessPreparedDataAccountsPayable(ImportResult)
	
	Try
		
		BeginTransaction();
		
		DataMatchingTable = ImportResult.DataMatchingTable;
		For Each TableRow IN DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			If ImportToApplicationIsPossible Then
				
				NewRow = Object.AccountsPayable.Add();
				FillPropertyValues(NewRow, TableRow, "Counterparty, Contract, AdvanceFlag, AmountCur, Amount", );
				
				StructureData = GetDataCounterpartyOnChange(NewRow.Counterparty, Object.Company, "AccountsPayable");
				If Not ValueIsFilled(NewRow.Contract) Then
					
					NewRow.Contract = StructureData.Contract;
					
				EndIf;
				
				NewRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
				NewRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
				NewRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
				NewRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
				
				NewRow.Amount = RecalculateFromCurrencyToAccountingCurrency(NewRow.AmountCur, StructureData.SettlementsCurrency, Object.Date);
				
				If NewRow.DoOperationsByOrders Then
					
					NewRow.PurchaseOrder = TableRow.Order;
					
				EndIf;
				
				If NewRow.DoOperationsByDocuments Then
					
					NewRow.Document = TableRow.Document;
					
				EndIf;
				
				If NewRow.TrackPaymentsByBills Then
					
					NewRow.InvoiceForPayment = TableRow.Account;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.Documents.EnterOpeningBalance, , NStr("en ='Accounts receivable: '") + ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion