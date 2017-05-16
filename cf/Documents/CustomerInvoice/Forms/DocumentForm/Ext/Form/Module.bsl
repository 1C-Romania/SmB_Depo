
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Company			= SmallBusinessServer.GetCompany(Object.Company);
	Counterparty	= Object.Counterparty;
	Contract		= Object.Contract;
	If ValueIsFilled(Contract) Then
		SettlementCurrency = CommonUse.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	Order				= Object.Order;
	NationalCurrency	= SmallBusinessReUse.GetNationalCurrency();
	StructureByCurrency	= InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", NationalCurrency));
	ExchangeRateNationalCurrency	= StructureByCurrency.ExchangeRate;
	MultiplicityNationalCurrency	= StructureByCurrency.Multiplicity;
	
	If Not ValueIsFilled(Object.Ref) Then
		If Parameters.Property("OperationKindReturn") Then
			Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor");
		EndIf;
		If Not ValueIsFilled(Parameters.Basis) AND Not ValueIsFilled(Parameters.CopyingValue) Then
			FillVATRateByCompanyVATTaxation();
		EndIf;
		If Not ValueIsFilled(Object.Order) And Parameters.Property("Basis") And TypeOf(Parameters.Basis)=Type("DocumentRef.InventoryTransfer") Then
			For Each RowInventory In Object.Inventory Do
				WorkWithProductsServer.FillDataInTabularSectionRow(Object, "Inventory", RowInventory);
			EndDo;
		EndIf;
	EndIf;
	GetOperationKindsStructure();
	
	// Generate price and currency label.
	CurrencyTransactionsAccounting	= GetFunctionalOption("CurrencyTransactionsAccounting");
	LabelStructure		= New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementCurrency, Object.ExchangeRate, ExchangeRateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency	= GenerateLabelPricesAndCurrency(LabelStructure);
	
	SetVisibleAndEnabled();
	
	// Attribute visible set from user settings
	SetVisibleFromUserSettings(); 
	
	Items.Cell.Visible	= Not Object.StructuralUnit.OrderWarehouse;
	
	User = Users.CurrentUser();
	
	SettingValue	= SmallBusinessReUse.GetValueByDefaultUser(User, "MainWarehouse");
	MainWarehouse	= ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainWarehouse);
	
	// Setting contract visible.
	SetContractVisible();
	
	// Department setting
	If Not GetFunctionalOption("AccountingBySeveralDepartments") Then
		Items.AdditionallyRightColumn.United = True;
	EndIf;
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	OperationKindSaleToCustomer = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer");
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
		
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

&AtClient
Procedure OnClose()

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification(NStr("ru = 'Изменение'; en = 'Change:'"), 
									GetURL(Object.Ref), 
									String(Object.Ref) + NStr("ru = '. Автоматические скидки (наценки) рассчитаны!'; en = '. Automatic discounts (markups) are calculated!'"), 
									PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
		AND IsInputAvailable() AND Not DiscountCardRead Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	// DiscountCards
	If DiscountCardRead Then
		DiscountCardRead = False;
	EndIf;
	// End DiscountCards
	
	If EventName = "Write_Counterparty" 
		AND ValueIsFilled(Parameter)
		AND Object.Counterparty = Parameter Then
			
		SetContractVisible();
		
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		InventoryAddressInStorage	= Parameter;
		
		GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
		
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		//Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf; 		
	EndIf;
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		
		UpdateAdditionalAttributesItems();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceEstimation
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerInvoicePositing");
	EndIf;
	// StandardSubsystems.PerformanceEstimation
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts AND Object.OperationKind = OperationKindSaleToCustomer Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text	= NStr("ru = 'Рассчитаны автоматические скидки (наценки)!'; en = 'Automatic discounts (markups) are calculated!'");
			Message.DataKey	= Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite	= True;
		Else
			Object.DiscountsAreCalculated	= True;
			RefreshImageAutoDiscountsAfterWrite	= True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(MessageText, Object.Contract, Object.Ref, Object.Company, Object.Counterparty, Object.OperationKind, Cancel);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("ru = 'Документ не проведен! ';en = 'Document is not posted! '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath	= "Object";
				Message.Field		= "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
		If SmallBusinessReUse.GetAdvanceOffsettingSettingValue() = PredefinedValue("Enum.YesNo.Yes")
			AND CurrentObject.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
			AND CurrentObject.Prepayment.Count() = 0 Then
			FillPrepayment(CurrentObject);
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	OrderIsFilled = False;
	FilledOrderReturn = False;
	For Each TSRow IN Object.Inventory Do
		If ValueIsFilled(TSRow.Order) Then
			If TypeOf(TSRow.Order) = Type("DocumentRef.CustomerOrder") Then
				OrderIsFilled = True;
			Else
				FilledOrderReturn = True;
			EndIf;
			Break;
		EndIf;		
	EndDo;	
	
	If OrderIsFilled Then
		Notify("Record_CustomerInvoice", Object.Ref);
	EndIf;
	
	If FilledOrderReturn Then
		Notify("Record_CustomerInvoiceReturn", Object.Ref);
	EndIf;
	
	Notify("NotificationAboutChangingDebt");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersHeader

&AtClient
Procedure DateOnChange(Item)
	
	// Date change event processor.
	DateBeforeChange	= DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;	
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementCurrency, Object.ExchangeRate, ExchangeRateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// DiscountCards
		// In this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");

EndProcedure

&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.BankAccount	= "";
	Object.Number	= "";
	StructureData	= GetDataCompanyOnChange();
	Company			= StructureData.Company;
	
	Object.Head				= StructureData.Head;
	Object.HeadPosition		= StructureData.HeadPosition;
	Object.ChiefAccountant	= StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition	= StructureData.ReleasedPosition;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementCurrency, Object.ExchangeRate, ExchangeRateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled(True);
	Object.Prepayment.Clear();
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		Items.Department.AutoChoiceIncomplete = True;
		Items.Department.AutoMarkIncomplete = True;
	Else
		Items.Department.AutoChoiceIncomplete = False;
		Items.Department.AutoMarkIncomplete = False;
		ClearMarkIncomplete();
	EndIf;
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementCurrency, Object.ExchangeRate, ExchangeRateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	SetCellVisible("Cell", Object.StructuralUnit);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	CounterpartyDoSettlementsByOrdersBeforeChange = CounterpartyDoSettlementsByOrders;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		Object.CounterpartyBankAcc	= Undefined;
		Object.ShippingAddress		= "";
		Object.StampBase			= "";
		
		ContractVisibleBeforeChange = Items.Contract.Visible;
		
		StructureData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		
		// Discount cards (
		StructureData.Insert("CallFromProcedureAtCounterpartyChange", True);
		// ) Discount cards.
		
		Object.Contract = StructureData.Contract;
		ContractBeforeChange = Contract;
		Contract = Object.Contract;
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("CounterpartyChange", True);
			DocumentParameters.Insert("ContractData", StructureData);
			DocumentParameters.Insert("CounterpartyBeforeChange", CounterpartyBeforeChange);
			DocumentParameters.Insert("CounterpartyDoSettlementsByOrdersBeforeChange", CounterpartyDoSettlementsByOrdersBeforeChange);
			DocumentParameters.Insert("ContractVisibleBeforeChange", ContractVisibleBeforeChange);
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en='Prepayment set-off will be cleared, do you want to continue?';ru='Зачет предоплаты будет очищен, продолжить?'");
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		ProcessContractConditionsChange(StructureData, ContractBeforeChange);
		
	Else
		
		Object.Contract	= Contract; // Restore the cleared contract automatically.
		Object.Order	= Items.Order.TypeRestriction.AdjustValue(Order);;
		
	EndIf;
	
	Order = Object.Order;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("CounterpartyOnChange");
	
EndProcedure

&AtClient
Procedure ContractOnChange(Item)
	
	ProcessContractChange();
	
EndProcedure

&AtClient
Procedure ContractStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Return;
	EndIf;
	
	FormParameters = GetChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderOnChange(Item)
	
	If Object.Prepayment.Count() > 0
	   AND Object.Order <> Order
	   AND Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		Mode = QuestionDialogMode.YesNo;
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("OrderOnChangeEnd", ThisObject), NStr("en='Prepayment set-off will be cleared, do you want to continue?';ru='Зачет предоплаты будет очищен, продолжить?'"), Mode, 0);
        Return;
	EndIf;
	
	OrderOnChangeFragment();
	
EndProcedure

&AtClient
Procedure OrderOnChangeEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.Prepayment.Clear();
    Else
		Object.Order	= Items.Order.TypeRestriction.AdjustValue(Order);;
        Return;
    EndIf;
    
    OrderOnChangeFragment();

EndProcedure

&AtClient
Procedure OrderOnChangeFragment()
    
    Order = Object.Order;

	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("OrderOnChange");
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company"				, Object.Company);
	StructureData.Insert("ProductsAndServices"	, TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic"		, TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation"			, Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate"		, Object.Date);
		StructureData.Insert("DocumentCurrency"		, Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT"	, Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind"			, Object.PriceKind);
		StructureData.Insert("Factor"				, 1);
		StructureData.Insert("DiscountMarkupKind"	, Object.DiscountMarkupKind);
	
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit		= StructureData.MeasurementUnit;
	TabularSectionRow.Quantity				= 1;
	TabularSectionRow.Price					= StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent	= StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate				= StructureData.VATRate;
	TabularSectionRow.Content				= "";
	
	TabularSectionRow.ProductsAndServicesTypeInventory = StructureData.IsInventoryItem;
	
	//Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,,UseSerialNumbersBalance);
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryProductsAndServicesOnChange()

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices",	TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",		TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",		Object.Date);
		StructureData.Insert("DocumentCurrency",	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind",		Object.PriceKind);
		StructureData.Insert("MeasurementUnit",	TabularSectionRow.MeasurementUnit);
		
	EndIf;
				
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price		= StructureData.Price;
	TabularSectionRow.Content	= "";
			
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryCharacteristicOnChange()

&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow	= Items.Inventory.CurrentData;
		ContentPattern		= SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
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
	
EndProcedure // InventoryMeasurementUnitChoiceProcessing()

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryPriceOnChange()

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryDiscountMarkupPercentOnChange()

&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
	// Discount.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Price = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Amount / ((1 - TabularSectionRow.DiscountMarkupPercent / 100) * TabularSectionRow.Quantity);
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // InventoryAmountOnChange()

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // InventoryVATRateOnChange()

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);	
	
EndProcedure // InventoryVATAmountOnChange()

#EndRegion

#Region FormItemEventHandlersFormTablePrepayment

&AtClient
Procedure PrepaymentSettlementsAmountOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
		
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
			?(Object.ExchangeRate = 0,
			1,
			Object.ExchangeRate),
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
			?(Object.Multiplicity = 0,
			1,
			Object.Multiplicity),
		TablePartRow.Multiplicity
	);
	
	TablePartRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.SettlementsAmount,
		TablePartRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
		TablePartRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
	);

EndProcedure

&AtClient
Procedure PrepaymentPaymentAmountOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = 1;
	
	TablePartRow.ExchangeRate =
		?(TablePartRow.SettlementsAmount = 0,
			1,
			TablePartRow.PaymentAmount
		  / TablePartRow.SettlementsAmount
		  * Object.ExchangeRate
	);
	
EndProcedure

&AtClient
Procedure PrepaymentDocumentOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	If ValueIsFilled(TablePartRow.Document) Then
		
		StructureData = GetDataDocumentOnChange(TablePartRow.Document);
		
		TablePartRow.SettlementsAmount = StructureData.SettlementsAmount;
		
		TablePartRow.ExchangeRate = 
			?(TablePartRow.ExchangeRate = 0,
				?(Object.ExchangeRate = 0,
				1,
				Object.ExchangeRate),
			TablePartRow.ExchangeRate
		);
		
		TablePartRow.Multiplicity =
			?(TablePartRow.Multiplicity = 0,
				?(Object.Multiplicity = 0,
				1,
				Object.Multiplicity),
			TablePartRow.Multiplicity
		);
			
		TablePartRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
			TablePartRow.SettlementsAmount,
			TablePartRow.ExchangeRate,
			?(Object.DocumentCurrency = NationalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
			TablePartRow.Multiplicity,
			?(Object.DocumentCurrency = NationalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
		);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	
	Return StructureData;
	
EndFunction // GetDataDocumentOnChange()

&AtClient
Procedure PrepaymentExchangeRateOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	TablePartRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.SettlementsAmount,
		TablePartRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
		TablePartRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

&AtClient
Procedure PrepaymentMultiplicityOnChange(Item)
	
	TablePartRow = Items.Prepayment.CurrentData;
	
	TablePartRow.ExchangeRate = ?(
		TablePartRow.ExchangeRate = 0,
		1,
		TablePartRow.ExchangeRate
	);
	
	TablePartRow.Multiplicity = ?(
		TablePartRow.Multiplicity = 0,
		1,
		TablePartRow.Multiplicity
	);
	
	TablePartRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
		TablePartRow.SettlementsAmount,
		TablePartRow.ExchangeRate,
		?(Object.DocumentCurrency = NationalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
		TablePartRow.Multiplicity,
		?(Object.DocumentCurrency = NationalCurrency, MultiplicityNationalCurrency, Object.Multiplicity)
	);
	
EndProcedure

#EndRegion

#Region TableEventHandlers
	
&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure // EditPricesAndCurrency()

&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en='Document will be completely refilled by ""Basis""! Continue?';ru='Документ будет полностью перезаполнен по ""Основанию""! Продолжить?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
        SetVisibleAndEnabled();
    EndIf;

EndProcedure // FillByBasis()

&AtClient
Procedure FillByOrder(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject), NStr("en='The document will be completely refilled by ""Order""! Continue?';ru='Документ будет полностью перезаполнен по ""Заказу""! Продолжить выполнение операции?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.Order);
        SetVisibleAndEnabled();
    EndIf;

EndProcedure // FillByOrder()

&AtClient
Procedure EditPrepaymentOffset(Command)
	
	If Not ValueIsFilled(Object.Counterparty) Then
		ShowMessageBox(, NStr("en='Specify the counterparty first.';ru='Укажите вначале контрагента!'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.Contract) Then
		ShowMessageBox(, NStr("en='Specify the counterparty contract first.';ru='Укажите вначале договор контрагента!'"));
		Return;
	EndIf;
	
	OrdersArray = New Array;
	For Each CurItem IN Object.Inventory Do
		OrderStructure = New Structure("Order, Total");
		OrderStructure.Order = ?(CurItem.Order = Undefined, PredefinedValue("Document.CustomerOrder.EmptyRef"), CurItem.Order);
		OrderStructure.Total = CurItem.Total;
		OrdersArray.Add(OrderStructure);
	EndDo;
	
	AddressPrepaymentInStorage = PlacePrepaymentToStorage();
	SelectionParameters = New Structure(
		"AddressPrepaymentInStorage,
		|Pick,
		|IsOrder,
		|OrderInHeader,
		|Company,
		|Order,
		|Date,
		|Ref,
		|Counterparty,
		|Contract,
		|ExchangeRate,
		|Multiplicity,
		|DocumentCurrency,
		|DocumentAmount",
		AddressPrepaymentInStorage, // AddressPrepaymentInStorage
		?(Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer"), True, False), // Pick
		True, // IsOrder
		OrderInHeader, // OrderInHeader
		Company, // Counterparty
		?(CounterpartyDoSettlementsByOrders, ?(OrderInHeader, Object.Order, OrdersArray), Undefined), // Order
		Object.Date, // Date
		Object.Ref, // Ref
		Object.Counterparty, // Counterparty
		Object.Contract, // Contract
		Object.ExchangeRate, // ExchangeRate
		Object.Multiplicity, // Multiplicity
		Object.DocumentCurrency, // DocumentCurrency
		Object.Inventory.Total("Total") // DocumentAmount
	);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		ReturnCode = Undefined;

		OpenForm("CommonForm.CustomerAdvancesPickForm", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd1", ThisObject, New Structure("AddressPrepaymentInStorage, SelectionParameters", AddressPrepaymentInStorage, SelectionParameters)));
        Return;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor") Then
		OpenForm("CommonForm.SupplierAdvancesPickForm", SelectionParameters,,,,, New NotifyDescription("EditPrepaymentOffsetEnd", ThisObject, New Structure("AddressPrepaymentInStorage", AddressPrepaymentInStorage)));
        Return;
	EndIf;
	
	EditPrepaymentOffsetFragment1(AddressPrepaymentInStorage, ReturnCode);
EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd1(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    SelectionParameters = AdditionalParameters.SelectionParameters;
    
    
    ReturnCode = Result;
    
    EditPrepaymentOffsetFragment1(AddressPrepaymentInStorage, ReturnCode);

EndProcedure

&AtClient
Procedure EditPrepaymentOffsetFragment1(Val AddressPrepaymentInStorage, Val ReturnCode)
    
    EditPrepaymentOffsetFragment(AddressPrepaymentInStorage, ReturnCode);

EndProcedure

&AtClient
Procedure EditPrepaymentOffsetEnd(Result, AdditionalParameters) Export
    
    AddressPrepaymentInStorage = AdditionalParameters.AddressPrepaymentInStorage;
    
    
    ReturnCode = Result;
    
    EditPrepaymentOffsetFragment(AddressPrepaymentInStorage, ReturnCode);

EndProcedure

&AtClient
Procedure EditPrepaymentOffsetFragment(Val AddressPrepaymentInStorage, Val ReturnCode)
    
    If (Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
        OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor"))
        AND (ReturnCode = DialogReturnCode.OK) Then
        GetPrepaymentFromStorage(AddressPrepaymentInStorage);
    EndIf;

EndProcedure // EditPrepaymentOffset()

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en='Enter barcode';ru='Введите штрихкод'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
    EndIf;

EndProcedure // SearchByBarcode()

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='It is required to select a line to get weight for it.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeight()

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en='Electronic scales returned zero weight.';ru='Электронные весы вернули нулевой вес.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
			CalculateAmountInTabularSectionLine(TabularSectionRow);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure // ImportDataFromDCT()

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure
// End Peripherals

&AtClient
Procedure DocumentSetting(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("CustomerOrderPositionInShipmentDocuments", 	Object.CustomerOrderPosition);
	ParametersStructure.Insert("WereMadeChanges",							False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetting", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructureDocumentSetting = Result;
    
    // 3. Apply changes made in "Document setting" form.
    If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
        
        Object.CustomerOrderPosition = StructureDocumentSetting.CustomerOrderPositionInShipmentDocuments;
        SetVisibleFromUserSettings();
        
    EndIf;

EndProcedure

&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Table part ""Products and services"" is not filled!';ru='Табличная часть ""Запасы и услуги"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
EndProcedure // ChangeReserveFillByReserves()

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='Table part ""Products and services"" is not filled!';ru='Табличная часть ""Запасы и услуги"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN Object.Inventory Do
		
		If TabularSectionRow.ProductsAndServicesTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure // ChangeReserveFillByBalances()

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		
	EndIf;
	
	SetContractVisible();
	
EndProcedure // FillByDocument()

&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", SettlementCurrency));
		
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	StructureData.Insert(
		"CurrencyRateRepetition",
		CurrencyRateRepetition
	);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

&AtServer
Function GetDataCompanyOnChange()
	
	StructureData = New Structure();
	StructureData.Insert("Company", SmallBusinessServer.GetCompany(Object.Company));
	
	ResponsiblePersons		= SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
	
	StructureData.Insert("Head", ResponsiblePersons.Head);
	StructureData.Insert("HeadPosition", ResponsiblePersons.HeadPositionRefs);
	StructureData.Insert("ChiefAccountant", ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released", ResponsiblePersons.WarehouseMan);
	StructureData.Insert("ReleasedPosition", ResponsiblePersons.WarehouseManPositionRef);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataCompanyOnChange()

&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	StructureData.Insert("IsInventoryItem", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotTaxableByVAT") Then
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateWithoutVAT());
		Else
			StructureData.Insert("VATRate", SmallBusinessReUse.GetVATRateZero());
		EndIf;	
																
	ElsIf ValueIsFilled(StructureData.ProductsAndServices.VATRate) Then
		StructureData.Insert("VATRate", StructureData.ProductsAndServices.VATRate);
	Else
		StructureData.Insert("VATRate", StructureData.Company.DefaultVATRate);
	EndIf;	
		
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
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction // ReceiveDataProductsAndServicesOnChange()

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	If StructureData.Property("PriceKind") Then
		
		If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			StructureData.Insert("Factor", 1);
		Else
			StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
		EndIf;
		
		Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	Return StructureData;
	
EndFunction // GetDataCharacteristicOnChange()

&AtServerNoContext
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

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
	);
		
	StructureData.Insert(
		"ContractDescription",
		ContractByDefault.Description
	);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", ContractByDefault.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		ContractByDefault.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		ContractByDefault.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"PriceKind",
		ContractByDefault.PriceKind
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(ContractByDefault.PriceKind), ContractByDefault.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	SetContractVisible();
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
		
	StructureData = New Structure();
	
	StructureData.Insert(
		"ContractDescription",
		Contract.Description
	);
	StructureData.Insert(
		"SettlementsCurrency",
		Contract.SettlementsCurrency
	);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency))
	);
	
	StructureData.Insert(
		"PriceKind",
		Contract.PriceKind
	);
	
	StructureData.Insert(
		"DiscountMarkupKind",
		Contract.DiscountMarkupKind
	);
	
	StructureData.Insert(
		"SettlementsInStandardUnits",
		Contract.SettlementsInStandardUnits
	);
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(Contract.PriceKind), Contract.PriceKind.PriceIncludesVAT, Undefined)
	);
	
	Return StructureData;
	
EndFunction // GetDataContractOnChange()

&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForSafeCustody") Then
		
		Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
		
	ElsIf Not ValueIsFilled(Object.VATTaxation) Then
		
		Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT");
		
	EndIf;
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByCompanyVATTaxation()

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
		
		For Each TabularSectionRow IN Object.Inventory Do
			
			If ValueIsFilled(TabularSectionRow.ProductsAndServices.VATRate) Then
				TabularSectionRow.VATRate = TabularSectionRow.ProductsAndServices.VATRate;
			Else
				TabularSectionRow.VATRate = Object.Company.DefaultVATRate;
			EndIf;	
			
			VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
			TabularSectionRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  		TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  		TabularSectionRow.Amount * VATRate / 100);
			TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
			
		EndDo;	
		
	Else
		
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotTaxableByVAT") Then
		    DefaultVATRate = SmallBusinessReUse.GetVATRateWithoutVAT();
		Else
			DefaultVATRate = SmallBusinessReUse.GetVATRateZero();
		EndIf;	
		
		For Each TabularSectionRow IN Object.Inventory Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;	
		
	EndIf;	
	
EndProcedure // FillVATRateByVATTaxation()	

&AtClient
Procedure CalculateVATAmount(TablePartRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TablePartRow.VATRate);
	
	TablePartRow.VATAmount = ?(Object.AmountIncludesVAT, 
									  TablePartRow.Amount - (TablePartRow.Amount) / ((VATRate + 100) / 100),
									  TablePartRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined, ResetFlagDiscountsAreCalculated = True)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		
		TabularSectionRow.Amount = 0;
		
	ElsIf Not TabularSectionRow.DiscountMarkupPercent = 0
		AND Not TabularSectionRow.Quantity = 0 Then
		
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	If ResetFlagDiscountsAreCalculated Then
		AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	EndIf;
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;

EndProcedure // CalculateAmountInTabularSectionLine()

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(NationalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(NationalCurrency);
		
		QuestionParameters = New Structure;
		QuestionParameters.Insert("NewExchangeRate", NewExchangeRate);
		QuestionParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd", ThisObject, QuestionParameters);
		
		QuestionText = NStr("ru = 'На дату документа у валюты расчетов (" + CurrencyRateInLetters + ") был задан курс.
									|Установить курс расчетов (" + RateNewCurrenciesInLetters + ") в соответствии с курсом валюты?'; en = 'As of the date of document the settlement currency (" + CurrencyRateInLetters + ") exchange rate was specified.
									|Set the settlements rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
		
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure // RecalculateRateAccountCurrencyRepetition()

&AtClient
Procedure QuestionOnRecalculatingPaymentCurrencyRateConversionFactorEnd(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, MultiplicityNationalCurrency, Object.Multiplicity));
		EndDo;
			
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementCurrency, Object.ExchangeRate, ExchangeRateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;

EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RefillPrices = False, RecalculatePrices = False, WarningText = "")
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate",		Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity",		Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation",		Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice",	Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty",		Object.Counterparty);
	ParametersStructure.Insert("Contract",			Object.Contract);
	ParametersStructure.Insert("Company",			Company);
	ParametersStructure.Insert("DocumentDate",		Object.Date);
	ParametersStructure.Insert("RefillPrices",		RefillPrices);
	ParametersStructure.Insert("RecalculatePrices",	RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges",	False);
	ParametersStructure.Insert("WarningText",		WarningText);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForSafeCustody") Then
		ParametersStructure.Insert("PriceKind", Object.PriceKind);
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
		ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
	EndIf;
	
	//Open form "Prices and Currency".
	//Refills tabular section "Costs" if changes were made in the "Price and Currency" form.
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm,,,, NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure // ProcessChangesByButtonPricesAndCurrencies()

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	StructurePricesAndCurrency = ClosingResult;
	SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
	
	If TypeOf(StructurePricesAndCurrency) = Type("Structure") AND StructurePricesAndCurrency.WereMadeChanges Then
		
		Object.PriceKind = StructurePricesAndCurrency.PriceKind;
		Object.DiscountMarkupKind = StructurePricesAndCurrency.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonUseClientServer.MessageToUser(
				NStr("en='Discount card is not read. Discount card owner does not match with a counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
				,
				"Counterparty",
				"Object");
			EndIf;
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		Object.DocumentCurrency = StructurePricesAndCurrency.DocumentCurrency;
		Object.ExchangeRate = StructurePricesAndCurrency.PaymentsRate;
		Object.Multiplicity = StructurePricesAndCurrency.SettlementsMultiplicity;
		Object.VATTaxation = StructurePricesAndCurrency.VATTaxation;
		Object.AmountIncludesVAT = StructurePricesAndCurrency.AmountIncludesVAT;
		Object.IncludeVATInPrice = StructurePricesAndCurrency.IncludeVATInPrice;
		
		// Recalculate prices by kind of prices.
		If StructurePricesAndCurrency.RefillPrices Then
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		EndIf;
		
		// Recalculate prices by currency.
		If Not StructurePricesAndCurrency.RefillPrices
			  AND StructurePricesAndCurrency.RecalculatePrices Then	
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If StructurePricesAndCurrency.VATTaxation <> StructurePricesAndCurrency.PrevVATTaxation Then
			FillVATRateByVATTaxation();
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not StructurePricesAndCurrency.RefillPrices
			AND Not StructurePricesAndCurrency.AmountIncludesVAT = StructurePricesAndCurrency.PrevAmountIncludesVAT Then
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
		EndIf;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, ExchangeRateNationalCurrency, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, MultiplicityNationalCurrency, Object.Multiplicity));  
		EndDo;
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;

	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
		Object.PriceKind, 
		Object.DiscountMarkupKind, 
		Object.DocumentCurrency, 
		SettlementCurrency, 
		Object.ExchangeRate, 
		ExchangeRateNationalCurrency, 
		Object.AmountIncludesVAT, 
		CurrencyTransactionsAccounting, 
		Object.VATTaxation,
		Object.DiscountCard,
		Object.DiscountPercentByDiscountCard);
		
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
EndProcedure // OpenPricesAndCurrencyFormEnd()

&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = NStr("en='%Currency%';ru='%Currency%'");
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;
	
	// Price kind
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		Else	
			LabelText = LabelText + NStr("en=' • %PriceKind%';ru=' • %PriceKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Discount type, markup
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountMarkupKind%';ru='%DiscountMarkupKind%'");
		Else
			LabelText = LabelText + NStr("en=' • %MarkupDiscountKind%';ru=' • %DiscountMarkupKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	// Discount card
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountCard%';ru='%DiscountCard%'");
		Else
			LabelText = LabelText + NStr("en=' • %DiscountCard%';ru=' • %DiscountCard%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
	EndIf;	
	
	If SmallBusinessServer.GetFunctionalOptionValue("UseVAT") Then
		
		// VAT taxation
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + NStr("en='%VATTaxation%';ru='%VATTaxation%'");
			Else
				LabelText = LabelText + NStr("en=' • %VATTaxation%';ru=' • %VATTaxation%'");
			EndIf;
			LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
		EndIf;
		
		// Flag showing that amount includes VAT
		If IsBlankString(LabelText) Then	
			If LabelStructure.AmountIncludesVAT Then
				LabelText = NStr("en='Amount includes VAT';ru='Сумма включает НДС'");
			Else
				LabelText = NStr("en='Amount does not include VAT';ru='Сумма не включает НДС'");
			EndIf;
		EndIf;
		
	EndIf;	
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		InformationRegisters.ProductsAndServicesBarcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.ProductsAndServicesBarcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsAndServicesData = New Structure();
			StructureProductsAndServicesData.Insert("Company", StructureData.Company);
			StructureProductsAndServicesData.Insert("ProductsAndServices", BarcodeData.ProductsAndServices);
			StructureProductsAndServicesData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsAndServicesData.Insert("VATTaxation", StructureData.VATTaxation);
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsAndServicesData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsAndServicesData.Insert("DocumentCurrency", StructureData.DocumentCurrency);
				StructureProductsAndServicesData.Insert("AmountIncludesVAT", StructureData.AmountIncludesVAT);
				StructureProductsAndServicesData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsAndServicesData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsAndServicesData.Insert("Factor", 1);
				EndIf;
				StructureProductsAndServicesData.Insert("DiscountMarkupKind", StructureData.DiscountMarkupKind);
			EndIf;
			
			// DiscountCards
			StructureProductsAndServicesData.Insert("DiscountPercentByDiscountCard", StructureData.DiscountPercentByDiscountCard);
			StructureProductsAndServicesData.Insert("DiscountCard", StructureData.DiscountCard);
			// End DiscountCards
			
			BarcodeData.Insert("StructureProductsAndServicesData", GetDataProductsAndServicesOnChange(StructureProductsAndServicesData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.ProductsAndServices.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure // GetDataByBarCodes()

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	// DiscountCards
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	// End DiscountCards
	
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode IN StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("ProductsAndServices,Characteristic,Batch,MeasurementUnit",BarcodeData.ProductsAndServices,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.ProductsAndServices = BarcodeData.ProductsAndServices;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsAndServicesData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsAndServicesData.Price;
				NewRow.DiscountMarkupPercent = BarcodeData.StructureProductsAndServicesData.DiscountMarkupPercent;
				NewRow.VATRate = BarcodeData.StructureProductsAndServicesData.VATRate;
				
				NewRow.ProductsAndServicesTypeInventory = BarcodeData.StructureProductsAndServicesData.IsInventoryItem;
				
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine(NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;			
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction // FillByBarcodesData()

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.ProductsAndServicesBarcodes.Form.ProductsAndServicesBarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure // BarcodesAreReceived()

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement IN ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement IN ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode IN UnknownBarcodes Do
		
		MessageString = NStr("en='Data by barcode is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure
// End Peripherals

&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure // FillColumnReserveByReservesAtServer()

&AtServer
Procedure SetContractVisible()
	
	If ValueIsFilled(Object.Counterparty) Then
		
		CalculationParametersWithCounterparty = CommonUse.ObjectAttributesValues(Object.Counterparty, "DoOperationsByOrders, DoOperationsByContracts");
		
		CounterpartyDoSettlementsByOrders = CalculationParametersWithCounterparty.DoOperationsByOrders;
		Items.Contract.Visible = CalculationParametersWithCounterparty.DoOperationsByContracts;
		
	Else
		
		CounterpartyDoSettlementsByOrders = False;
		Items.Contract.Visible = False;
		
	EndIf;
	
EndProcedure // SetContractVisible()

&AtServerNoContext
Procedure CheckContractToDocumentConditionAccordance(MessageText, Contract, Document, Company, Counterparty, OperationKind, Cancel)
	
	If Not SmallBusinessReUse.CounterpartyContractsControlNeeded()
		OR Not Counterparty.DoOperationsByContracts Then
		
		Return;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	ContractKindsList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	
	If Not ManagerOfCatalog.ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList)
		AND GetFunctionalOption("DoNotPostDocumentsWithIncorrectContracts") Then
		
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Document, OperationKind);
	
	FormParameters = New Structure;
	FormParameters.Insert("ControlContractChoice", Counterparty.DoOperationsByContracts);
	FormParameters.Insert("Counterparty", Counterparty);
	FormParameters.Insert("Company", Company);
	FormParameters.Insert("ContractKinds", ContractTypesList);
	FormParameters.Insert("CurrentRow", Contract);
	
	Return FormParameters;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationKind)
	
	If Counterparty.DoOperationsByContracts = False Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtClient
Procedure ProcessContractChange()
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		Object.StampBase = "";
		ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
		
		If Object.Prepayment.Count() > 0
			AND Object.Contract <> ContractBeforeChange Then
			
			DocumentParameters = New Structure;
			DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
			DocumentParameters.Insert("ContractData", ContractData);
			
			NotifyDescription = New NotifyDescription("PrepaymentClearingQuestionEnd", ThisObject, DocumentParameters);
			QuestionText = NStr("en='Prepayment set-off will be cleared, do you want to continue?';ru='Зачет предоплаты будет очищен, продолжить?'");
			
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			Return;
		EndIf;
		
		ProcessContractConditionsChange(ContractData, ContractBeforeChange);
		
	Else
		
		Object.Order = Items.Order.TypeRestriction.AdjustValue(Order);
		
	EndIf;
	
	Order = Object.Order;
	
EndProcedure

&AtClient
Procedure PrepaymentClearingQuestionEnd(Result, AdditionalParameters) Export
	
	ContractBeforeChange = AdditionalParameters.ContractBeforeChange;
	
	If Result = DialogReturnCode.Yes Then
		Object.Prepayment.Clear();
	Else
		If AdditionalParameters.Property("CounterpartyChange") Then
			Object.Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			Counterparty = AdditionalParameters.CounterpartyBeforeChange;
			CounterpartyDoSettlementsByOrders = AdditionalParameters.CounterpartyDoSettlementsByOrdersBeforeChange;
			Items.Contract.Visible = AdditionalParameters.ContractVisibleBeforeChange;
		EndIf;
		Object.Contract = ContractBeforeChange;
		Contract = ContractBeforeChange;
		Object.Order = Order;
		Return;
	EndIf;
	
	ProcessContractConditionsChange(AdditionalParameters.ContractData, ContractBeforeChange);

EndProcedure

&AtClient
Procedure ProcessContractConditionsChange(ContractData, ContractBeforeChange)
	
	Object.StampBase = NStr("en='Contract: ';ru='Договор: '") + String(Object.Contract);
	
	SettlementsCurrencyBeforeChange = SettlementCurrency;
	SettlementCurrency = ContractData.SettlementsCurrency;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity = ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
	EndIf;
	
	PriceKindChanged = Object.PriceKind <> ContractData.PriceKind 
		AND ValueIsFilled(ContractData.PriceKind);
		
	DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind 
		AND ValueIsFilled(ContractData.DiscountMarkupKind);
		
	// Discount card (	
	If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
		ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
	Else
		ClearDiscountCard = False;
	EndIf;			
	
	If ClearDiscountCard Then
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;		
	EndIf;
	// ) Discount card.
			
	QueryPriceKind = ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged);
	If QueryPriceKind Then
		If PriceKindChanged Then
			Object.PriceKind = ContractData.PriceKind;
		EndIf; 
		If DiscountKindChanged Then
			Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		EndIf; 
	EndIf;
	
	OpenFormPricesAndCurrencies = (ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementCurrency)
		AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency)
		AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
		AND Object.Inventory.Count() > 0;
	
	DocumentParameters = New Structure;
	DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
	DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
	DocumentParameters.Insert("ContractData", ContractData);
	
	Object.DocumentCurrency = SettlementCurrency;
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If QueryPriceKind Then
			WarningText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Perhaps you have to refill prices.';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Возможно, необходимо перезаполнить цены.'") + Chars.LF + Chars.LF;
		EndIf;
		
		WarningText = WarningText + NStr("en='Settlement currency of the contract with counterparty changed! 
		|It is necessary to check the document currency!';ru='Изменилась валюта расчетов по договору с контрагентом! 
		|Необходимо проверить валюту документа!'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, PriceKindChanged, True, WarningText);
		
	ElsIf QueryPriceKind Then
		
		RecalculationRequired = (Object.Inventory.Count() > 0);
		
		LabelStructure = 
			New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, DiscountKind, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
				Object.DocumentCurrency, 
				SettlementCurrency, 
				Object.ExchangeRate, 
				ExchangeRateNationalCurrency, 
				Object.AmountIncludesVAT, 
				CurrencyTransactionsAccounting, 
				Object.PriceKind, 
				Object.DiscountMarkupKind, 
				Object.VATTaxation,
				Object.DiscountCard,
				Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If RecalculationRequired Then
			
			QuestionText = NStr("en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
		|Recalculate the document according to the contract?';ru='Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
		|Пересчитать документ в соответствии с договором?'");
			
			NotifyDescription = New NotifyDescription("RecalculationQuestionByPriceKindEnd", ThisObject, DocumentParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		LabelStructure = 
			New Structure("DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, PriceKind, DiscountKind, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
				Object.DocumentCurrency, 
				SettlementCurrency, 
				Object.ExchangeRate, 
				ExchangeRateNationalCurrency, 
				Object.AmountIncludesVAT, 
				CurrencyTransactionsAccounting, 
				Object.PriceKind, 
				Object.DiscountMarkupKind, 
				Object.VATTaxation,
				Object.DiscountCard,
				Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
	// Clear order.
	For Each CurRow IN Object.Inventory Do
		CurRow.Order = Undefined;
	EndDo;
	
EndProcedure // ProcessContractConditionsChange()

&AtClient
Procedure RecalculationQuestionByPriceKindEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
		
	EndIf;
	
EndProcedure // DefineDocumentRecalculateNeedByContractTerms()

&AtServer
Procedure FillPrepayment(CurrentObject)
	
	CurrentObject.FillPrepayment();
	
EndProcedure // FillPrepayment()

#EndRegion

#Region WorkWithPick
	
&AtClient
Procedure Pick(Command)
	
	TabularSectionName  = "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",						Object.Date);
	SelectionParameters.Insert("Company",						Company);
	SelectionParameters.Insert("StructuralUnit",				Object.StructuralUnit);
	SelectionParameters.Insert("DiscountMarkupKind",			Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountPercentByDiscountCard",	Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("PriceKind",						Object.PriceKind);
	SelectionParameters.Insert("Currency",						Object.DocumentCurrency);
	SelectionParameters.Insert("VATTaxation",					Object.VATTaxation);
	SelectionParameters.Insert("AmountIncludesVAT",				Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization",			Object.Company);
	SelectionParameters.Insert("AvailablePriceChanging",		Not Items.InventoryPrice.ReadOnly);
	
	SelectionParameters.Insert("Cell",	Object.Cell);
	
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission") Then
		SelectionParameters.Insert("ReservationUsed", True);
	EndIf;
	
	ProductsAndServicesType = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "ProductsAndServices"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.ProductsAndServicesType" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					ProductsAndServicesType.Add(FixArrayItem);
				EndDo; 
			Else
				ProductsAndServicesType.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	SelectionParameters.Insert("ProductsAndServicesType", ProductsAndServicesType);
	
	BatchStatus = New ValueList;
	For Each ArrayElement IN Items[TabularSectionName + "Batch"].ChoiceParameters Do
		If ArrayElement.Name = "Filter.Status" Then
			If TypeOf(ArrayElement.Value) = Type("FixedArray") Then
				For Each FixArrayItem IN ArrayElement.Value Do
					BatchStatus.Add(FixArrayItem);
				EndDo;
			Else
				BatchStatus.Add(ArrayElement.Value);
			EndIf;
		EndIf;
	EndDo;
	
	SelectionParameters.Insert("BatchStatus", BatchStatus);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	#If WebClient Then
		//Form data transmission platform error crawl in Web client when form item content change
		OpenForm("CommonForm.BalanceReservesPricesPickForm", SelectionParameters, ThisForm);
		
	#Else
		
		OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
		
	#EndIf
	
EndProcedure // ExecutePick()

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If ValueIsFilled(ImportRow.ProductsAndServices) Then
			
			NewRow.ProductsAndServicesTypeInventory = (ImportRow.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
			
		EndIf;
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure // GetInventoryFromStorage()

&AtServer
Function PlacePrepaymentToStorage()
	
	Return PutToTempStorage(
		Object.Prepayment.Unload(,
			"Document,
			|Order,
			|SettlementsAmount,
			|ExchangeRate,
			|Multiplicity,
			|PaymentAmount"),
		UUID
	);
	
EndFunction // PlacePrepaymentToStorage()

&AtServer
Procedure GetPrepaymentFromStorage(AddressPrepaymentInStorage)
	
	TableForImport = GetFromTempStorage(AddressPrepaymentInStorage);
	Object.Prepayment.Load(TableForImport);
	
EndProcedure // GetPrepaymentFromStorage()

#EndRegion

#Region FormViewManagement
	
&AtServer
Procedure SetVisibleAndEnabled(ChangedTypeOperations = False)
	
	// Order types availability.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToPrincipal") Then
		ValidTypes = New TypeDescription("DocumentRef.PurchaseOrder");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromProcessing")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission") Then
		ValidTypes = New TypeDescription("DocumentRef.CustomerOrder");
	Else
		FilterArray = New Array;
		FilterArray.Add(Type("DocumentRef.PurchaseOrder"));
		FilterArray.Add(Type("DocumentRef.CustomerOrder"));
		ValidTypes = New TypeDescription(FilterArray);
	EndIf;
	
	Items.Order.TypeRestriction = ValidTypes;
	Items.Inventory.ChildItems.InventoryOrder.TypeRestriction = ValidTypes;
	
	Items.PricesAndCurrency.MaxWidth	= 34;
	
	// Generate price and currency label.
	
	// Kinds of prices.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromProcessing")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToPrincipal")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody") Then
		Object.PriceKind = Undefined;
	EndIf;
	
	// Discounts and discount cards.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		Items.Inventory.ChildItems.InventoryDiscountPercentMargin.Visible = True;
		Items.ReadDiscountCard.Visible = True; // DiscountCards
		
		// AutomaticDiscounts
		Items.Inventory.ChildItems.InventoryAutomaticDiscountPercent.Visible = True;
		Items.Inventory.ChildItems.InventoryAutomaticDiscountAmount.Visible = True;
		Items.InventoryCalculateDiscountsMarkups.Visible = True;
		// End AutomaticDiscounts
	Else
		Items.Inventory.ChildItems.InventoryDiscountPercentMargin.Visible = False;
		
		// AutomaticDiscounts
		Items.Inventory.ChildItems.InventoryAutomaticDiscountPercent.Visible = False;
		Items.Inventory.ChildItems.InventoryAutomaticDiscountAmount.Visible = False;
		Items.InventoryCalculateDiscountsMarkups.Visible = False;
		ResetFlagDiscountsAreCalculatedServer("CalculateAmountInTabularSectionLine");
		// End AutomaticDiscounts
		
		Object.DiscountMarkupKind = Undefined;
		For Each StringInventory IN Object.Inventory Do
			If StringInventory.DiscountMarkupPercent <> 0 Then
				StringInventory.DiscountMarkupPercent = 0;
			EndIf;
			
			// AutomaticDiscounts
			If StringInventory.AutomaticDiscountAmount <> 0 Or StringInventory.AutomaticDiscountsPercent <> 0 Then
				StringInventory.AutomaticDiscountsPercent = 0;
				StringInventory.AutomaticDiscountAmount = 0;
			EndIf;
			// End AutomaticDiscounts
		EndDo;
		
		// DiscountCards
		Items.ReadDiscountCard.Visible = False;
		If Not Object.DiscountCard.IsEmpty() Then
			Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
			Object.DiscountPercentByDiscountCard = 0;
		EndIf;
		// End DiscountCards
	EndIf;
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementCurrency, Object.ExchangeRate, ExchangeRateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// ProductsAndServices.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
		NewArray.Add(PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
		ArrayInventoryAndServices = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", ArrayInventoryAndServices);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryAndServices);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryProductsAndServices.ChoiceParameters = NewParameters;
	Else
		NewParameter = New ChoiceParameter("Filter.ProductsAndServicesType", PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryProductsAndServices.ChoiceParameters = NewParameters;
		
		For Each StringInventory IN Object.Inventory Do
			If StringInventory.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service") Then
				StringInventory.ProductsAndServices = Undefined;
			EndIf;
		EndDo;
		
	EndIf;
	
	// Batches.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToPrincipal") Then
		NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.ProductsOnCommission"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromProcessing") Then
		NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.CommissionMaterials"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody") Then
		NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.SafeCustody"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.ProductsOnCommission"));
		ArrayOwnInventoryAndGoodsOnCommission = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Status", ArrayOwnInventoryAndGoodsOnCommission);
		NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", ArrayOwnInventoryAndGoodsOnCommission);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	Else
		NewParameter = New ChoiceParameter("Filter.Status", PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	EndIf;
	
	// Basis document.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToPrincipal") Then
		NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForCommission"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromProcessing") Then
		NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionIntoProcessing"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody") Then
		NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForSafeCustody"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceiptFromVendor"));
		NewArray.Add(PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForCommission"));
		ArrayOfProviderAndCommission = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.OperationKind", ArrayOfProviderAndCommission);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForSafeCustody") Then
		NewParameter = New ChoiceParameter("Filter.OperationKind", PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceiptFromVendor"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
	Else
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceiptFromVendor"));
		NewArray.Add(PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForCommission"));
		NewArray.Add(PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionIntoProcessing"));
		NewArray.Add(PredefinedValue("Enum.OperationKindsSupplierInvoice.ReceptionForSafeCustody"));
		ArrayPosting = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.OperationKind", ArrayPosting);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BasisDocument.ChoiceParameters = NewParameters;
	EndIf;
	
	// Prepayment set-off.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor") Then
		Items.GroupPrepayment.Visible = True;
	Else
		Items.GroupPrepayment.Visible = False;
	EndIf;
	
	// Order when safe storage.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForSafeCustody")
	 OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody") Then
		Items.Order.Visible = False;
		Items.FillByOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryOrder.Visible = False;
	Else
		Items.Order.Visible = OrderInHeader;
		Items.FillByOrder.Visible = OrderInHeader;
		Items.Inventory.ChildItems.InventoryOrder.Visible = Not OrderInHeader;
	EndIf;
	
	// Reserves.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission")
		OR Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing") Then
		Items.InventoryChangeReserve.Visible = True;
		Items.Inventory.ChildItems.InventoryReserve.Visible = True;
	Else
		Items.InventoryChangeReserve.Visible = False;
		Items.Inventory.ChildItems.InventoryReserve.Visible = False;
		For Each StringInventory IN Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
	EndIf;
	
	// Department.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer") Then
		Items.Department.AutoChoiceIncomplete = True;
		Items.Department.AutoMarkIncomplete = True;
	EndIf;
	
	// VAT Rate, VAT Amount, Total.
	If ChangedTypeOperations Then
		FillVATRateByCompanyVATTaxation();
	Else
		
		If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
			
			Items.InventoryVATRate.Visible = True;
			Items.InventoryVATAmount.Visible = True;
			Items.InventoryAmountTotal.Visible = True;
			
		Else
			
			Items.InventoryVATRate.Visible = False;
			Items.InventoryVATAmount.Visible = False;
			Items.InventoryAmountTotal.Visible = False;
			
		EndIf;
		
	EndIf;
	
	// Warehouse.
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor") Then
		
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Warehouse"));
		NewArray.Add(PredefinedValue("Enum.StructuralUnitsTypes.Retail"));
		
		ArrayTypesOfStructuralUnit = New FixedArray(NewArray);
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfStructuralUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
	Else
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", PredefinedValue("Enum.StructuralUnitsTypes.Warehouse"));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		If Object.StructuralUnit.StructuralUnitType <> PredefinedValue("Enum.StructuralUnitsTypes.Warehouse") Then
			Object.StructuralUnit = "";
		EndIf;
		
	EndIf;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
	
	// Set Counterparty title: Customer or Supplier
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.SaleToCustomer")
		Or Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission")
		Or Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromProcessing")
		Or Not ValueIsFilled(Object.OperationKind) Then
		Items.Counterparty.Title = NStr("ru = 'Покупатель'; en = 'Customer'");
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForSafeCustody") Then
		Items.Counterparty.Title = NStr("ru = 'Получатель'; en = 'Recipient'");
	Else	
		Items.Counterparty.Title = NStr("ru = 'Поставщик'; en = 'Supplier'");
	EndIf;
	
EndProcedure // SetVisibleAndEnabled()

&AtServer
Procedure SetVisibleFromUserSettings()
	
	VisibleValue = (Object.CustomerOrderPosition = PredefinedValue("Enum.AttributePositionOnForm.InHeader"));
	
	Items.Order.Visible 		= VisibleValue;
	Items.InventoryOrder.Visible	= Not VisibleValue;
	Items.FillByOrder.Visible = VisibleValue;
	OrderInHeader 					= VisibleValue;
	
EndProcedure // SetVisibleFromUserSettings()

&AtServer
Procedure SetCellVisible(CellName, Warehouse)
	
	Items[CellName].Visible = Not Warehouse.OrderWarehouse;
		
EndProcedure // SetCellVisible()	

&AtServer
Procedure GetOperationKindsStructure()
	
	If Parameters.Property("OperationKindReturn") Then
		
		Items.OperationKind.ChoiceList.Clear();
		
	Else
		
		If GetFunctionalOption("TransferOfProductsOnCommission") Then
			Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForCommission"));
		EndIf;
		
		If GetFunctionalOption("TransferRawMaterialsForProcessing") Then
			Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferToProcessing"));
		EndIf;
		
		If GetFunctionalOption("TransferInventoryOnSafeCustody") Then
			Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.TransferForSafeCustody"));
		EndIf;
		
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToVendor"));
	
	If GetFunctionalOption("ReceiveProductsOnCommission") Then
		Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnToPrincipal"));
	EndIf;
	
	If GetFunctionalOption("Tolling") Then
		Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromProcessing"));
	EndIf;
	
	If GetFunctionalOption("ReceiveInventoryOnSafeCustody") Then
		Items.OperationKind.ChoiceList.Add(PredefinedValue("Enum.OperationKindsCustomerInvoice.ReturnFromSafeCustody"));
	EndIf;
	
EndProcedure // GetOperationKindsStructure()

#EndRegion

#Region AutomaticDiscounts

&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	
EndProcedure

&AtServer
Procedure CalculateMarkupsDiscountsForOrderServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	OrdersArray = New Array;
	
	If Not ValueIsFilled(Object.CustomerOrderPosition) Then
		CustomerOrderPosition = SmallBusinessReUse.GetValueOfSetting("CustomerOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(Object.CustomerOrderPosition) Then
			CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
	Else
		CustomerOrderPosition = Object.CustomerOrderPosition;
	EndIf;
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		OrdersArray.Add(Object.Order);
	Else
		OrdersGO = Object.Inventory.Unload(, "Order");
		OrdersGO.GroupBy("Order");
		OrdersArray = OrdersGO.UnloadColumn("Order");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
	|	CASE
	|		WHEN CustomerOrderInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsAndServicesTypeInventory,
	|	CASE
	|		WHEN VALUETYPE(CustomerOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE CustomerOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	CustomerOrderInventory.ProductsAndServices,
	|	CustomerOrderInventory.Characteristic,
	|	CustomerOrderInventory.MeasurementUnit,
	|	CustomerOrderInventory.Quantity
	|FROM
	|	Document.CustomerOrder.DiscountsMarkups AS DiscountsMarkups
	|		INNER JOIN Document.CustomerOrder.Inventory AS CustomerOrderInventory
	|		ON DiscountsMarkups.Ref = CustomerOrderInventory.Ref
	|			AND DiscountsMarkups.ConnectionKey = CustomerOrderInventory.ConnectionKey
	|WHERE
	|	DiscountsMarkups.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	OrderDiscountsMarkups = ResultsArray[0].Unload();
	
	Object.DiscountsMarkups.Clear();
	For Each CurrentDocumentRow IN Object.Inventory Do
		CurrentDocumentRow.AutomaticDiscountsPercent = 0;
		CurrentDocumentRow.AutomaticDiscountAmount = 0;
	EndDo;
	
	DiscountsMarkupsCalculationResult = Object.DiscountsMarkups.Unload();
	
	For Each CurrentOrderRow IN OrderDiscountsMarkups Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Order", CurrentOrderRow.Order);
		StructureForSearch.Insert("ProductsAndServices", CurrentOrderRow.ProductsAndServices);
		StructureForSearch.Insert("Characteristic", CurrentOrderRow.Characteristic);
		
		DocumentRowsArray = Object.Inventory.FindRows(StructureForSearch);
		If DocumentRowsArray.Count() = 0 Then
			Continue;
		EndIf;
		
		QuantityInOrder = CurrentOrderRow.Quantity * CurrentOrderRow.Factor;
		Distributed = 0;
		For Each CurrentDocumentRow IN DocumentRowsArray Do
			QuantityToWriteOff = CurrentDocumentRow.Quantity * 
									?(TypeOf(CurrentDocumentRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), 1, CurrentDocumentRow.MeasurementUnit.Factor);
			
			RecalculateAmounts = QuantityInOrder <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInOrder, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				CurrentAutomaticDiscountAmount = ROUND(CurrentOrderRow.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			Else
				CurrentAutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount;
			EndIf;
			
			DiscountString = DiscountsMarkupsCalculationResult.Add();
			FillPropertyValues(DiscountString, CurrentOrderRow);
			DiscountString.Amount = CurrentAutomaticDiscountAmount;
			DiscountString.ConnectionKey = CurrentDocumentRow.ConnectionKey;
			
			CurrentOrderRow.AutomaticDiscountAmount = CurrentOrderRow.AutomaticDiscountAmount - CurrentAutomaticDiscountAmount;
			QuantityInOrder = QuantityInOrder - QuantityToWriteOff;
			If QuantityInOrder <=0 Or CurrentOrderRow.AutomaticDiscountAmount <=0 Then
				Break;
			EndIf;
		EndDo;
		
	EndDo;
	
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(Object, "Inventory", DiscountsMarkupsCalculationResult);
	
EndProcedure

&AtClient
Procedure CalculateDiscountsMarkupsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
		
EndProcedure

// Function compares discount calculating data on current moment with data of the discount last calculation in document.
// If discounts changed the function returns the value True.
//
&AtServer
Function DiscountsChanged()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                False);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
	DiscountsChanged = False;
	
	LineCount = AppliedDiscounts.TableDiscountsMarkups.Count();
	If LineCount <> Object.DiscountsMarkups.Count() Then
		DiscountsChanged = True;
	Else
		
		If Object.Inventory.Total("AutomaticDiscountAmount") <> Object.DiscountsMarkups.Total("Amount") Then
			DiscountsChanged = True;
		EndIf;
		
		If Not DiscountsChanged Then
			For LineNumber = 1 To LineCount Do
				If    Object.DiscountsMarkups[LineNumber-1].Amount <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].Amount
					OR Object.DiscountsMarkups[LineNumber-1].ConnectionKey <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].ConnectionKey
					OR Object.DiscountsMarkups[LineNumber-1].DiscountMarkup <> AppliedDiscounts.TableDiscountsMarkups[LineNumber-1].DiscountMarkup Then
					DiscountsChanged = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	If DiscountsChanged Then
		AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	EndIf;
	
	Return DiscountsChanged;
	
EndFunction

&AtServer
Function GetAutomaticDiscountCalculationParametersStructureServer()

	OrderParametersStructure = New Structure("ImplementationByOrders, SalesExceedingOrder", False, False);
	
	If Not ValueIsFilled(Object.CustomerOrderPosition) Then
		CustomerOrderPosition = SmallBusinessReUse.GetValueOfSetting("CustomerOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(CustomerOrderPosition) Then
			CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader;
		EndIf;
	Else
		CustomerOrderPosition = Object.CustomerOrderPosition;
	EndIf;
	If CustomerOrderPosition = Enums.AttributePositionOnForm.InHeader Then
		If ValueIsFilled(Object.Order) Then
			OrderParametersStructure.ImplementationByOrders = True;
		Else
			OrderParametersStructure.ImplementationByOrders = False;
		EndIf;
		OrderParametersStructure.SalesExceedingOrder = False;
	Else
		Query = New Query;
		Query.Text = 
			"SELECT
			|	CustomerInvoiceInventory.Order AS Order
			|INTO TU_Inventory
			|FROM
			|	&Inventory AS CustomerInvoiceInventory
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TU_Inventory.Order AS Order
			|FROM
			|	TU_Inventory AS TU_Inventory
			|
			|GROUP BY
			|	TU_Inventory.Order";
		
		Query.SetParameter("Inventory", Object.Inventory.Unload());
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			If ValueIsFilled(Selection.Order) Then
				OrderParametersStructure.ImplementationByOrders = True;
			Else
				OrderParametersStructure.SalesExceedingOrder = True;
			EndIf;
		EndDo;
	EndIf;
	
	Return OrderParametersStructure;
	
EndFunction // ThereAreOrdersInTS()

&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	OrderParametersStructure = GetAutomaticDiscountCalculationParametersStructureServer(); // If there are orders in TS "Goods", then for such rows the automatic discount shall be calculated by the order.
	If OrderParametersStructure.ImplementationByOrders Then
		CalculateMarkupsDiscountsForOrderServer();
		If OrderParametersStructure.SalesExceedingOrder Then
			ParameterStructure.Insert("SalesExceedingOrder", True);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		Else
			ParameterStructure.Insert("ApplyToObject", False);
			AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
		EndIf;
	Else
		AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	EndIf;
	
	AddressDiscountsAppliedInTemporaryStorage = PutToTempStorage(AppliedDiscounts, UUID);
	
	Modified = True;
	
	DiscountsMarkupsServerOverridable.UpdateDiscountDisplay(Object, "Inventory");
	
	If Not Object.DiscountsAreCalculated Then
	
		Object.DiscountsAreCalculated = True;
	
	EndIf;
	
	Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
	
	ThereAreManualDiscounts = Constants.FunctionalOptionUseDiscountsMarkups.Get();
	For Each CurrentRow IN Object.Inventory Do
		ManualDiscountCurAmount = ?(ThereAreManualDiscounts, CurrentRow.Price * CurrentRow.Quantity * CurrentRow.DiscountMarkupPercent / 100, 0);
		CurAmountDiscounts = ManualDiscountCurAmount + CurrentRow.AutomaticDiscountAmount;
		If CurAmountDiscounts >= CurrentRow.Amount AND CurrentRow.Price > 0 Then
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = True;
		Else
			CurrentRow.TotalDiscountAmountIsMoreThanAmount = False;
		EndIf;
	EndDo;

EndProcedure

&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

&AtClient
Procedure OpenInformationAboutDiscountsClient()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ApplyToObject",                True);
	ParameterStructure.Insert("OnlyPreliminaryCalculation",      False);
	
	ParameterStructure.Insert("OnlyMessagesAfterRegistration",   False);
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		Workplace = EquipmentManagerClientReUse.GetClientWorkplace();
	Else
		Workplace = ""
	EndIf;
	
	ParameterStructure.Insert("Workplace", Workplace);
	
	If Not Object.DiscountsAreCalculated Then
		QuestionText = NStr("en='Discounts (markups) are not calculated, calculate?';ru='Скидки (наценки) не рассчитаны, рассчитать?'");
		
		AdditionalParameters = New Structure; 
		AdditionalParameters.Insert("ParameterStructure", ParameterStructure);
		NotificationHandler = New NotifyDescription("NotificationQueryCalculateDiscounts", ThisObject, AdditionalParameters);
		ShowQueryBox(NotificationHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Item.CurrentItem = Items.InventoryAutomaticDiscountPercent
		AND Not ReadOnly Then
		
		StandardProcessing = False;
		OpenInformationAboutDiscountsClient()
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	// AutomaticDiscounts
	If NewRow AND Copy Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	EndIf;
	// End AutomaticDiscounts
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;	
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;

EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,,UseSerialNumbersBalance);

EndProcedure

&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If Object.OperationKind = OperationKindSaleToCustomer Then
		If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
			RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
		EndIf;
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If Object.OperationKind = OperationKindSaleToCustomer Then
		If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
			RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
		EndIf;
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

&AtServer
Procedure AutomaticDiscountsOnCreateAtServer()
	
	InstalledGrayColor = False;
	UseAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscountsMarkups");
	If UseAutomaticDiscounts Then
		If Object.Inventory.Count() = 0 Then
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateGray;
			InstalledGrayColor = True;
		ElsIf Not Object.DiscountsAreCalculated Then
			Object.DiscountsAreCalculated = False;
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.UpdateRed;
		Else
			Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure InventoryOrderOnChange(Item)
	
	// AutomaticDiscounts
	If ClearCheckboxDiscountsAreCalculatedClient("InventoryOrderOnChange") Then
		CalculateAmountInTabularSectionLine(Undefined, False);
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion

#Region DiscountCards

&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en='Counterparty is filled and discount card is read';ru='Заполнен контрагент и считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The counterparty is filled out in the document and discount card %1 is read';ru='В документе заполнен контрагент и считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Discount card is not read. Discount card owner does not match with a counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
			,
			"Counterparty",
			"Object");
		
		Return;
	Else
		ShowUserNotification(
			NStr("en='Discount card read';ru='Считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en='Discount card %1 is read';ru='Считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	EndIf;
	
	DiscountCardIsSelectedAdditionally(DiscountCard);
		
EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementCurrency,
			Object.ExchangeRate,
			ExchangeRateNationalCurrency,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
			
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en='Refill discounts in all rows?';ru='Перезаполнить скидки во всех строках?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;

EndProcedure

&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountKindsForDiscountCards.FixedDiscount;
	
EndFunction

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChange()
	
	If Object.DiscountCard.IsEmpty() OR ThisDiscountCardWithFixedDiscount(Object.DiscountCard) Then
		Return;
	EndIf;
	
	PreDiscountPercentByDiscountCard = Object.DiscountPercentByDiscountCard;
	NewDiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, Object.DiscountCard);
	
	If PreDiscountPercentByDiscountCard <> NewDiscountPercentByDiscountCard Then
		
		If Object.Inventory.Count() > 0 Then
			Text = NStr("en = 'Change the percent of discount of the progressive discount card with "+PreDiscountPercentByDiscountCard+"% on "+NewDiscountPercentByDiscountCard+"% and refill discounts in all rows?'");
			
			AdditionalParameters = New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, True);
			Notification = New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
		Else
			Text = NStr("en = 'Change the percent of discount of the progressive discount card with "+PreDiscountPercentByDiscountCard+"% on "+NewDiscountPercentByDiscountCard+"%?'");
			
			AdditionalParameters = New Structure("NewDiscountPercentByDiscountCard, RecalculateTP", NewDiscountPercentByDiscountCard, False);
			Notification = New NotifyDescription("RecalculateDiscountPercentAtDocumentDateChangeEnd", ThisObject, AdditionalParameters);
		EndIf;
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
				Object.PriceKind,
				Object.DiscountMarkupKind,
				Object.DocumentCurrency,
				SettlementCurrency,
				Object.ExchangeRate,
				ExchangeRateNationalCurrency,
				Object.AmountIncludesVAT,
				CurrencyTransactionsAccounting,
				Object.VATTaxation,
				Object.DiscountCard,
				Object.DiscountPercentByDiscountCard);
				
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
				
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);	
	
EndProcedure

&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

#EndRegion

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

// StandardSubsystems.DataLoadFromFile
&AtClient
Procedure LoadFromFileEnd(ImportedDataAddress, AdditionalParameter) Export
	
	If ImportedDataAddress = Undefined Then 
		Return;
	EndIf;
	
	LoadFromFileAtServer(ImportedDataAddress);
	
	For Each TableRow IN Object.Inventory Do 
		CalculateAmountInTabularSectionLine(TableRow);
	EndDo;
	
EndProcedure

&AtServer
Procedure LoadFromFileAtServer(ImportedDataAddress)
	
	ImportedData = GetFromTempStorage(ImportedDataAddress);
	
	ProductsAdded = False;
	For Each TableRow IN ImportedData Do 
		
		If Not ValueIsFilled(TableRow.ProductsAndServices) Then 
			Continue;
		EndIf;
		
		NewStringProducts = Object.Inventory.Add();
		
		NewStringProducts.ProductsAndServices = TableRow.ProductsAndServices;
		NewStringProducts.Price = TableRow.Price;
		NewStringProducts.Quantity = TableRow.Quantity;
		NewStringProducts.MeasurementUnit = TableRow.MeasurementUnit;
		NewStringProducts.Characteristic = TableRow.Characteristic;
		NewStringProducts.Batch = TableRow.Batch;
		
		If ValueIsFilled(TableRow.VATRate) Then
			NewStringProducts.VATRate = TableRow.VATRate;
		Else
			NewStringProducts.VATRate = TableRow.ProductsAndServices.VATRate;
		EndIf;

		ProductsAdded = True;

	EndDo;
	
	If ProductsAdded Then
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure DataLoadFromFile(Command)
	
	ExportParameters = DataLoadFromFileClient.DataImportingParameters();
	ExportParameters.TabularSectionFullName = "CustomerInvoice.Inventory";
	ExportParameters.TemplateNameWithTemplate = "LoadFromFileInventory";
	ExportParameters.Title = NStr("en='Import inventory from file';ru='Загрузка запасов из файла'");
	
	Notification = New NotifyDescription("LoadFromFileEnd", ThisObject);
	DataLoadFromFileClient.ShowImportForm(ExportParameters, Notification);
	
EndProcedure
// End StandardSubsystems. DataLoadFromFile

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure // Attachable_EditPropertyContent()

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

// ServiceTechnology.InformationCenter
&AtClient
Procedure Attachable_ClickOnInformationLink(Item)
	
	InformationCenterClient.ClickOnInformationLink(ThisForm, Item);
	
EndProcedure

&AtClient
Procedure Attachable_ReferenceClickAllInformationLinks(Item)
	
	InformationCenterClient.ReferenceClickAllInformationLinks(ThisForm.FormName);
	
EndProcedure

#EndRegion

//Rise { Aghabekyan 2017-02-11
#Region CopyPasteRows

&AtClient
Procedure CopyRows(Command)
	CopyRowsTabularPart("Inventory");	
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure PasteRows(Command)
	
	PasteRowsTabularPart("Inventory");  
	
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	ProcessPastedRows(TabularPartName, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtClient 
Procedure ProcessPastedRows(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For Iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - Iterator];
		CalculateAmountInTabularSectionLine(Row);
		
	EndDo; 
	
EndProcedure

&AtServer 
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructData = New Structure;
		StructData.Insert("Company",        	  Object.Company);
		StructData.Insert("ProductsAndServices",  Row.ProductsAndServices);
		StructData.Insert("VATTaxation", 		  Object.VATTaxation);
		
		StructData = GetDataProductsAndServicesOnChange(StructData);
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructData.MeasurementUnit;
		EndIf;
		
		Row.VATRate							 = StructData.VATRate;
		Row.ProductsAndServicesTypeInventory = StructData.IsInventoryItem;
		
	EndDo;
	
EndProcedure

#EndRegion
//Rise } Aghabekyan 2017-02-11

#Region ServiceProceduresAndFunctions

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
		
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

#EndRegion
//Rise } Aghabekyan 2017-02-11
