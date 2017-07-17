
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ThisObject.InventoryReservation	= GetFunctionalOption("InventoryReservation");
	ThisObject.CurrencyTransactionsAccounting	= GetFunctionalOption("CurrencyTransactionsAccounting");
	
	ThisObject.Company		= SmallBusinessServer.GetCompany(Object.Company);
	ThisObject.Counterparty	= Object.Counterparty;
	ThisObject.Contract		= Object.Contract;
	If ValueIsFilled(ThisObject.Contract) Then
		ThisObject.SettlementsCurrency = CommonUse.ObjectAttributeValue(Contract, "SettlementsCurrency");
	EndIf;
	ThisObject.NationalCurrency	= SmallBusinessReUse.GetNationalCurrency();
	StructureByCurrency			= InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", ThisObject.NationalCurrency));
	ThisObject.NationalCurrencyExchangeRate	= StructureByCurrency.ExchangeRate;
	ThisObject.NationalCurrencyMultiplicity	= StructureByCurrency.Multiplicity;
	TabularSectionName = "Inventory";
	
	ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Object.Counterparty);
	
	TollProcessing	= GetFunctionalOption("Tolling");
	Items.OperationKind.ReadOnly	= Not TollProcessing;
	Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCustomerOrder.OrderForSale);
	If TollProcessing Then
		Items.OperationKind.ChoiceList.Add(Enums.OperationKindsCustomerOrder.OrderForProcessing);
	EndIf;

	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		
		FillVATRateByCompanyVATTaxation(True);
		
	ElsIf Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		Items.InventoryVATRate.Visible						= True;
		Items.InventoryVATAmount.Visible					= True;
		Items.InventoryAmountTotal.Visible					= True;
		Items.PaymentCalendarPayVATAmount.Visible			= True;
		Items.ListPaymentCalendarPayVATAmount.Visible	= True;
		
	Else
		
		Items.InventoryVATRate.Visible						= False;
		Items.InventoryVATAmount.Visible					= False;
		Items.InventoryAmountTotal.Visible					= False;
		Items.PaymentCalendarPayVATAmount.Visible			= False;
		Items.ListPaymentCalendarPayVATAmount.Visible	= False;
		
	EndIf;
	
	Items.EditInList.Check	= Object.PaymentCalendar.Count() > 1;
	Items.PagePaymentCalendar.Visible	= GetFunctionalOption("PaymentCalendar");
	Items.StructuralUnitReserve.Visible	= ThisObject.InventoryReservation;
	
	If Items.OperationKind.ChoiceList.Count() = 1 Then
		Items.OperationKind.Visible = False;
	EndIf;
	
	// Generate price and currency label.
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, NationalCurrencyExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	// If the document is opened from pick, fill the tabular section products
	If Parameters.FillingValues.Property("InventoryAddressInStorage") 
		AND ValueIsFilled(Parameters.FillingValues.InventoryAddressInStorage) Then
		
		GetInventoryFromStorage(Parameters.FillingValues.InventoryAddressInStorage, 
							Parameters.FillingValues.TabularSectionName,
							Parameters.FillingValues.AreCharacteristics,
							Parameters.FillingValues.AreBatches);
		
	EndIf;
	
	// PickProductsAndServicesInDocuments
	PickProductsAndServicesInDocuments.AssignPickForm(SelectionOpenParameters, Object.Ref.Metadata().Name, "Inventory");
	// End PickProductsAndServicesInDocuments
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.InventoryPrice.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryDiscountPercentMargin.ReadOnly	= Not AllowedEditDocumentPrices;
	Items.InventoryAmount.ReadOnly					= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly				= Not AllowedEditDocumentPrices;
	
	// Status.
	If Not GetFunctionalOption("UseCustomerOrderStates") Then
		
		Items.StateGroup.Visible = False;
		
		InProcessStatus = SmallBusinessReUse.GetStatusInProcessOfCustomerOrders();
		CompletedStatus = SmallBusinessReUse.GetStatusCompletedCustomerOrders();
		Items.Status.ChoiceList.Add("In process", "In process");
		Items.Status.ChoiceList.Add("Completed", "Completed");
		Items.Status.ChoiceList.Add("Canceled", "Canceled");
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			Status = "In process";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	UpdateTotalsServer();
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsCustomerOrder);
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
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

&AtClient
Procedure OnClose()
	
	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+". Automatic discounts (markups) are calculated!", 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure // OnClose()

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
		
		ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Parameter);
		FormManagement();
		
	ElsIf EventName = "SelectionIsMade" 
		AND ValueIsFilled(Parameter) 
		//Check for the form owner
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
			
		InventoryAddressInStorage	= Parameter;
		AreCharacteristics 		= True;
		
		AreBatches			= False;
		
		If SelectionMarker = "Inventory" Then
			
			TabularSectionName	= "Inventory";
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
			
			If Not IsBlankString(EventLogMonitorErrorText) Then
				WriteErrorReadingDataFromStorage();
			EndIf;
			
			UpdateTotalsClient();
			RecalculatePaymentCalendar();
			
		ElsIf SelectionMarker = "Materials" Then
			
			TabularSectionName	= "ConsumerMaterials";
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches);
			
		EndIf;
		
		SelectionMarker = "";
		
	EndIf;
		
	// StandardSubsystems.Properties
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// EndStandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
	UpdateTotalsServer();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// AutomaticDiscounts
	DiscountsCalculatedBeforeWrite = False;
	// If the document is being posted, we check whether the discounts are calculated.
	If UseAutomaticDiscounts Then
		If Not Object.DiscountsAreCalculated AND DiscountsChanged() Then
			CalculateDiscountsMarkupsClient();
			CalculatedDiscounts = True;
			
			Message = New UserMessage;
			Message.Text = "Automatic discounts (markups) are calculated!";
			Message.DataKey = Object.Ref;
			Message.Message();
			
			DiscountsCalculatedBeforeWrite = True;
			
			UpdateTotalsClient();
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
	// StandardSubsystems.PerformanceEstimation
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerOrderPosting");
	// StandardSubsystems.PerformanceEstimation
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting Then
		
		MessageText = "";
		CheckContractToDocumentConditionAccordance(
			MessageText, 
			CurrentObject.Contract, 
			CurrentObject.Ref, 
			CurrentObject.Company, 
			CurrentObject.Counterparty, 
			CurrentObject.OperationKind, 
			Cancel
		);
		
		If MessageText <> "" Then
			
			Message = New UserMessage;
			Message.Text = ?(Cancel, NStr("en='Document is not posted! ';ru='Документ не проведен! '") + MessageText, MessageText);
			
			If Cancel Then
				Message.DataPath = "Object";
				Message.Field = "Contract";
				Message.Message();
				Return;
			Else
				Message.Message();
			EndIf;
		EndIf;
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCustomerOrderAfterWriteOnServer");
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure // AfterWriteOnServer()

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_CustomerOrder", Object.Ref);
	
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
Procedure StatusOnChange(Item)
	
	If Status = "In process" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
		Object.Closed = True;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanelSB.Form.SectionSales");
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	// Processing change event dates.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange, SettlementsCurrency);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
		
		If ValueIsFilled(SettlementsCurrency) Then
			RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData);
		EndIf;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, NationalCurrencyExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		UpdateTotalsClient();
		RecalculatePaymentCalendar();
		
		// DiscountCards
		// IN this procedure call not modal window of question is occurred.
		RecalculateDiscountPercentAtDocumentDateChange();
		// End DiscountCards
		
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)

	// Company change event processor.
	Object.Number = "";
	StructureData = GetDataCompanyOnChange();
	Company = StructureData.Company;
	If Object.DocumentCurrency = StructureData.BankAccountCashAssetsCurrency Then
		Object.BankAccount = StructureData.BankAccount;
	EndIf;
	
	// Petty cash by default
	If StructureData.Property("PettyCash") Then
		Object.PettyCash = StructureData.PettyCash;
	EndIf;
	// End Petty cash by default
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	ProcessContractChange();
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, NationalCurrencyExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	ProcessContractChange();
	
	// DiscountCards
	TypeOfOperationsBeforeChange = OperationKind;
	OperationKind = Object.OperationKind;
	
	If TypeOfOperationsBeforeChange <> Object.OperationKind Then
		If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForSale") Then
			Items.ReadDiscountCard.Visible = True;
		Else
			If Not Object.DiscountCard.IsEmpty() Then
				Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
				Object.DiscountPercentByDiscountCard = 0;
				LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DiscountMarkupKind, Object.DocumentCurrency, SettlementsCurrency, Object.ExchangeRate, NationalCurrencyExchangeRate, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
				PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);				
			EndIf;
			Items.ReadDiscountCard.Visible = False;
		EndIf;
	EndIf;
	// End DiscountCards
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	CounterpartyBeforeChange = Counterparty;
	Counterparty = Object.Counterparty;
	
	If CounterpartyBeforeChange <> Object.Counterparty Then
		
		ContractData = GetDataCounterpartyOnChange(Object.Date, Object.DocumentCurrency, Object.Counterparty, Object.Company);
		ContractData.Insert("CallFromProcedureAtCounterpartyChange", True);
		Object.Contract = ContractData.Contract;
		ProcessContractChange(ContractData);
		FormManagement();
		
	Else
		
		Object.Contract = Contract; // Restore the cleared contract automatically.
		
	EndIf;
	
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
	
	FormParameters = GetContractChoiceFormParameters(Object.Ref, Object.Company, Object.Counterparty, Object.Contract, Object.OperationKind);
	If FormParameters.ControlContractChoice Then
		
		StandardProcessing = False;
		OpenForm("Catalog.CounterpartyContracts.Form.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditPricesAndCurrency(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPricesAndCurrencies(Object.DocumentCurrency);
	Modified = True;
	
EndProcedure

&AtClient
Procedure CashAssetsTypeOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure SchedulePaymentOnChange(Item)
	
	If Object.SchedulePayment AND Object.PaymentCalendar.Count() = 0 Then
		
		UpdateTotalsClient();
		
		NewRow = Object.PaymentCalendar.Add();
		NewRow.PayDate				= Object.Date + GetCustomerPaymentDueDate(Object.Contract) * 86400;
		NewRow.PaymentPercentage	= 100;
		NewRow.PaymentAmount		= TotalAmount;
		NewRow.PayVATAmount			= TotalVATAmount;

	ElsIf Not Object.SchedulePayment AND Object.PaymentCalendar.Count() > 0 Then
		
		Object.PaymentCalendar.Clear();
		
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure BankAccountOnChange(Item)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure BankAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Object.Contract) Then
		Return;
	EndIf;
	
	FormParameters = GetBankAccountChoiceFormParameters(Object.Contract, Object.Company, NationalCurrency);
	If FormParameters.SettlementsInStandardUnits Then
		
		StandardProcessing = False;
		OpenForm("Catalog.BankAccounts.ChoiceForm", FormParameters, Item);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PettyCashOnChange(Item)
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableInventory

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
	
	If NewRow And Copy And 
		(Item.CurrentData.AutomaticDiscountsPercent <> 0 Or Item.CurrentData.AutomaticDiscountAmount <> 0) Then
		Item.CurrentData.AutomaticDiscountsPercent = 0;
		Item.CurrentData.AutomaticDiscountAmount = 0;
		CalculateAmountInTabularSectionLine();
	ElsIf UseAutomaticDiscounts And NewRow And Copy Then
		// Automatic discounts have become irrelevant.
		ClearCheckboxDiscountsAreCalculatedClient("OnStartEdit");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();

EndProcedure

&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure

&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity				= 1;
	TabularSectionRow.Price					= StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent	= StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate				= StructureData.VATRate;
	TabularSectionRow.Content				= "";
	TabularSectionRow.Specification			= StructureData.Specification;
	
	TabularSectionRow.ProductsAndServicesTypeInventory	= StructureData.IsInventoryItem;
	
	CalculateAmountInTabularSectionLine();
	
	UpdateTotalsClient();
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices", 	TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", 	TabularSectionRow.Characteristic);
	
	If ValueIsFilled(Object.PriceKind) Then
	
		StructureData.Insert("ProcessingDate", 		Object.Date);
		StructureData.Insert("DocumentCurrency", 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 	TabularSectionRow.VATRate);
		StructureData.Insert("Price", 		TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = "";
	TabularSectionRow.Specification = StructureData.Specification;
	
	CalculateAmountInTabularSectionLine();
	
	UpdateTotalsClient();
	
EndProcedure

&AtClient
Procedure InventoryContentAutoComplete(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		
		StandardProcessing = False;
		
		TabularSectionRow = Items.Inventory.CurrentData;
		ContentPattern = SmallBusinessServer.GetContentText(TabularSectionRow.ProductsAndServices, TabularSectionRow.Characteristic);
		
		ChoiceData = New ValueList;
		ChoiceData.Add(ContentPattern);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
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
	
	UpdateTotalsClient();
	
EndProcedure

&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

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
		
	// VAT amount.
	CalculateVATAmount(TabularSectionRow);
	
	// Total.
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", "Amount");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormConsumerMaterials

&AtClient
Procedure ConsumerMaterialsProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.ConsumerMaterials.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Company", Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);

	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormPaymentCalendar

&AtClient
Procedure PaymentCalendarBeforeDelete(Item, Cancel)
	
	If Object.PaymentCalendar.Count() = 1 Then
		Object.SchedulePayment = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentCalendarOnStartEdit(Item, NewRow, Copy)
	
	If Not NewRow Then
		Return;
	EndIf;
	
	Object.SchedulePayment = True;
	CurrentRow = Item.CurrentData;
	PaymentPercentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PaymentPercentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PaymentPercentTotal - 100);
	EndIf;
	
	UpdateTotalsClient();
	
	CurrentRow.PaymentAmount	= Round(TotalAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PayVATAmount		= Round(TotalVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentPercentageOnChange(Item)
	
	If Items.EditInList.Check Then
		CurrentRow = Items.ListPaymentCalendar.CurrentData;
	Else
		CurrentRow = Object.PaymentCalendar[0];
	EndIf;
	PaymentPercentTotal = Object.PaymentCalendar.Total("PaymentPercentage");
	
	If PaymentPercentTotal > 100 Then
		CurrentRow.PaymentPercentage = CurrentRow.PaymentPercentage - (PaymentPercentTotal - 100);
	EndIf;
	
	UpdateTotalsClient();
	
	CurrentRow.PaymentAmount	= Round(TotalAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	CurrentRow.PayVATAmount		= Round(TotalVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPaymentAmountOnChange(Item)
	
	If Items.EditInList.Check Then
		CurrentRow = Items.ListPaymentCalendar.CurrentData;
	Else
		CurrentRow = Object.PaymentCalendar[0];
	EndIf;
	
	UpdateTotalsClient();
	
	PaymentCalendarTotal = Object.PaymentCalendar.Total("PaymentAmount");
	
	If PaymentCalendarTotal > TotalAmount Then
		CurrentRow.PaymentAmount = CurrentRow.PaymentAmount - (PaymentCalendarTotal - TotalAmount);
	EndIf;
	
	CurrentRow.PaymentPercentage	= ?(TotalAmount = 0, 0, Round(CurrentRow.PaymentAmount / TotalAmount * 100, 2, 1));
	CurrentRow.PayVATAmount			= Round(TotalVATAmount * CurrentRow.PaymentPercentage / 100, 2, 1);
	
EndProcedure

&AtClient
Procedure ListPaymentCalendarPayVATAmountOnChange(Item)
	
	If Items.EditInList.Check Then
		CurrentRow = Items.ListPaymentCalendar.CurrentData;
	Else
		CurrentRow = Object.PaymentCalendar[0];
	EndIf;
	
	InventoryTotal			= Object.Inventory.Total("VATAmount");
	PaymentCalendarTotal	= Object.PaymentCalendar.Total("PayVATAmount");
	
	If PaymentCalendarTotal > InventoryTotal Then
		CurrentRow.PayVATAmount = CurrentRow.PayVATAmount - (PaymentCalendarTotal - InventoryTotal);
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandEvents
	
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
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure // SearchByBarcode()

// Gets the weight for tabular section row.
//
&AtClient
Procedure GetWeightForTabularSectionRow(TabularSectionRow)
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en='Select a line for which the weight should be received.';ru='Необходимо выбрать строку, для которой необходимо получить вес.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NOTifyDescription, UUID);
		
	EndIf;
	
EndProcedure // GetWeightForTabularSectionRow()

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

&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	GetWeightForTabularSectionRow(TabularSectionRow);
	
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
Procedure EditInList(Command)
	
	If Items.EditInList.Check And Object.PaymentCalendar.Count() > 1 Then
		
		NotifyDescription = New NotifyDescription("SetOptionEditInListCompleted", ThisObject);
		
		ShowQueryBox(
			NotifyDescription,
			NStr("en='All lines except for the first one will be deleted. Continue?';ru='Все строки кроме первой будут удалены. Продолжить?'"),
			QuestionDialogMode.YesNo
		);
		Return;
	EndIf;
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	FormManagement();
	
EndProcedure

&AtClient
Procedure DocumentSetting(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ShipmentDatePositionInCustomerOrder", Object.ShipmentDatePosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	OpenForm("CommonForm.DocumentSetting", ParametersStructure,,,,, New NotifyDescription("DocumentSettingCompleted", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingCompleted(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.ShipmentDatePosition = StructureDocumentSetting.ShipmentDatePositionInCustomerOrder;
		
		BeforeShipmentDateVisible = Items.ShipmentDate.Visible;
		
		FormManagement();
		
		If BeforeShipmentDateVisible = False // It was in TS.
			AND Items.ShipmentDate.Visible = True Then // It is in the header.
			
			For Each Row In Object.Inventory Do
				If Not ValueIsFilled(Row.ShipmentDate) Then
					Continue;
				EndIf;
				Object.ShipmentDate = Row.ShipmentDate;
				Break;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Goods, services"" tabular section is not filled in.';ru='Табличная часть ""Товары, услуги"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByBalancesAtServer();
	
EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en='The ""Goods, services"" tabular section is not filled in.';ru='Табличная часть ""Товары, услуги"" не заполнена!'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow IN Object.Inventory Do
		
		If TabularSectionRow.ProductsAndServicesTypeInventory Then
			TabularSectionRow.Reserve = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
	
&AtServerNoContext
Function GetBankAccountChoiceFormParameters(Contract, Company, NationalCurrency)
	
	ContractAttributes = CommonUse.ObjectAttributesValues(Contract, "SettlementsCurrency, SettlementsInStandardUnits");
	
	CurrenciesList = New ValueList;
	CurrenciesList.Add(ContractAttributes.SettlementsCurrency);
	CurrenciesList.Add(NationalCurrency);
	
	FormParameters = New Structure;
	FormParameters.Insert("SettlementsInStandardUnits", ContractAttributes.SettlementsInStandardUnits);
	FormParameters.Insert("Owner", Company);
	FormParameters.Insert("CurrenciesList", CurrenciesList);
	
	Return FormParameters;
	
EndFunction

&AtClient
Procedure ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters)
	
	ContractBeforeChange = DocumentParameters.ContractBeforeChange;
	SettlementsCurrencyBeforeChange = DocumentParameters.SettlementsCurrencyBeforeChange;
	ContractData = DocumentParameters.ContractData;
	QueryPriceKind = DocumentParameters.QueryPriceKind;
	OpenFormPricesAndCurrencies = DocumentParameters.OpenFormPricesAndCurrencies;
	PriceKindChanged = DocumentParameters.PriceKindChanged;
	DiscountKindChanged = DocumentParameters.DiscountKindChanged;
	If DocumentParameters.Property("ClearDiscountCard") Then
		ClearDiscountCard = DocumentParameters.ClearDiscountCard;
	Else
		ClearDiscountCard = False;
	EndIf;
	RecalculationRequiredInventory	= DocumentParameters.RecalculationRequiredInventory;
	RecalculationRequiredWork		= DocumentParameters.RecalculationRequiredWork;
	
	If Not ContractData.AmountIncludesVAT = Undefined Then
		
		Object.AmountIncludesVAT = ContractData.AmountIncludesVAT;
		
	EndIf;
	
	If ValueIsFilled(Object.Contract) Then 
		
		Object.ExchangeRate	= ?(ContractData.SettlementsCurrencyRateRepetition.ExchangeRate = 0, 1, ContractData.SettlementsCurrencyRateRepetition.ExchangeRate);
		Object.Multiplicity	= ?(ContractData.SettlementsCurrencyRateRepetition.Multiplicity = 0, 1, ContractData.SettlementsCurrencyRateRepetition.Multiplicity);
		
	EndIf;
	
	If PriceKindChanged Then
		
		Object.PriceKind = ContractData.PriceKind;
		
	EndIf; 
	
	If DiscountKindChanged Then
		
		Object.DiscountMarkupKind = ContractData.DiscountMarkupKind;
		
	EndIf;
	
	If ClearDiscountCard Then
		
		Object.DiscountCard = PredefinedValue("Catalog.DiscountCards.EmptyRef");
		Object.DiscountPercentByDiscountCard = 0;
		
	EndIf;
	
	If Object.DocumentCurrency <> ContractData.SettlementsCurrency Then
		
		Object.BankAccount = Undefined;
		
	EndIf;
	Object.DocumentCurrency = ContractData.SettlementsCurrency;
	
	If OpenFormPricesAndCurrencies Then
		
		WarningText = "";
		If PriceKindChanged OR DiscountKindChanged Then
			
			WarningText = NStr("ru = 'Договор с контрагентом предусматривает условия цен и скидок, 
									|отличные от установленных в документе! 
									|Возможно, необходимо перезаполнить цены.'; en='The price and discount conditions in the contract with counterparty
									|differ from price and discount in the document! 
									|Perhaps you have to refill prices.'") + Chars.LF + Chars.LF;
			
		EndIf;
		
		WarningText = WarningText + NStr("ru = 'Изменилась валюта расчетов по договору с контрагентом! 
										|Необходимо проверить валюту документа!'; en='Settlement currency of the contract with counterparty changed! 
										|It is necessary to check the document currency!'");
		
		ProcessChangesOnButtonPricesAndCurrencies(SettlementsCurrencyBeforeChange, True, (PriceKindChanged OR DiscountKindChanged), WarningText);
		
	ElsIf QueryPriceKind Then
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			NationalCurrencyExchangeRate,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If (RecalculationRequiredInventory AND Object.Inventory.Count() > 0)
			OR (RecalculationRequiredWork AND Object.Works.Count() > 0) Then
			
			QuestionText = NStr("ru = 'Договор с контрагентом предусматривает условия цен и скидок, отличные от установленных в документе! 
										|Пересчитать документ в соответствии с договором?'; en='The price and discount conditions in the contract with counterparty differ from price and discount in the document! 
										|Recalculate the document according to the contract?'");
			
			NotifyDescription = New NotifyDescription("DefineDocumentRecalculateNeedByContractTerms", ThisObject, DocumentParameters);
			ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
			
		EndIf;
		
	Else
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			NationalCurrencyExchangeRate,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure

&AtServer
Function GetDataDateOnChange(DateBeforeChange, SettlementsCurrency)
	
	DATEDIFF = SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange);
	CurrencyRateRepetition = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", SettlementsCurrency));
	
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
	StructureData.Insert("BankAccount", Object.Company.BankAccountByDefault);
	StructureData.Insert("BankAccountCashAssetsCurrency", Object.Company.BankAccountByDefault.CashCurrency);
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	StructureData.Insert("IsService", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
	StructureData.Insert("IsInventoryItem", StructureData.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then		
		StructureData.TimeNorm = SmallBusinessServer.GetWorkTimeRate(StructureData);
	EndIf;
	
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
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsAndServicesCharacteristics.EmptyRef());
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			If StructureData.ProductsAndServices.FixedCost Then
				
				Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
				StructureData.Insert("Price", Price);
			
			Else
			
				StructureData.ProductsAndServices = StructureData.WorkKind;
				StructureData.Characteristic = Catalogs.ProductsAndServicesCharacteristics.EmptyRef();
				Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
				StructureData.Insert("Price", Price);
				
			EndIf;
		
		Else
		
			Price = SmallBusinessServer.GetProductsAndServicesPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
		
		EndIf;
		
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
	
	StructureData.Insert("Specification", SmallBusinessServer.GetDefaultSpecification(StructureData.ProductsAndServices, StructureData.Characteristic));
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = SmallBusinessServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

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
	
EndFunction

&AtServer
Function GetDataCounterpartyOnChange(Date, DocumentCurrency, Counterparty, Company)
	
	ContractByDefault = GetContractByDefault(Object.Ref, Counterparty, Company, Object.OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault
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
	
	ReadCounterpartyAttributes(ThisObject.CounterpartyAttributes, Counterparty);
	
	Return StructureData;
	
EndFunction // GetDataCounterpartyOnChange()

&AtServerNoContext
Function GetDataContractOnChange(Date, DocumentCurrency, Contract)
	
	StructureData = New Structure();
	
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
	
EndFunction

&AtServerNoContext
Function GetCustomerPaymentDueDate(Contract)
	
	Return Contract.CustomerPaymentDueDate;

EndFunction

&AtServer
Procedure FillVATRateByCompanyVATTaxation(IsOpening = False)
	
	TaxationBeforeChange	= Object.VATTaxation;
	Object.VATTaxation		= SmallBusinessServer.VATTaxation(Object.Company,, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Or IsOpening Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.TaxableByVAT") Then
		
		Items.InventoryVATRate.Visible					= True;
		Items.InventoryVATAmount.Visible				= True;
		Items.InventoryAmountTotal.Visible				= True;
		Items.PaymentCalendarPayVATAmount.Visible		= True;
		Items.ListPaymentCalendarPayVATAmount.Visible	= True;
		
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
		
		For Each TabularSectionRow IN Object.Works Do
			
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
		Items.PaymentCalendarPayVATAmount.Visible = False;
		Items.ListPaymentCalendarPayVATAmount.Visible = False;
		
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
		
		For Each TabularSectionRow IN Object.Works Do
		
			TabularSectionRow.VATRate = DefaultVATRate;
			TabularSectionRow.VATAmount = 0;
			
			TabularSectionRow.Total = TabularSectionRow.Amount;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CalculateVATAmount(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	If Object.AmountIncludesVAT Then
		TabularSectionRow.VATAmount = TabularSectionRow.Amount - TabularSectionRow.Amount / ((VATRate + 100) / 100);
	Else
		TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
	EndIf;
											
EndProcedure 

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionName = "Inventory", TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items[TabularSectionName].CurrentData;
	EndIf;
		
	// Amount.
	If TabularSectionName = "Works" Then
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Multiplicity * TabularSectionRow.Factor * TabularSectionRow.Price;
	Else
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf; 
		
	// Discounts.
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATAmount(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // CalculateAmountInTabularSectionLine()	

&AtClient
Procedure RecalculatePaymentCalendar()
	
	For Each CurRow IN Object.PaymentCalendar Do
		CurRow.PaymentAmount	= Round(TotalAmount * CurRow.PaymentPercentage / 100, 2, 1);
		CurRow.PayVATAmount		= Round(TotalVATAmount * CurRow.PaymentPercentage / 100, 2, 1);
	EndDo;
	
EndProcedure

&AtClient
Procedure RecalculateExchangeRateMultiplicitySettlementCurrency(StructureData)
	
	NewExchangeRate = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
	NewRatio = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	
	If Object.ExchangeRate <> NewExchangeRate
		OR Object.Multiplicity <> NewRatio Then
		
		CurrencyRateInLetters = String(Object.Multiplicity) + " " + TrimAll(SettlementsCurrency) + " = " + String(Object.ExchangeRate) + " " + TrimAll(NationalCurrency);
		RateNewCurrenciesInLetters = String(NewRatio) + " " + TrimAll(SettlementsCurrency) + " = " + String(NewExchangeRate) + " " + TrimAll(NationalCurrency);
		
		QuestionText = NStr("en = 'As of the date of document the settlement currency (" + CurrencyRateInLetters + ") exchange rate was specified.
							|Set the settlements rate (" + RateNewCurrenciesInLetters + ") according to exchange rate?'");
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("NewExchangeRate", NewExchangeRate);
		AdditionalParameters.Insert("NewRatio", NewRatio);
		
		NotifyDescription = New NotifyDescription("DefineNewCurrencyRateSettingNeed", ThisObject, AdditionalParameters);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessChangesOnButtonPricesAndCurrencies(Val SettlementsCurrencyBeforeChange, RecalculatePrices = False, RefillPrices = False, WarningText = "")
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency", Object.DocumentCurrency);
	ParametersStructure.Insert("ExchangeRate", Object.ExchangeRate);
	ParametersStructure.Insert("Multiplicity", Object.Multiplicity);
	ParametersStructure.Insert("VATTaxation", Object.VATTaxation);
	ParametersStructure.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	ParametersStructure.Insert("IncludeVATInPrice", Object.IncludeVATInPrice);
	ParametersStructure.Insert("Counterparty", Object.Counterparty);
	ParametersStructure.Insert("Contract", Object.Contract);
	ParametersStructure.Insert("Company",	Company); 
	ParametersStructure.Insert("DocumentDate", Object.Date);
	ParametersStructure.Insert("RefillPrices", RefillPrices);
	ParametersStructure.Insert("RecalculatePrices", RecalculatePrices);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	ParametersStructure.Insert("DiscountKind", Object.DiscountMarkupKind);
	If Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForSale") Then
		ParametersStructure.Insert("DiscountCard", Object.DiscountCard);
		ParametersStructure.Insert("WarningText", WarningText);
	EndIf;
	
	NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange));
	OpenForm("CommonForm.PricesAndCurrencyForm", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure	

&AtClient
Procedure RefillTabularSectionPricesByPriceKind() 
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;

	DataStructure.Insert("Date",				Object.Date);
	DataStructure.Insert("Company",				Company);
	DataStructure.Insert("PriceKind",			Object.PriceKind);
	DataStructure.Insert("DocumentCurrency",	Object.DocumentCurrency);
	DataStructure.Insert("AmountIncludesVAT",	Object.AmountIncludesVAT);
	
	DataStructure.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	DataStructure.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	DataStructure.Insert("DiscountMarkupPercent", 0);
	
	If WorkKindInHeader Then
		
		For Each TSRow IN Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.ProductsAndServices) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			Object.WorkKind);
			TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	Else
	
		For Each TSRow IN Object.Works Do
			
			TSRow.Price = 0;
			
			If Not ValueIsFilled(TSRow.WorkKind) Then
				Continue;	
			EndIf; 
			
			TabularSectionRow = New Structure();
			TabularSectionRow.Insert("WorkKind",			TSRow.WorkKind);
			TabularSectionRow.Insert("ProductsAndServices",		TSRow.ProductsAndServices);
			TabularSectionRow.Insert("Characteristic",		TSRow.Characteristic);
			TabularSectionRow.Insert("Price",				0);
			
			DocumentTabularSection.Add(TabularSectionRow);
			
		EndDo;
	
	EndIf;
		
	GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);	
	
	For Each TSRow IN DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices", TSRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		
		SearchResult = Object.Works.FindRows(SearchStructure);
		
		For Each ResultRow IN SearchResult Do				
			ResultRow.Price = TSRow.Price;
			CalculateAmountInTabularSectionLine("Works", ResultRow);
		EndDo;
		
	EndDo;
	
	For Each TabularSectionRow IN Object.Works Do
		TabularSectionRow.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent;
		CalculateAmountInTabularSectionLine("Works", TabularSectionRow);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection)
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		AND ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;	
	
	// Discount card.
	If DataStructure.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(DataStructure.DiscountPercentByDiscountCard) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent + DataStructure.DiscountPercentByDiscountCard;
		
	EndIf;
		
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsAndServicesTable = New ValueTable;
	
	Array = New Array;
	
	// Work kind.
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("WorkKind", TypeDescription);
	
	// ProductsAndServices.
	Array.Add(Type("CatalogRef.ProductsAndServices"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("ProductsAndServices", TypeDescription);
	
	// FixedValue.
	Array.Add(Type("Boolean"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("FixedCost", TypeDescription);
	
	// Characteristic.
	Array.Add(Type("CatalogRef.ProductsAndServicesCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsAndServicesTable.Columns.Add("VATRate", TypeDescription);	
	
	For Each TSRow IN DocumentTabularSection Do
		
		NewRow = ProductsAndServicesTable.Add();
		NewRow.WorkKind	 	 = TSRow.WorkKind;
		NewRow.FixedCost	 = TSRow.ProductsAndServices.FixedCost;
		NewRow.ProductsAndServices	 = TSRow.ProductsAndServices;
		NewRow.Characteristic	 = TSRow.Characteristic;
		If TypeOf(TSRow) = Type("Structure")
		   AND TSRow.Property("VATRate") Then
			NewRow.VATRate		 = TSRow.VATRate;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsAndServicesTable.WorkKind,
	|	ProductsAndServicesTable.FixedCost,
	|	ProductsAndServicesTable.ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic,
	|	ProductsAndServicesTable.VATRate
	|INTO TemporaryProductsAndServicesTable
	|FROM
	|	&ProductsAndServicesTable AS ProductsAndServicesTable";
	
	Query.SetParameter("ProductsAndServicesTable", ProductsAndServicesTable);
	Query.Execute();
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
		RoundingOrder = DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;	
	EndIf;	
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	ProductsAndServicesTable.ProductsAndServices AS ProductsAndServices,
	|	ProductsAndServicesTable.Characteristic AS Characteristic,
	|	ProductsAndServicesTable.VATRate AS VATRate,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency AS ProductsAndServicesPricesCurrency,
	|	ProductsAndServicesPricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	ProductsAndServicesPricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(ProductsAndServicesPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) / ISNULL(ProductsAndServicesPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsAndServicesTable AS ProductsAndServicesTable
	|		LEFT JOIN InformationRegister.ProductsAndServicesPrices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS ProductsAndServicesPricesSliceLast
	|		ON (CASE
	|				WHEN ProductsAndServicesTable.FixedCost
	|					THEN ProductsAndServicesTable.ProductsAndServices = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|				ELSE ProductsAndServicesTable.WorkKind = ProductsAndServicesPricesSliceLast.ProductsAndServices
	|			END)
	|			AND (CASE
	|				WHEN ProductsAndServicesTable.FixedCost
	|					THEN ProductsAndServicesTable.Characteristic = ProductsAndServicesPricesSliceLast.Characteristic
	|				ELSE TRUE
	|			END)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON (ProductsAndServicesPricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.CurrencyRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	ProductsAndServicesPricesSliceLast.Actuality";
		
	Query.SetParameter("ProcessingDate",	 DataStructure.Date);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	Query.SetParameter("DocumentCurrency", DataStructure.DocumentCurrency);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow IN DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		If TypeOf(TSRow) = Type("Structure")
		   AND TabularSectionRow.Property("VATRate") Then
			SearchStructure.Insert("VATRate", TabularSectionRow.VATRate);
		EndIf;
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
										
				Else	
					
					RoundingOrder = SearchResult[0].RoundingOrder;
					RoundUp = SearchResult[0].RoundUp;
	
				EndIf;
				
				If DataStructure.Property("AmountIncludesVAT") 
				   AND ((DataStructure.AmountIncludesVAT AND Not SearchResult[0].PriceIncludesVAT) 
				   OR (NOT DataStructure.AmountIncludesVAT AND SearchResult[0].PriceIncludesVAT)) Then
					Price = SmallBusinessServer.RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
										
				TabularSectionRow.Price = SmallBusinessServer.RoundPrice(Price, RoundingOrder, RoundUp);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close()
	
EndProcedure

&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			LabelText = NStr("en='%Currency%';ru='%Currency%'");
			LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
		EndIf;
	EndIf;
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		Else
			LabelText = LabelText + NStr("en=' • %PriceKind%';ru=' • %PriceKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	EndIf;
	
	// Margins discount kind.
	If ValueIsFilled(LabelStructure.DiscountKind) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountMarkupKind%';ru='%DiscountMarkupKind%'");
		Else
			LabelText = LabelText + NStr("en=' • %MarkupDiscountKind%';ru=' • %MarkupDiscountKind%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountMarkupKind%", TrimAll(String(LabelStructure.DiscountKind)));
	EndIf;
	
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		If IsBlankString(LabelText) Then
			LabelText = LabelText + NStr("en='%DiscountCard%';ru='%DiscountCard%'");
		Else
			LabelText = LabelText + NStr("en=' • %DiscountCard%';ru=' • %DiscountCard%'");
		EndIf;
		LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
	EndIf;	
	
	If SmallBusinessServer.GetFunctionalOptionValue("UseVAT") Then
		
		// VAT taxation.
		If ValueIsFilled(LabelStructure.VATTaxation) Then
			If IsBlankString(LabelText) Then
				LabelText = LabelText + NStr("en='%VATTaxation%';ru='%VATTaxation%'");
			Else
				LabelText = LabelText + NStr("en=' • %VATTaxation%';ru=' • %VATTaxation%'");
			EndIf;
			LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
		EndIf;
		
		// Flag showing that amount includes VAT.
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
				NewRow.Specification = BarcodeData.StructureProductsAndServicesData.Specification;
				
				NewRow.ProductsAndServicesTypeInventory = BarcodeData.StructureProductsAndServicesData.IsInventoryItem;
				
				CalculateAmountInTabularSectionLine( , NewRow);
				Items.Inventory.CurrentRow = NewRow.GetID();
				
			Else
				
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				CalculateAmountInTabularSectionLine( , FoundString);
				Items.Inventory.CurrentRow = FoundString.GetID();
				
			EndIf;
		EndIf;
	EndDo;
	
	UpdateTotalsClient();
	
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
		
		MessageString = NStr("en='Barcode data is not found: %1%; quantity: %2%';ru='Данные по штрихкоду не найдены: %1%; количество: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure
// End Peripherals

&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

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
Function GetContractChoiceFormParameters(Document, Company, Counterparty, Contract, OperationKind)
	
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
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtServer
Procedure ProcessOperationKindChange()
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationKind);
	
	For Each StringInventory IN Object.Inventory Do
		StringInventory.Reserve = 0;
	EndDo;
	
EndProcedure

&AtClient
Procedure ProcessContractChange(ContractData = Undefined)
	
	ContractBeforeChange = Contract;
	Contract = Object.Contract;
		
	If ContractBeforeChange <> Object.Contract Then
		
		If ContractData = Undefined Then
			
			ContractData = GetDataContractOnChange(Object.Date, Object.DocumentCurrency, Object.Contract);
			
		EndIf;
		
		PriceKindChanged = Object.PriceKind <> ContractData.PriceKind AND ValueIsFilled(ContractData.PriceKind);
		DiscountKindChanged = Object.DiscountMarkupKind <> ContractData.DiscountMarkupKind AND ValueIsFilled(ContractData.DiscountMarkupKind);
		If ContractData.Property("CallFromProcedureAtCounterpartyChange") Then
			ClearDiscountCard = ValueIsFilled(Object.DiscountCard); // Attribute DiscountCard will be cleared later.
		Else
			ClearDiscountCard = False;
		EndIf;			
			
		QueryPriceKind = (ValueIsFilled(Object.Contract) AND (PriceKindChanged OR DiscountKindChanged));
		
		SettlementsCurrencyBeforeChange = SettlementsCurrency;
		SettlementsCurrency = ContractData.SettlementsCurrency;
		
		NewContractAndCalculationCurrency = ValueIsFilled(Object.Contract) AND ValueIsFilled(SettlementsCurrency) 
										AND Object.Contract <> ContractBeforeChange AND SettlementsCurrencyBeforeChange <> ContractData.SettlementsCurrency;
		OpenFormPricesAndCurrencies = NewContractAndCalculationCurrency AND Object.DocumentCurrency <> ContractData.SettlementsCurrency
			AND Object.Inventory.Count() > 0;
		
		DocumentParameters = New Structure;
		DocumentParameters.Insert("ContractBeforeChange", ContractBeforeChange);
		DocumentParameters.Insert("SettlementsCurrencyBeforeChange", SettlementsCurrencyBeforeChange);
		DocumentParameters.Insert("ContractData", ContractData);
		DocumentParameters.Insert("QueryPriceKind", QueryPriceKind);
		DocumentParameters.Insert("OpenFormPricesAndCurrencies", OpenFormPricesAndCurrencies);
		DocumentParameters.Insert("PriceKindChanged", PriceKindChanged);
		DocumentParameters.Insert("DiscountKindChanged", DiscountKindChanged);
		DocumentParameters.Insert("ClearDiscountCard", ClearDiscountCard);
		DocumentParameters.Insert("RecalculationRequiredInventory", Object.Inventory.Count() > 0);
		DocumentParameters.Insert("RecalculationRequiredWork", False);
		
		ProcessPricesKindAndSettlementsCurrencyChange(DocumentParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") 
		AND ClosingResult.WereMadeChanges Then
		
		Modified = True;
		
		If Object.DocumentCurrency <> ClosingResult.DocumentCurrency Then
			
			Object.BankAccount = Undefined;
			
		EndIf;
		
		Object.PriceKind = ClosingResult.PriceKind;
		Object.DiscountMarkupKind = ClosingResult.DiscountKind;
		// DiscountCards
		If ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Not Object.Counterparty.IsEmpty() Then
			If ClosingResult.Counterparty = Object.Counterparty Then
				Object.DiscountCard = ClosingResult.DiscountCard;
				Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			Else // We will show the message and we will not change discount card data.
				CommonUseClientServer.MessageToUser(
				NStr("en='Discount card is not read. Discount card owner does not match the counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
				,
				"Counterparty",
				"Object");
			EndIf;
		ElsIf ValueIsFilled(ClosingResult.DiscountCard) AND ValueIsFilled(ClosingResult.Counterparty) AND Object.Counterparty.IsEmpty() Then
			Object.Counterparty = ClosingResult.Counterparty;
			CounterpartyOnChange(Items.Counterparty); // Discount card data is cleared in this procedure.
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
			
			ShowUserNotification(
				NStr("en='Counterparty is filled in and discount card is read';ru='Заполнен контрагент и считана дисконтная карта'"),
				GetURL(Object.DiscountCard),
				StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The counterparty is filled out in the document and discount card %1 is read';ru='В документе заполнен контрагент и считана дисконтная карта %1'"), Object.DiscountCard),
				PictureLib.Information32);
		Else
			Object.DiscountCard = ClosingResult.DiscountCard;
			Object.DiscountPercentByDiscountCard = ClosingResult.DiscountPercentByDiscountCard;
		EndIf;
		// End DiscountCards
		Object.DocumentCurrency = ClosingResult.DocumentCurrency;
		Object.ExchangeRate = ClosingResult.PaymentsRate;
		Object.Multiplicity = ClosingResult.SettlementsMultiplicity;
		Object.AmountIncludesVAT = ClosingResult.AmountIncludesVAT;
		Object.IncludeVATInPrice = ClosingResult.IncludeVATInPrice;
		Object.VATTaxation = ClosingResult.VATTaxation;
		SettlementsCurrencyBeforeChange = AdditionalParameters.SettlementsCurrencyBeforeChange;
		
		// Recalculate prices by kind of prices.
		If ClosingResult.RefillPrices Then
			
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
		EndIf;
		
		// Recalculate prices by currency.
		If Not ClosingResult.RefillPrices
			AND ClosingResult.RecalculatePrices Then
			
			SmallBusinessClient.RecalculateTabularSectionPricesByCurrency(ThisForm, SettlementsCurrencyBeforeChange, "Inventory");
			
		EndIf;
		
		// Recalculate the amount if VAT taxation flag is changed.
		If ClosingResult.VATTaxation <> ClosingResult.PrevVATTaxation Then
			
			FillVATRateByVATTaxation();
			
		EndIf;
		
		// Recalculate the amount if the "Amount includes VAT" flag is changed.
		If Not ClosingResult.RefillPrices
			AND Not ClosingResult.AmountIncludesVAT = ClosingResult.PrevAmountIncludesVAT Then
			
			SmallBusinessClient.RecalculateTabularSectionAmountByFlagAmountIncludesVAT(ThisForm, "Inventory");
			
		EndIf;
		
		// DiscountCards
		If ClosingResult.RefillDiscounts AND Not ClosingResult.RefillPrices Then
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		EndIf;
		// End DiscountCards
		
		For Each TabularSectionRow IN Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, NationalCurrencyExchangeRate, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, NationalCurrencyMultiplicity, Object.Multiplicity));
				
		EndDo;
		
		// Generate price and currency label.
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			NationalCurrencyExchangeRate,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
			
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		// AutomaticDiscounts
		If ClosingResult.RefillDiscounts OR ClosingResult.RefillPrices OR ClosingResult.RecalculatePrices Then
			ClearCheckboxDiscountsAreCalculatedClient("RefillByFormDataPricesAndCurrency");
		EndIf;
	EndIf;
	
	UpdateTotalsClient();
	RecalculatePaymentCalendar();
	
EndProcedure

&AtClient
Procedure DefineNewCurrencyRateSettingNeed(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Object.ExchangeRate = AdditionalParameters.NewExchangeRate;
		Object.Multiplicity = AdditionalParameters.NewRatio;
		
		For Each TabularSectionRow IN Object.Prepayment Do
			
			TabularSectionRow.PaymentAmount = SmallBusinessClient.RecalculateFromCurrencyToCurrency(
				TabularSectionRow.SettlementsAmount,
				TabularSectionRow.ExchangeRate,
				?(Object.DocumentCurrency = NationalCurrency, NationalCurrencyExchangeRate, Object.ExchangeRate),
				TabularSectionRow.Multiplicity,
				?(Object.DocumentCurrency = NationalCurrency, NationalCurrencyMultiplicity, Object.Multiplicity));  
			
		EndDo;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", 
			Object.PriceKind, 
			Object.DiscountMarkupKind, 
			Object.DocumentCurrency, 
			SettlementsCurrency, 
			Object.ExchangeRate, 
			NationalCurrencyExchangeRate, 
			Object.AmountIncludesVAT, 
			CurrencyTransactionsAccounting, 
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
		
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
	EndIf;
	
EndProcedure // DefineNewCurrencyRateSettingNeed()

&AtClient
Procedure DefineDocumentRecalculateNeedByContractTerms(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ContractData = AdditionalParameters.ContractData;
		
		If AdditionalParameters.RecalculationRequiredInventory Then
			
			SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
			
		EndIf;
		
		If AdditionalParameters.RecalculationRequiredWork Then
			
			RefillTabularSectionPricesByPriceKind();
			
		EndIf;
		
		UpdateTotalsClient();
		RecalculatePaymentCalendar();
		
	EndIf;
	
EndProcedure // DefineDocumentRecalculateNeedByContractTerms()

&AtServerNoContext
Procedure ReadCounterpartyAttributes(StructureAttributes, Val Counterparty)
	
	Attributes = "DoOperationsByContracts";
	
	If StructureAttributes = Undefined Then
		StructureAttributes = New Structure(Attributes);
	EndIf;
	
	If ValueIsFilled(Counterparty) Then
		FillPropertyValues(StructureAttributes, CommonUse.ObjectAttributesValues(Counterparty, Attributes));
	Else
		StructureAttributes.DoOperationsByContracts = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetOptionEditInListCompleted(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	While Object.PaymentCalendar.Count() > 1 Do
		Object.PaymentCalendar.Delete(Object.PaymentCalendar.Count()-1);
	EndDo;
	
	Items.EditInList.Check = Not Items.EditInList.Check;
	FormManagement();
	
EndProcedure

&AtClient
Procedure FormManagement()
	
	ShipmentDateInHeader	= Object.ShipmentDatePosition = PredefinedValue("Enum.AttributePositionOnForm.InHeader");
	EditInList				= Items.EditInList.Check;
	IsOrderForProcessing	= Object.OperationKind = PredefinedValue("Enum.OperationKindsCustomerOrder.OrderForProcessing");
	OrderSaved				= Not object.Ref.IsEmpty();
	
	Items.ShipmentDate.Visible							= ShipmentDateInHeader;
	Items.InventoryShipmentDate.Visible					= Not ShipmentDateInHeader;
	Items.BankAccount.Visible							= Object.CashAssetsType	= PredefinedValue("Enum.CashAssetTypes.Noncash");
	Items.PettyCash.Visible								= Object.CashAssetsType = PredefinedValue("Enum.CashAssetTypes.Cash");
	Items.PaymentCalendarAsString.Visible				= Not EditInList;
	Items.ListPaymentCalendar.Visible					= EditInList;
	Items.Contract.Visible								= CounterpartyAttributes.DoOperationsByContracts;
	Items.InventoryCommandsChangeReserve.Visible		= Not IsOrderForProcessing;
	Items.InventoryReserve.Visible						= Not IsOrderForProcessing;
	Items.PageConsumerMaterials.Visible					= IsOrderForProcessing;
	Items.InventoryBatch.Visible						= Not IsOrderForProcessing And ThisObject.InventoryReservation;
	Items.PaymentCalendarFields.Enabled					= Object.SchedulePayment;
	Items.BankAccount.MarkIncomplete					= Object.SchedulePayment And Not ValueIsFilled(Object.BankAccount);
	Items.PettyCash.MarkIncomplete						= Object.SchedulePayment And Not ValueIsFilled(Object.PettyCash);
	
EndProcedure

&AtClient
Procedure UpdateTotalsClient()
	
	UpdateTotals(
	Object.Inventory,
	TotalAmount,
	TotalVATAmount);
	
EndProcedure

&AtServer
Процедура UpdateTotalsServer()
	
	UpdateTotals(
	Object.Inventory,
	TotalAmount,
	TotalVATAmount);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateTotals(TableInventory, TotalAmount, TotalVATAmount)
	
	TotalAmount		= 0;
	TotalVATAmount	= 0;
	
	For Each Row In TableInventory Do
		TotalAmount = TotalAmount + Row.Total;
		TotalVATAmount = TotalVATAmount + Row.VATAmount;
	КонецЦикла;
	
EndProcedure

#EndRegion

#Region WorkWithPick
	
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName = "Inventory";
	SelectionMarker = "Inventory";
	
	If Not IsBlankString(SelectionOpenParameters[TabularSectionName]) Then
		
		PickProductsAndServicesInDocumentsClient.OpenPick(ThisForm, TabularSectionName, SelectionOpenParameters[TabularSectionName]);
		Return;
		
	EndIf;
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",				Object.Date);
	SelectionParameters.Insert("Company",				Company);
	SelectionParameters.Insert("SpecificationsUsed",	True);
	
	If InventoryReservation Then
		
		SelectionParameters.Insert("StructuralUnit", 	Object.StructuralUnitReserve);
		SelectionParameters.Insert("FillReserve", 		True);
		SelectionParameters.Insert("ReservationUsed", True);
		
	Else
		
		SelectionParameters.Insert("FillReserve", 		False);
		
	EndIf;
	
	SelectionParameters.Insert("AvailableStructuralUnitEdit", True);
	
	SelectionParameters.Insert("DiscountMarkupKind", 		Object.DiscountMarkupKind);
	SelectionParameters.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);
	SelectionParameters.Insert("PriceKind", 				Object.PriceKind);
	SelectionParameters.Insert("Currency", 				Object.DocumentCurrency);
	SelectionParameters.Insert("AmountIncludesVAT", 		Object.AmountIncludesVAT);
	SelectionParameters.Insert("DocumentOrganization", 	Object.Company);
	SelectionParameters.Insert("VATTaxation",		Object.VATTaxation);
	SelectionParameters.Insert("AvailablePriceChanging",	Not Items.InventoryPrice.ReadOnly);
	
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
	
	SelectionParameters.Insert("ProductsAndServicesType",		ProductsAndServicesType);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	#If WebClient Then
		//Form data transmission platform error crawl in Web client when form item content change
		OpenForm("CommonForm.BalanceReservesPricesPickForm", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	#Else
		
		OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	#EndIf
	
EndProcedure // ExecutePick()

&AtClient
Procedure MaterialsPick(Command)
	
	TabularSectionName = "Materials";
	SelectionMarker = "Materials";
	
	SelectionParameters = New Structure;
	
	SelectionParameters.Insert("Period",	Object.Date);
	SelectionParameters.Insert("Company",	Company);
	
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
	
	TabularSectionName = "ConsumerMaterials";
	
	SelectionParameters.Insert("ProductsAndServicesType", ProductsAndServicesType);
	
	SelectionParameters.Insert("OwnerFormUUID", UUID);
	
	#If WebClient Then
		//Form data transmission platform error crawl in Web client when form item content change
		OpenForm("CommonForm.BalanceReservesPricesPickForm", SelectionParameters, ThisForm);
		
	#Else
		
		OpenForm("CommonForm.PickForm", SelectionParameters, ThisForm);
		
	#EndIf
	
EndProcedure // ExecutePick()

&AtClient
Procedure WriteErrorReadingDataFromStorage()
	
	EventLogMonitorClient.AddMessageForEventLogMonitor("Error", , EventLogMonitorErrorText);
		
EndProcedure // WriteErrorReadingDataFromStorage()

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	If Not (TypeOf(TableForImport) = Type("ValueTable")
		OR TypeOf(TableForImport) = Type("Array")) Then
		
		EventLogMonitorErrorText = "Mismatch the type of passed to the document from pick [" + TypeOf(TableForImport) + "].
				|Address of inventories in storage: " + TrimAll(InventoryAddressInStorage) + "
				|Tabular section name: " + TrimAll(TabularSectionName);
		
		Return;
		
	Else
		
		EventLogMonitorErrorText = "";
		
	EndIf;
	
	For Each ImportRow IN TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If NewRow.Property("Total")
			AND Not ValueIsFilled(NewRow.Total) Then
			
			NewRow.Total = NewRow.Amount + ?(Object.AmountIncludesVAT, 0, NewRow.VATAmount);
			
		EndIf;
		
		// Refilling
		If TabularSectionName = "Works" Then
			
			NewRow.ConnectionKey = SmallBusinessServer.CreateNewLinkKey(ThisForm);
			
			If ValueIsFilled(ImportRow.ProductsAndServices) Then
				
				NewRow.ProductsAndServicesTypeService = (ImportRow.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.Service"));
				
			EndIf;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If ValueIsFilled(ImportRow.ProductsAndServices) Then
				
				NewRow.ProductsAndServicesTypeInventory = (ImportRow.ProductsAndServices.ProductsAndServicesType = PredefinedValue("Enum.ProductsAndServicesTypes.InventoryItem"));
				
			EndIf;
			
		EndIf;
		
		If NewRow.Property("Specification") Then 
			
			NewRow.Specification = SmallBusinessServer.GetDefaultSpecification(ImportRow.ProductsAndServices, ImportRow.Characteristic);
			
		EndIf;
		
	EndDo;
	
	// AutomaticDiscounts
	If TableForImport.Count() > 0 Then
		ResetFlagDiscountsAreCalculatedServer("PickDataProcessor");
	EndIf;

EndProcedure // GetInventoryFromStorage()

#EndRegion

#Region DiscountCards

// Procedure - selection handler of discount card, beginning.
//
&AtClient
Procedure DiscountCardIsSelected(DiscountCard)

	DiscountCardOwner = GetDiscountCardOwner(DiscountCard);
	If Object.Counterparty.IsEmpty() AND Not DiscountCardOwner.IsEmpty() Then
		Object.Counterparty = DiscountCardOwner;
		CounterpartyOnChange(Items.Counterparty);
		
		ShowUserNotification(
			NStr("en='Counterparty is filled in and discount card is read';ru='Заполнен контрагент и считана дисконтная карта'"),
			GetURL(DiscountCard),
			StringFunctionsClientServer.SubstituteParametersInString(NStr("en='The counterparty is filled out in the document and discount card %1 is read';ru='В документе заполнен контрагент и считана дисконтная карта %1'"), DiscountCard),
			PictureLib.Information32);
	ElsIf Object.Counterparty <> DiscountCardOwner AND Not DiscountCardOwner.IsEmpty() Then
		
		CommonUseClientServer.MessageToUser(
			NStr("en='Discount card is not read. Discount card owner does not match the counterparty in the document.';ru='Дисконтная карта не считана. Владелец дисконтной карты не совпадает с контрагентом в документе.'"),
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

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionally(DiscountCard)
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Object.DiscountCard = DiscountCard;
	Object.DiscountPercentByDiscountCard = SmallBusinessServer.CalculateDiscountPercentByDiscountCard(Object.Date, DiscountCard);
	
	LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
			Object.PriceKind,
			Object.DiscountMarkupKind,
			Object.DocumentCurrency,
			SettlementsCurrency,
			Object.ExchangeRate,
			NationalCurrencyExchangeRate,
			Object.AmountIncludesVAT,
			CurrencyTransactionsAccounting,
			Object.VATTaxation,
			Object.DiscountCard,
			Object.DiscountPercentByDiscountCard);
			
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	If Object.Inventory.Count() > 0 Then
		Text = NStr("en='Refill discounts in all lines?';ru='Перезаполнить скидки во всех строках?'");
		Notification = New NotifyDescription("DiscountCardIsSelectedAdditionallyEnd", ThisObject);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	EndIf;
	
EndProcedure

// Procedure - selection handler of discount card, end.
//
&AtClient
Procedure DiscountCardIsSelectedAdditionallyEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
		
		UpdateTotalsClient();
		RecalculatePaymentCalendar();
	EndIf;
	
	// AutomaticDiscounts
	ClearCheckboxDiscountsAreCalculatedClient("DiscountRecalculationByDiscountCard");
	
EndProcedure

// Function returns True if the discount card, which is passed as the parameter, is fixed.
//
&AtServerNoContext
Function ThisDiscountCardWithFixedDiscount(DiscountCard)
	
	Return DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountKindsForDiscountCards.FixedDiscount;
	
EndFunction

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
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

// Procedure executes only for ACCUMULATIVE discount cards.
// Procedure calculates document discounts after document date change. Recalculation is executed if
// the discount percent by selected discount card changed. 
//
&AtClient
Procedure RecalculateDiscountPercentAtDocumentDateChangeEnd(QuestionResult, AdditionalParameters) Export

	If QuestionResult = DialogReturnCode.Yes Then
		Object.DiscountPercentByDiscountCard = AdditionalParameters.NewDiscountPercentByDiscountCard;
		
		LabelStructure = New Structure("PriceKind, DiscountKind, DocumentCurrency, SettlementsCurrency, Rate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard",
				Object.PriceKind,
				Object.DiscountMarkupKind,
				Object.DocumentCurrency,
				SettlementsCurrency,
				Object.ExchangeRate,
				NationalCurrencyExchangeRate,
				Object.AmountIncludesVAT,
				CurrencyTransactionsAccounting,
				Object.VATTaxation,
				Object.DiscountCard,
				Object.DiscountPercentByDiscountCard);
				
		PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
		
		If AdditionalParameters.RecalculateTP Then
			SmallBusinessClient.RefillDiscountsTablePartAfterDiscountCardRead(ThisForm, "Inventory");
			
			UpdateTotalsClient();
			RecalculatePaymentCalendar();
		EndIf;
				
	EndIf;
	
EndProcedure

// Function returns the discount card owner.
//
&AtServerNoContext
Function GetDiscountCardOwner(DiscountCard)
	
	Return DiscountCard.CardOwner;
	
EndFunction

// Procedure - Command handler ReadDiscountCard forms.
//
&AtClient
Procedure ReadDiscountCardClick(Item)
	
	ParametersStructure = New Structure("Counterparty", Object.Counterparty);
	NotifyDescription = New NotifyDescription("ReadDiscountCardClickEnd", ThisObject);
	OpenForm("Catalog.DiscountCards.Form.ReadingDiscountCard", ParametersStructure, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Final part of procedure - of command handler ReadDiscountCard forms.
// Is called after read form closing of discount card.
//
&AtClient
Procedure ReadDiscountCardClickEnd(ReturnParameters, Parameters) Export

	If TypeOf(ReturnParameters) = Type("Structure") Then
		DiscountCardRead = ReturnParameters.DiscountCardRead;
		DiscountCardIsSelected(ReturnParameters.DiscountCard);
	EndIf;

EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Procedure - form command handler CalculateDiscountsMarkups.
//
&AtClient
Procedure CalculateDiscountsMarkups(Command)
	
	If Object.Inventory.Count() = 0 Then
		If Object.DiscountsMarkups.Count() > 0 Then
			Object.DiscountsMarkups.Clear();
		EndIf;
		Return;
	EndIf;
	
	CalculateDiscountsMarkupsClient();
	UpdateTotalsClient();
	
EndProcedure

// Procedure calculates discounts by document.
//
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

// Procedure calculates discounts by document.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	AppliedDiscounts = DiscountsMarkupsServerOverridable.Calculate(Object, ParameterStructure);
	
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

// Procedure - command handler "OpenInformationAboutDiscounts".
//
&AtClient
Procedure OpenInformationAboutDiscounts(Command)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenInformationAboutDiscountsClient()
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row.
//
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

// End modeless window opening "ShowQuestion()". Procedure opens a common form for information analysis about discounts by current row.
//
&AtClient
Procedure NotificationQueryCalculateDiscounts(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.No Then
		Return;
	EndIf;
	ParameterStructure = AdditionalParameters.ParameterStructure;
	CalculateDiscountsMarkupsOnServer(ParameterStructure);
	CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure);
	
EndProcedure

// Procedure opens a common form for information analysis about discounts by current row after calculation of automatic discounts (if it was necessary).
//
&AtClient
Procedure CalculateDiscountsCompleteQuestionDataProcessor(ParameterStructure)
	
	If Not ValueIsFilled(AddressDiscountsAppliedInTemporaryStorage) Then
		CalculateDiscountsMarkupsClient();
		UpdateTotalsClient();
	EndIf;
	
	CurrentData = Items.Inventory.CurrentData;
	MarkupsDiscountsClient.OpenFormAppliedDiscounts(CurrentData, Object, ThisObject);
	
EndProcedure

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculatedServer(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox "DiscountsAreCalculated" if it is necessary and returns True if it is required to recalculate discounts.
//
&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
	EndIf;
	Return RecalculationIsRequired;
	
EndFunction

// Function clears checkbox DiscountsAreCalculated if it is necessary and returns True if it is required to recalculate discounts.
//
&AtServer
Function ResetFlagDiscountsAreCalculated(Action, SPColumn = "")
	
	Return DiscountsMarkupsServer.ResetFlagDiscountsAreCalculated(ThisObject, Action, SPColumn);
	
EndFunction

// Procedure executes necessary actions when creating the form on server.
//
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

#EndRegion

#Region InteractiveActionResultHandlers

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

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure // UpdateAdditionalAttributeItems()
// End StandardSubsystems.Properties

#EndRegion

