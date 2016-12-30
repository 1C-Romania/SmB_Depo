#Region ProgramInterface

// Returns HTML text of a generated contract text.
//
// Returns:
//  String
//
Function GetGeneratedContractHTML(Object, Document = Undefined, ListOfParameters) Export
	
	If Not ValueIsFilled(Object.ContractForm) Then
		ContractHTMLDocument = EmptyDocumentField();
		Return ContractHTMLDocument;
	EndIf;
	
	If Object.ContractForm.Form.Get() = Undefined Then
		Return "";
	EndIf;
	
	ContractHTMLDocument = Object.ContractForm.Form.Get().HTMLText;
	
	If Find(ContractHTMLDocument, "<body>") Then 
		ContractHTMLDocument = StrReplace(ContractHTMLDocument, "<body>", "<body style='margin:0;padding:0px;overflow:auto;width:100%;height:100%;'>");
	ElsIf Find(ContractHTMLDocument, "<BODY>") Then 
		ContractHTMLDocument = StrReplace(ContractHTMLDocument, "<BODY>", "<BODY style='margin:0;padding:0px;overflow:auto;width:100%;height:100%;'>");
	EndIf;
	
	If Find(ContractHTMLDocument, "http-equiv=""X-UA-Compatible""") Then
		ContractHTMLDocument = StrReplace(ContractHTMLDocument, "http-equiv=""X-UA-Compatible""", "");
	ElsIf Find(ContractHTMLDocument, "http-equiv=""X-UA-Compatible""") Then
		ContractHTMLDocument = StrReplace(ContractHTMLDocument, "http-equiv='X-UA-Compatible'", "");
	EndIf;
	
	CounterpartyPassportData = Undefined;
	
	ParameterType = "";
	For Each Parameter IN ListOfParameters Do
		If TypeOf(Parameter.Parameter) = Type("EnumRef.ContractsWithCounterpartiesTemplatesParameters") Then
			If Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_IssueDate
				OR Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_WhoIssued
				OR Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_DepartmentCode
				OR Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_Number
				OR Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_Series
				OR Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_ValidityPeriod Then
				
				If CounterpartyPassportData = Undefined Then
					CounterpartyPassportData = GetParameterValue(Object, , "PassportData");
				EndIf;
				
				PassportDataAttribute = Mid(Parameter.Parameter, StrLen("PassportData_") + 1, StrLen(Parameter.Parameter) - StrLen("PassportData_"));
				ParameterValue = CounterpartyPassportData[PassportDataAttribute];
			Else
				ParameterValue = GetParameterValue(Object, Document, Parameter.Parameter, Parameter.Presentation);
			EndIf;
			
			If Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.Facsimile
				OR Parameter.Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.Logo Then
				ParameterType = "imageParameter";
			EndIf;
			
			If ValueIsFilled(Parameter.Value) Then
				ParameterValue = Parameter.Value;
			Else
				Parameter.Value = ParameterValue;
			EndIf;
			
			If ValueIsFilled(ParameterValue) Then
				ParameterColor = "#FFFFFF";
				ParameterClass = "Filled";
			Else
				ParameterValue = UnfilledFieldPresentation();
				ParameterColor = "#DCDCDC";
				ParameterClass = "Empty";
			EndIf;
		ElsIf TypeOf(Parameter.Parameter) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInformation") Then
			
			ParameterValue = GetAdditionalAttributeValue(Object, Document, Parameter.Parameter);
			
			If ValueIsFilled(Parameter.Value) Then
				ParameterValue = Parameter.Value;
			Else
				Parameter.Value = ParameterValue;
			EndIf;
			
			If ValueIsFilled(ParameterValue) Then
				ParameterColor = "#FFFFFF";
				ParameterClass = "Filled";
			Else
				ParameterValue = UnfilledFieldPresentation();
				ParameterColor = "#DCDCDC";
				ParameterClass = "Empty";
			EndIf;
			
		Else
			If ValueIsFilled(Parameter.Value) Then 
				ParameterValue = Parameter.Value;
				ParameterColor = "#FFFFFF";
				ParameterClass = "Filled";
			Else
				ParameterValue = UnfilledFieldPresentation();
				ParameterColor = "#DCDCDC";
				ParameterClass = "Empty";
			EndIf;
		EndIf;
		
		HTMLParameter = "<a name='parameterType' id='parameterID' style = 'background-color: parameterColor' class='parameterClass'>parameterValue</a>";
		HTMLParameter = StrReplace(HTMLParameter, "parameterID", Parameter.ID);
		HTMLParameter = StrReplace(HTMLParameter, "parameterValue", ParameterValue);
		HTMLParameter = StrReplace(HTMLParameter, "parameterColor", ParameterColor);
		HTMLParameter = StrReplace(HTMLParameter, "parameterClass", ParameterClass);
		If ValueIsFilled(ParameterType) Then
			HTMLParameter = StrReplace(HTMLParameter, "parameterType", ParameterType);
		Else
			HTMLParameter = StrReplace(HTMLParameter, "parameterType", "parameter");
		EndIf;
			
		ContractHTMLDocument = StrReplace(ContractHTMLDocument, Parameter.Presentation, HTMLParameter);
	EndDo;
	
	ContractHTMLDocument = StrReplace(ContractHTMLDocument, "/*PageBreak*/", "<div style='page-break-after:always'></div>");
	
	Return ContractHTMLDocument;
	
EndFunction // GetGeneratedContractHTML()

Function UnfilledFieldPresentation() Export
	Return "__________";
EndFunction

// Returns the value of infobase parameter.
//
// Returns:
//  String
//
Function GetParameterValue(Object, Document = Undefined, Parameter, PresentationParameter = Undefined) Export
	
	Parameters = Enums.ContractsWithCounterpartiesTemplatesParameters;
	
	If Document <> Undefined Then
		Company = Document.Company;
	Else
		If SmallBusinessReUse.CounterpartyContractsControlNeeded()
			AND ValueIsFilled(Object.Company) Then
			Company = Object.Company;
		ElsIf ValueIsFilled(SmallBusinessReUse.GetValueOfSetting("MainCompany")) Then
			Company = SmallBusinessReUse.GetValueOfSetting("MainCompany");
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
	EndIf;
	
	If Parameter = Parameters.BankCompany Then
		
		ParameterValue = ?(Company.BankAccountByDefault.Bank.Description <> "",
					Company.BankAccountByDefault.Bank.Description, "");
		
	ElsIf Parameter = Parameters.CounterpartyBank Then
		
		ParameterValue = ?(Object.Owner.BankAccountByDefault.Bank.Description <> "",
					Object.Owner.BankAccountByDefault.Bank.Description, "");
		
	ElsIf Parameter = Parameters.Date Then
		
		ParameterValue = ?(Format(Object.ContractDate, "DLF=DD") <> "",
					Format(Object.ContractDate, "DLF=DD"), "");
		
	ElsIf Parameter = Parameters.PositionOfContactPersonOfCounterparty Then
		
		If ValueIsFilled(Object.Owner.ContactPerson.Position) Then
			ParameterValue = Object.Owner.ContactPerson.Position;
		Else
			If Object.Owner.ContactPerson.ContactPersonRoles.Count() <> 0 Then 
				ParameterValue = ?(Object.Owner.ContactPerson.ContactPersonRoles[0].ContactPersonRole.Description <> "",
							Object.Owner.ContactPerson.ContactPersonRoles[0].ContactPersonRole.Description, "");
			Else
				ParameterValue = "";
			EndIf;
		EndIf;
		
	ElsIf Parameter = Parameters.ContactPersonOfCounterparty Then
		
		ParameterValue = ?(ValueIsFilled(Object.Owner.ContactPerson.Ind),
					Object.Owner.ContactPerson.Ind.Description, "");
		
	ElsIf Parameter = Parameters.ContactPersonOfCounterpartyInitials Then
		
		ContactPerson = Object.Owner.ContactPerson.Ind;
		
		Selection = InformationRegisters.IndividualsDescriptionFull.Select(,, New Structure("Ind", ContactPerson));
		If Selection.Next() Then
			Name = Selection.Name;
			Patronymic = Selection.Patronymic;
			Surname = Selection.Surname;
		Else
			Return "";
		EndIf;
		
		Case = CaseParameter(PresentationParameter);
		DeclineValue(Parameter, Surname, Case);
		Initials = Surname + " " + Mid(Name, 1, 1) + ". " + Mid(Patronymic, 1, 1) + ".";
		
		Return Initials;
		
	ElsIf Parameter = Parameters.CompanyName Then
		
		ParameterValue = ?(Company.DescriptionFull <> "",
					Company.DescriptionFull, "");
					
	ElsIf Parameter = Parameters.CompanyCounterpartyName Then
		
		ParameterValue = ?(Object.Owner.DescriptionFull <> "",
					Object.Owner.DescriptionFull, "");
		
	ElsIf Parameter = Parameters.ContractNo Then
		
		ParameterValue = ?(Object.ContractNo <> "",
					Object.ContractNo, "");
		
	ElsIf Parameter = Parameters.CompanyBankAcc Then
		
		ParameterValue = ?(Company.BankAccountByDefault.AccountNo <> "",
					Company.BankAccountByDefault.AccountNo, "");
		
	ElsIf Parameter = Parameters.CounterpartyBankAcc Then
		
		ParameterValue = ?(Object.Owner.BankAccountByDefault.AccountNo <> "",
					Object.Owner.BankAccountByDefault.AccountNo, "");
		
	ElsIf Parameter = Parameters.CustomerPaymentDueDate Then
		
		ParameterValue = ?(Object.CustomerPaymentDueDate <> "",
					Object.CustomerPaymentDueDate, "");
		
	ElsIf Parameter = Parameters.VendorPaymentDueDate Then
		
		ParameterValue = ?(Object.VendorPaymentDueDate <> "",
					Object.VendorPaymentDueDate, "");
		
	ElsIf Parameter = Parameters.CompanyLegalAddress Then
		
		ParameterValue = "";
		For Each String IN Company.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CompanyLegalAddress Then 
				ParameterValue = String.Presentation;
				
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CompanyFactAddress Then
		
		ParameterValue = "";
		For Each String IN Company.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CompanyFactAddress Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CompanyPhone Then
		
		ParameterValue = "";
		For Each String IN Company.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CompanyPhone Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyFax Then
		
		ParameterValue = "";
		For Each String IN Company.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyFax Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CompanyEmailAddress Then
		
		ParameterValue = "";
		For Each String IN Company.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CompanyEmail Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyPostalAddress Then
		
		ParameterValue = "";
		For Each String IN Company.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyPostalAddress Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyLegalAddress Then 
		
		ParameterValue = "";
		For Each String IN Object.Owner.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyLegalAddress Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyFactAddress Then
		
		ParameterValue = "";
		For Each String IN Object.Owner.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyFactAddress Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyPhone Then
		
		ParameterValue = "";
		For Each String IN Object.Owner.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyPhone Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyFax Then
		
		ParameterValue = "";
		For Each String IN Object.Owner.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyFax Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyEMailAddress Then
		
		ParameterValue = "";
		For Each String IN Object.Owner.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyEmail Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyPostalAddress Then
		
		ParameterValue = "";
		For Each String IN Object.Owner.ContactInformation Do 
			
			If String.Type = Catalogs.ContactInformationTypes.CounterpartyPostalAddress Then 
				ParameterValue = String.Presentation;
			EndIf;
		EndDo;
		ParameterValue = ?(ParameterValue <> "", ParameterValue, "");
		
	ElsIf Parameter = Parameters.CounterpartyTIN Then
		
		ParameterValue = ?(Object.Owner.TIN <> "",
					Object.Owner.TIN, "");
		
	ElsIf Parameter = Parameters.CompanyTIN Then
		
		ParameterValue = ?(Company.TIN <> "",
					Company.TIN, "");
		
	ElsIf Parameter = Parameters.CounterpartyCRR Then
		
		ParameterValue = ?(Object.Owner.KPP <> "",
					Object.Owner.KPP, "");
		
	ElsIf Parameter = Parameters.CompanyKPP Then
		
		ParameterValue = ?(Company.KPP <> "",
					Company.KPP, "");
		
	ElsIf Parameter = Parameters.CompanyOKTMO Then
		
		ParameterValue = ?(Company.CodebyRNCMT <> "",
					Company.CodebyRNCMT, "");
		
	ElsIf Parameter = Parameters.CompanyOKATO Then
		
		ParameterValue = ?(Company.CodeByOKATO <> "",
					Company.CodeByOKATO, "");
		
	ElsIf Parameter = Parameters.CounterpartyRNCBO Then
		
		ParameterValue = ?(Object.Owner.CodeByOKPO <> "",
					Object.Owner.CodeByOKPO, "");
		
	ElsIf Parameter = Parameters.CompanyRNCBO Then
		
		ParameterValue = ?(Company.CodeByOKPO <> "",
					Company.CodeByOKPO, "");
					
	ElsIf Parameter = Parameters.CompanyHead Then
		
		ResponsiblePersons = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Company, CurrentDate());
		If Not ValueIsFilled(ResponsiblePersons.Head) Then
			Return "";
		EndIf;
		ParameterValue = ?(ValueIsFilled(ResponsiblePersons.Head.Ind),
					ResponsiblePersons.Head.Ind.Description, "");
					
	ElsIf Parameter = Parameters.CompanyHeadInitials Then
		
		ResponsiblePersons = SmallBusinessServer.OrganizationalUnitsResponsiblePersons(Company, CurrentDate());
		If Not ValueIsFilled(ResponsiblePersons.Head) Then
			Return "";
		EndIf;
		CompanyHead = ResponsiblePersons.Head.Ind;
		
		Selection = InformationRegisters.IndividualsDescriptionFull.Select(,, New Structure("Ind", CompanyHead));
		If Selection.Next() Then
			Name = Selection.Name;
			Patronymic = Selection.Patronymic;
			Surname = Selection.Surname;
		Else
			Return "";
		EndIf;
		
		Case = CaseParameter(PresentationParameter);
		DeclineValue(Parameter, Surname, Case);
		Initials = Surname + " " + Mid(Name, 1, 1) + ". " + Mid(Patronymic, 1, 1) + ".";
		
		Return Initials;
		
	ElsIf Parameter = Parameters.CounterpartyBIK Then
		
		ParameterValue = ?(ValueIsFilled(Object.Owner.BankAccountByDefault.Bank.Code),
					Object.Owner.BankAccountByDefault.Bank.Code, "");
					
	ElsIf Parameter = Parameters.CorrCounterpartyAccount Then
		
		ParameterValue = ?(ValueIsFilled(Object.Owner.BankAccountByDefault.Bank.CorrAccount),
					Object.Owner.BankAccountByDefault.Bank.CorrAccount, "");
					
	ElsIf Parameter = Parameters.CompanyBIK Then
		
		ParameterValue = ?(ValueIsFilled(Company.BankAccountByDefault.Bank.Code),
					Company.BankAccountByDefault.Bank.Code, "");
					
	ElsIf Parameter = Parameters.CompanyCorrAccount Then
		
		ParameterValue = ?(ValueIsFilled(Company.BankAccountByDefault.Bank.CorrAccount),
					Company.BankAccountByDefault.Bank.CorrAccount, "");
					
	ElsIf Parameter = Parameters.DocumentAmount Then
		
		If Document <> Undefined Then 
			ParameterValue = Document.DocumentAmount;
		Else 
			ParameterValue = "";
		EndIf;
		
	ElsIf Parameter = Parameters.DocumentNumber Then
		
		If Document <> Undefined Then 
			ParameterValue = Document.Number;
		Else 
			ParameterValue = "";
		EndIf;
		
	ElsIf Parameter = Parameters.DocumentDate Then 
		
		If Document <> Undefined Then 
			ParameterValue = Format(Document.Date, "DF=dd MMMM yyyy'");
		Else 
			ParameterValue = "";
		EndIf;
		
	ElsIf Parameter = "PassportData" Then
		
		Query = New Query;
		Query.Text = 
			"SELECT
			|	IndividualsDocuments.Series,
			|	IndividualsDocuments.Number,
			|	IndividualsDocuments.IssueDate,
			|	IndividualsDocuments.ValidityPeriod,
			|	IndividualsDocuments.WhoIssued,
			|	IndividualsDocuments.DepartmentCode
			|FROM
			|	InformationRegister.IndividualsDocuments AS IndividualsDocuments
			|WHERE
			|	IndividualsDocuments.Ind.Ref = &Ind
			|	AND IndividualsDocuments.DocumentKind.Ref = &DocumentKind";
		
		Query.SetParameter("DocumentKind", Catalogs.IndividualsDocumentsKinds.LocalPassport.Ref);
		If ValueIsFilled(Object.Owner.Individual) Then
			Individual = Object.Owner.Individual;
		Else
			Individual = Object.Owner.ContactPerson.Ind;
		EndIf;
		Query.SetParameter("Ind", Individual);
		
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		PassportData = New Structure;
		PassportData.Insert("Series", "");
		PassportData.Insert("Number", "");
		PassportData.Insert("IssueDate", "");
		PassportData.Insert("ValidityPeriod", "");
		PassportData.Insert("WhoIssued", "");
		PassportData.Insert("DepartmentCode", "");
		
		While SelectionDetailRecords.Next() Do 
			If ValueIsFilled(SelectionDetailRecords.Series) Then 
				PassportData.Series = SelectionDetailRecords.Series;
			EndIf;
			If ValueIsFilled(SelectionDetailRecords.Number) Then 
				PassportData.Number = SelectionDetailRecords.Number;
			EndIf;
			If ValueIsFilled(SelectionDetailRecords.IssueDate) Then 
				PassportData.IssueDate = Format(SelectionDetailRecords.IssueDate, "DF='dd.MM.yyyy'");
			EndIf;
			If ValueIsFilled(SelectionDetailRecords.ValidityPeriod) Then 
				PassportData.ValidityPeriod = Format(SelectionDetailRecords.ValidityPeriod, "DF='dd.MM.yyyy'");
			EndIf;
			If ValueIsFilled(SelectionDetailRecords.WhoIssued) Then 
				PassportData.WhoIssued = SelectionDetailRecords.WhoIssued;
			EndIf;
			If ValueIsFilled(SelectionDetailRecords.DepartmentCode) Then 
				PassportData.DepartmentCode = SelectionDetailRecords.DepartmentCode;
			EndIf;
		EndDo;
		
		Return PassportData;
		
	ElsIf Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_IssueDate
		OR Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_WhoIssued
		OR Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_DepartmentCode
		OR Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_Number
		OR Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_Series
		OR Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PassportData_ValidityPeriod Then
		
		PassportDataAttribute = Mid(Parameter, StrLen("PassportData_") + 1, StrLen(Parameter) - StrLen("PassportData_"));
		Query = New Query;
		Query.Text = 
			"SELECT
			|	IndividualsDocuments." + PassportDataAttribute + "
			|FROM
			|	InformationRegister.IndividualsDocuments
			|AS
			|	IndividualsDocuments WHERE IndividualsDocuments.Individual.Ref
			|	= & Individual AND IndividualsDocuments.DocumentKind Link = & DocumentKind";
			
		If ValueIsFilled(Object.Owner.Individual) Then
			Individual = Object.Owner.Individual;
		Else
			Individual = Object.Owner.ContactPerson.Ind;
		EndIf;
		Query.SetParameter("DocumentKind", Catalogs.IndividualsDocumentsKinds.LocalPassport.Ref);
		Query.SetParameter("Ind", Individual);
		
		QueryResult = Query.Execute();
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			If TypeOf(SelectionDetailRecords[PassportDataAttribute]) = Type("Date") Then
				Return Format(SelectionDetailRecords[PassportDataAttribute], "DF='dd.MM.yyyy'");
			Else
				Return SelectionDetailRecords[PassportDataAttribute];
			EndIf;
		EndIf;
		
	ElsIf Parameter = Parameters.Facsimile Then 
		If ValueIsFilled(Company.FileFacsimilePrinting) Then
			PictureData = AttachedFiles.GetFileBinaryData(Company.FileFacsimilePrinting);
			If ValueIsFilled(PictureData) Then
				Return "<img src=""data:image/png;base64," + Base64String(PictureData) + """>";
			EndIf;
		EndIf;
		
		Return "<span style='background-color: #DCDCDC'>Facsimile is not set for company</span>";
		
	ElsIf Parameter = Parameters.Logo Then 
		If ValueIsFilled(Company.LogoFile) Then
			PictureData = AttachedFiles.GetFileBinaryData(Company.LogoFile);
			If ValueIsFilled(PictureData) Then
				Return "<img src=""data:image/png;base64," + Base64String(PictureData) + """>";
			EndIf;
		EndIf;
		
		Return "<span style='background-color: #DCDCDC'>Logo is not set for company</span>";
		
	EndIf;
	
	Case = CaseParameter(PresentationParameter);
	If Case = Undefined OR Not ValueIsFilled(ParameterValue) Then
		Return ParameterValue;
	EndIf;
	
	DeclineValue(Parameter, ParameterValue, Case);
	Return ParameterValue;
	
EndFunction

// Returns a value of an additional attribute.
//
// Returns:
//  String
//
Function GetAdditionalAttributeValue(Object, Document, AttributeRef) Export
	
	If AttributeRef.PropertySet = Catalogs.AdditionalAttributesAndInformationSets.Catalog_CounterpartyContracts Then
		ValuesOfAdditionalAttributes = Object.AdditionalAttributes;
	ElsIf AttributeRef.PropertySet = Catalogs.AdditionalAttributesAndInformationSets.Catalog_Counterparties Then
		ValuesOfAdditionalAttributes = Object.Owner.AdditionalAttributes;
	ElsIf AttributeRef.PropertySet = Catalogs.AdditionalAttributesAndInformationSets.Document_CustomerOrder Then
		If Document <> Undefined Then
			ValuesOfAdditionalAttributes = Document.AdditionalAttributes;
		Else
			ValuesOfAdditionalAttributes = Undefined;
		EndIf;
	ElsIf AttributeRef.PropertySet = Catalogs.AdditionalAttributesAndInformationSets.Document_InvoiceForPayment Then
		If Document <> Undefined Then
			ValuesOfAdditionalAttributes = Document.AdditionalAttributes;
		Else
			ValuesOfAdditionalAttributes = Undefined;
		EndIf;
	EndIf;
	
	If ValuesOfAdditionalAttributes = Undefined Then
		Return "";
	EndIf;
	
	FilterParameters = New Structure;
	FilterParameters.Insert("Property", AttributeRef);
	AttributeDataTable = ValuesOfAdditionalAttributes.Unload(FilterParameters);
	
	TypesAttribute = AttributeRef.ValueType.Types();
	If TypesAttribute.Count() > 0 Then 
		CompoundAttribute = ?(TypesAttribute.Count() > 1, True, False);
	EndIf;
	
	If Not CompoundAttribute Then 
		AttributeType = TypesAttribute[0];
	Else
		If AttributeDataTable.Count() = 0 Then 
			Return "";
		Else 
			AttributeType = TypeOf(AttributeDataTable[0].Value);
		EndIf;
	EndIf;
	
	FormatString = AttributeRef.FormatProperties;
	
	If AttributeType = Type("Boolean") Then 
		If AttributeDataTable.Count() > 0 Then 
			Return Format(AttributeDataTable[0].Value, FormatString);
		Else 
			Return Format(False, AttributeRef.FormatProperties);
		EndIf;
		
	ElsIf AttributeType = Type("String") Then 
		If AttributeDataTable.Count() > 0 Then 
			Return AttributeDataTable[0].Value;
		Else 
			Return "";
		EndIf;
		
	ElsIf AttributeType = Type("Date") Then 
		If AttributeDataTable.Count() > 0 Then 
			Return Format(AttributeDataTable[0].Value, FormatString);
		Else
			Return "";
		EndIf;
		
	ElsIf AttributeType = Type("Number") Then 
		If AttributeDataTable.Count() > 0 Then 
			Return Format(AttributeDataTable[0].Value, FormatString);
		Else
			Return "";
		EndIf;
		
	ElsIf AttributeType = Type("CatalogRef.Counterparties")
		Or AttributeType = Type("CatalogRef.Users")
		Or AttributeType = Type("CatalogRef.Individuals") 
		Or AttributeType = Type("CatalogRef.Currencies") Then 
		If AttributeDataTable.Count() > 0 Then 
			Return AttributeDataTable[0].Value.Description;
		Else
			Return "";
		EndIf;
		
	ElsIf AttributeType = Type("CatalogRef.ObjectsPropertiesValues") 
		Or AttributeType = Type("CatalogRef.ObjectsPropertiesValuesHierarchy") Then 
		If AttributeDataTable.Count() > 0 Then 
			Return AttributeDataTable[0].Value.Description;
		Else 
			Return "";
		EndIf;
		
	EndIf;
	
EndFunction

// Returns the value of a filled in field.
//
// Returns:
//  String
//
Function GetFilledFieldValueOnGeneratingPrintedForm(Object, ParameterID) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	CounterpartyContractsEdditedParameters.Value
		|FROM
		|	Catalog.CounterpartyContracts.EditableParameters AS CounterpartyContractsEdditedParameters
		|WHERE
		|	CounterpartyContractsEdditedParameters.FormRefs = &FormRef
		|	AND CounterpartyContractsEdditedParameters.ID = &ParameterID
		|	AND CounterpartyContractsEdditedParameters.Ref = &ContractRef";
		
	Query.SetParameter("FormRef", Object.ContractForm);
	Query.SetParameter("ContractRef", Object.Ref);
	Query.SetParameter("ParameterID", ParameterID);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Return Selection.Value;
	EndDo;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function EmptyDocumentField()
	EmptyDocumentField = 
	"
	|<html>
	|<head>
	|<style type='text/css'>
	|</style>
	|</head>
	|<body>
	|</br>
	|<p align='center'><font color='grey'>Specify form treaty</font></p>
	|</body>
	|</html>";
	Return EmptyDocumentField;
EndFunction

Function CaseParameter(Parameter)
	If Find(Parameter, "nominative") <> 0 Then
		Return 1;
	ElsIf Find(Parameter, "genitive") <> 0 Then
		Return 2;
	ElsIf Find(Parameter, "dative") <> 0 Then
		Return 3;
	ElsIf Find(Parameter, "accusative") <> 0 Then
		Return 4;
	ElsIf Find(Parameter, "instrumental") <> 0 Then
		Return 5;
	ElsIf Find(Parameter, "prepositional") <> 0 Then
		Return 6;
	Else
		Return Undefined;
	EndIf;
EndFunction

Procedure DeclineValue(Parameter, ParameterValue, Case)
	If Parameter = Enums.ContractsWithCounterpartiesTemplatesParameters.PositionOfContactPersonOfCounterparty Then
		// Declension of position
		ArrayOfWords = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(ParameterValue, " ", True, True);
		
		WordsExceptions = New Array();
		WordsExceptions.Add("leading");
		WordsExceptions.Add("junior");
		WordsExceptions.Add("head");
		WordsExceptions.Add("executive");
		WordsExceptions.Add("discharge");
		
		WordsSeparators = New Array();
		WordsSeparators.Add("to");
		WordsSeparators.Add("on");
		WordsSeparators.Add("assembler");
		WordsSeparators.Add("coordinator");
		WordsSeparators.Add("engineer");
		WordsSeparators.Add("assistant");
		WordsSeparators.Add("developer");
		WordsSeparators.Add("deputy");
		WordsSeparators.Add("manager");
		WordsSeparators.Add("director");
		WordsSeparators.Add("manager");
		WordsSeparators.Add("head");
		WordsSeparators.Add("administrator");
		WordsSeparators.Add("executive");
		WordsSeparators.Add("acting");
		WordsSeparators.Add("and.O.");
		WordsSeparators.Add("and.");
		WordsSeparators.Add("temporarily in charge");
		WordsSeparators.Add("temp.and.O.");
		WordsSeparators.Add("temp.and.O.");
		WordsSeparators.Add("discharge");
		
		DeclinedWords = New Array;
		NeedToDecline = True;
		For Each Word IN ArrayOfWords Do
			
			If NeedToDecline Then
				If WordsExceptions.Find(Lower(Word)) = Undefined Then
					Try
						AttachAddIn("CommonTemplate.DeclinationComponentDescriptionFull", "NameDecl", AddInType.Native);
						DeclinationComponent = New("AddIn.NameDecl.CNameDecl");
						NewWord = DeclinationComponent.Decline(Word, Case);
					Except
						NewWord = Word;
					EndTry;
				Else
					NewWord = DeclineException(Word, Case);
				EndIf;
			Else
				NewWord = Word;
			EndIf;
			DeclinedWords.Add(NewWord);
			
			For Each WordSeparator IN WordsSeparators Do
				If Lower(Word) = WordSeparator Then
					NeedToDecline = False;
				EndIf;
			EndDo;
		EndDo;
		
		ParameterValue = StringFunctionsClientServer.RowFromArraySubrows(DeclinedWords, " ");
	Else
		// Declension Full name
		Try
			AttachAddIn("CommonTemplate.DeclinationComponentDescriptionFull", "NameDecl", AddInType.Native);
			DeclinationComponent = New("AddIn.NameDecl.CNameDecl");
			ParameterValue = DeclinationComponent.Decline(ParameterValue, Case);
		Except
		EndTry;
	EndIf;
	
EndProcedure

Function DeclineException(Word, Case)
	
	PassedWord = Lower(Word);
	
	If PassedWord = "leading"
		OR PassedWord = "head"
		OR PassedWord = "executive" Then
		
		If Case = 1 Then
			Return Word;
		ElsIf Case = 2 Then
			Return StrReplace(Word, "leading", "leading");
		ElsIf Case = 3 Then
			Return StrReplace(Word, "leading", "leading");
		ElsIf Case = 4 Then
			Return StrReplace(Word, "leading", "leading");
		ElsIf Case = 5 Then
			Return StrReplace(Word, "leading", "leading");
		ElsIf Case = 6 Then
			Return StrReplace(Word, "leading", "leading");
		EndIf;
		
	ElsIf PassedWord = "junior" Then
		
		If Case = 1 Then
			Return Word;
		ElsIf Case = 2 Then
			Return StrReplace(Word, "junior", "junior");
		ElsIf Case = 3 Then
			Return StrReplace(Word, "junior", "junior");
		ElsIf Case = 4 Then
			Return StrReplace(Word, "junior", "junior");
		ElsIf Case = 5 Then
			Return StrReplace(Word, "junior", "junior");
		ElsIf Case = 6 Then
			Return StrReplace(Word, "junior", "junior");
		EndIf;
		
	ElsIf PassedWord = "discharge" Then
		
		Return Word;
		
	Else
		Return Word;
	EndIf;
	
EndFunction

#EndRegion


