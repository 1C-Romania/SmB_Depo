#Region ProgramInterface

// Legal entity details are returned according to LEGAL ENTITIES data (name, address, codes, etc.)
//
// Parameters:
//  TIN  - String - TIN of a legal entity, details of which you have to get
//
// Returns:
//   Structure   - legal entity details. 
//                 Structure content - see function LegalEntityNewDetails
//
Function LegalEntityDetailsByTIN(Val TIN) Export
	
	LegalEntityDetails = NewLegalEntityDetails();
	LegalEntityDetails.TIN = TIN;
	
	ErrorDescription = "";
	Proxy = ProxyService(ErrorDescription);
	If Proxy <> Undefined Then
		InputParameters = Proxy.XDTOFactory.Create(
			Proxy.XDTOFactory.Type(TargetNamespace(), "getCorporationRequisitesByTIN"));
		InputParameters.TIN = TIN;
		InputParameters.configurationName = Metadata.Name;
		Try
			Response = Proxy.getCorporationRequisitesByTIN(InputParameters);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='TIN %1:';ru='ИНН %1:'"), TIN)
				+ Chars.LF + DetailErrorDescription(ErrorInfo);
		EndTry;
	EndIf;

	If ValueIsFilled(ErrorDescription) Then
		HandleServiceError(ErrorDescription, LegalEntityDetails);
		Return LegalEntityDetails;
	EndIf;
	
	XDTODataObject = Response.DetailsOfLegalEntity;
	
	FillLegalEntityNames(XDTODataObject, LegalEntityDetails);
	
	LegalEntityDetails.RegistrationNumber = XDTODataObject.OGRN;
	LegalEntityDetails.KPP = XDTODataObject.KPP;
	
	LegalEntityDetails.RegistrationDate = XDTODataObject.LegalEntityNameInfo.LegalEntityFormationDate;
	
	FillOutOKVEDCode(XDTODataObject, LegalEntityDetails);
	
	FillInRegistrationWithTaxAuthority(XDTODataObject, LegalEntityDetails);
	
	FillInPensionFundDetails(XDTODataObject, LegalEntityDetails);
	
	FillInSocialInsuranceFundDetails(XDTODataObject, LegalEntityDetails);
	
	FillInLegalAddress(XDTODataObject, LegalEntityDetails);
	
	FillInManagerAndPhoneNumber(XDTODataObject, LegalEntityDetails);
	
	Return LegalEntityDetails;
	
EndFunction

// Sole proprietor details returned by PATENTING data (initials, certificate of registration, codes, etc.)
//
// Parameters:
//  TIN  - String - TIN attributes of an individual entrepreneur which must get
//
// Returns:
//   Structure   - sole proprietor details. 
//                 Structure content - see function EntrepreneurNewDetails
//
Function EntrepreneurDetailsByTIN(Val TIN) Export
	
	EntrepreneurDetails = NewEntrepreneurDetails();
	EntrepreneurDetails.TIN = TIN;
	
	ErrorDescription = "";
	Proxy = ProxyService(ErrorDescription);
	If Proxy <> Undefined Then
		InputParameters = Proxy.XDTOFactory.Create(
			Proxy.XDTOFactory.Type(TargetNamespace(), "getEntrepreneurRequisitesByTIN"));
		InputParameters.TIN = TIN;
		InputParameters.configurationName = Metadata.Name;
		Try
			Response = Proxy.getEntrepreneurRequisitesByTIN(InputParameters);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='TIN %1:';ru='ИНН %1:'"), TIN)
				+ Chars.LF + DetailErrorDescription(ErrorInfo);
		EndTry;
	EndIf;
	
	If ValueIsFilled(ErrorDescription) Then
		HandleServiceError(ErrorDescription, EntrepreneurDetails);
		Return EntrepreneurDetails;
	EndIf;
	
	XDTODataObject = Response.SPDetails;
	
	EntrepreneurDetails.Surname  = Title(XDTODataObject.PrPP.InitialsEng.Surname);
	EntrepreneurDetails.Name      = Title(XDTODataObject.PrPP.InitialsEng.Name);
	EntrepreneurDetails.Patronymic = Title(XDTODataObject.PrPP.InitialsEng.Patronymic);
	EntrepreneurDetails.Gender      = ?(XDTODataObject.PrPP.Gender = "2", 
		Enums.IndividualGender.Female, 
		Enums.IndividualGender.Male);
	
	FillOutOKVEDCode(XDTODataObject, EntrepreneurDetails);
	
	FillInRegistrationWithTaxAuthority(XDTODataObject, EntrepreneurDetails);
	
	FillInPensionFundDetails(XDTODataObject, EntrepreneurDetails);
	
	FillOutRegistrationCertificate(XDTODataObject, EntrepreneurDetails);
	
	EntrepreneurDetails.Description = EntrepreneurDetails.Surname 
		+ " " + EntrepreneurDetails.Name
		+ " " + EntrepreneurDetails.Patronymic;
	EntrepreneurDetails.DescriptionFull = XDTODataObject.SoleProprietorNameKind
		+ " " + EntrepreneurDetails.Surname 
		+ " " + EntrepreneurDetails.Name
		+ " " + EntrepreneurDetails.Patronymic;
	EntrepreneurDetails.AbbreviatedName = ?(XDTODataObject.SoleProprietorKindCode = "1", "IP ", "") 
		+ EntrepreneurDetails.Description;
	EntrepreneurDetails.RegistrationNumber = XDTODataObject.OGRNIP;
	
	If XDTODataObject.CitizenInfo <> Undefined Then
		EntrepreneurDetails.CitizenshipCountryCode = XDTODataObject.CitizenInfo.OKSM;
	EndIf;
	
	If XDTODataObject.SoleProprietorRegistrationInfo <> Undefined Then
		EntrepreneurDetails.RegistrationDate = XDTODataObject.SoleProprietorRegistrationInfo.RegDate;
	EndIf;
	
	Return EntrepreneurDetails;
	
EndFunction

// Legal entity main details are returned according to LEGAL ENTITIES data that match search by name
//
// Parameters:
//  Description - String - one or several words from legal entity name for search in
//  LEGAL ENTITIES RegionCode - String, 2 - region code in legal entity address for search
//  in LEGAL ENTITIES Address - String - one or several words from legal entity address (from state to street) for search in LEGAL ENTITIES
//
// Returns:
//   Structure   - details of found legal entities. Structure content: 
//                 * LegalEntitiesDetails - Array - details of found legal entities, array items - Structure, description
//                 (see function LegalEntityNewDetails), only main details are populated (TIN,
//                 name, legal address, manager's initials) if more than 20 counterparties are found - only details of the
//                 first 20 are returned * FoundNumber - Number - total quantity of found details (can be
//                 more than 20) * ErrorDescription - String - service attribute.
//
Function LegalEntitiesDetailsByName(Val Description, Val StateCode = "", Val Address = "") Export
	
	LegalEntitiesDetails = New Structure("LegalEntitiesDetails,FoundCount,ErrorDescription",
		New Array, 0, Undefined);
	
	ErrorDescription = "";
	Proxy = ProxyService(ErrorDescription);
	If Proxy <> Undefined Then
		InputParameters = Proxy.XDTOFactory.Create(
			Proxy.XDTOFactory.Type(TargetNamespace(), "getCorporationRequisitesByNameAndAddress"));
		InputParameters.name = Description;
		InputParameters.address = Address;
		InputParameters.regionCode = StateCode;
		InputParameters.configurationName = Metadata.Name;
		Try
			Response = Proxy.getCorporationRequisitesByNameAndAddress(InputParameters);
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Name - %1:';ru='Наименование - %1:'"), Description)
				+ Chars.LF + DetailErrorDescription(ErrorInfo);
		EndTry;
	EndIf;

	If ValueIsFilled(ErrorDescription) Then
		HandleServiceError(ErrorDescription, LegalEntitiesDetails);
		Return LegalEntitiesDetails;
	EndIf;
	
	If Response.CorporationSearchResult <> Undefined Then
		
		For Each XDTODataObject IN Response.CorporationSearchResult.DetailsOfLegalEntity Do
			
			DetailsOfLegalEntity     = NewLegalEntityDetails();
			DetailsOfLegalEntity.TIN = XDTODataObject.TIN;
			
			FillLegalEntityNames(XDTODataObject, DetailsOfLegalEntity);
			
			FillInLegalAddress(XDTODataObject, DetailsOfLegalEntity);
			
			FillInManagerAndPhoneNumber(XDTODataObject, DetailsOfLegalEntity);
			
			LegalEntitiesDetails.LegalEntitiesDetails.Add(DetailsOfLegalEntity);
			
		EndDo; 
		
		LegalEntitiesDetails.FoundCount = Response.CorporationSearchResult.corporationsFound;
		
	EndIf;
	
	Return LegalEntitiesDetails;
	
EndFunction

#EndRegion

#Region DetailsDescription

Function NewLegalEntityDetails()

	DetailsOfLegalEntity = New Structure;
	
	// Filled out based on LEGAL ENTITIES data
	
	DetailsOfLegalEntity.Insert("TIN");                         // String, 10
	DetailsOfLegalEntity.Insert("KPP");                         // String, 9
	DetailsOfLegalEntity.Insert("Description");                // String, 0
	DetailsOfLegalEntity.Insert("DescriptionFull");          // String, 0
	DetailsOfLegalEntity.Insert("AbbreviatedName");     // String, 0
	DetailsOfLegalEntity.Insert("RegistrationNumber");        // String, 13 - OGRN
	// The following properties may contain Undefined in case of absence in data service
	DetailsOfLegalEntity.Insert("LegalForm");               // String, 0
	DetailsOfLegalEntity.Insert("LegalAddress");            // Structure from NewContactInformation()
	DetailsOfLegalEntity.Insert("Phone");                     // Structure from NewContactInformation()
	DetailsOfLegalEntity.Insert("Head");                // Structure from NewContactPerson()
	DetailsOfLegalEntity.Insert("RegistrationWithTaxAuthority"); // Structure from NewRegistrationWithTaxAuthority
	DetailsOfLegalEntity.Insert("RegistrationDate");             // Date
	DetailsOfLegalEntity.Insert("RegistrationInPensionFund"); // Structure from NewRegistrationInPensionFund()
	DetailsOfLegalEntity.Insert("RegistrationInSIF");             // Structure from NewRegistrationInSIF()
	DetailsOfLegalEntity.Insert("OKVEDCode");                    // String, 8
	
	// Service attribute
	DetailsOfLegalEntity.Insert("ErrorDescription");              // String, 0
	
	Return DetailsOfLegalEntity;

EndFunction 

Function NewEntrepreneurDetails()

	EntrepreneurDetails = New Structure;
	
	// Filled out based on PATENTING data
	
	EntrepreneurDetails.Insert("TIN");                         // String, 12
	EntrepreneurDetails.Insert("Description");                // String, 0
	EntrepreneurDetails.Insert("DescriptionFull");          // String, 0
	EntrepreneurDetails.Insert("AbbreviatedName");     // String, 0
	EntrepreneurDetails.Insert("Surname");                     // String, 0
	EntrepreneurDetails.Insert("Name");                         // String, 0
	EntrepreneurDetails.Insert("Patronymic");                    // String, 0
	EntrepreneurDetails.Insert("RegistrationNumber");        // String, 13 - OGRN
	// The following properties may contain Undefined in case of absence in data service
	EntrepreneurDetails.Insert("Gender");                         // EnumRef.PrivatePersonGender
	EntrepreneurDetails.Insert("CitizenshipCountryCode");        // String, 3
	EntrepreneurDetails.Insert("RegistrationWithTaxAuthority"); // Structure from NewRegistrationWithTaxAuthority
	EntrepreneurDetails.Insert("RegistrationInPensionFund"); // Structure from NewRegistrationInPensionFund()
	EntrepreneurDetails.Insert("RegistrationInSIF");             // Structure from NewRegistrationInSIF()
	EntrepreneurDetails.Insert("RegistrationDate");             // Date
	EntrepreneurDetails.Insert("OKVEDCode");                    // String, 8
	EntrepreneurDetails.Insert("RegistrationCertificate");   // Structure from NewRegistrationCertificate()
	
	// Service attribute
	EntrepreneurDetails.Insert("ErrorDescription");       // String, 0
	
	Return EntrepreneurDetails;

EndFunction 

Function NewContactInformation()

	Result = New Structure;
	Result.Insert("ContactInformation"); // String, 0 - XML 
	Result.Insert("Presentation");        // String, 0
	Result.Insert("Comment");          // String, 0
	Return Result;

EndFunction

Function NewContactPerson()

	Result = New Structure;
	Result.Insert("Position"); // String, 0
	Result.Insert("Surname");   // String, 0
	Result.Insert("Name");       // String, 0
	Result.Insert("Patronymic");  // String, 0
	Result.Insert("TIN");       // String, 12
	Return Result;

EndFunction

Function NewRegistrationWithTaxAuthority()
	
	Result = New Structure;
	Result.Insert("Code");          // String, 4
	Result.Insert("Description"); // String, 0
	Result.Insert("OKTMO");        // String, 11
	Result.Insert("OKATO");        // String, 11
	Return Result;
	
EndFunction

Function NewRegistrationInPensionFund()
	
	Result = New Structure;
	Result.Insert("PFRRegistrationNumber"); // String, 14
	Result.Insert("PFRBodyCode");            // String, 7
	Result.Insert("PFRBodyName");   // String, 0
	Return Result;
	
EndFunction

Function NewRegistrationInSIF()
	
	Result = New Structure;
	Result.Insert("SIFRegistrationNumber"); // String, 15
	Result.Insert("SubordinationCode");        // String, 5
	Result.Insert("SIFAgencyCode");            // String, 4
	Result.Insert("SIFBodyName");   // String, 0
	Return Result;
	
EndFunction

Function NewRegistrationCertificate()
	
	Result = New Structure;
	Result.Insert("Series");  // String, 0
	Result.Insert("Number");  // String, 0
	Result.Insert("Date");   // Date
	Return Result;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillLegalEntityNames(XDTODataObject, Attributes)

	LegalForms = New Array;
	LegalForms.Add("Limited liability company");
	LegalForms.Add("Closed Joint-Stock Company");
	LegalForms.Add("Open Joint-Stock Company");
	LegalForms.Add("Public Joint-Stock Company");
	LegalForms.Add("Joint-Stock Company");
	If XDTODataObject.LegalEntityNameInfo.LFO <> Undefined Then
		ObjectLegalForm = String(XDTODataObject.LegalEntityNameInfo.LFO.BusinessEntityDescriptionFull);
		Attributes.LegalForm = ObjectLegalForm;
		If LegalForms.Find(ObjectLegalForm) = Undefined Then
			LegalForms.Add(ObjectLegalForm);
		EndIf;
	EndIf;
	
	Attributes.DescriptionFull = XDTODataObject.LegalEntityNameInfo.LegalEntityDescriptionFull;
	For Each LegalForm IN LegalForms Do
		If Upper(LegalForm) = Upper(Left(Attributes.DescriptionFull, StrLen(LegalForm))) Then
			Attributes.DescriptionFull = LegalForm + Mid(Attributes.DescriptionFull, StrLen(LegalForm) + 1);
			Break;
		EndIf;
	EndDo;
	
	Attributes.AbbreviatedName = XDTODataObject.LegalEntityNameInfo.LegalEntityNameShort;
	If Not ValueIsFilled(Attributes.AbbreviatedName) 
		OR Attributes.AbbreviatedName = "-" Then
		Attributes.AbbreviatedName = Attributes.DescriptionFull;
	EndIf;
	
	Attributes.Description = Attributes.AbbreviatedName;
	Pos = Find(Attributes.Description, """");
	If Pos > 0 AND Pos <= 10 Then
		Attributes.Description = TrimR(Mid(Attributes.Description, Pos)) + " " + TrimR(Left(Attributes.Description, Pos-1));
		Attributes.Description = StrReplace(Attributes.Description, """", "");
	EndIf;

EndProcedure

Procedure FillInContactInformationXDTOObject(Factory, Object, InitialObject)
	
	For Each SourceObjectProperty IN InitialObject.Properties() Do
		
		ObjectProperty = Object.Properties().Get(SourceObjectProperty.Name);
		If ObjectProperty <> Undefined Then
			
			PropertyValue = InitialObject[SourceObjectProperty.Name];
			If PropertyValue = Undefined Then
				Continue;
			EndIf;
			
			If TypeOf(PropertyValue) = Type("XDTODataObject") Then
				
				Object[ObjectProperty.Name] = Factory.Create(ObjectProperty.Type);
				FillInContactInformationXDTOObject(Factory, Object[ObjectProperty.Name], InitialObject[SourceObjectProperty.Name]);
				
			ElsIf TypeOf(PropertyValue) = Type("XDTOList") Then
				
				For Each SourceItem IN PropertyValue Do
					
					Item = Factory.Create(ObjectProperty.Type);
					FillInContactInformationXDTOObject(Factory, Item, SourceItem);
					Object[ObjectProperty.Name].Add(Item);
					
				EndDo;
				
			ElsIf TypeOf(PropertyValue) = Type("String") Then
				
				ArrayOfWords      = StringFunctionsClientServer.SplitStringIntoWordArray(PropertyValue, " ");
				MaxWordIndex = ?(ArrayOfWords.Count() = 1, 0, ArrayOfWords.Count() - 2);
				For WordIndex = 0 To MaxWordIndex Do
					ArrayOfWords[WordIndex] = Title(ArrayOfWords[WordIndex]);
				EndDo;
				Object[ObjectProperty.Name] = StringFunctionsClientServer.RowFromArraySubrows(ArrayOfWords, " ");
				
			Else
				
				Object[ObjectProperty.Name] = PropertyValue;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillInRegistrationWithTaxAuthority(XDTODataObject, Attributes)
	
	If XDTODataObject.TaxRegistrationInfo <> Undefined
		AND XDTODataObject.TaxRegistrationInfo.TaxAuthorityInfo <> Undefined Then
		
		Attributes.RegistrationWithTaxAuthority = NewRegistrationWithTaxAuthority();
		
		Attributes.RegistrationWithTaxAuthority.Code          = XDTODataObject.TaxRegistrationInfo.TaxAuthorityInfo.TaxAuthorityCode;
		Attributes.RegistrationWithTaxAuthority.Description = XDTODataObject.TaxRegistrationInfo.TaxAuthorityInfo.TaxAuthorityName;
		
		If XDTODataObject.Properties().Get("InfoAddress") <> Undefined // Only legal entities have an address
			AND XDTODataObject.InfoAddress <> Undefined 
			AND XDTODataObject.InfoAddress.Address <> Undefined Then
			
			Address = XDTODataObject.InfoAddress.Address;
			Attributes.RegistrationWithTaxAuthority.OKTMO = Address.Content.OKTMO;
			Attributes.RegistrationWithTaxAuthority.OKATO = Address.Content.OKATO;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillOutOKVEDCode(XDTODataObject, Attributes)
	
	If XDTODataObject.InfoOKVED <> Undefined Then
		
		OKVEDList = XDTODataObject.InfoOKVED;
		OKVEDCode  = "";
		OKVEDDate = '00010101';
		For Each OKVEDItem IN OKVEDList Do
			If OKVEDItem.ActBegDate > OKVEDDate
				AND OKVEDItem.SignPrimarySecondaryActivity = "1" Then
				OKVEDDate = OKVEDItem.ActBegDate;
				OKVEDCode  = OKVEDItem.OKVEDCode;
			EndIf;
		EndDo;
		Attributes.OKVEDCode = OKVEDCode;
		
	EndIf;
	
EndProcedure

Procedure FillInPensionFundDetails(XDTODataObject, Attributes)
	
	If XDTODataObject.PensionFundRegistrationInfo <> Undefined Then
		
		RegistrationInPFR = NewRegistrationInPensionFund();
		
		PFRRegistrationNumber = XDTODataObject.PensionFundRegistrationInfo.PensionFundRegistrationNumber;
		PFRRegistrationNumber = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1-%2-%3';ru='%1-%2-%3'"), 
					Left(PFRRegistrationNumber, 3), Mid(PFRRegistrationNumber,4, 3), Right(PFRRegistrationNumber, 6));
		RegistrationInPFR.PFRRegistrationNumber = PFRRegistrationNumber;
		If XDTODataObject.PensionFundRegistrationInfo.PensionFundAgencyInfo <> Undefined Then
			PFRBodyCode = XDTODataObject.PensionFundRegistrationInfo.PensionFundAgencyInfo.CodePF;
			PFRBodyCode = StringFunctionsClientServer.SubstituteParametersInString(NStr("en='%1-%2';ru='%1-%2'"), 
				Left(PFRBodyCode, 3), Right(PFRBodyCode, 3));
			RegistrationInPFR.PFRBodyCode          = PFRBodyCode;
			RegistrationInPFR.PFRBodyName = XDTODataObject.PensionFundRegistrationInfo.PensionFundAgencyInfo.PensionFundName;
		EndIf;
		
		Attributes.RegistrationInPensionFund = RegistrationInPFR;
		
	EndIf;
	
EndProcedure

Procedure FillInSocialInsuranceFundDetails(XDTODataObject, Attributes)
	
	If XDTODataObject.SIFRegistrationInfo <> Undefined Then
		
		RegistrationInSIF = NewRegistrationInSIF();
		
		If StrLen(XDTODataObject.SIFRegistrationInfo.SIFRegNumber) <= 10 Then
			RegistrationInSIF.SIFRegistrationNumber = TrimAll(XDTODataObject.SIFRegistrationInfo.SIFRegNumber);
			RegistrationInSIF.SubordinationCode        = "";
		Else
			RegistrationInSIF.SIFRegistrationNumber = TrimAll(Left(XDTODataObject.SIFRegistrationInfo.SIFRegNumber, 10));
			RegistrationInSIF.SubordinationCode        = TrimAll(Mid(XDTODataObject.SIFRegistrationInfo.SIFRegNumber, 11));
			If StrLen(RegistrationInSIF.SubordinationCode) <> 5 Then
				RegistrationInSIF.SubordinationCode = "";
			EndIf;
		EndIf;
		
		If XDTODataObject.SIFRegistrationInfo.SIFAgencyInfo <> Undefined Then
			RegistrationInSIF.SIFAgencyCode            = XDTODataObject.SIFRegistrationInfo.SIFAgencyInfo.CodeSIF;
			RegistrationInSIF.SIFBodyName   = XDTODataObject.SIFRegistrationInfo.SIFAgencyInfo.SIFName;
		EndIf;
		
		Attributes.RegistrationInSIF = RegistrationInSIF;
		
	EndIf;
	
EndProcedure

Procedure FillOutRegistrationCertificate(XDTODataObject, Attributes)
	
	If XDTODataObject.ValidRecordsInfo <> Undefined Then
		
		Certificate = NewRegistrationCertificate();
		Certificate.Date = '00010101';
		For Each Record IN XDTODataObject.ValidRecordsInfo Do
			For Each CertificateRecord IN Record.CertInfo Do
				If ValueIsFilled(CertificateRecord.DocDate) Then
					DocDate = CertificateRecord.DocDate;
				ElsIf ValueIsFilled(Record.DocDate) Then
					DocDate = Record.DocDate;
				Else
					DocDate = '00010101';
				EndIf;
				If DocDate > Certificate.Date Then
					Certificate.Date  = DocDate;
					Certificate.Series = CertificateRecord.Series;
					Certificate.Number = Right("000000000" + CertificateRecord.Number, 9);
				EndIf;
			EndDo;
		EndDo;
		
		If Certificate.Date > '00010101' Then
			Attributes.RegistrationCertificate = Certificate;
		EndIf
		
	EndIf;
	
EndProcedure

Procedure FillInLegalAddress(XDTODataObject, Attributes)
	
	CINamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	If XDTODataObject.InfoAddress <> Undefined 
		AND XDTODataObject.InfoAddress.Address <> Undefined Then
		
		AddressRF_KI         = XDTOFactory.Create(XDTOFactory.Type(CINamespace, "AddressRF"));
		FillInContactInformationXDTOObject(XDTOFactory, AddressRF_KI, XDTODataObject.InfoAddress.Address.Content);
		
		KI = XDTOFactory.Create(XDTOFactory.Type(CINamespace, "ContactInformation"));
		KI.Content        = XDTOFactory.Create(XDTOFactory.Type(CINamespace, "Address"));
		KI.Content.Country = XDTODataObject.InfoAddress.Address.Country;
		KI.Content.Content = AddressRF_KI;
		KI.Presentation = ContactInformationManagement.PresentationContactInformation(
			KI, Catalogs.ContactInformationTypes.CounterpartyLegalAddress);
		
		CIStructure = NewContactInformation();
		CIStructure.ContactInformation = XDTOObjectSerialization(KI);
		CIStructure.Presentation  = KI.Presentation;
		
		Attributes.LegalAddress = CIStructure;
		
	EndIf;
	
EndProcedure

Procedure FillInManagerAndPhoneNumber(XDTODataObject, Attributes)
	
	CINamespace = ContactInformationManagementClientServerReUse.TargetNamespace();
	
	If XDTODataObject.ActivitiesManagementInfo <> Undefined
		AND XDTODataObject.ActivitiesManagementInfo.PrivatePersonPositionInfo <> Undefined Then
		
		For Each InformationAboutPosition IN XDTODataObject.ActivitiesManagementInfo.PrivatePersonPositionInfo Do
			If Find(InformationAboutPosition.PositionNameKind, "Head") > 0 
				AND InformationAboutPosition.Initials <> Undefined Then
				
				// Head
				CIStructure = NewContactPerson();
				CIStructure.Surname    = Title(InformationAboutPosition.Initials.Surname);
				CIStructure.Name        = Title(InformationAboutPosition.Initials.Name);
				CIStructure.Patronymic   = Title(InformationAboutPosition.Initials.Patronymic);
				CIStructure.Position  = SentenceWithCapitalLetter(InformationAboutPosition.PositionName);
				CIStructure.TIN        = InformationAboutPosition.PrivatePersonTIN;
				
				Attributes.Head = CIStructure;
				
				// Phone number
				If ValueIsFilled(InformationAboutPosition.PhoneNumber) Then
					KI = XDTOFactory.Create(XDTOFactory.Type(CINamespace, "ContactInformation"));
					KI.Content = XDTOFactory.Create(XDTOFactory.Type(CINamespace, "PhoneNumber"));
					If Left(InformationAboutPosition.PhoneNumber, 1) = "(" Then
						CityCodeEnd     = Find(InformationAboutPosition.PhoneNumber, ")");
						KI.Content.CityCode = Mid(InformationAboutPosition.PhoneNumber, 2, CityCodeEnd - 2);
						KI.Content.Number     = Mid(InformationAboutPosition.PhoneNumber, CityCodeEnd + 1);
					Else
						KI.Content.Number     = InformationAboutPosition.PhoneNumber;
					EndIf;
					KI.Presentation = ContactInformationManagement.PresentationContactInformation(
						KI, Catalogs.ContactInformationTypes.CounterpartyPhone);
					CIStructure = NewContactInformation();
					CIStructure.ContactInformation = XDTOObjectSerialization(KI);
					CIStructure.Presentation = KI.Presentation;
					
					Attributes.Phone         = CIStructure;
					
				EndIf;
				Break;
				
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

Function SentenceWithCapitalLetter(String)
	
	If ValueIsFilled(String) Then
		Return Upper(Left(String, 1)) + Lower(Mid(String, 2))
	Else
		Return String;
	EndIf;
	
EndFunction

Function ProxyService(ErrorDescription)
	
	Proxy = Undefined;
	AuthenticationParameters = AuthenticationParametersInService();
	
	If AuthenticationParameters = Undefined Then
		
		// Service text. Must be processed on client.
		ErrorDescription = "AuthenticationParametersAreNotSpecified"; 
		
	Else
		
		Try
			Proxy = CommonUse.WSProxy(
				ServiceAddress(),                             // WSDLAddress
				TargetNamespace(),                         // NamespaceURI
				"RequisitesWebServiceEndpointImpl2Service", // ServiceName
				"RequisitesWebServiceEndpointImpl2Port",    // EndpointName
				AuthenticationParameters.login,              // UserName
				AuthenticationParameters.password,           // Password
				30);                                        //Timeout
		Except
			ErrorInfo = ErrorInfo();
			ErrorDescription = DetailErrorDescription(ErrorInfo);
		EndTry; 
		
	EndIf;
	
	Return Proxy;
	
EndFunction

Function AuthenticationParametersInService()
	
	If CommonUseReUse.DataSeparationEnabled() Then
		Return New Structure("login,password", 
			"fresh", "fresh");
				
	Else
		AuthenticationData = OnlineUserSupport.OnlineSupportUserAuthenticationData();
		If AuthenticationData <> Undefined Then
			Return New Structure("login,password", 
				AuthenticationData.Login, 
				AuthenticationData.Password);
		Else
			Return Undefined;
		EndIf;
		
	EndIf;
	
EndFunction

Function ServiceAddress()

	Return "";

EndFunction

Function TargetNamespace()

	Return "http://ws.orgregister.company1c.com/";

EndFunction

Procedure HandleServiceError(ErrorDescription, AttributesStructure)
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode(); // To record event in the events log monitor
	
	If ErrorDescription = "AuthenticationParametersAreNotSpecified" Then
		ErrorText    = "AuthenticationParametersAreNotSpecified"; // Service text. Must be processed on client.
		ErrorDescription = NStr("en='Login and password for access to online support are not specified';ru='Не указаны логин и пароль для доступа к интернет-поддержке'");
		EventText   = NStr("en='Access error';ru='Ошибка доступа'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, """status"":401") > 0 Then
		ErrorText  = NStr("en='Incorrect login and password to access online support';ru='Неверно указаны логин и пароль для доступа к интернет-поддержке'");
		EventText = NStr("en='Access error';ru='Ошибка доступа'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-1:") > 0 Then
		ErrorText  = NStr("en='TIN of the legal entity is not specified';ru='Не указан ИНН юридического лица'");
		EventText = NStr("en='Data receiving error';ru='Ошибка получения данных'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-2:") > 0 Then
		ErrorText  = NStr("en='TIN of legal entity should consist of 10 digits';ru='ИНН юридического лица должен состоять из 10 цифр'");
		EventText = NStr("en='Data receiving error';ru='Ошибка получения данных'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-3:") > 0 Then
		ErrorText  = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to find data to fill out details by TIN %1';ru='Не удалось найти данные для заполнения реквизитов по ИНН %1'"),
			AttributesStructure.TIN);
		EventText = NStr("en='Data receiving error';ru='Ошибка получения данных'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-4:") > 0 Then
		ErrorText  = NStr("en='TIN of the entrepreneur is not specified';ru='Не указан ИНН предпринимателя'");
		EventText = NStr("en='Data receiving error';ru='Ошибка получения данных'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-5:") > 0 Then
		ErrorText  = NStr("en='TIN of entrepreneur should consist of 12 digits';ru='ИНН предпринимателя должен состоять из 12 цифр'");
		EventText = NStr("en='Data receiving error';ru='Ошибка получения данных'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-6:") > 0 Then
		ErrorText  = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Failed to find data to fill out details by TIN %1';ru='Не удалось найти данные для заполнения реквизитов по ИНН %1'"),
			AttributesStructure.TIN);
		EventText = NStr("en='Data receiving error';ru='Ошибка получения данных'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-7:") > 0 Then
		ErrorText  = NStr("en='Limit of service calls is exceeded for one day';ru='Превышен лимит количества вызовов сервиса за один день'");
		EventText = NStr("en='Access error';ru='Ошибка доступа'", MainLanguageCode);
		
	ElsIf Find(ErrorDescription, "SERVER-8:") > 0 Then
		ErrorText  = NStr("en='Valid ITS contract is not available';ru='Отсутствует действующий договор ИТС'");
		EventText = NStr("en='Access error';ru='Ошибка доступа'", MainLanguageCode);
		
	Else
		ErrorText  = NStr("en='Service error (for more information see events log monitor)';ru='Ошибка при работе с сервисом (подробнее см. Журнал регистрации)'");
		EventText = NStr("en='Service error';ru='Ошибка при работе с сервисом'", MainLanguageCode);
	EndIf;
	
	AttributesStructure.ErrorDescription = ErrorText;
	
	EventName = NStr("en='Unified state register data service.';ru='Сервис данных единых гос_реестров.'", MainLanguageCode) + " " + EventText;
	WriteLogEvent(EventName, EventLogLevel.Error, , , ErrorDescription);
	
EndProcedure

Function XDTOObjectSerialization(XDTODataObject) Export
	
	Record = New XMLWriter;
	Record.SetString(New XMLWriterSettings(, , False, False, ""));
	If XDTODataObject <> Undefined Then
		XDTOFactory.WriteXML(Record, XDTODataObject);
	EndIf;
	
	Return StrReplace(Record.Close(), Chars.LF, "&#10;");
	
EndFunction

#EndRegion
