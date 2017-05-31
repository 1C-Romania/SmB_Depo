
Function GetVATRate(Company, BusinessAccountingGroup, ItemAccountingGroup) Export 
	
	If TypeOf(BusinessAccountingGroup) = TypeOf(Catalogs.CustomerAccountingGroups.EmptyRef()) Then
		If BusinessAccountingGroup.LocationType = Enums.BusinessPartnersLocationTypes.Domestic Then
			Return ItemAccountingGroup.DomesticCustomerVATRate;
		ElsIf BusinessAccountingGroup.LocationType = Enums.BusinessPartnersLocationTypes.EuropeanUnion Then	
			Return ItemAccountingGroup.EuropeanUnionCustomerVATRate;
		ElsIf BusinessAccountingGroup.LocationType = Enums.BusinessPartnersLocationTypes.Foreign Then		
			Return ItemAccountingGroup.ForeignCustomerVATRate;
		EndIf;	
	ElsIf TypeOf(BusinessAccountingGroup) = TypeOf(Catalogs.SupplierAccountingGroups.EmptyRef()) Then	
		If BusinessAccountingGroup.LocationType = Enums.BusinessPartnersLocationTypes.Domestic Then
			Return ItemAccountingGroup.DomesticSupplierVATRate;
		ElsIf BusinessAccountingGroup.LocationType = Enums.BusinessPartnersLocationTypes.EuropeanUnion Then	
			Return ItemAccountingGroup.EuropeanUnionSupplierVATRate;
		ElsIf BusinessAccountingGroup.LocationType = Enums.BusinessPartnersLocationTypes.Foreign Then		
			Return ItemAccountingGroup.ForeignSupplierVATRate;
		EndIf;	
	EndIf;	
	
EndFunction // GetVATRate()

//Creates "nice" VATNumber presentation for print forms, etc.
// Replaces given VATNumber in any presentation (e.g. "raw" - no formatting) 
// with a presentation aligned with system settings provided by user.
//
Function GetVATNumberPresentation(VATNumber, TemplatesStructure = Undefined) Export
	
	VATNumberOnlyDigits = "";
	VATNumberLength = StrLen(VATNumber);
	
	//Retrieve VATNumber numbers, remove any other characters
	For a = 1 To VATNumberLength Do
		
		VATNumberChar = Mid(VATNumber, a, 1);
		If Find("0123456789", VATNumberChar) > 0 Then
			VATNumberOnlyDigits = VATNumberOnlyDigits + VATNumberChar;
		EndIf;
		
	EndDo;
	
	VATNumberOnlyDigitsLength = StrLen(VATNumberOnlyDigits);
	If VATNumberOnlyDigitsLength = 0 Then
		Return VATNumber;
	EndIf;
	
	//Retrieve VATNumber template for given VATNumber length
	If TemplatesStructure = Undefined Then
		TemplatesStructure = Constants.VATNumberFormatStrings.Get().Get();
	EndIf;
	
	If TypeOf(TemplatesStructure) <> Type("Map") Then
		Return VATNumber;
	EndIf; 
	
	VATNumberTemplate = TemplatesStructure.Get(VATNumberOnlyDigitsLength);
	
	If VATNumberTemplate = Undefined Then
		Return VATNumber;
	EndIf;
	
	
	//Apply VATNumber template to VATNumber
	AdjustedVATNumber = "";
	FigureNumber = 0;
	VATNumberTemplateLength = StrLen(VATNumberTemplate);
	
	For a = 1 To VATNumberTemplateLength Do
		
		TemplateChar = Mid(VATNumberTemplate, a, 1);
		
		If TemplateChar = "9" Then
			FigureNumber = FigureNumber + 1;
			AdjustedVATNumber = AdjustedVATNumber + Mid(VATNumberOnlyDigits, FigureNumber, 1);
		Else
			AdjustedVATNumber = AdjustedVATNumber + TemplateChar;
		EndIf;
		
	EndDo;
	
	Return AdjustedVATNumber;
	
EndFunction //GetVATNumberPresentation()

Function GetVATNumberPresentationWithCash(VATNumber, TemplatesStructure, FormattedVATNumbersMap) Export
	
	AdjustedVATNumber = FormattedVATNumbersMap[VATNumber];
	
	If AdjustedVATNumber = Undefined Then
		
		AdjustedVATNumber = GetVATNumberPresentation(VATNumber, TemplatesStructure);
		FormattedVATNumbersMap.Insert(VATNumber, AdjustedVATNumber);
		
	EndIf;
	
	Return AdjustedVATNumber;
	
EndFunction // GetVATNumberPresentationWithCash()

Function GetBusinessPartnerVATNumberDescription(Date, BusinessPartner, LanguageCode, ForLocationType = Undefined) Export
	
	Return Alerts.ParametrizeString(Nstr("en = 'VAT number: %P1'; pl = 'NIP: %P1'; ru = 'ИНН: %P1'",LanguageCode) ,New Structure("P1",GetBusinessPartnerVATNumberPresentation(Date,BusinessPartner,ForLocationType)));
	
EndFunction	

Function GetBusinessPartnerVATNumberPresentation(Date, BusinessPartner, ForLocationType = Undefined, Val Country = Undefined) Export
	
	If Country = Catalogs.Countries.Poland Or ValueIsNotFilled(Country) Then
		Country = Undefined;
	EndIf;
	
	If ValueIsNotFilled(BusinessPartner) Then
		Return "";
	EndIf;
	
	If Not Country = Undefined Then
		Return InformationRegisters.BusinessPartnersAttributesHistory.GetLast(Date, New Structure("BusinessPartner, Attribute, Country", BusinessPartner, Enums.BusinessPartnersAttributesTypes.VATNumber, Country)).Description;
	EndIf;
	
	VATNumberPrefix = "";
	VATNumber = InformationRegisters.BusinessPartnersAttributesHistory.GetLast(Date, New Structure("BusinessPartner, Attribute", BusinessPartner, Enums.BusinessPartnersAttributesTypes.VATNumber)).Description;

	If ForLocationType = Undefined Or ForLocationType = Enums.BusinessPartnersLocationTypes.Domestic Then
		VATNumber = GetVATNumberPresentation(VATNumber);
	Else
		If TypeOf(BusinessPartner) = TypeOf(Catalogs.Companies.EmptyRef()) Then
			VATNumberPrefix = BusinessPartner.VATNumberPrefix + " ";
			VATNumber = GetVATNumberPresentation(VATNumber);
		EndIf;	
	EndIf;
	
	Return VATNumberPrefix + VATNumber;
EndFunction
