
////////////////////////////////////////////////////////////////////////////////
// 1C Taxcom Connection subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure returns data to fill application for
// obtaining a unique subscriber identifier and adding subscriber certificate.
//	
// Parameters:
// Company - Arbitrary - reference to the
// Companies CompanyData catalog item - structure with company data:
// * Code - String - company postal code;
// * State - String - company state code;
// * Region - String;
// * City - String;
// * Settlement - String - locality where company is situated;
// * Street - String;
// * House - String;
// * House - String;
// * Apartment - String;
// * Phone - String - company phone;
// * Description - String - company name;
// * TIN - String - Company's TIN;
// * OGRN - String - Company OGRN;
// * TaxOfficeCode - String - IMNS company code;
// * LegalEntityIndividual - String - kind, possible values are: LegalEntity or Individual;
// * Last name - String - manager name;
// * Name - String - manager name;
// * Patronymic - String - manager patronymic;
//	
//	
// Example:
//	
// for Trade management 11
//	
// CompanyObject = Undefined;
// Try
// 	ObjectCompany = Company.ReceiveObject();
// Exception
// TryEnd;
//	
// CompanyData.Clear();
//	
// /// Return structure should contain all /
// keys listed below and their values - Strings
// / //Properties will not be checked any more
//	
// CompanyData.Insert(CompanyRef, Company);
//	
// / in the Trade management configuration address
// / components storage is not realized that is why address components remain empty
//	
// CompanyData.Insert(Index         , );
// CompanyData.Insert(Region         , );
// CompanyData.Insert(District          , );
// CompanyData.Insert(City          , );
// CompanyData.Insert(Locality, );
// CompanyData.Insert(Street          , );
// CompanyData.Insert(House            , );
// CompanyData.Insert(Building         , );
// CompanyData.Insert(Apartment,       );
//	
// If CompanyObject = Undefined Then
//		
// 	CompanyData.Insert(Name   , );
// 	CompanyData.Insert(TIN            , );
// 	CompanyData.Insert(OGRN           , );
// 	CompanyData.Insert(IMNSCode        , );
// 	CompanyData.Insert(LegalEntityIndividual,      Individual);
//		
// 	CompanyData.Insert(Surname        , );
// 	CompanyData.Insert(Name            , );
// 	CompanyData.Insert(Patronymic       , );
//	
// 	Return;
//		
// EndIf;
//	
// / enable company attributes
//	
// CompanyData.Insert(Name,   CompanyObject.DescriptionFull);
// CompanyData.Insert(TIN,            CompanyObject.TIN);
// CompanyData.Insert(OGRN,           CompanyObject.OGRN);
// CompanyData.Insert(IMNSCode        , );
//	
// BodyKinds = Enums.CounterpartyKinds;
// If CompanyObject.LegalEntityIndividual
// 	= BodyKinds.LegalEntity OR CompanyObject.LegalEntityIndividual =
// 	BodyKinds.LegalEntityNotResident Then CompanyData.Insert(LegalEntityIndividual, LegalEntity);
// Else
// 	CompanyData.Insert(LegalEntityIndividual,      Individual);
// EndIf;
//	
// CompanyData.Insert(Surname , );
// CompanyData.Insert(Name     , );
// CompanyData.Insert(Patronymic, );
//	
// Manager = CompanyObject.CurrentManager;
// If NOT Manager.IsEmpty() Then
//		
// 	DescriptionFullArray = RowFunctionsClientServer.DecomposeRowInSubrowArray (Manager.Name,);
// 	ItemsQuantity = DescriptionFullArray.Count();
//		
// 	If ItemsQuantity > 0
// 		Then CompanyData.Surname = ArrayDescriptionFull[0];
// 	EndIf;
//		
// 	If ItemsQuantity > 1
// 		Then CompanyData.Surname = ArrayDescriptionFull[1];
// 	EndIf;
//		
// 	If ItemsQuantity > 2
// 		Then CompanyData.Surname = ArrayDescriptionFull[2];
// 	EndIf;
//		
// EndIf;
//	
// CompanyData.Insert(Phone, );
//	
// SearchStructure = New Structure;
// SearchStructure.Insert(Type, Enums.ContactInformationTypes.Phone);
// SearchStructure.Insert(Kind, Catalogs.ContactInformationKinds.CompanyPhone);
// PhoneRows = CompanyObject.ContactInformation.FindRows(SearchStructure);
//	
// If PhoneRows.Count() >
// 	0 Then CompanyData.Phone = PhoneRows[0].PhoneNumber;
// EndIf;
//	
//	
// /////////////////////////////////////////////////////////////////////////////
//	
// Example for Enterprise accounting, edition 3.0:
//	
// CompanyProperties = CommonUse.ObjectAttributeValues(Company, DescriptionFull, TIN, OGRN, TaxOfficeCode, LegalEntityIndividual);
//	
// CompanyIndividual = CompanyProperties.LegalEntityIndividual = Enums.CounterpartyKinds.Individual;
//	
// CompanyData.Insert(CompanyRef, Company);
//	
// CompanyData.Insert(Name   , CompanyProperties.DescriptionFull);
// CompanyData.Insert(TIN,            CompanyProperties.TIN);
// CompanyData.Insert(OGRN,           CompanyProperties.OGRN);
// CompanyData.Insert(IMNSCode,        CompanyProperties.TaxOfficeCode);
//	
// If OrganizationIndividual
// 	Then CompanyData.Insert(LegalEntityIndividual, Individual);
// Else
// 	CompanyData.Insert(LegalEntityIndividual,      LegalEntity);
// EndIf;
//	
// Authorities = AuthoritiesBP.Authorities(Company, CurrentSessionDate());
// CompanyData.Insert(Surname, Authorities.ManagerDescriptionFull.Surname);
// CompanyData.Insert(Name,Authorities.ManagerDescriptionFull.Name);
// CompanyData.Insert(Patronymic, Authorities.ManagerNameAndSurname.Patronymic);
//	
//	
// If CompanyIndividual
// 	Then ContactInformationObject = CommonUse.GetAttributeValue(Company, Entrepreneur);
// 	ContactInformationKind = Catalogs.ContactInformationKinds.ResidenceAddress Individuals;
// 	CatalogName = Individuals;
// Else
// 	ContactInformationObject = Company;
// 	ContactInformationKind = Catalogs.ContactInformationKinds.CompanyLegalAddress;
// 	CatalogName = Company;
// EndIf;
//	
// CompanyData.Insert(Index         , );
// CompanyData.Insert(Region         , );
// CompanyData.Insert(District          , );
// CompanyData.Insert(City          , );
// CompanyData.Insert(Locality, );
// CompanyData.Insert(Street          , );
// CompanyData.Insert(House            , );
// CompanyData.Insert(Building         , );
// CompanyData.Insert(Apartment,       );
//	
// QueryText =
// "SELECT ALLOWED
// |	ContactInformation.FieldsValues
// |FROM
// |	Catalog." + CatalogName + ".ContactInformation
// |AS
// |ContactInformation WHERE ContactInformation.Ref
// |	= &Ref AND ContactInformation.Type = &Kind";
//	
// Query = New Query;
// Query.Text = QueryText;
// Query.SetParameter(Ref, ContactInformationObject);
// Query.SetParameter(Kind,    ContactInformationKind);
// Selection = Query.Execute().Select();
// If Selection.Next() Then
//		
// 	AddressStructure = ContactInformationService.PreviousXMLContactInformationStructure (Selection.FieldsValues);
// 	If AddressByStructure.Property(Index)
// 		Then CompanyData.Apartment = AddressByStructure.Index;
// 	EndIf;
// 	If AddressByStructure.Property(Region)
// 		Then CompanyData.Apartment = AddressByStructure.Region;
// 		CompanyData.Insert(RegionCode, RegulatedReportingServerCall.StateCodeByName(AddressByStructure.Region));
// 	EndIf;
// 	If AddressByStructure.Property(District)
// 		Then CompanyData.Apartment = AddressByStructure.District;
// 	EndIf;
// 	If AddressByStructure.Property(City)
// 		Then CompanyData.Apartment = AddressByStructure.City;
// 	EndIf;
// 	If AddressByStructure.Property
// 		(Locality) Then CompanyData.Locality = AddressByStructure.Locality;
// 	EndIf;
// 	If AddressByStructure.Property(Street)
// 		Then CompanyData.Apartment = AddressByStructure.Street;
// 	EndIf;
// 	If AddressByStructure.Property(House)
// 		Then CompanyData.Apartment = AddressByStructure.House;
// 	EndIf;
// 	If AddressByStructure.Property(Building)
// 		Then CompanyData.Apartment = AddressByStructure.Building;
// 	EndIf;
// 	If AddressByStructure.Property(Apartment)
// 		Then CompanyData.Apartment = AddressByStructure.Apartment;
// 	EndIf;
//		
// EndIf;
//	
// CompanyData.Insert(Phone,
// 			ContactInformationManagement.ObjectContactInformation( Company,?(CompanyIndividual, Catalogs.ContactInfomationKinds.WorkPhoneIndividuals, Companies.ContactInformationTypes.CompanyPhone)));
//
Procedure FillCompanyRegistrationData(Company, CompanyData) Export
	
	CompanyProperties = CommonUse.ObjectAttributesValues(Company, 
			"DescriptionFull, TIN, OGRN, LegalEntityIndividual");
	
	CompanyData.Insert("CompanyRef", Company);
	
	CompanyData.Insert("Description", CompanyProperties.DescriptionFull);
	CompanyData.Insert("TIN"         , CompanyProperties.TIN);
	CompanyData.Insert("OGRN"        , CompanyProperties.OGRN);
	CompanyData.Insert("TaxOfficeCode"     , "");
	
	If CompanyProperties.LegalEntityIndividual = Enums.CounterpartyKinds.Individual Then
		CompanyData.Insert("LegalEntityIndividual", "Ind");
	Else
		CompanyData.Insert("LegalEntityIndividual", "LegalEntity");
	EndIf;
	
	CompanyData.Insert("Surname" , "");
	CompanyData.Insert("Name"     , "");
	CompanyData.Insert("Patronymic", "");
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ResponsiblePersonsSliceLast.Employee.Ind AS Ind
		|INTO vtDirector
		|FROM
		|	InformationRegister.ResponsiblePersons.SliceLast(
		|			,
		|			Company = &Company
		|				AND ResponsiblePersonType = VALUE(Enum.ResponsiblePersonTypes.Head)) AS ResponsiblePersonsSliceLast
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	IndividualsDescriptionFullSliceLast.Ind,
		|	IndividualsDescriptionFullSliceLast.Surname,
		|	IndividualsDescriptionFullSliceLast.Name,
		|	IndividualsDescriptionFullSliceLast.Patronymic
		|FROM
		|	InformationRegister.IndividualsDescriptionFull.SliceLast(
		|			,
		|			Ind In
		|				(SELECT
		|					vtDirector.Ind
		|				IN
		|					vtDirector)) AS IndividualsDescriptionFullSliceLast";
	
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		CompanyData.Insert("Surname" , Selection.Surname);
		CompanyData.Insert("Name"     , Selection.Name);
		CompanyData.Insert("Patronymic", Selection.Patronymic);
	EndIf;
	
	CompanyData.Insert("IndexOf"         , "");
	CompanyData.Insert("Region"         , "");
	CompanyData.Insert("District"          , "");
	CompanyData.Insert("City"          , "");
	CompanyData.Insert("Settlement", "");
	CompanyData.Insert("Street"          , "");
	CompanyData.Insert("Building"            , "");
	CompanyData.Insert("Section"         , "");
	CompanyData.Insert("Apartment"       , "");
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	ContactInformation.FieldsValues
		|FROM
		|	Catalog.Companies.ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.Ref = &Company
		|	AND ContactInformation.Type = VALUE(Catalog.ContactInformationKinds.CompanyLegalAddress)";
	
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		AddressStructure = ContactInformationManagement.PreviousStructureOfContactInformationXML(Selection.FieldsValues);
		If AddressStructure.Property("IndexOf") Then
			CompanyData.IndexOf = AddressStructure.IndexOf;
		EndIf;
		If AddressStructure.Property("Region") Then
			CompanyData.Region = AddressStructure.Region;
			CompanyData.Insert("StateCode", AddressClassifier.StateCodeByName(TrimAll(AddressStructure.Region)));
		EndIf;
		If AddressStructure.Property("District") Then
			CompanyData.District = AddressStructure.District;
		EndIf;
		If AddressStructure.Property("City") Then
			CompanyData.City = AddressStructure.City;
		EndIf;
		If AddressStructure.Property("Settlement") Then
			CompanyData.Settlement = AddressStructure.Settlement;
		EndIf;
		If AddressStructure.Property("Street") Then
			CompanyData.Street = AddressStructure.Street;
		EndIf;
		If AddressStructure.Property("Building") Then
			CompanyData.Building = AddressStructure.Building;
		EndIf;
		If AddressStructure.Property("Section") Then
			CompanyData.Section = AddressStructure.Section;
		EndIf;
		If AddressStructure.Property("Apartment") Then
			CompanyData.Apartment = AddressStructure.Apartment;
		EndIf;
		
	EndIf;
	
	CompanyData.Insert("Phone", ContactInformationManagement.ObjectContactInformation(
				Company, Catalogs.ContactInformationKinds.CompanyPhone));
	
EndProcedure

#EndRegion