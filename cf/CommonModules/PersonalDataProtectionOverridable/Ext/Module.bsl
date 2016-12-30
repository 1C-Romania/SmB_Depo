////////////////////////////////////////////////////////////////////////////////
// Subsystem "Personal data protection".
// Module is intended to place overridable subsystem procedures.
//  
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Procedure provides collection of information about the storage of data related to personal data
//
// Parameters:
// 	InfoTable - value table with fields:
// 		Object 			- a string containing the full
// 		name of the metadata object, RegistrationFields - a string that lists the names of
// 							the registration fields, registration fields
// 							are separated by a comma, alternative - symbol
// 		"|", AccessFields		- a string that lists the names of access fields separated with commas.
// 		DataArea	- a string with data area identifier, optional.
//
Procedure FillInfoAboutPersonalData(InfoTable) Export
	
	// StandardSubsystems.Individuals
	NewInfo = InfoTable.Add();
	NewInfo.Object			= "Catalog.Individuals";
	NewInfo.LoggedFields	= "Ref";
	NewInfo.AccessFields		= "BirthDate,Gender";
	NewInfo.DataArea		= "PersonalData";
	
	// InformationRegister.IndividualsDocuments
	NewInfo = InfoTable.Add();
	NewInfo.Object			= "InformationRegister.IndividualsDocuments";
	NewInfo.LoggedFields	= "Ind";
	NewInfo.AccessFields		= "DocumentKind,Series,Number,IssueDate,ValidityPeriod,WhoIssued,DepartmentCode,Presentation";
	NewInfo.DataArea		= "PassportData";
	// End StandardSubsystems.Individuals
	
EndProcedure

// Procedure provides collections of personal data areas.
//
// Parameters:
// 	PersonalDataAreas - value table with fields:
// 		Name - data area identifier.
// 		Presentation - user presentation of the data area.
// 		Parent - identifier of the parent data area.
//
Procedure FillPersonalDataAreas(PersonalDataAreas) Export
	
	// Filling presentations for
	// used areas StandardSubsystems.Individuals
	NewArea = PersonalDataAreas.Add();
	NewArea.Name = "PersonalData";
	NewArea.Presentation = NStr("en='Personal data';ru='Персональные данные субъекта'");
	
	NewArea = PersonalDataAreas.Add();
	NewArea.Name = "PassportData";
	NewArea.Presentation = NStr("en='Passport data';ru='Паспортные данные'");
	NewArea.Parent = "PersonalData";
	// End StandardSubsystems.Individuals
	
EndProcedure

// Procedure is called when filling out the "Consent to
//  process personal data" forms with the persons' data passed as the parameters.
//
// Parameters:
// 	PersonalDataSubjects 	- collection form data containing information about persons.
// 	UpdateDate			- date on which the data must be filled.
//
Procedure AddDataToSubjectsPersonalData(PersonalDataSubjects, UpdateDate) Export
	
	For Each PersonPD IN PersonalDataSubjects Do
		
		PersonRef = PersonPD.Subject;
		If TypeOf(PersonRef) = Type("CatalogRef.Individuals") Then
			
			PersonPD.Initials = InformationRegisters.IndividualsDescriptionFull.IndividualDescriptionFull(UpdateDate, PersonRef);
			If IsBlankString(PersonPD.Initials) Then
				
				PersonPD.Initials = PersonRef.Description;
				
			EndIf;
			
			PersonPD.Address = ContactInformationManagement.ObjectContactInformation(PersonRef, Catalogs.ContactInformationTypes.IndividualAddressByRegistration);
			
			IndividualsDocuments = Catalogs.Individuals.IndividualDocumentByType(UpdateDate, PersonRef, Catalogs.IndividualsDocumentsKinds.LocalPassport);
			If IndividualsDocuments.Count() > 0 Then
				
				PersonPD.PassportData	= IndividualsDocuments[0].Presentation;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure is called when filling the "Consent to process
//  personal data" form with the company's data.
//
// Parameters:
// 	Company					- company - personal data operator.
// 	CompanyData			- structure with company's data (address, full name of responsible person, etc.).
// 	UpdateDate			- date on which the data must be filled.
//
Procedure AddCompanyDataPersonalDataOperator(Company, CompanyData, UpdateDate) Export
	
	InfoAboutCompany = SmallBusinessServer.InfoAboutLegalEntityIndividual(Company, UpdateDate);
	CompanyData.CompanyAddress = SmallBusinessServer.CompaniesDescriptionFull(InfoAboutCompany, "LegalAddress");
	
	ResponsiblePersons		= SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Company, UpdateDate);
	CompanyData.ResponsibleForPersonalDataProcessing = ResponsiblePersons.Head;
	
EndProcedure

#EndRegion