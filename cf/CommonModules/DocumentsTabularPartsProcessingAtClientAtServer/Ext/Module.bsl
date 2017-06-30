Procedure ProceedTabularPartRow(Row, Val ActionsArray, Form = Undefined) Export
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	For Each Action In ActionsArray Do
		
		// Jack 29.05.2017
		//If Action.Name = "SetSalesUnitOfMeasure" Then
		//	SetSalesUnitOfMeasure(Row, Action.Parameters);
		//EndIf;	
		//
		//If Action.Name = "SetVATRate" Then
		//	SetVATRate(Row, Action.Parameters);
		//EndIf;	
		
		If Action.Name = "SetRowCurrency" Then
			SetRowCurrency(Row, Action.Parameters);
		EndIf;	
		
		// Jack 29.05.2017	
		//If Action.Name = "SetRowValuesForOpeningBalanceDebtsWithEmployees" Then
		//	SetRowValuesForOpeningBalanceDebtsWithEmployees(Row, Action.Parameters);
		//EndIf;	
		//
		//If Action.Name = "SetRowValuesForOpeningBalanceDebtsWithPartners" Then
		//	SetRowValuesForOpeningBalanceDebtsWithPartners(Row, Action.Parameters);
		//EndIf;	
		//				
		//If Action.Name = "SetSalesPrice" AND Form <> Undefined Then
		//	SetSalesPrice(Row, Action.Parameters, Form);
		//EndIf;	
		//
		//If Action.Name = "CalculatePriceByDiscountAndInitialPrice" Then
		//	CalculatePriceByDiscountAndInitialPrice(Row, Action.Parameters);
		//EndIf;	
		//
		//If Action.Name = "CalculatePriceByNetAmountAndQuantity" Then
		//	CalculatePriceByNetAmountAndQuantity(Row, Action.Parameters);
		//EndIf;	

		//If Action.Name = "CalculatePriceByGrossAmountAndQuantity" Then
		//	CalculatePriceByGrossAmountAndQuantity(Row, Action.Parameters);
		//EndIf;	
		//
		//If Action.Name = "CalculateDiscountByPriceAndInitialPrice" Then
		//	CalculateDiscountByPriceAndInitialPrice(Row, Action.Parameters);
		//EndIf;	

		//If Action.Name = "CalculateRowAmountByPriceAndQuantity" Then
		//	CalculateRowAmountByPriceAndQuantity(Row, Action.Parameters);
		//EndIf;	
		
		//If Action.Name = "CalculateRowNetAmount" Then
		//	CalculateRowNetAmount(Row, Action.Parameters);
		//EndIf;	
		
		//If Action.Name = "CalculateRowNetAmountByAmount" Then
		//	CalculateRowNetAmountByAmount(Row, Action.Parameters);
		//EndIf;	

		//If Action.Name = "CalculateRowGrossAmount" Then
		//	CalculateRowGrossAmount(Row, Action.Parameters);
		//EndIf;
		//
		//If Action.Name = "CalculateRowGrossAmountByAmount" Then
		//	CalculateRowGrossAmountByAmount(Row, Action.Parameters);
		//EndIf;	
		
		//If Action.Name = "CalculateRowVAT" Then
		//	CalculateRowVAT(Row, Action.Parameters);
		//EndIf;	
		//
		//If Action.Name = "CalculateRowVATByAmount" Then
		//	CalculateRowVATByAmount(Row, Action.Parameters);
		//EndIf;	

		//If Action.Name = "CalculateRowAmount" Then
		//	CalculateRowAmount(Row, Action.Parameters);
		//EndIf;	
		//
		//If Action.Name = "CalculateRowAmountNationalByAmount" Then
		//	CalculateRowAmountNationalByAmount(Row, Action.Parameters);
		//EndIf;	
		
		//If Action.Name = "FillCurrentEmployee" Then
		//	FillCurrentEmployee(Row, Action.Parameters);
		//EndIf;
	EndDo;	
		
EndProcedure	

// Jack 29.05.2017
//Procedure SetSalesUnitOfMeasure(Row, Val ParametersStructure)
//		
//	Row.UnitOfMeasure = Row.Item.SalesUnitOfMeasure;
//	
//EndProcedure	

//Procedure SetVATRate(Row,  Val ParametersStructure)
//	
//	Row.VATRate      = TaxesAtClientAtServer.GetVATRate(ParametersStructure.Company, ParametersStructure.PartnerAccountingGroup, ParametersStructure.ItemAccountingGroup);
//	
//EndProcedure	

Procedure SetRowCurrency(Row,  Val ParametersStructure)
	If ParametersStructure.CurrencySourceColumn <> Undefined Then
		If ValueIsNotFilled(Row.Currency) Then
			Row.Currency      = Row[ParametersStructure.CurrencySourceColumn].Currency;				
			Row.ExchangeRate      = CommonAtServer.GetExchangeRate(Row.Currency, ParametersStructure.Date);			
		EndIf;
	EndIf;
	
EndProcedure	

// Jack 29.05.2017
//Procedure SetRowValuesForOpeningBalanceDebtsWithEmployees(Row,  Val ParametersStructure)
//	If ValueIsNotFilled(Row.Employee) And ValueIsFilled(Row.Document) Then
//		Row.Employee = Row.Document.Employee;
//	EndIf;
//	
//	If ValueIsNotFilled(Row.Currency) And ValueIsFilled(Row.Document) Then
//		
//		If CommonAtServer.IsDocumentAttribute("SettlementCurrency", Row.Document.Metadata()) Then
//			Row.Currency = Row.Document.SettlementCurrency;
//		ElsIf CommonAtServer.IsDocumentAttribute("RecordsCurrency", Row.Document.Metadata()) Then
//			Row.Currency = Row.Document.RecordsCurrency;
//		ElsIf CommonAtServer.IsDocumentAttribute("Currency", Row.Document.Metadata()) Then
//			Row.Currency = Row.Document.Currency;
//		EndIf;
//		
//	EndIf;
//	
//	If ValueIsNotFilled(Row.ExchangeRate) And ValueIsFilled(Row.Document) Then
//		
//		If CommonAtServer.IsDocumentAttribute("SettlementExchangeRate", Row.Document.Metadata()) Then
//			Row.ExchangeRate = Row.Document.SettlementExchangeRate;
//		ElsIf CommonAtServer.IsDocumentAttribute("RecordsExchangeRate", Row.Document.Metadata()) Then
//			Row.ExchangeRate = Row.Document.RecordsExchangeRate;
//		ElsIf CommonAtServer.IsDocumentAttribute("ExchangeRate", Row.Document.Metadata()) Then
//			Row.ExchangeRate = Row.Document.ExchangeRate;	
//		EndIf;
//		
//	EndIf;

//EndProcedure	

//Procedure SetRowValuesForOpeningBalanceDebtsWithPartners(Row,  Val ParametersStructure)
//	
//	If ValueIsNotFilled(Row.Partner) And ValueIsFilled(Row.Document) Then
//			
//		If CommonAtServer.IsDocumentAttribute("Partner", Row.Document.Metadata()) Then
//			Row.Partner = Row.Document.Partner;
//		ElsIf CommonAtServer.IsDocumentAttribute("Customer", Row.Document.Metadata()) Then
//			Row.Partner = Row.Document.Customer;
//		ElsIf CommonAtServer.IsDocumentAttribute("Supplier", Row.Document.Metadata()) Then
//			Row.Partner = Row.Document.Supplier;
//		EndIf;
//			
//	EndIf;
//		
//	If ValueIsNotFilled(Row.Currency) And ValueIsFilled(Row.Document) Then
//			
//		If CommonAtServer.IsDocumentAttribute("SettlementCurrency", Row.Document.Metadata()) Then
//			Row.Currency = Row.Document.SettlementCurrency;
//		ElsIf CommonAtServer.IsDocumentAttribute("RecordsCurrency", Row.Document.Metadata()) Then
//			Row.Currency = Row.Document.Currency;
//		ElsIf CommonAtServer.IsDocumentAttribute("Currency", Row.Document.Metadata()) Then
//			Row.Currency = Row.Document.Currency;
//		EndIf;
//			
//	EndIf;
//		
//	If ValueIsNotFilled(Row.ExchangeRate) And ValueIsFilled(Row.Document) Then
//			
//		If CommonAtServer.IsDocumentAttribute("SettlementExchangeRate", Row.Document.Metadata()) Then
//			Row.ExchangeRate = Row.Document.SettlementExchangeRate;
//		ElsIf CommonAtServer.IsDocumentAttribute("RecordsExchangeRate", Row.Document.Metadata()) Then
//			Row.ExchangeRate = Row.Document.RecordsExchangeRate;
//		ElsIf CommonAtServer.IsDocumentAttribute("ExchangeRate", Row.Document.Metadata()) Then
//			Row.ExchangeRate = Row.Document.ExchangeRate;	
//		EndIf;
//			
//	EndIf;
//	
//EndProcedure	

Procedure CalculateRowAmountNationalByAmount(Row,  Val ParametersStructure)
	
	Row.AmountNational = CommonAtServer.GetNationalAmount(Row.Amount,Row.Currency,Row.ExchangeRate);
				
EndProcedure	

// Jack 29.05.2017
//Procedure SetSalesPrice(Row,  Val ParametersStructure, Form)
//	If TypeOf(Form) = Type("ManagedForm") Then
//		ObjectMetadataName = Form.ObjectMetadataName;
//	Else
//		ObjectMetadataName = Form.Ref.Metadata().Name;
//	EndIf;
//	If CommonAtServer.NeedSetSalesPrice(ObjectMetadataName) Then
//		PricesStructure = PricesAndDiscountsAtServer.GetCustomersPricesStructure(ParametersStructure.Object.Date, ParametersStructure.Object.PriceType, Row.Item, ParametersStructure.Object.Currency, Undefined, Row.Quantity, Row.UnitOfMeasure, ParametersStructure.Object.AmountType, Row.VATRate, ParametersStructure.Object.Customer, ParametersStructure.Object.DiscountGroup,ParametersStructure.Object);
//		Row.PricePromotion = PricesStructure.PricePromotion; 
//		Row.InitialPrice = PricesStructure.InitialPrice;
//		// checking if new price after discount is the same as in the row
//		TmpPrice = PricesAndDiscountsAtClientAtServer.GetPriceOnDiscountPercentageChange(Row.InitialPrice,PricesStructure.Price,Row.Discount);
//		If TmpPrice <> Row.Price Then
//			Row.Discount = PricesStructure.Discount; 
//			Row.Price  = PricesStructure.Price;	
//		EndIf;	
//	EndIf;
//EndProcedure	

//Procedure CalculateRowAmountByPriceAndQuantity(Row,  Val ParametersStructure)
//	
//	Row.Amount = GetItemsLinesRowAmount(Row.Price, Row.Quantity);
//	
//EndProcedure	

//Procedure CalculateRowVATByAmount(Row,  Val ParametersStructure)
//	
//	Row.VAT = GetItemsLinesRowVATAmount(Row.Amount, Row.VATRate, ParametersStructure.AmountType);
//	
//EndProcedure	

//Procedure CalculateRowNetAmountByAmount(Row,  Val ParametersStructure)
//	
//	Row.NetAmount = GetNetAmount(Row.Amount, Row.VAT, ParametersStructure.AmountType);
//	
//EndProcedure	

//Procedure CalculateRowAmount(Row,  Val ParametersStructure)
//	
//	If ParametersStructure.AmountType = PredefinedValue("Enum.NetGross.Net") Then
//		Row.Amount = Row.NetAmount;
//	ElsIf ParametersStructure.AmountType = PredefinedValue("Enum.NetGross.Gross") Then	
//		Row.Amount = Row.GrossAmount;
//	Else
//		Row.Amount = 0;
//	EndIf;	
//	
//EndProcedure	

//Procedure CalculateRowVAT(Row,  Val ParametersStructure)
//	
//	If ParametersStructure.AmountType = PredefinedValue("Enum.NetGross.Net") Then
//		Row.VAT = GetItemsLinesRowVATAmount(Row.NetAmount, Row.VATRate, ParametersStructure.AmountType);
//	ElsIf ParametersStructure.AmountType = PredefinedValue("Enum.NetGross.Gross") Then
//		Row.VAT = GetItemsLinesRowVATAmount(Row.GrossAmount, Row.VATRate, ParametersStructure.AmountType);
//	Else	
//		Row.VAT = 0;
//	EndIf;	
//		
//EndProcedure

// Jack 29.05.2017
//Procedure CalculatePriceByNetAmountAndQuantity(Row,  Val ParametersStructure)
//	
//	If ParametersStructure.AmountType = PredefinedValue("Enum.NetGross.Net") Then
//		Row.Price = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowPrice(Row.NetAmount, Row.Quantity, Row.Price);
//	Else	
//		TmpVAT = GetItemsLinesRowVATAmount(Row.NetAmount, Row.VATRate, PredefinedValue("Enum.NetGross.Net"));
//		Row.Price = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowPrice(GetGrossAmount(Row.NetAmount, TmpVAT, PredefinedValue("Enum.NetGross.Net")), Row.Quantity, Row.Price);
//	EndIf;	
//	
//EndProcedure	

//Procedure CalculatePriceByGrossAmountAndQuantity(Row,  Val ParametersStructure)
//	
//	If ParametersStructure.AmountType = PredefinedValue("Enum.NetGross.Gross") Then
//		Row.Price = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowPrice(Row.GrossAmount, Row.Quantity, Row.Price);
//	Else	
//		TmpVAT = GetItemsLinesRowVATAmount(Row.GrossAmount, Row.VATRate, PredefinedValue("Enum.NetGross.Gross"));
//		Row.Price = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowPrice(GetNetAmount(Row.GrossAmount, TmpVAT, PredefinedValue("Enum.NetGross.Gross")), Row.Quantity, Row.Price);
//	EndIf;	
//		
//EndProcedure	

//Procedure CalculateRowNetAmount(Row,  Val ParametersStructure)
//	
//	Row.NetAmount = GetNetAmount(Row.Amount, Row.VAT, ParametersStructure.AmountType);
//	
//EndProcedure

//Procedure CalculateRowGrossAmount(Row,  Val ParametersStructure)
//	
//	Row.GrossAmount = GetGrossAmount(Row.NetAmount, Row.VAT, PredefinedValue("Enum.NetGross.Net"));
//	
//EndProcedure

//Procedure CalculateRowGrossAmountByAmount(Row,  Val ParametersStructure)
//	
//	Row.GrossAmount = GetGrossAmount(Row.Amount, Row.VAT, ParametersStructure.AmountType);
//	
//EndProcedure

// Jack 29.05.2017
//Procedure CalculateDiscountByPriceAndInitialPrice(Row,  Val ParametersStructure)
//	
//	Row.Discount = PricesAndDiscountsAtClientAtServer.GetDiscountPercentageOnPriceChange(Row.InitialPrice,Row.Price);
//	
//EndProcedure

//Procedure CalculatePriceByDiscountAndInitialPrice(Row,  Val ParametersStructure)
//	
//	Row.Price = PricesAndDiscountsAtClientAtServer.GetPriceOnDiscountPercentageChange(Row.InitialPrice,Row.Price,Row.Discount);
//	
//EndProcedure

//Procedure FillCurrentEmployee(Row,  Val ParametersStructure)
//	Row.Employee = ParametersStructure.CurrentEmployee;	
//EndProcedure

//Function GetItemsLinesRowAmount(Val Price, Val Quantity) Export 
//	
//	Return Price*Quantity;
//	
//EndFunction

Function GetItemsLinesRowVATAmount(Val Amount, Val VATRate, Val AmountType) Export 
	
	#If Client Then
	VATRatePercentage = ObjectsExtensionsAtServer.GetAttributeFromRef(VATRate,"Percentage");
	#Else
	VATRatePercentage = VATRate.Percentage;
	#EndIf
	Return Amount/(100 + (VATRatePercentage*?(AmountType = PredefinedValue("Enum.NetGross.Gross"), 1,0)))*VATRatePercentage;
	
EndFunction

// Jack 29.05.2017
//Function GetItemsLinesRowPrice(Val Amount, Val Quantity, Val OldPrice = 0) Export 
//	
//	If OldPrice = 0 And Quantity <> 0 Then
//		
//		Return Amount / Quantity;
//		
//	Else
//		
//		Return OldPrice;
//		
//	EndIf;
//	
//EndFunction

//Function CalculateItemsLinesRowAmounts(ItemsLinesRow, Val AmountType) Export
//	
//	ItemsLinesRow.Amount = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowAmount(ItemsLinesRow.Price, ItemsLinesRow.Quantity);
//	ItemsLinesRow.VAT    = DocumentsTabularPartsProcessingAtClientAtServer.GetItemsLinesRowVATAmount(ItemsLinesRow.Amount, ItemsLinesRow.VATRate, AmountType);
//	
//	ItemsLinesRow.GrossAmount = DocumentsTabularPartsProcessingAtClientAtServer.GetGrossAmount(ItemsLinesRow.Amount, ItemsLinesRow.VAT, AmountType);
//	ItemsLinesRow.NetAmount = DocumentsTabularPartsProcessingAtClientAtServer.GetNetAmount(ItemsLinesRow.Amount, ItemsLinesRow.VAT, AmountType);	
//	
//EndFunction	

//Function GetGrossAmount(Val Amount, Val VAT, Val AmountType) Export
//	
//	Return Amount + ?(AmountType = PredefinedValue("Enum.NetGross.Gross"), 0, VAT);
//	
//EndFunction // GetGrossAmount()

//Function GetNetAmount(Val Amount, Val VAT, Val AmountType) Export
//	
//	Return Amount - ?(AmountType = PredefinedValue("Enum.NetGross.Gross"), VAT, 0);
//	
//EndFunction // GetNetAmount()

