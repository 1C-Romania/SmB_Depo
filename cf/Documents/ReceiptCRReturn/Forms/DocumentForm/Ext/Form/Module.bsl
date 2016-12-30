////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure recalculates the document on client.
//
&AtClient
Procedure RecalculateDocumentAtClient()
	
	Object.DocumentAmount = Object.Inventory.Total("Total");
	
EndProcedure // RecalculateDocumentAtClient()

// The procedure fills out a list of payment card kinds.
//
&AtServer
Procedure GetChoiceListOfPaymentCardKinds()
	
	ArrayTypesOfPaymentCards = Catalogs.POSTerminals.PaymentCardKinds(Object.POSTerminal);
	
	Items.PaymentByChargeCardTypeCards.ChoiceList.LoadValues(ArrayTypesOfPaymentCards);
	
EndProcedure // GetPaymentCardKindsChoiceList()

// Gets references to external equipment.
//
&AtServer
Procedure GetRefsToEquipment()
	
	FiscalRegister = ?(
		ValueIsFilled(Object.CashCR) AND ValueIsFilled(Object.CashCR.Peripherals),
		Object.CashCR.Peripherals.Ref,
		Catalogs.Peripherals.EmptyRef()
	);
	
	POSTerminal = ?(
		ValueIsFilled(Object.POSTerminal) AND ValueIsFilled(Object.POSTerminal.Peripherals),
		Object.POSTerminal.Peripherals,
		Catalogs.Peripherals.EmptyRef()
	);
	
	Items.PaymentWithPaymentCardsCancelPayment.Enabled = ValueIsFilled(POSTerminal);
	
EndProcedure // GetRefsOnEquipment()

// Procedure fills VAT Rate in tabular section
// by company taxation system.
// 
&AtServer
Procedure FillVATRateByCompanyVATTaxation()
	
	TaxationBeforeChange = Object.VATTaxation;
	Object.VATTaxation = SmallBusinessServer.VATTaxation(Object.Company, Object.StructuralUnit, Object.Date);
	
	If Not TaxationBeforeChange = Object.VATTaxation Then
		FillVATRateByVATTaxation();
	EndIf;
	
EndProcedure // FillVATRateByVATTaxation()

// Procedure fills the VAT rate in the tabular section according to the taxation system.
// 
&AtServer
Procedure FillVATRateByVATTaxation()
	
	If Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
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
		
		If Object.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then	
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

// Receives the set of data from the server for the ProductsAndServicesOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsAndServicesOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.ProductsAndServices.MeasurementUnit);
	
	StructureData.Insert(
		"Content",
		SmallBusinessServer.GetProductsAndServicesPresentationForPrinting(
			?(ValueIsFilled(StructureData.ProductsAndServices.DescriptionFull),
			StructureData.ProductsAndServices.DescriptionFull, StructureData.ProductsAndServices.Description),
			StructureData.Characteristic, StructureData.ProductsAndServices.SKU)
	);
	
	If StructureData.Property("VATTaxation") 
		AND Not StructureData.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotTaxableByVAT Then
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

// It receives data set from server for the CharacteristicOnChange procedure.
//
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

// It receives data set from server for the DateOnChange procedure.
//
&AtServer
Function GetDataDateOnChange(DateBeforeChange)
	
	StructureData = New Structure();
	
	StructureData.Insert("DATEDIFF", SmallBusinessServer.CheckDocumentNumber(Object.Ref, Object.Date, DateBeforeChange));
	
	FillVATRateByCompanyVATTaxation();
	
	Return StructureData;
	
EndFunction // GetDataDateOnChange()

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
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

// VAT amount is calculated in the row of tabular section.
//
&AtClient
Procedure CalculateVATSUM(TabularSectionRow)
	
	VATRate = SmallBusinessReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(
		Object.AmountIncludesVAT,
		TabularSectionRow.Amount
	  - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
	  TabularSectionRow.Amount * VATRate / 100);
	
EndProcedure // CalculateVATAmount()

// Procedure calculates the amount in the row of tabular section.
//
&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	AmountBeforeCalculation = TabularSectionRow.Amount;
	
	If TabularSectionRow.DiscountMarkupPercent = 100 Then
		TabularSectionRow.Amount = 0;
	ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
		    AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
	EndIf;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = AmountBeforeCalculation - TabularSectionRow.Amount;
	
	// AutomaticDiscounts.
	RecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine");
	
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	
	// If picture was changed that focus goes from TS and procedure RecalculateDocumentAtClient() is not called.
	If RecalculationIsRequired Then
		RecalculateDocumentAtClient();
	EndIf;
	// End AutomaticDiscounts

EndProcedure // CalculateAmountInTabularSectionLine()

// Procedure calculates discount % in tabular section string.
//
&AtClient
Procedure CalculateDiscountPercent(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	If TabularSectionRow.Quantity * TabularSectionRow.Price < TabularSectionRow.DiscountAmount Then
		TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.DiscountAmount;
	If TabularSectionRow.Price <> 0
	   AND TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.DiscountMarkupPercent = (1 - TabularSectionRow.Amount / (TabularSectionRow.Price * TabularSectionRow.Quantity)) * 100;
	Else
		TabularSectionRow.DiscountMarkupPercent = 0;
	EndIf;
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // CalculateDiscountPercent()

// Function returns the label text "Prices and currency".
//
&AtClientAtServerNoContext
Function GenerateLabelPricesAndCurrency(LabelStructure)
	
	LabelText = "";
	
	// Currency.
	If LabelStructure.CurrencyTransactionsAccounting Then
		If ValueIsFilled(LabelStructure.DocumentCurrency) Then
			//===============================
			//©# (Begin)	AlekS [2016-09-13]
			//LabelText = NStr("en='%Currency%';ru='%Вал%'");
			//LabelText = StrReplace(LabelText, "%Currency%", TrimAll(String(LabelStructure.DocumentCurrency)));
			LabelText = TrimAll(String(LabelStructure.DocumentCurrency));
			//©# (End)		AlekS [2016-09-13]
			//===============================
		EndIf;
	EndIf;
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		//===============================
		//©# (Begin)	AlekS [2016-09-13]
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%PriceKind%';ru='%PriceKind%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %PriceKind%';ru=' • %ВидЦен%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
		LabelText = LabelText + " • " + TrimAll(String(LabelStructure.PriceKind));
		//©# (End)		AlekS [2016-09-13]
		//===============================
	EndIf;
	
	// Discount card.
	If ValueIsFilled(LabelStructure.DiscountCard) Then
		//===============================
		//©# (Begin)	AlekS [2016-09-13]
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%DiscountCard%';ru='%ДисконтнаяКарта%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %DiscountCard%';ru=' • %ДисконтнаяКарта%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%DiscountCard%", String(LabelStructure.DiscountPercentByDiscountCard)+"% by map"); //ShortLP(String(LabelStructure.DiscountCard)));
		LabelText = LabelText + " • " + String(LabelStructure.DiscountPercentByDiscountCard) + 
							NStr("en='% by card';ru='% по карте'"); 
		//©# (End)		AlekS [2016-09-13]
		//===============================
	EndIf;	
	
	// VAT taxation.
	If ValueIsFilled(LabelStructure.VATTaxation) Then
		//If IsBlankString(LabelText) Then
		//	LabelText = LabelText + NStr("en='%VATTaxation%';ru='%VATTaxation%'");
		//Else
		//	LabelText = LabelText + NStr("en=' • %VATTaxation%';ru=' • %НалогообложениеНДС%'");
		//EndIf;
		//LabelText = StrReplace(LabelText, "%VATTaxation%", TrimAll(String(LabelStructure.VATTaxation)));
		LabelText = LabelText + " • " + TrimAll(String(LabelStructure.VATTaxation));
		//©# (End)		AlekS [2016-09-13]
		//===============================
	EndIf;
	
	
//===============================
//©# (Begin)	AlekS [2016-09-13]
//
//  THIS FLAG HAS NO CHANCE TO BE SHOWED - need attention !   8-(
//
//©# (End)		AlekS [2016-09-13]
//===============================
	// Flag showing that amount includes VAT.
	If IsBlankString(LabelText) Then	
		If LabelStructure.AmountIncludesVAT Then	
			LabelText = NStr("en='Amount includes VAT';ru='Сумма включает НДС'");
		Else
			LabelText = NStr("en='Amount does not include VAT';ru='Сумма не включает НДС'");
		EndIf;
	EndIf;
	
	Return LabelText;
	
EndFunction // GenerateLabelPricesAndCurrency()	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR CONTROL OF THE FORM APPEARANCE

// Procedure sets mode Only view.
//
Procedure SetModeReadOnly()
	
	ReadOnly = True; // Receipt is issued. Change information is forbidden.
	Items.IssueReceipt.Enabled = False;
	Items.PaymentWithPaymentCardsCancelPayment.Enabled = False;
	
EndProcedure // SetModeOnlyViewing()

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
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
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	// Temporarily.
	//( elmi #11
	//Object.IncludeVATInPrice = True;  
	//) elmi
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	
	If ValueIsFilled(Object.ReceiptCRNumber)
	AND Not CashCRUseWithoutEquipmentConnection Then
		SetModeReadOnly();
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		GetChoiceListOfPaymentCardKinds();
	EndIf;
	
	UsePeripherals = SmallBusinessReUse.UsePeripherals();
	If UsePeripherals Then
		GetRefsToEquipment();
	EndIf;
	
	If Not ValueIsFilled(Object.Ref)
		AND Not ValueIsFilled(Parameters.Basis) 
		AND Not ValueIsFilled(Parameters.CopyingValue) Then
		FillVATRateByCompanyVATTaxation();
	ElsIf Object.VATTaxation = Enums.VATTaxationTypes.TaxableByVAT Then	
		Items.InventoryVATRate.Visible = True;
		Items.InventoryVATAmount.Visible = True;
		Items.InventoryAmountTotal.Visible = True;
	Else
		Items.InventoryVATRate.Visible = False;
		Items.InventoryVATAmount.Visible = False;
		Items.InventoryAmountTotal.Visible = False;
	EndIf;
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Object.DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		//( elmi # 08.5
	    //StructureByCurrency.ExchangeRate = 0,
		  StructureByCurrency.Multiplicity = 0,
		//) elmi


		1,
		StructureByCurrency.Multiplicity
	);
	
	StructureByCurrency = InformationRegisters.CurrencyRates.GetLast(Object.Date, New Structure("Currency", Constants.NationalCurrency.Get()));
	RateNationalCurrency = StructureByCurrency.ExchangeRate;
	RepetitionNationalCurrency = StructureByCurrency.Multiplicity;
	
	CurrencyTransactionsAccounting = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	LabelStructure = New Structure("PriceKind, DocumentCurrency, SettlementsCurrency, ExchangeRate, RateNationalCurrency, AmountIncludesVAT, CurrencyTransactionsAccounting, VATTaxation, DiscountCard, DiscountPercentByDiscountCard", Object.PriceKind, Object.DocumentCurrency, Object.DocumentCurrency, ExchangeRate, RateNationalCurrency, Object.AmountIncludesVAT, CurrencyTransactionsAccounting, Object.VATTaxation, Object.DiscountCard, Object.DiscountPercentByDiscountCard);
	PricesAndCurrency = GenerateLabelPricesAndCurrency(LabelStructure);
	
	ETUseWithoutEquipmentConnection = Object.POSTerminal.UseWithoutEquipmentConnection;
	Items.PaymentWithPaymentCardsCancelPayment.Visible = Not ETUseWithoutEquipmentConnection;
	
	Items.InventoryDiscountAmount.Visible = Constants.FunctionalOptionUseDiscountsMarkups.Get();
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = SmallBusinessAccessManagementReUse.AllowedEditDocumentPrices();
	SaleFromWarehouse = Object.StructuralUnit.StructuralUnitType = Enums.StructuralUnitsTypes.Warehouse;
	
	Items.InventoryPrice.ReadOnly 					= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse;
	Items.InventoryAmount.ReadOnly 				= Not AllowedEditDocumentPrices OR Not SaleFromWarehouse; 
	Items.InventoryDiscountPercentMargin.ReadOnly  = Not AllowedEditDocumentPrices;
	Items.InventoryDiscountAmount.ReadOnly 			= Not AllowedEditDocumentPrices;
	Items.InventoryVATAmount.ReadOnly 				= Not AllowedEditDocumentPrices;
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// AutomaticDiscounts.
	AutomaticDiscountsOnCreateAtServer();

EndProcedure // OnCreateAtServer()

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	For Each CurRow IN Object.Inventory Do
		CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
	EndDo;
	
	RecalculateDocumentAtClient();
	
EndProcedure // OnOpen()

// Procedure - OnReadAtServer event handler of the form.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ChangeProhibitionDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	GetChoiceListOfPaymentCardKinds();
	Items.IssueReceipt.Enabled = Not Object.DeletionMark;
	
EndProcedure // OnReadAtServer()

// Procedure - event handler OnClose form.
//
&AtClient
Procedure OnClose()

	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

	// AutomaticDiscounts
	// Display message about discount calculation if you click the "Post and close" or form closes by the cross with change saving.
	If UseAutomaticDiscounts AND DiscountsCalculatedBeforeWrite Then
		ShowUserNotification("Update:", 
										GetURL(Object.Ref), 
										String(Object.Ref)+". Automatic discounts (markups) are calculated!", 
										PictureLib.Information32);
	EndIf;
	// End AutomaticDiscounts

EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			//Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "RefreshReceiptCRDocumentsListForm" Then
		For Each CurRow IN Object.Inventory Do
			CurRow.DiscountAmount = CurRow.Price * CurRow.Quantity - CurRow.Amount;
		EndDo;
	EndIf;
	
EndProcedure

// BeforeRecord event handler procedure.
//
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
		Else
			Object.DiscountsAreCalculated = True;
			RefreshImageAutoDiscountsAfterWrite = True;
		EndIf;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshReceiptCRDocumentsListForm");
	
	// CWP
	If TypeOf(ThisForm.FormOwner) = Type("ManagedForm")
		AND Find(ThisForm.FormOwner.FormName, "DocumentForm_CWP") > 0 
		Then
		Notify("CWP_Write_ReceiptCRReturn", New Structure("Ref, Number, Date", Object.Ref, Object.Number, Object.Date));
	EndIf;
	// End CWP
	
EndProcedure // AfterWrite()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Receipt print procedure on fiscal register.
//
&AtClient
Procedure IssueReceipt()
	
	ErrorDescription = "";
	
	If Object.ReceiptCRNumber <> 0
	AND Not CashCRUseWithoutEquipmentConnection Then
		
		MessageText = NStr("en='Check has already been issued on the fiscal record!';ru='Чек уже пробит на фискальном регистраторе!'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ShowMessageBox = False;
	If Object.PaymentWithPaymentCards.Count() = 0 OR SmallBusinessClient.CheckPossibilityOfReceiptPrinting(ThisForm, ShowMessageBox) Then
		
		DeviceIdentifierET = Undefined;
		DeviceIdentifierFR = Undefined;
		ResultFR               = True;
		ResultET               = True;
		
		If UsePeripherals Then
			
			If EquipmentManagerClient.RefreshClientWorkplace() Then
				
				// Device selection FR
				DeviceIdentifierFR = ?(
					ValueIsFilled(FiscalRegister),
					FiscalRegister,
					Undefined
				);
				
				If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
					
					If Not CashCRUseWithoutEquipmentConnection Then
						
						// FR device connection
						ResultFR = EquipmentManagerClient.ConnectEquipmentByID(
							UUID,
							DeviceIdentifierFR,
							ErrorDescription
						);
						
					EndIf;
					
					If ResultFR OR CashCRUseWithoutEquipmentConnection Then
						
						//It is required to check and cancel noncash payments in advance
						If ValueIsFilled(POSTerminal)
						   AND Object.PaymentWithPaymentCards.Count() > 0
						   AND Not ETUseWithoutEquipmentConnection Then
							
							// Device selection ET
							DeviceIdentifierET = ?(
								ValueIsFilled(POSTerminal),
								POSTerminal,
								Undefined
							);
							
							If DeviceIdentifierET <> Undefined Then
								
								// ET device connection
								ResultET = EquipmentManagerClient.ConnectEquipmentByID(
									UUID,
									DeviceIdentifierET,
									ErrorDescription
								);
								
								If ResultET Then
									
									For Each OperationPayment IN Object.PaymentWithPaymentCards Do
										
										If OperationPayment.PaymentCanceled Then
											Continue;
										EndIf;
										
										AmountOfOperations       = OperationPayment.Amount;
										CardNumber          = OperationPayment.ChargeCardNo;
										OperationRefNumber = OperationPayment.RefNo;
										ETReceiptNo         = OperationPayment.ETReceiptNo;
										SlipCheckString      = "";
										
										InputParameters  = New Array();
										Output_Parameters = Undefined;
										
										InputParameters.Add(AmountOfOperations);
										InputParameters.Add(OperationRefNumber);
										InputParameters.Add(ETReceiptNo);
										
										// Executing the operation on POS terminal
										ResultET = EquipmentManagerClient.RunCommand(
											DeviceIdentifierET,
											"AuthorizeVoid",
											InputParameters,
											Output_Parameters
										);
										
										If Not ResultET Then
											
											MessageText = NStr("en='When operation execution there
		|was error: ""%ErrorDescription%"".
		|Cancellation by card has not been performed.';ru='При выполнении операции возникла ошибка:
		|""%ОписаниеОшибки%"".
		|Отмена по карте не была произведена.'"
											);
											MessageText = StrReplace(
												MessageText,
												"%ErrorDescription%",
												Output_Parameters[1]
											);
											CommonUseClientServer.MessageToUser(MessageText);
											
										Else
											
											If Not IsBlankString(Output_Parameters[0][1]) Then
												
												glPeripherals.Insert("LastSlipReceipt", Output_Parameters[0][1]);
												
											EndIf;
											
											CardNumber          = "";
											OperationRefNumber = "";
											ETReceiptNo         = "";
											SlipCheckString      = Output_Parameters[0][1];
											
											If Not IsBlankString(SlipCheckString) Then
												
												InputParameters  = New Array();
												InputParameters.Add(SlipCheckString);
												Output_Parameters = Undefined;
												
												ResultFR = EquipmentManagerClient.RunCommand(
													DeviceIdentifierFR,
													"PrintText",
													InputParameters,
													Output_Parameters
												);
												
											EndIf;
											
										EndIf;
										
										If ResultET AND Not ResultFR Then
											
											ErrorDescriptionFR = Output_Parameters[1];
											
											MessageText = NStr("en='When printing slip receipt
		|there was error: ""%ErrorDescription%"".
		|Operation by card has been cancelled.';ru='При печати слип-чека
		|возникла ошибка: ""%ОписаниеОшибки%"".
		|Операция по карте была отменена.'"
											);
											MessageText = StrReplace(
												MessageText,
												"%ErrorDescription%",
												ErrorDescriptionFR
											);
											CommonUseClientServer.MessageToUser(MessageText);
											
										ElsIf ResultET Then
											
											OperationPayment.PaymentCanceled = True;
											
										EndIf;
										
									EndDo;
									
									// ET device disconnect
									EquipmentManagerClient.DisableEquipmentById(
										UUID,
										DeviceIdentifierET
									);
									
								Else
									
									MessageText = NStr("en='When POS terminal connection there
		|was error: ""%ErrorDescription%"".
		|Operation by card has not been performed.';ru='При подключении эквайрингового
		|терминала произошла ошибка: ""%ОписаниеОшибки%"".
		|Операция по карте не была выполнена.'"
									);
									MessageText = StrReplace(
										MessageText,
										"%ErrorDescription%",
										ErrorDescription
									);
									CommonUseClientServer.MessageToUser(MessageText);
									
								EndIf;
								
							EndIf;
							
						EndIf;
						
						// Write the document for data loss prevention
						PostingResult = True;
						If Object.PaymentWithPaymentCards.Count() <> 0 Then
							
							PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
							
						EndIf;
						
						If (ResultET OR ETUseWithoutEquipmentConnection) AND PostingResult Then
							
							If Not CashCRUseWithoutEquipmentConnection Then
								
								// Prepare data
								InputParameters  = New Array;
								Output_Parameters = Undefined;
								
								SectionNumber = 1;
								
								// Preparation of the product table
								ProductsTable = New Array();
								
								For Each TSRow IN Object.Inventory Do
									
									VATRate = SmallBusinessReUse.GetVATRateValue(TSRow.VATRate);
									
									ProductsTableRow = New ValueList();
									ProductsTableRow.Add(String(TSRow.ProductsAndServices));
									                                                      //  1 - Description
									ProductsTableRow.Add("");                    //  2 - Barcode
									ProductsTableRow.Add("");                    //  3 - SKU
									ProductsTableRow.Add(SectionNumber);           //  4 - Department number
									ProductsTableRow.Add(TSRow.Price);         //  5 - Price for position without discount
									ProductsTableRow.Add(TSRow.Quantity);   //  6 - Quantity
									ProductsTableRow.Add("");                    //  7 - Discount/markup description
									ProductsTableRow.Add(0);                     //  8 - Amount of a discount/markup
									ProductsTableRow.Add(0);                     //  9 - Discount/markup percent
									ProductsTableRow.Add(TSRow.Amount);        // 10 - Position amount with discount
									ProductsTableRow.Add(0);                     // 11 - Tax number (1)
									ProductsTableRow.Add(TSRow.VATAmount);     // 12 - Tax amount (1)
									ProductsTableRow.Add(VATRate);             // 13 - Tax percent (1)
									ProductsTableRow.Add(0);                     // 14 - Tax number (2)
									ProductsTableRow.Add(0);                     // 15 - Tax amount (2)
									ProductsTableRow.Add(0);                     // 16 - Tax percent (2)
									ProductsTableRow.Add("");                    // 17 - Section name of commodity string formatting
									
									ProductsTable.Add(ProductsTableRow);
									
								EndDo;
								
								// Preparation of the payment table
             PaymentsTable = New Array();
								
								// Cash
								PaymentRow = New ValueList();
								PaymentRow.Add(0);
								PaymentRow.Add(Object.DocumentAmount - Object.PaymentWithPaymentCards.Total("Amount"));
								PaymentRow.Add("Payment by cash");
								PaymentRow.Add("");
								PaymentsTable.Add(PaymentRow);
								// Noncash
								PaymentRow = New ValueList();
								PaymentRow.Add(1);
								PaymentRow.Add(Object.PaymentWithPaymentCards.Total("Amount"));
								PaymentRow.Add("Group Cashless payment");
								PaymentRow.Add("");
								PaymentsTable.Add(PaymentRow);
								
								// Preparation of the common parameters table
								CommonParameters = New Array();
								CommonParameters.Add(1);                      //  1 - Receipt type
								CommonParameters.Add(True);                 //  2 - Fiscal receipt sign
								CommonParameters.Add(Undefined);           //  3 - Print on lining document
								CommonParameters.Add(Object.DocumentAmount);  //  4 - Amount by receipt without discounts/markups
								CommonParameters.Add(Object.DocumentAmount);  //  5 - Amount by receipt with accounting all discounts/markups
								CommonParameters.Add("");                     //  6 - Discount card number
								CommonParameters.Add("");                     //  7 - Header text
								CommonParameters.Add("");                     //  8 - Footer text
								CommonParameters.Add(0);                      //  9 - Session number (for receipt copy)
								CommonParameters.Add(0);                      // 10 - Receipt number (for receipt copy)
								CommonParameters.Add(0);                      // 11 - Document No (for receipt copy)
								CommonParameters.Add(0);                      // 12 - Document date (for receipt copy)
								CommonParameters.Add("");                     // 13 - Cashier name (for receipt copy)
								CommonParameters.Add("");                     // 14 - Cashier password
								CommonParameters.Add(0);                      // 15 - Template number
								CommonParameters.Add("");                     // 16 - Section name header format
								CommonParameters.Add("");                     // 17 - Section name cellar format
								
								InputParameters.Add(ProductsTable);
								InputParameters.Add(PaymentsTable);
								InputParameters.Add(CommonParameters);
								
								// Print receipt.
								Result = EquipmentManagerClient.RunCommand(
									DeviceIdentifierFR,
									"PrintReceipt",
									InputParameters,
									Output_Parameters
								);
								
							EndIf;
							
							If CashCRUseWithoutEquipmentConnection OR Result Then
								
								// Set the received value of receipt number to document attribute.
								If Not CashCRUseWithoutEquipmentConnection Then
									Object.ReceiptCRNumber = Output_Parameters[1];
								EndIf;
								
								Object.Date = CurrentDate();
								If Not ValueIsFilled(Object.ReceiptCRNumber) Then
									Object.ReceiptCRNumber = 1;
								EndIf;
								
								Modified = True;
								
								PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
								If PostingResult = True
								AND Not CashCRUseWithoutEquipmentConnection Then
									SetModeReadOnly();
								EndIf;
								
							Else
								
								MessageText = NStr("en='When printing a receipt, an error occurred.
		|Receipt is not printed on the fiscal register.
		|Additional
		|description: %AdditionalDetails%';ru='При печати чека произошла ошибка.
		|Чек не напечатан на фискальном регистраторе.
		|Дополнительное
		|описание: %ДополнительноеОписание%'"
								);
								
								MessageText = StrReplace(
									MessageText,
									"%AdditionalDetails%",
									Output_Parameters[1]
								);
								
								CommonUseClientServer.MessageToUser(MessageText);
								
							EndIf;
							
						EndIf;
						
						If Not CashCRUseWithoutEquipmentConnection Then
							
							// Disconnect FR
							EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifierFR);
							
						EndIf;
						
					Else
						
						MessageText = NStr("en='When fiscal registrar connection there
		|was error: ""%ErrorDescription%"".
		|Operation by card has not been performed.';ru='При подключении фискального регистратора произошла ошибка:
		|""%ОписаниеОшибки%"".
		|Операция по карте не была выполнена.'"
						);
						MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				EndIf;
				
			Else
				
				MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
				CommonUseClientServer.MessageToUser(MessageText);
				
			EndIf;
			
		Else
			
			// External equipment is not used
			Object.Date = CurrentDate();
			If Not ValueIsFilled(Object.ReceiptCRNumber) Then
				Object.ReceiptCRNumber = 1;
			EndIf;
			
			Modified = True;
			
			PostingResult = Write(New Structure("WriteMode", DocumentWriteMode.Posting));
			If PostingResult = True
			AND Not CashCRUseWithoutEquipmentConnection Then
				SetModeReadOnly();
			EndIf;
			
		EndIf;
		
	ElsIf ShowMessageBox Then
		ShowMessageBox(Undefined,NStr("en='Failed to post the document';ru='Не удалось выполнить проведение документа'"));
	EndIf;
	
	Notify("RefreshFormListDocumentsReceiptsCRReturn");
	
EndProcedure // IssueReceipt()

// Procedure is called when pressing the PrintReceipt command panel button.
//
&AtClient
Procedure IssueReceiptExecute()
	
	Cancel = False;
	
	ClearMessages();
	
	If Object.DeletionMark Then
		
		ErrorText = NStr("en='The document is marked for deletion.';ru='Документ помечен на удаление'");
		
		Message = New UserMessage;
		Message.Text = ErrorText;
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	Object.Date = CurrentDate();
	
	If Not Cancel AND CheckFilling() Then
		
		IssueReceipt();
		
	EndIf;
	
EndProcedure // IssueReceiptExecute()

// The procedure is called when clicking CancelPayment on the command panel.
//
&AtClient
Procedure CancelPayment(Command)
	
	DeviceIdentifierET = Undefined;
	DeviceIdentifierFR = Undefined;
	ErrorDescription            = "";
	
	//Check selected string in payment table by payment cards
	CurrentData = Items.PaymentWithPaymentCards.CurrentData;
	If CurrentData = Undefined Then
		CommonUseClientServer.MessageToUser(NStr("en='Select string of canceled payment card.';ru='Выберите строку отменяемой оплаты картой.'"));
		Return;
	EndIf;
	
	If CurrentData.PaymentCanceled Then
		CommonUseClientServer.MessageToUser(NStr("en='This payment is already cancelled.';ru='Данная оплата уже отменена.'"));
		Return;
	EndIf;
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		AmountOfOperations       = CurrentData.Amount;
		CardNumber          = CurrentData.ChargeCardNo;
		OperationRefNumber = CurrentData.RefNo;
		ETReceiptNo         = CurrentData.ETReceiptNo;
		SlipCheckString      = "";
		
		// Device selection ET
		DeviceIdentifierET = ?(
			ValueIsFilled(POSTerminal),
			POSTerminal,
			Undefined
		);
		
		If DeviceIdentifierET <> Undefined Then
			
			// Device selection FR
			DeviceIdentifierFR = ?(
				ValueIsFilled(FiscalRegister),
				FiscalRegister,
				Undefined
			);
			
			If DeviceIdentifierFR <> Undefined OR CashCRUseWithoutEquipmentConnection Then
				
				// ET device connection
				ResultET = EquipmentManagerClient.ConnectEquipmentByID(
					UUID,
					DeviceIdentifierET,
					ErrorDescription
				);
				
				If ResultET Then
					
					// FR device connection
					ResultFR = EquipmentManagerClient.ConnectEquipmentByID(
						UUID,
						DeviceIdentifierFR,
						ErrorDescription
					);
					
					If ResultFR OR CashCRUseWithoutEquipmentConnection Then
						
						InputParameters  = New Array();
						Output_Parameters = Undefined;
						
						InputParameters.Add(AmountOfOperations);
						InputParameters.Add(OperationRefNumber);
						InputParameters.Add(ETReceiptNo);
						
						// Executing the operation on POS terminal
						ResultET = EquipmentManagerClient.RunCommand(
							DeviceIdentifierET,
							"AuthorizeVoid",
							InputParameters,
							Output_Parameters
						);
						
						If ResultET Then
							
							CardNumber          = "";
							OperationRefNumber = "";
							ETReceiptNo         = "";
							SlipCheckString      = Output_Parameters[0][1];
							
							If Not IsBlankString(SlipCheckString) Then
								glPeripherals.Insert("LastSlipReceipt", SlipCheckString);
							EndIf;
							
							If Not IsBlankString(SlipCheckString) AND Not CashCRUseWithoutEquipmentConnection Then
								
								InputParameters = New Array();
								InputParameters.Add(SlipCheckString);
								Output_Parameters = Undefined;
								
								ResultFR = EquipmentManagerClient.RunCommand(
									DeviceIdentifierFR,
									"PrintText",
									InputParameters,
									Output_Parameters
								);
							EndIf;
							
						Else
							
							MessageText = NStr("en='When operation execution there
		|was error: ""%ErrorDescription%"".
		|Cancellation by card has not been performed.';ru='При выполнении операции возникла ошибка:
		|""%ОписаниеОшибки%"".
		|Отмена по карте не была произведена.'"
							);
							
							MessageText = StrReplace(
								MessageText,
								"%ErrorDescription%",
								Output_Parameters[1]
							);
							
							CommonUseClientServer.MessageToUser(MessageText);
							
						EndIf;
						
						If ResultET AND (NOT ResultFR AND Not CashCRUseWithoutEquipmentConnection) Then
							
							ErrorDescriptionFR = Output_Parameters[1];
							
							MessageText = NStr("en='When printing slip receipt
		|there was error: ""%ErrorDescription%"".
		|Operation by card has been cancelled.';ru='При печати слип-чека
		|возникла ошибка: ""%ОписаниеОшибки%"".
		|Операция по карте была отменена.'"
							);
							
							MessageText = StrReplace(
								MessageText,
								"%ErrorDescription%",
								ErrorDescriptionFR
							);
							
							CommonUseClientServer.MessageToUser(MessageText);
							
						ElsIf ResultET Then
							
							CurrentData.PaymentCanceled = True;
							
						EndIf;
						
						// FR device disconnect
						EquipmentManagerClient.DisableEquipmentById(
							UUID,
							DeviceIdentifierFR
						);
						// ET device disconnect
						EquipmentManagerClient.DisableEquipmentById(
							UUID,
							DeviceIdentifierET
						);
						
					Else
						
						MessageText = NStr("en='When fiscal registrar connection there
		|was error: ""%ErrorDescription%"".
		|Operation by card has not been performed.';ru='При подключении фискального регистратора произошла ошибка:
		|""%ОписаниеОшибки%"".
		|Операция по карте не была выполнена.'"
						);
						MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
						CommonUseClientServer.MessageToUser(MessageText);
						
					EndIf;
					
				Else
					
					MessageText = NStr("en='When POS terminal connection there
		|was error: ""%ErrorDescription%"".
		|Operation by card has not been performed.';ru='При подключении эквайрингового
		|терминала произошла ошибка: ""%ОписаниеОшибки%"".
		|Операция по карте не была выполнена.'"
					);
					MessageText = StrReplace(
						MessageText,
						"%ErrorDescription%",
						ErrorDescription
					);
					CommonUseClientServer.MessageToUser(MessageText);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		MessageText = NStr("en='First, you need to select the workplace of the current session peripherals.';ru='Предварительно необходимо выбрать рабочее место внешнего оборудования текущего сеанса.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF HEADER ATTRIBUTES

// Procedure - event handler OnChange field CashRegister on server.
//
&AtServer
Procedure CashCROnChangeAtServer()
	
	StatusCashCRSession = Documents.RetailReport.GetCashCRSessionAttributesToDate(Object.CashCR, ?(ValueIsFilled(Object.Ref), Object.Date, CurrentDate()));
	
	If ValueIsFilled(StatusCashCRSession.CashCRSessionStatus) Then
		
		FillPropertyValues(Object, StatusCashCRSession);
		
	EndIf;
	
	Counterparty = SmallBusinessServer.GetCompany(Object.Company);
	
	Object.POSTerminal = Catalogs.POSTerminals.GetPOSTerminalByDefault(Object.CashCR);
	
	GetRefsToEquipment();
	
	Object.Department = Object.CashCR.Department;
	
	If Not ValueIsFilled(Object.Department) Then
		
		User = Users.CurrentUser();
		SettingValue = SmallBusinessReUse.GetValueByDefaultUser(User, "MainDepartment");
		MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.StructuralUnits.MainDepartment);
		Object.Department = MainDepartment;
		
	EndIf;
	
	FillVATRateByCompanyVATTaxation();
	
	CashCRUseWithoutEquipmentConnection = Object.CashCR.UseWithoutEquipmentConnection;
	Items.InventoryPrice.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.StructuralUnitsTypes.Warehouse;
	Items.InventoryAmount.ReadOnly = Object.StructuralUnit.StructuralUnitType <> Enums.StructuralUnitsTypes.Warehouse;
	
EndProcedure // CashCROnChangeAtServer()

// Procedure - event handler OnChange field CashCR.
//
&AtClient
Procedure CashCROnChange(Item)
	
	CashCROnChangeAtServer();
	SmallBusinessClient.RefillTabularSectionPricesByPriceKind(ThisForm, "Inventory", True);
	RecalculateDocumentAtClient();
	
EndProcedure // CashCROnChange()

// Procedure - event handler OnChange field POSTerminal on server.
//
&AtServer
Procedure POSTerminalOnChangeAtServer()
	
	GetRefsToEquipment();
	GetChoiceListOfPaymentCardKinds();
	ETUseWithoutEquipmentConnection = Object.POSTerminal.UseWithoutEquipmentConnection;
	Items.PaymentWithPaymentCardsCancelPayment.Visible = Not ETUseWithoutEquipmentConnection;
	
EndProcedure // POSTerminalOnChangeAtServer()

// Procedure - OnChange event handler of the POSTerminal field.
//
&AtClient
Procedure POSTerminalOnChange(Item)
	
	POSTerminalOnChangeAtServer();
	
EndProcedure // POSTerminalOnChange()

// Procedure - event handler OnChange of the Date input field.
// IN procedure situation is determined when date change document is
// into document numbering another period and in this case
// assigns to the document new unique number.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
	// AutomaticDiscounts
	DocumentDateChangedManually = True;
	ClearCheckboxDiscountsAreCalculatedClient("DateOnChange");
	
EndProcedure // DateOnChange()

// Procedure - event handler OnChange field Company.
//
&AtClient
Procedure CompanyOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure // CompanyOnChange()

// Procedure - OnChange event handler of the StructuralUnit field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	FillVATRateByCompanyVATTaxation();
	
EndProcedure // StructuralUnitOnChange()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the ProductsAndServices input field.
//
&AtClient
Procedure InventoryProductsAndServicesOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("ProductsAndServices", TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	StructureData.Insert("VATTaxation", Object.VATTaxation);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 Object.Date);
		StructureData.Insert("DocumentCurrency",  Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		StructureData.Insert("Content", "");
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
		
	EndIf;
	
	// DiscountCards
	StructureData.Insert("DiscountCard", Object.DiscountCard);
	StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	// End DiscountCards
	
	StructureData = GetDataProductsAndServicesOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
	TabularSectionRow.VATRate = StructureData.VATRate;
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryProductsAndServicesOnChange()

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
		
	StructureData = New Structure;
	StructureData.Insert("ProductsAndServices",	 TabularSectionRow.ProductsAndServices);
	StructureData.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate",	 	Object.Date);
		StructureData.Insert("DocumentCurrency",	 	Object.DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT", 	Object.AmountIncludesVAT);
		
		StructureData.Insert("VATRate", 			TabularSectionRow.VATRate);
		StructureData.Insert("Price",			 	TabularSectionRow.Price);
		
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
	EndIf;
				
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Price = StructureData.Price;
	TabularSectionRow.Content = StructureData.Content;
			
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryCharacteristicOnChange()

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryQuantityOnChange()

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
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

// Procedure - event handler OnChange of the Price input field.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryPriceOnChange()

// Procedure - event handler OnChange of the DiscountMarkupPercent input field.
//
&AtClient
Procedure InventoryDiscountMarkupPercentOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure // InventoryDiscountMarkupPercentOnChange()

// Procedure - OnChange event handler of the DiscountAmount input field.
//
&AtClient
Procedure InventoryOfDiscountAmountIfYouChange(Item)
	
	CalculateDiscountPercent();
	
EndProcedure // InventoryOfDiscountAmountIfYouChange()

// Procedure - event handler OnChange of the Amount input field.
//
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
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	TabularSectionRow.DiscountAmount = TabularSectionRow.Quantity * TabularSectionRow.Price - TabularSectionRow.Amount;
	
	// AutomaticDiscounts.
	AutomaticDiscountsRecalculationIsRequired = ClearCheckboxDiscountsAreCalculatedClient("CalculateAmountInTabularSectionLine", ThisObject.CurrentItem.CurrentItem.Name);
		
	TabularSectionRow.AutomaticDiscountsPercent = 0;
	TabularSectionRow.AutomaticDiscountAmount = 0;
	TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	// End AutomaticDiscounts
	
EndProcedure // InventoryAmountOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATRateOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	CalculateVATSUM(TabularSectionRow);
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
EndProcedure // InventoryVATRateOnChange()

// Procedure - event handler OnChange of the VATRate input field.
//
&AtClient
Procedure InventoryVATAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(Object.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);	
	
EndProcedure // InventoryVATAmountOnChange()

&AtClient
// Procedure - event handler OnEditEnd of the Inventory list row.
//
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure

// Procedure - event handler AfterDeletion of the Inventory list row.
//
&AtClient
Procedure InventoryAfterDeleteRow(Item)
	
	RecalculateDocumentAtClient();
	
	// AutomaticDiscounts.
	ClearCheckboxDiscountsAreCalculatedClient("DeleteRow");
	
EndProcedure // InventoryAfterDeletion()

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure // CommentOnChange()

&AtClient
Procedure Attachable_SetPictureForComment()
	
	SmallBusinessClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PAYMENT WITH PAYMENT CARDS TS ATTRIBUTES

// Procedure - OnEditEnd event handler of the PaymentWithPaymentCards list string.
//
&AtClient
Procedure PaymentWithPaymentCardsOnEditEnd(Item, NewRow, CancelEdit)
	
	RecalculateDocumentAtClient();
	
EndProcedure // PaymentWithPaymentCardsOnEditEnd()

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
	
	RecalculateDocumentAtClient();
	
EndProcedure

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
Procedure CalculateDiscountsMarkupsByBaseDocumentServer()

	DiscountsMarkupsServer.FillLinkingKeysInSpreadsheetPartProducts(Object, "Inventory");
	
	ReceiptsCRArray = New Array;
	ReceiptsCRArray.Add(Object.ReceiptCR);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS AutomaticDiscountAmount,
	|	CASE
	|		WHEN ReceiptCRInventory.ProductsAndServices.ProductsAndServicesType = VALUE(Enum.ProductsAndServicesTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsAndServicesTypeInventory,
	|	CASE
	|		WHEN VALUETYPE(ReceiptCRInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE ReceiptCRInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	ReceiptCRInventory.ProductsAndServices,
	|	ReceiptCRInventory.Characteristic,
	|	ReceiptCRInventory.MeasurementUnit,
	|	ReceiptCRInventory.Quantity
	|FROM
	|	Document.ReceiptCR.DiscountsMarkups AS DiscountsMarkups
	|		INNER JOIN Document.ReceiptCR.Inventory AS ReceiptCRInventory
	|		ON DiscountsMarkups.Ref = ReceiptCRInventory.Ref
	|			AND DiscountsMarkups.ConnectionKey = ReceiptCRInventory.ConnectionKey
	|WHERE
	|	DiscountsMarkups.Ref IN(&ReceiptsCRArray)";
	
	Query.SetParameter("ReceiptsCRArray", ReceiptsCRArray);
	
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

// Procedure - "CalculateDiscountsMarkups" command handler.
//
&AtServer
Procedure CalculateDiscountsMarkupsOnServer(ParameterStructure)
	
	CalculateDiscountsMarkupsByBaseDocumentServer();
	ParameterStructure.Insert("ApplyToObject", True);
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
	
	If (Item.CurrentItem = Items.InventoryAutomaticDiscountPercent OR Item.CurrentItem = Items.InventoryAutomaticDiscountAmount)
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
	
EndProcedure

&AtClient
Function ClearCheckboxDiscountsAreCalculatedClient(Action, SPColumn = "")
	
	RecalculationIsRequired = False;
	If UseAutomaticDiscounts AND Object.Inventory.Count() > 0 AND (Object.DiscountsAreCalculated OR InstalledGrayColor) Then
		RecalculationIsRequired = ResetFlagDiscountsAreCalculated(Action, SPColumn);
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
Procedure AppliedDiscounts(Command)
	
	If Object.Ref.IsEmpty() Then
		QuestionText = "Data is still not recorded.
		|Transfer to ""Applied discounts"" is possible only after data is written.
		|Data will be written.";
		NotifyDescription = New NotifyDescription("AppliedDiscountsCompletion", ThisObject);
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.OKCancel);
	Else
		FormParameters = New Structure("DocumentRef", Object.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	EndIf;
	
EndProcedure

&AtClient
Procedure AppliedDiscountsCompletion(Result, Parameters) Export
	
	If Result <> DialogReturnCode.OK Then
		Return;
	EndIf;

	If Write() Then
		FormParameters = New Structure("DocumentRef", Object.Ref);
		OpenForm("Report.DiscountsAppliedInDocument.Form.ReportForm", FormParameters, ThisObject, UUID);
	EndIf;
	
EndProcedure // AppliedDiscountsCompletion()

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// AutomaticDiscounts
	If RefreshImageAutoDiscountsAfterWrite Then
		Items.InventoryCalculateDiscountsMarkups.Picture = PictureLib.Refresh;
		RefreshImageAutoDiscountsAfterWrite = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion














