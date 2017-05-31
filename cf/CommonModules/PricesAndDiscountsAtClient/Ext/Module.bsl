Function SetDocumentAmountOrDiscountsManagementAtClient(Val ObjectAddress,Val TabularPartName,Val TabularPartType,Val DocumentDiscountType, Owner = Undefined) Export

	ParametersStructure = New Structure("AdressDocObject, TabularPartType, TabularPartName", ObjectAddress, TabularPartType, TabularPartName);
	FormName = "";
	If DocumentDiscountType = PredefinedValue("Enum.DocumentDiscountType.ManageDiscounts") Then
		FormName = "DataProcessor.SetDocumentDiscount.Form.DiscountManagementForm";
	ElsIf DocumentDiscountType = PredefinedValue("Enum.DocumentDiscountType.SetDocumentAmount") Then	
		FormName = "DataProcessor.SetDocumentDiscount.Form.SetNewDocumentAmountForm";
	EndIf;
	
	If NOT IsBlankString(FormName) Then
		
		OpenFormModal(FormName, ParametersStructure,Owner);
		
	EndIf;	
	
EndFunction

Function RecalculatePriceAndDiscounts(Val ObjectAddress,Val PreviousValueStructure,Val ValueStructure,Val PartnerChanged = False,Val TabularPartStructure,Val ReturnStructure = Undefined,Owner,AdditionalProperties=Undefined) Export
	
	ParametersStructure = New Structure("AdressDocObject, PreviousValueStructure, ValueStructure, PartnerChanged, TabularPartStructure, AdditionalProperties, ReturnStructure",ObjectAddress,PreviousValueStructure,ValueStructure,PartnerChanged, TabularPartStructure, AdditionalProperties, ReturnStructure);
	
	ReturnCode = OpenFormModal("DataProcessor.PriceAndDiscountsRecalculation.Form.Form",ParametersStructure,Owner);
	
	Return ReturnCode;
		
EndFunction	

Function GetLabelsStructureForPriceAndDiscountAttributes(PriceAndDiscountAttributesSet,ShowCurrency = True,ShowDiscountGroup = True,ShowPriceType = True,ShowAmountType = True,ShowNBPTable = False) Export
	#If ThickClientOrdinaryApplication Then
		NationalCurrency = Constants.NationalCurrency.Get();
	#Else	
		NationalCurrency = ApplicationParameters.NationalCurrency;
	#EndIf
	If ValueIsNotFilled(PriceAndDiscountAttributesSet.Currency) 
		OR PriceAndDiscountAttributesSet.Currency = NationalCurrency
		OR PriceAndDiscountAttributesSet.ExchangeRate = Undefined Then
		CurrencyTextWithoutHeader = String(PriceAndDiscountAttributesSet.Currency);
	Else	
		CurrencyTextWithoutHeader = AlertsAtClient.ParametrizeString("%Currency(1 %Currency:%ExchangeRate %NationalCurrency)",New Structure("Currency, NationalCurrency, ExchangeRate",PriceAndDiscountAttributesSet.Currency,NationalCurrency,PriceAndDiscountAttributesSet.ExchangeRate));
		If ShowNBPTable Then
			CurrencyTextWithoutHeader = AlertsAtClient.ParametrizeString(Nstr("en='%P1 %P2 from %P3';pl='%P1 %P2 z dnia %P3';ru='%P1 %P2 от %P3'"),New Structure("P1, P2, P3",CurrencyTextWithoutHeader,PriceAndDiscountAttributesSet.NBPTableNumber,Format(PriceAndDiscountAttributesSet.ExchangeRateDate,"DLF=D; DE=")));
		EndIf;	
	EndIf;
	
	CurrencyText = AlertsAtClient.ParametrizeString(Nstr("en='Currency: %P1';pl='Waluta: %P1';ru='Валюта: %P1'"),New Structure("P1",CurrencyTextWithoutHeader));
	
	DiscountGroupTextWithoutHeader = String(PriceAndDiscountAttributesSet.DiscountGroup);
	DiscountGroupText = AlertsAtClient.ParametrizeString(Nstr("en='Discount group: %DiscountGroup';pl='Grupa rabatu: %DiscountGroup';ru='Группа скидок: %DiscountGroup'"),New Structure("DiscountGroup",DiscountGroupTextWithoutHeader));
	PriceTypeTextWithoutHeader = String(PriceAndDiscountAttributesSet.PriceType);
	PriceTypeText = AlertsAtClient.ParametrizeString(Nstr("en='Price type: %PriceType';pl='Typ ceny: %PriceType';ru='Тип цены: %PriceType'"),New Structure("PriceType",PriceTypeTextWithoutHeader));
	AmountTypeTextWithoutHeader = String(PriceAndDiscountAttributesSet.AmountType);
	AmountTypeText = AlertsAtClient.ParametrizeString(Nstr("en='Amount type: %AmountType';pl='Typ kwot: %AmountType';ru='Тип суммы: %AmountType'"),New Structure("AmountType",AmountTypeTextWithoutHeader));
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("CurrencyTextWithoutHeader",CurrencyTextWithoutHeader);
	ReturnStructure.Insert("CurrencyText",CurrencyText);
	ReturnStructure.Insert("DiscountGroupTextWithoutHeader",DiscountGroupTextWithoutHeader);
	ReturnStructure.Insert("DiscountGroupText",DiscountGroupText);
	ReturnStructure.Insert("AmountTypeTextWithoutHeader",AmountTypeTextWithoutHeader);
	ReturnStructure.Insert("AmountTypeText",AmountTypeText);
	ReturnStructure.Insert("PriceTypeTextWithoutHeader",PriceTypeTextWithoutHeader);
	ReturnStructure.Insert("PriceTypeText",PriceTypeText);	
	
	TemplateArray = New Array;
	If ShowCurrency Then
		TemplateArray.Add("%CurrencyText");
	EndIf;	
	
	If ShowPriceType Then
		TemplateArray.Add("%PriceTypeText");
	EndIf;	
	
	If ShowDiscountGroup Then
		TemplateArray.Add("%DiscountGroupText");
	EndIf;	
	
	If ShowAmountType Then
		TemplateArray.Add("%AmountTypeText");
	EndIf;

	StringTemplate = "";
	
	For Each Item In TemplateArray Do
		
		StringTemplate = StringTemplate + Item + ", ";
		
	EndDo;	
	
	StringTemplate = Left(StringTemplate,StrLen(StringTemplate)-2);
	
	LabelText = AlertsAtClient.ParametrizeString(StringTemplate,ReturnStructure);	
	
	ReturnStructure.Insert("LabelText",LabelText);
	
	Return ReturnStructure;
	
EndFunction

