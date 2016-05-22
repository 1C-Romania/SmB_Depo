////////////////////////////////////////////////////////////////////////////////
// MODAL VARIABLES MASTERS (Client)

&AtClient
Var mCurrentPageNumber;

&AtClient
Var mFirstPage;

&AtClient
Var mLastPage;

&AtClient
Var mFormRecordCompleted;

////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure sets the explanation text.
//
&AtClient
Procedure SetExplanationText()
	
	If mCurrentPageNumber = 0 Then
		Items.DecorationNextActionExplanation.Title = "Click Next to fill cash funds balance";
	ElsIf mCurrentPageNumber = 1 Then
		Items.DecorationNextActionExplanation.Title = "Click Next to fill balances of products";
	ElsIf mCurrentPageNumber = 2 Then
		Items.DecorationNextActionExplanation.Title = "Click Next to fill balance by acounts payable";
	ElsIf mCurrentPageNumber = 3 Then
		Items.DecorationNextActionExplanation.Title = "Click Next to fill balance by acounts receivable";
	ElsIf mCurrentPageNumber = 4 Then
		Items.DecorationNextActionExplanation.Title = "Press ""Next"" to proceed to the final step";
	ElsIf mCurrentPageNumber = 5 Then
		Items.DecorationNextActionExplanation.Title = "To complete, it is required to click Finish";
	EndIf;
	
EndProcedure // SetExplanationText()

// Procedure sets the active page.
//
&AtClient
Procedure SetActivePage()
	
	SearchString = "Step" + String(mCurrentPageNumber);
	Items.Pages.CurrentPage = Items.Find(SearchString);
	
	ThisForm.Title = "Opening balance input wizard (Step " + String(mCurrentPageNumber)+ "/" + String(mLastPage) + ")";
	SetExplanationText();
	
EndProcedure // SetActivePage()

// Procedure sets the buttons accessibility.
//
&AtClient
Procedure SetButtonsEnabled()
	
	Items.Back.Enabled = mCurrentPageNumber <> mFirstPage;
	
	If mCurrentPageNumber = mLastPage Then
		Items.GoToNext.Title = "Finish";
		Items.GoToNext.Representation = ButtonRepresentation.Text;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,True);
	Else
		Items.GoToNext.Title = "Next";
		Items.GoToNext.Representation = ButtonRepresentation.PictureAndText;
		Items.GoToNext.Font = New Font(Items.GoToNext.Font,,,False);
	EndIf;
	
EndProcedure // SetButtonsEnabled()

// Function adds products and services.
//
&AtServerNoContext
Function AddProductsAndServicesAtServer(ProductsAndServices, UseBatches, UseCharacteristics)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductsAndServices.Ref
	|FROM
	|	Catalog.ProductsAndServices AS ProductsAndServices
	|WHERE
	|	ProductsAndServices.Description = &Description";
	Query.SetParameter("Description", ProductsAndServices);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	If SelectionOfQueryResult.Next() Then
		ProductsAndServicesToReturn = SelectionOfQueryResult.Ref;
	Else
		NewProductsAndServices = Catalogs.ProductsAndServices.CreateItem();
		NewProductsAndServices.Description = ProductsAndServices;
		NewProductsAndServices.DescriptionFull = ProductsAndServices;
		NewProductsAndServices.UseBatches = UseBatches = Enums.YesNo.Yes;
		NewProductsAndServices.UseCharacteristics = UseCharacteristics = Enums.YesNo.Yes;
		NewProductsAndServices.MeasurementUnit = Catalogs.UOMClassifier.pcs;
		NewProductsAndServices.ProductsAndServicesCategory = Catalogs.ProductsAndServicesCategories.MainGroup;
		NewProductsAndServices.InventoryGLAccount = ChartsOfAccounts.Managerial.RawMaterialsAndMaterials;
		NewProductsAndServices.ExpensesGLAccount = ChartsOfAccounts.Managerial.UnfinishedProduction;
		NewProductsAndServices.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
		NewProductsAndServices.EstimationMethod = Enums.InventoryValuationMethods.ByAverage;
		NewProductsAndServices.BusinessActivity = Catalogs.BusinessActivities.MainActivity;
		NewProductsAndServices.VATRate = Catalogs.Companies.MainCompany.DefaultVATRate;
		NewProductsAndServices.ProductsAndServicesType = Enums.ProductsAndServicesTypes.InventoryItem;
		NewProductsAndServices.OrderCompletionDeadline = 1;
		NewProductsAndServices.ReplenishmentDeadline = 1;
		NewProductsAndServices.Warehouse = Catalogs.StructuralUnits.MainWarehouse;
		NewProductsAndServices.Write();
		ProductsAndServicesToReturn = NewProductsAndServices.Ref;
	EndIf;
	
	StructuralUnitUser = SmallBusinessReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainWarehouse");
	
	ReturnStructure = New Structure("ProductsAndServices, StructuralUnit", ProductsAndServicesToReturn, ?(ValueIsFilled(ProductsAndServicesToReturn.Warehouse), ProductsAndServicesToReturn.Warehouse, StructuralUnitUser));
	
	Return ReturnStructure;
	
EndFunction // AddProductsAndServicesAtServer()

// Procedure writes the form changes.
//
&AtServer
Procedure WriteFormChanges(FinishEntering = False)
	
	If EnterOpeningBalanceBankAndPettyCash.CashAssets.Count() > 0 Then
		EnteringInitialBalancesBankAndCashObject = FormAttributeToValue("EnterOpeningBalanceBankAndPettyCash");
		EnteringInitialBalancesBankAndCashObject.Date = BalanceDate;
		EnteringInitialBalancesBankAndCashObject.Company = Company;
		EnteringInitialBalancesBankAndCashObject.Comment = "# Document is entered by the balances input assistant.";
		EnteringInitialBalancesBankAndCashObject.AccountingSection = "Cash assets";
		EnteringInitialBalancesBankAndCashObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(EnteringInitialBalancesBankAndCashObject, "EnterOpeningBalanceBankAndPettyCash");
	EndIf;
	
	If EnterOpeningBalanceProducts.Inventory.Count() > 0 Then
		EnterOpeningBalanceProductsObject = FormAttributeToValue("EnterOpeningBalanceProducts");
		EnterOpeningBalanceProductsObject.Date = BalanceDate;
		EnterOpeningBalanceProductsObject.Company = Company;
		EnterOpeningBalanceProductsObject.Comment = "# Document is entered by the balances input assistant.";
		EnterOpeningBalanceProductsObject.AccountingSection = "Inventory";
		EnterOpeningBalanceProductsObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(EnterOpeningBalanceProductsObject, "EnterOpeningBalanceProducts");
	EndIf;
	
	If EnterOpeningBalanceCounterpartiesSettlements.AccountsPayable.Count() > 0
	 OR EnterOpeningBalanceCounterpartiesSettlements.AccountsReceivable.Count() > 0 Then
		EnterOpeningBalanceCounterpartiesSettlementsObject = FormAttributeToValue("EnterOpeningBalanceCounterpartiesSettlements");
		EnterOpeningBalanceCounterpartiesSettlementsObject.Date = BalanceDate;
		EnterOpeningBalanceCounterpartiesSettlementsObject.Company = Company;
		EnterOpeningBalanceCounterpartiesSettlementsObject.Autogeneration = True;
		EnterOpeningBalanceCounterpartiesSettlementsObject.Comment = "# Document is entered by the balances input assistant.";
		EnterOpeningBalanceCounterpartiesSettlementsObject.AccountingSection = "Settlements with suppliers and customers";
		EnterOpeningBalanceCounterpartiesSettlementsObject.Write(DocumentWriteMode.Posting);
		ValueToFormAttribute(EnterOpeningBalanceCounterpartiesSettlementsObject, "EnterOpeningBalanceCounterpartiesSettlements");
	EndIf;
	
	Constants.FunctionalOptionAccountingByMultipleWarehouses.Set(
		?(AccountingBySeveralWarehouses = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.FunctionalOptionAccountingInVariousUOM.Set(
		?(AccountingInVariousUOM = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.FunctionalOptionUseCharacteristics.Set(
		?(UseCharacteristics = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.FunctionalOptionUseBatches.Set(
		?(UseBatches = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.FunctionalCurrencyTransactionsAccounting.Set(
		?(CurrencyTransactionsAccounting = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	Constants.AccountingCurrency.Set(AccountingCurrency);
	Constants.NationalCurrency.Set(NationalCurrency);
	
	If FinishEntering Then
		Constants.InitialSettingOpeningBalancesFilled.Set(True);
	EndIf;
	
	SetAccountsAttributesVisible(, , , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , , "AccountsReceivable");
	
EndProcedure // WriteFormChanges()

// Procedure calculates the amount in tabular section row.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine()
	
	TabularSectionRow = Items.EnterOpeningBalanceProductsInventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure // CalculateAmountInTabularSectionLine()

// Procedure writes changes of accounting in various units.
//
&AtServerNoContext
Procedure WriteChangesAccountingInVariousUOM(AccountingInVariousUOM)
	
	Constants.FunctionalOptionAccountingInVariousUOM.Set(
		?(AccountingInVariousUOM = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure // WriteChangesAccountingInVariousUOM()

// Procedure writes changes of accounting by multiple warehouses.
//
&AtServerNoContext
Procedure WriteChangesAccountingBySeveralWarehouses(AccountingBySeveralWarehouses)
	
	Constants.FunctionalOptionAccountingByMultipleWarehouses.Set(
		?(AccountingBySeveralWarehouses = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure // WriteChangesAccountingInVariousUOM()

// Procedure writes changes in characteristics application.
//
&AtServerNoContext
Procedure WriteChangesUseCharacteristics(UseCharacteristics)
	
	Constants.FunctionalOptionUseCharacteristics.Set(
		?(UseCharacteristics = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure // WriteChangesUseCharacteristics()

&AtServerNoContext
// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure();
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataMeasurementUnitOnChange()

// Procedure writes the changes in batches usage.
//
&AtServerNoContext
Procedure WriteChangesUseBatches(UseBatches)
	
	Constants.FunctionalOptionUseBatches.Set(
		?(UseBatches = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
EndProcedure // WriteChangesUseBatches()

// Function puts the Inventory tabular section in
// temporary storage and returns the address.
//
&AtServer
Function PlaceInventoryToStorage()
	
	Return PutToTempStorage(
		EnterOpeningBalanceProducts.Inventory.Unload(,
			"ProductsAndServices,
			|Characteristic,
			|Batch,
			|MeasurementUnit,
			|Price"
		),
		UUID
	);
	
EndFunction // PlaceInventoryToStorage()

// Procedure writes changes of currency operations accounting.
//
&AtServer
Procedure WriteChangesCurrencyTransactionsAccounting(CurrencyTransactionsAccounting)
	
	Constants.FunctionalCurrencyTransactionsAccounting.Set(
		?(CurrencyTransactionsAccounting = Enums.YesNo.Yes,
			True,
			False
		)
	);
	
	If CurrencyTransactionsAccounting = PredefinedValue("Enum.YesNo.Yes") Then
		Items.AccountingCurrency.ReadOnly = False;
		Items.AccountingCurrency.AutoChoiceIncomplete = True;
		Items.AccountingCurrency.AutoMarkIncomplete = True;
		Items.NationalCurrency.ReadOnly = False;
		Items.NationalCurrency.AutoChoiceIncomplete = True;
		Items.NationalCurrency.AutoMarkIncomplete = True;
	Else
		Items.AccountingCurrency.ReadOnly = True;
		Items.AccountingCurrency.AutoChoiceIncomplete = False;
		Items.AccountingCurrency.AutoMarkIncomplete = False;
		Items.NationalCurrency.ReadOnly = True;
		Items.NationalCurrency.AutoChoiceIncomplete = False;
		Items.NationalCurrency.AutoMarkIncomplete = False;
		AccountingCurrency = NationalCurrency;
	EndIf;
	
EndProcedure // WriteChangesCurrencyTransactionsAccounting()

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

// Function converts the amount from specified currency to the currency of man. accounting.
//
// Parameters:      
// AmountCur  - Number                    - Currency amount that shall be recalculated.
// Currency    - Catalog.Ref.Currencies - currency from which it is required to recalculate.
// ExchangeRateDate - Date                     - exchange rate date.
//
// Returns: 
//  Number - Amount in the currency of management. accounting.
//
&AtServerNoContext
Function RecalculateFromCurrencyToAccountingCurrency(AmountCur, CurrencyContract, ExchangeRateDate) Export
	
	Amount = 0;
	
	If ValueIsFilled(CurrencyContract) Then
		
		Currency = ?(TypeOf(CurrencyContract) = Type("CatalogRef.CounterpartyContracts"), CurrencyContract.SettlementsCurrency, CurrencyContract);
		
		AccountingCurrency = Constants.AccountingCurrency.Get();
		
		CurrencyRatesStructure = SmallBusinessServer.GetCurrencyRates(Currency, AccountingCurrency, ExchangeRateDate);
		
		Amount = SmallBusinessServer.RecalculateFromCurrencyToCurrency(
			AmountCur,
			CurrencyRatesStructure.InitRate,
			CurrencyRatesStructure.ExchangeRate,
			CurrencyRatesStructure.RepetitionBeg,
			CurrencyRatesStructure.Multiplicity
		);
		
	EndIf;
	
	Return Amount;
	
EndFunction // RecalculateFromCurrencyToAccountingCurrency()

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

// Procedure checks filling of the mandatory attributes when you go to the next page.
//
&AtClient
Procedure ExecuteActionsOnTransitionToNextPage(Cancel)
	
	ClearMessages();
	
	If mCurrentPageNumber = 1 Then
		
		If Not ValueIsFilled(AccountingCurrency) Then
			MessageText = NStr("en = 'Specify currency of accounting.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"AccountingCurrency",
				,
				Cancel
			);
		EndIf;
		
		If Not ValueIsFilled(NationalCurrency) Then
			MessageText = NStr("en = 'Specify national currency.'");
			CommonUseClientServer.MessageToUser(
				MessageText,
				,
				"NationalCurrency",
				,
				Cancel
			);
		EndIf;
		
		For Each CurRow IN EnterOpeningBalanceBankAndPettyCash.CashAssets Do
			If Not ValueIsFilled(CurRow.BankAccountPettyCash) Then
				MessageText = NStr("en = 'Specify banking account or petty cash in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.CashCurrency) Then
				MessageText = NStr("en = 'Specify currency in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = NStr("en = 'Specify amount in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
			If CurrencyTransactionsAccounting = PredefinedValue("Enum.YesNo.Yes")
			AND Not ValueIsFilled(CurRow.Amount) Then
				MessageText = NStr("en = 'Specify amount by accounting currency in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceBankAndPettyCash",
					,
					Cancel
				);
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 2 Then
		
		For Each CurRow IN EnterOpeningBalanceProducts.Inventory Do
			If Not ValueIsFilled(CurRow.StructuralUnit) Then
				MessageText = NStr("en = 'Specify structural unit in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceProducts",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.ProductsAndServices) Then
				MessageText = NStr("en = 'Specify item of list of goods in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceProducts",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.MeasurementUnit) Then
				MessageText = NStr("en = 'Specify unit of measurement in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceProducts",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Quantity) Then
				MessageText = NStr("en = 'Specify quantity in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceProducts",
					,
					Cancel
				);
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 3 Then
		
		For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements.AccountsPayable Do
			If Not ValueIsFilled(CurRow.Counterparty) Then
				MessageText = NStr("en = 'Specify counterparty in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Contract) Then
				MessageText = NStr("en = 'Specify contract in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = NStr("en = 'Specify amount in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If CurrencyTransactionsAccounting = PredefinedValue("Enum.YesNo.Yes")
			AND Not ValueIsFilled(CurRow.Amount) Then
				MessageText = NStr("en = 'Specify amount by accounting currency in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceProducts",
					,
					Cancel
				);
			EndIf;
		EndDo;
		
	ElsIf mCurrentPageNumber = 4 Then
		
		For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements.AccountsReceivable Do
			If Not ValueIsFilled(CurRow.Counterparty) Then
				MessageText = NStr("en = 'Specify counterparty in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.Contract) Then
				MessageText = NStr("en = 'Specify contract in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If Not ValueIsFilled(CurRow.AmountCur) Then
				MessageText = NStr("en = 'Specify amount in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceCounterpartiesSettlements",
					,
					Cancel
				);
			EndIf;
			If CurrencyTransactionsAccounting = PredefinedValue("Enum.YesNo.Yes")
			AND Not ValueIsFilled(CurRow.Amount) Then
				MessageText = NStr("en = 'Specify amount by accounting currency in the line '") + CurRow.LineNumber + ".";
				CommonUseClientServer.MessageToUser(
					MessageText,
					,
					"EnterOpeningBalanceProducts",
					,
					Cancel
				);
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure // ExecuteActionsOnTransitionToNextPage()

// Imports the form settings.
// If settings are imported during form attribute
// change, for example for new company, it shall be checked
// whether extension for file handling is enabled.
//
// Data in attributes of the processed object will be a flag of connection failure:
// ExportFile, ImportFile
//
&AtServer
Procedure ImportFormSettings()
	
	Settings = SystemSettingsStorage.Load("CommonForm.FormBalancesEntering", "FormSettings");
	
	If Settings <> Undefined Then
		AssistantSimpleUseMode = Settings.Get("AssistantSimpleUseMode");
	EndIf;
	
EndProcedure // ImportFormSettings()

// Saves form settings.
//
&AtServer
Procedure SaveFormSettings()
	
	Settings = New Map;
	Settings.Insert("AssistantSimpleUseMode", AssistantSimpleUseMode);
	SystemSettingsStorage.Save("CommonForm.FormBalancesEntering", "FormSettings", Settings);
	
EndProcedure // SaveFormSettings()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	mCurrentPageNumber = 0;
	mFirstPage = 0;
	mLastPage = 5;
	mFormRecordCompleted = False;
	
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // OnOpen()

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company = Catalogs.Companies.MainCompany;
	
	InformationCenterServer.OutputContextReferences(ThisForm, Items.InformationReferences);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EnterOpeningBalance.Ref,
	|	EnterOpeningBalance.Comment,
	|	EnterOpeningBalance.AccountingSection,
	|	EnterOpeningBalance.Autogeneration,
	|	EnterOpeningBalance.Date
	|FROM
	|	Document.EnterOpeningBalance AS EnterOpeningBalance
	|WHERE
	|	EnterOpeningBalance.Comment LIKE &Comment";
	
	Query.SetParameter("Comment", "# Document is entered by the balances input assistant.");
	
	SelectionQueryResult = Query.Execute().Select();
	
	While SelectionQueryResult.Next() Do
		If SelectionQueryResult.AccountingSection = "Cash assets" Then
			ValueToFormAttribute(SelectionQueryResult.Ref.GetObject(), "EnterOpeningBalanceBankAndPettyCash");
		ElsIf SelectionQueryResult.AccountingSection = "Inventory" Then
			ValueToFormAttribute(SelectionQueryResult.Ref.GetObject(), "EnterOpeningBalanceProducts");
		ElsIf SelectionQueryResult.AccountingSection = "Settlements with suppliers and customers" Then
			ValueToFormAttribute(SelectionQueryResult.Ref.GetObject(), "EnterOpeningBalanceCounterpartiesSettlements");
			AutoGenerateAccountingDocuments = ?(
				SelectionQueryResult.Autogeneration,
				Enums.YesNo.Yes,
				Enums.YesNo.No
			);
		EndIf;
		BalanceDate = SelectionQueryResult.Date;
	EndDo;
	
	AccountingBySeveralWarehouses = ?(
		Constants.FunctionalOptionAccountingByMultipleWarehouses.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	AccountingInVariousUOM = ?(
		Constants.FunctionalOptionAccountingInVariousUOM.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	UseCharacteristics = ?(
		Constants.FunctionalOptionUseCharacteristics.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	UseBatches = ?(
		Constants.FunctionalOptionUseBatches.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	CurrencyTransactionsAccounting = ?(
		Constants.FunctionalCurrencyTransactionsAccounting.Get(),
		Enums.YesNo.Yes,
		Enums.YesNo.No
	);
	
	AccountingCurrency = Constants.AccountingCurrency.Get();
	NationalCurrency = Constants.NationalCurrency.Get();
	
	If CurrencyTransactionsAccounting = Enums.YesNo.Yes Then
		Items.AccountingCurrency.ReadOnly = False;
		Items.AccountingCurrency.AutoChoiceIncomplete = True;
		Items.AccountingCurrency.AutoMarkIncomplete = True;
		Items.NationalCurrency.ReadOnly = False;
		Items.NationalCurrency.AutoChoiceIncomplete = True;
		Items.NationalCurrency.AutoMarkIncomplete = True;
	Else
		Items.AccountingCurrency.ReadOnly = True;
		Items.AccountingCurrency.AutoChoiceIncomplete = False;
		Items.AccountingCurrency.AutoMarkIncomplete = False;
		Items.NationalCurrency.ReadOnly = True;
		Items.NationalCurrency.AutoChoiceIncomplete = False;
		Items.NationalCurrency.AutoMarkIncomplete = False;
	EndIf;
	
	ImportFormSettings();
	
	If Not ValueIsFilled(AssistantSimpleUseMode) Then
		AssistantSimpleUseMode = Enums.YesNo.Yes;
	EndIf;
	
	SetAssistantUsageMode();
	
	// Filling in the additional attributes of tabular section.
	SetAccountsAttributesVisible(, , , , "AccountsPayable");
	SetAccountsAttributesVisible(, , , , "AccountsReceivable");
	
	If Not ValueIsFilled(BalanceDate) Then
		BalanceDate = CurrentDate();
	EndIf;
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.EnterOpeningBalance.TabularSections.Inventory, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not mFormRecordCompleted
		AND Modified Then
		
		Cancel = True;
		NotifyDescription = New NotifyDescription("BeforeCloseEnd", ThisObject);
		Text = NStr("en='To want to save the changes made?'");
		ShowQueryBox(NOTifyDescription, Text, QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure // BeforeClose()

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		Cancel = False;
		ExecuteActionsOnTransitionToNextPage(Cancel);
		If Not Cancel Then
			WriteFormChanges();
			SaveFormSettings();
			Modified = False;
			Close();
		EndIf;
	ElsIf Result = DialogReturnCode.No Then
		Modified = False;
		Close();
	EndIf;
	
EndProcedure // BeforeCloseEnd()

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AfterRecordingOfCounterparty" Then
		If ValueIsFilled(Parameter) Then
			For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements.AccountsReceivable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , , "AccountsReceivable");
					Return;
				EndIf;
			EndDo;
			For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements.AccountsPayable Do
				If Parameter = CurRow.Counterparty Then
					SetAccountsAttributesVisible(, , , , "AccountsPayable");
					Return;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - CloseForm command handler.
//
&AtClient
Procedure CloseForm(Command)
	
	Close(False);
	
EndProcedure // CloseForm()

// Procedure - Next command handler.
//
&AtClient
Procedure GoToNext(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	If mCurrentPageNumber = mLastPage Then
		WriteFormChanges(True);
		mFormRecordCompleted = True;
		SaveFormSettings();
		Close(True);
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber + 1 > mLastPage, mLastPage, mCurrentPageNumber + 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // GoToNext()

// Procedure - Back command handler.
//
&AtClient
Procedure Back(Command)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = ?(mCurrentPageNumber - 1 < mFirstPage, mFirstPage, mCurrentPageNumber - 1);
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Back()

// Procedure - handler of the AddProductsAndServices command.
//
&AtClient
Procedure AddProductsAndServices(Command)
	
	If Not ValueIsFilled(ProductsAndServices) Then
		MessageText = NStr("en='Fill in the ProductsAndServices description first!'");
		ShowMessageBox(Undefined,MessageText);
		Return;
	EndIf;
	
	ReturnStructure = AddProductsAndServicesAtServer(ProductsAndServices, UseBatches, UseCharacteristics);
	ProductsAndServicesToAdd = ReturnStructure.ProductsAndServices;
	
	SearchStructure = New Structure;
	SearchStructure.Insert("ProductsAndServices", ProductsAndServicesToAdd);
	RowArray = EnterOpeningBalanceProducts.Inventory.FindRows(SearchStructure);
	
	If RowArray.Count() = 0 Then
		NewRow = EnterOpeningBalanceProducts.Inventory.Add();
		NewRow.ProductsAndServices = ProductsAndServicesToAdd;
		NewRow.MeasurementUnit = PredefinedValue("Catalog.UOMClassifier.pcs");
		NewRow.Quantity = 1;
		NewRow.StructuralUnit = ReturnStructure.StructuralUnit;
	Else
		RowArray[0].Quantity = RowArray[0].Quantity + 1;
		CalculateAmountInTabularSectionLine();
	EndIf;
	
EndProcedure // AddProductsAndServices()

// Procedure - handler of the AddFromTable command.
//
&AtClient
Procedure AddFromTable(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKind", "ProductsAndServices");
	OpenForm("DataProcessor.ImportFromSpreadsheet.Form", FormParameters);
	
EndProcedure // AddFromTable()

// Procedure - handler of the AddConterpartiesFromTable command.
//
&AtClient
Procedure AddCounterpartiesFromTable(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKind","Counterparties");
	OpenForm("DataProcessor.ImportFromSpreadsheet.Form", FormParameters);

EndProcedure // AddCounterpartiesFromTable()

// Procedure - handler of the GoToPricing command.
//
&AtClient
Procedure GoToPricing(Command)
	
	AddressInventoryInStorage = PlaceInventoryToStorage();
	
	ParametersStructure = New Structure(
		"AddressInventoryInStorage, ToDate",
		AddressInventoryInStorage,
		BalanceDate
	);
	
	Notification = New NotifyDescription("GoToPricingCompletion",ThisForm);
	OpenForm("DataProcessor.Pricing.Form", ParametersStructure,,,,,Notification);
	
EndProcedure // GoToPricing()

&AtClient
Procedure GoToPricingCompletion(GenerationResult,Parameters) Export
	
	Result = GenerationResult;
	
EndProcedure

// Procedure - handler of the DocumentsListEnterOpeningBalance command.
//
&AtClient
Procedure DocumentsListEnterOpeningBalance(Command)
	
	If Modified Then
		Text = NStr("en='All the entered data will be saved. Continue?'");
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("DocumentsListEnterOpeningBalanceEnd", ThisObject), Text, Mode, 0);
        Return;
	EndIf;
	
	DocumentsListEnterOpeningBalanceFragment();
EndProcedure

&AtClient
Procedure DocumentsListEnterOpeningBalanceEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    WriteFormChanges(True);
    mFormRecordCompleted = True;
    SaveFormSettings();
    Modified = False;
    
    DocumentsListEnterOpeningBalanceFragment();

EndProcedure

&AtClient
Procedure DocumentsListEnterOpeningBalanceFragment()
    
    OpenForm("Document.EnterOpeningBalance.ListForm");

EndProcedure // DocumentsListEnterOpeningBalance()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - event handler OnEditEnd attribute EnterOpeningBalanceProductsInventory.
//
&AtClient
Procedure EnterOpeningBalanceProductsInventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	TabularSectionRow = Items.EnterOpeningBalanceProductsInventory.CurrentData;
	If TabularSectionRow <> Undefined
		AND Not ValueIsFilled(TabularSectionRow.StructuralUnit) Then
		TabularSectionRow.StructuralUnit = PredefinedValue("Catalog.StructuralUnits.MainWarehouse");
	EndIf;
	
EndProcedure // EnterOpeningBalanceProductsInventoryOnEditEnd()

// Procedure - handler of the OnChange event of the CurrencyTransactionsAccounting attribute.
//
&AtClient
Procedure CurrencyTransactionsAccountingOnChange(Item)
	
	NeedToRefreshInterface = False;
	
	WriteChangesCurrencyTransactionsAccounting(CurrencyTransactionsAccounting);
	Items.Pages.CurrentPage = Items.Step1;
	
	If NeedToRefreshInterface Then
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.Visible = False;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.Visible = True;
	EndIf;
	
EndProcedure // CurrencyTransactionsAccountingOnChange()

// Procedure - event handler OnChange of attribute EnterOpeningBalanceProductsInventoryPrice.
//
&AtClient
Procedure EnterOpeningBalanceProductsInventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // EnterOpeningBalanceProductsInventoryPriceOnChange()

// Procedure - handler of the OnChange event of the AccountingBySeveralWarehouses attribute.
//
&AtClient
Procedure AccountingBySeveralWarehousesOnChange(Item)
	
	WriteChangesAccountingBySeveralWarehouses(AccountingBySeveralWarehouses);
	
	Items.EnterOpeningBalanceProductsInventory.Visible = False;
	Items.EnterOpeningBalanceProductsInventory.Visible = True;
	
EndProcedure // AccountingBySeveralWarehousesOnChange()

// Procedure - event handler OnChange of attribute EnterOpeningBalanceProductsInventoryQuantity.
//
&AtClient
Procedure EnterOpeningBalanceProductsInventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // EnterOpeningBalanceProductsInventoryQuantityOnChange()

// Procedure - event handler OnChange of attribute EnterOpeningBalanceProductsInventoryAmount.
//
&AtClient
Procedure EnterOpeningBalanceProductsInventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceProductsInventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure // EnterOpeningBalanceProductsInventoryAmountOnChange()

// Procedure - handler of the OnChange event of the AccountingInVariousUOM attribute.
//
&AtClient
Procedure AccountingInVariousUOMOnChange(Item)
	
	WriteChangesAccountingInVariousUOM(AccountingInVariousUOM);
	
	Items.EnterOpeningBalanceProductsInventory.Visible = False;
	Items.EnterOpeningBalanceProductsInventory.Visible = True;
	
EndProcedure // AccountingInVariousUOMOnChange()

// Procedure - handler of the OnChange event of the UseCharacteristics attribute.
//
&AtClient
Procedure UseCharacteristicsOnChange(Item)
	
	WriteChangesUseCharacteristics(UseCharacteristics);
	Items.EnterOpeningBalanceProductsInventory.Visible = False;
	Items.EnterOpeningBalanceProductsInventory.Visible = True;
	
EndProcedure // UseCharacteristicsOnChange()

// Procedure - handler of the OnChange event of the UseBatches attribute.
//
&AtClient
Procedure UseBatchesOnChange(Item)
	
	WriteChangesUseBatches(UseBatches);
	Items.EnterOpeningBalanceProductsInventory.Visible = False;
	Items.EnterOpeningBalanceProductsInventory.Visible = True;
	
EndProcedure // UseBatchesOnChange()

// Procedure - handler of the OnChange event of the InputInitialBalancesBankAndPettyCashCashAssetsAmountCur attribute.
//
&AtClient
Procedure EnterOpeningBalanceBankAndPettyCashCashAssetsAmountCurOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceBankAndPettyCashCashAssets.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate
	);
	
EndProcedure // EnterOpeningBalanceBankAndPettyCashCashAssetsAmountCurOnChange()

// Procedure - handler of the OnChange event of the InputOpeningBalancesBankAndPettyCashCashAssetsBankAccountPettyCash attribute.
//
&AtClient
Procedure EnterOpeningBalanceBankAndPettyCashCashAssetsBankAccountPettyCashOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceBankAndPettyCashCashAssets.CurrentData;
	
	StructureData = GetDataCashAssetsBankAccountPettyCashOnChange(TabularSectionRow.BankAccountPettyCash);
	
	TabularSectionRow.CashCurrency = StructureData.Currency;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate
	);
	
EndProcedure // EnterOpeningBalanceBankAndPettyCashCashAssetsBankAccountPettyCashOnChange()

// Procedure - handler of the OnChange event of the InputOpeningBalancesBankAndPettyCashCashAssetsCurrencyCashAssets attribute.
//
&AtClient
Procedure EnterOpeningBalanceBankAndPettyCashCashAssetsCurrencyOfCashAssetsOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceBankAndPettyCashCashAssets.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.CashCurrency,
		BalanceDate
	);
	
EndProcedure // EnterOpeningBalanceBankAndPettyCashCashAssetsCurrencyOfCashAssetsOnChange()

// Procedure - handler of the SelectionStart event of the InputOpeningBalancesBankAndPettyCashCashAssetsCurrencyCashAssets attribute.
//
&AtClient
Procedure EnterOpeningBalanceBankAndPettyCashCashAssetsCurrencyOfCashAssetsStartChoice(Item, ChoiceData, StandardProcessing)
	
	TabularSectionRow = Items.EnterOpeningBalanceBankAndPettyCashCashAssets.CurrentData;
	
	// If type of cash assets is changed, appropriate actions are required.
	If TypeOf(TabularSectionRow.BankAccountPettyCash) = Type("CatalogRef.BankAccounts") Then
		ShowMessageBox(Undefined,NStr("en='It is prohibited to change currency of the bank account!'"));
		StandardProcessing = False;
	EndIf;
	
EndProcedure // EnterOpeningBalanceBankAndPettyCashCashAssetsCurrencyOfCashAssetsStartChoice()

// It receives data set from the server for the CounterpartyOnChange procedure.
//
&AtServer
Function GetDataCounterpartyOnChange(Counterparty, Company, TabularSectionName)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		Counterparty.ContractByDefault
	);
	
	StructureData.Insert(
		"SettlementsCurrency",
		Counterparty.ContractByDefault.SettlementsCurrency
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
	
	FillServiceAttributesByCounterpartyInCollection(EnterOpeningBalanceCounterpartiesSettlements[TabularSectionName]);
	
	For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements[TabularSectionName] Do
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
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableContract.Visible = DoOperationsByContracts;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableDocument.Visible = DoOperationsByDocuments;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayablePurchaseOrder.Visible = DoOperationsByOrders;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableInvoiceForPayment.Visible = TrackPaymentsByBills;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableContract.Visible = DoOperationsByContracts;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableDocument.Visible = DoOperationsByDocuments;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableCustomerOrder.Visible = DoOperationsByOrders;
		Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableInvoiceForPayment.Visible = TrackPaymentsByBills;
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

// Procedure - handler of the OnChange event of input field.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.CurrentData;
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Company, "AccountsPayable");
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		StructureData.SettlementsCurrency,
		BalanceDate
	);
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableCounterpartyOnChange()

// Procedure - handler of the OnChange event of input field.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableCounterpartyOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivable.CurrentData;
	StructureData = GetDataCounterpartyOnChange(TabularSectionRow.Counterparty, Company, "AccountsReceivable");
	TabularSectionRow.Contract = StructureData.Contract;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		StructureData.SettlementsCurrency,
		BalanceDate
	);
	
	TabularSectionRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
	TabularSectionRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
	TabularSectionRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
	TabularSectionRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableCounterpartyOnChange()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration47Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 1;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration47Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration53Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 3;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration53Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration50Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 2;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration50Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration56Click(Item)
	
	Cancel = False;
	ExecuteActionsOnTransitionToNextPage(Cancel);
	If Cancel Then
		Return;
	EndIf;
	
	mCurrentPageNumber = 4;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration56Click()

// Procedure - handler of clicking on the input field.
//
&AtClient
Procedure Decoration133Click(Item)
	
	mCurrentPageNumber = 0;
	SetActivePage();
	SetButtonsEnabled();
	
EndProcedure // Decoration133Click()

// Procedure - handler of the OnChange event of the ProductsAndServices attribute in tablular section.
//
&AtClient
Procedure EnterOpeningBalanceProductsInventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceProductsInventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	If TabularSectionRow.Quantity = 0 Then
		TabularSectionRow.Quantity = 1;
	EndIf;
	
EndProcedure // EnterOpeningBalanceProductsInventoryProductsAndServicesOnChange()

&AtClient
// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
Procedure EnterOpeningBalanceProductsInventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.EnterOpeningBalanceProductsInventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // EnterOpeningBalanceProductsInventoryMeasurementUnitChoiceProcessing()

// Procedure - handler of the OnChange event of the AmountCur attribute in tabular section.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableAmountValOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		BalanceDate
	);

EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableAmountCurOnChange()

// Procedure - handler of the OnChange event of the AmountCur attribute in tabular section.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableAmountCurOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		BalanceDate
	);
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableAmountCurOnChange()

// Procedure - handler of the OnChange event of the AccountsReceivableContract attribute in tabular section.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableContractOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		BalanceDate
	);
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableContractOnChange()

// Procedure - handler of the OnChange event of the AccountsPayableContract attribute in tabular section.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableContractOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	TabularSectionRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
		TabularSectionRow.AmountCur,
		TabularSectionRow.Contract,
		BalanceDate
	);
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableContractOnChange()

// Procedure - handler of the OnChange event of the AssistantSimpleUseMode attribute in tabular section.
//
&AtClient
Procedure AssistantSimpleUseModeOnChange(Item)
	
	SetAssistantUsageMode();
	
EndProcedure // AssistantSimpleUseModeOnChange()

// Procedure changes the visible of attributes depending on the usage mode.
//
&AtServer
Procedure SetAssistantUsageMode()
	
	AdditionalAttributesVisible = AssistantSimpleUseMode = Enums.YesNo.No;
	
	Items.Step1FOTitle.Visible = AdditionalAttributesVisible;
	Items.Step1FO.Visible = AdditionalAttributesVisible;
	Items.Step2FOTitle.Visible = AdditionalAttributesVisible;
	Items.Step2FO.Visible = AdditionalAttributesVisible;
	
EndProcedure // SetAssistantUsageMode()

// Procedure - event data processor.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableAfterDeleteRowRow(Item)
	
	SetAccountsAttributesVisible(, , , , "AccountsPayable");
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableAfterDeleteRowRow()

// Procedure - event data processor.
//
&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableAfterDeleteRowRow(Item)
	
	SetAccountsAttributesVisible(, , , , "AccountsReceivable");
	
EndProcedure // EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableAfterDeleteRowRow()

// Procedure - event data processor.
//
&AtClient
Procedure DateOfChange(Item)
	
	BalanceDateOnChangeAtServer();
	
EndProcedure // BalanceDateOnChange()

// Procedure - event data processor.
//
&AtServer
Procedure BalanceDateOnChangeAtServer()
	
	For Each CurRow IN EnterOpeningBalanceBankAndPettyCash.CashAssets Do
		
		CurRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
			CurRow.AmountCur,
			CurRow.CashCurrency,
			BalanceDate
		);
		
	EndDo;
	
	For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements.AccountsPayable Do
		
		CurRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
			CurRow.AmountCur,
			CurRow.Contract,
			BalanceDate
		);
		
	EndDo;
	
	For Each CurRow IN EnterOpeningBalanceCounterpartiesSettlements.AccountsReceivable Do
		
		CurRow.Amount = RecalculateFromCurrencyToAccountingCurrency(
			CurRow.AmountCur,
			CurRow.Contract,
			BalanceDate
		);
		
	EndDo;
	
EndProcedure // BalanceDateOnChangeAtServer()

&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.CurrentData;
	
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

EndProcedure

&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsPayableDocumentOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsPayable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashPayment")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.ExpenseReport") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.Netting") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableAdvanceFlagOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
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
	
EndProcedure

&AtClient
Procedure EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivableDocumentOnChange(Item)
	
	TabularSectionRow = Items.EnterOpeningBalanceCounterpartiesSettlementsAccountsReceivable.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashReceipt")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentReceipt") Then
		TabularSectionRow.AdvanceFlag = True;
	ElsIf TypeOf(TabularSectionRow.Document) <> Type("DocumentRef.Netting") Then
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
EndProcedure


#Region LibrariesHandlers

// StandardSubsystems.DataImportFromExternalSources
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory";
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesAccountsPayable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable";
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DataImportFromExternalSourcesAccountsReceivable(Command)
	
	DataLoadSettings.FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable";
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		
		If ImportResult.ActionsDetails = "ChangeDataImportFromExternalSourcesMethod" Then
		
			DataImportFromExternalSources.ChangeDataImportFromExternalSourcesMethod(DataLoadSettings.DataImportFormNameFromExternalSources);
			
			NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
			DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
			
		ElsIf ImportResult.ActionsDetails = "ProcessPreparedData" Then
			
			FillingObjectFullName = AdditionalParameters.FillingObjectFullName;
			If FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.Inventory" Then
				
				ProcessPreparedDataInventory(ImportResult);
				ShowMessageBox(,NStr("en ='The data import is completed.'"));
				
			ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsPayable" Then
				
				ProcessPreparedDataAccountsPayable(ImportResult);
				ShowMessageBox(,NStr("en ='The data import is completed.'"));
				
			ElsIf FillingObjectFullName = "Document.EnterOpeningBalance.TabularSection.AccountsReceivable" Then
				
				ProcessPreparedDataAccountsReceivable(ImportResult);
				ShowMessageBox(,NStr("en ='The data import is completed.'"));
				
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
				
				NewRow = EnterOpeningBalanceProducts.Inventory.Add();
				FillPropertyValues(NewRow, TableRow);
				
				NewRow.Amount = TableRow.Price * TableRow.Quantity;
				
			EndIf;
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.Catalogs.ProductsAndServices, , ErrorDescription());
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
				
				NewRow = EnterOpeningBalanceCounterpartiesSettlements.AccountsPayable.Add();
				FillPropertyValues(NewRow, TableRow, "Counterparty, Contract, AdvanceFlag, AmountCur, Amount", );
				
				StructureData = GetDataCounterpartyOnChange(NewRow.Counterparty, Company, "AccountsPayable");
				If Not ValueIsFilled(NewRow.Contract) Then
					
					NewRow.Contract = StructureData.Contract;
					
				EndIf;
				
				NewRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
				NewRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
				NewRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
				NewRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
				
				NewRow.Amount = RecalculateFromCurrencyToAccountingCurrency(NewRow.AmountCur, StructureData.SettlementsCurrency, BalanceDate);
				
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
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.Catalogs.ProductsAndServices, , ErrorDescription());
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
				
				NewRow = EnterOpeningBalanceCounterpartiesSettlements.AccountsReceivable.Add();
				FillPropertyValues(NewRow, TableRow, "Counterparty, Contract, AdvanceFlag, AmountCur, Amount", );
				
				StructureData = GetDataCounterpartyOnChange(NewRow.Counterparty, Company, "AccountsReceivable");
				If Not ValueIsFilled(NewRow.Contract) Then
					
					NewRow.Contract = StructureData.Contract;
					
				EndIf;
				
				NewRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
				NewRow.DoOperationsByDocuments = StructureData.DoOperationsByDocuments;
				NewRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
				NewRow.TrackPaymentsByBills = StructureData.TrackPaymentsByBills;
				
				NewRow.Amount = RecalculateFromCurrencyToAccountingCurrency(NewRow.AmountCur, StructureData.SettlementsCurrency, BalanceDate);
				
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
		
		WriteLogEvent(NStr("en='Data Import'"), EventLogLevel.Error, Metadata.Catalogs.ProductsAndServices, , ErrorDescription());
		RollbackTransaction();
		
	EndTry;
	
EndProcedure
// End StandardSubsystems.DataImportFromExternalSource

#EndRegion