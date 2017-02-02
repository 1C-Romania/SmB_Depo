
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Not Parameters.Property("ConformityDate", ConformityDate) Then
		ConformityDate = CurrentSessionDate();
	EndIf;
	
	If Not Parameters.Property("Company", Company) Then
		If CommonUse.SubsystemExists("StandardSubsystems.Companies") Then
			Module = CommonUse.CommonModule("Catalogs.Companies");
			Company = Module.CompanyByDefault();
		EndIf;
	EndIf;
	FillCompanyData();
	
	If ValueIsFilled(Parameters.Subjects) Then
		AgreementPrintVariant = "OutputBySubjects";
		For Each Subject IN Parameters.Subjects Do
			NewRow = PersonalDataSubjects.Add();
			NewRow.Subject = Subject;
		EndDo;
		FillDataOfPersonalDataSubjects();
	Else
		AgreementPrintVariant = "DisplayForm";
	EndIf;
	
	If CommonUseClientServer.IsLinuxClient() Then
		Items.MSWordPrintForm.Visible = False;
		Items.FormPrintOOWritter.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetSubjectsChoiceListAvailability();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// FORM ITEMS EVENTS HANDLERS

&AtClient
Procedure AgreementPrintVariantOnChange(Item)
	
	SetSubjectsChoiceListAvailability();
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	FillCompanyData();
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// COMMAND HANDLERS

&AtClient
Procedure Print(Command)
	
	Cancel = False;
	
	CheckFormFilling(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	CommandParameter = New Array;
	If PersonalDataSubjects.Count() > 0 AND ValueIsFilled(PersonalDataSubjects[0].Subject) Then
		CommandParameter.Add(PersonalDataSubjects[0].Subject);
	Else
		CommandParameter.Add(PredefinedValue("Catalog.Users.EmptyRef"));
	EndIf;
	
	PrintManagementClient.ExecutePrintCommand("DataProcessor.PersonalDataProcessingConsent", "PersonalDataProcessingConsent",
		CommandParameter, ThisObject, New Structure("AgreementPrintData", AgreementPrintData()));

EndProcedure

&AtClient
Procedure PrintMSWord(Command)
	
	Cancel = False;
	
	CheckFormFilling(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	PrintOfPersonalDataProcessingConsent("DataProcessor.PersonalDataProcessingConsent", "PersonalDataProcessorConsent(MSWord)", AgreementPrintData(), ThisObject);
	
EndProcedure

&AtClient
Procedure PrintOOWritter(Command)
	
	Cancel = False;
	
	CheckFormFilling(Cancel);
	
	If Cancel Then
		Return;
	EndIf;

	PrintOfPersonalDataProcessingConsent("DataProcessor.PersonalDataProcessingConsent", "PersonalDataProcessorConsent(ODT)", AgreementPrintData(), ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure SetSubjectsChoiceListAvailability()
	
	Items.FolderAgreementPrintData.CurrentPage = Items[AgreementPrintVariant];
	
EndProcedure

&AtClient
Function AgreementPrintData()
	
	SharedData = New Structure;
	SharedData.Insert("ConformityDate", 		?(ValueIsFilled(ConformityDate), Format(ConformityDate, "DLF=DD"), NStr("en='""____""__________________.';ru='""____""__________________.'")));
	SharedData.Insert("Company", 		?(ValueIsFilled(Company), Company, NStr("en='<Company>';ru='<Организация>'")));
	SharedData.Insert("CompanyAddress", 	?(ValueIsFilled(CompanyAddress), CompanyAddress, NStr("en=""<Company's address>"";ru='<Адрес организации>'")));
	SharedData.Insert("ResponsibleForPersonalDataProcessing", ?(ValueIsFilled(ResponsibleForPersonalDataProcessing), ResponsibleForPersonalDataProcessing, NStr("en='<Responsible person full name>';ru='<ФИО ответственного лица>'")));
	
	Subjects = New Array;
	If AgreementPrintVariant = "DisplayForm" Then
		Subjects.Add(New Structure("Initials, Address, PassportData", NStr("en='<Subject full name>';ru='<ФИО субъекта>'"), NStr("en='<Subject address>';ru='<Адрес субъекта>'"), NStr("en='<Subject passport data>';ru='<Паспортные данные субъекта>'")));
	Else
		For Each Subject IN PersonalDataSubjects Do
			SubjectData = New Structure("Initials, Address, PassportData");
			FillPropertyValues(SubjectData, Subject);
			Subjects.Add(SubjectData);
		EndDo;
	EndIf;
	
	// Structure for the each subject is complemented by the general data.
	For Each Subject IN Subjects Do
		For Each KeyAndValue IN SharedData Do
			Subject.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
	EndDo;
	
	Return Subjects;
	
EndFunction

&AtServer
Procedure FillCompanyData()
	
	OperatorCompanyData = New Structure("CompanyAddress, ResponsibleForPersonalDataProcessing");
	
	PersonalDataProtectionOverridable.AddCompanyDataPersonalDataOperator(Company, OperatorCompanyData, ConformityDate);
	
	FillPropertyValues(ThisObject, OperatorCompanyData);
	
EndProcedure

&AtServer
Procedure FillDataOfPersonalDataSubjects()
	
	// Filling of subjects data.
	PersonalDataProtectionOverridable.AddDataToSubjectsPersonalData(PersonalDataSubjects, ConformityDate);
	
EndProcedure

&AtClient
Procedure PrintOfPersonalDataProcessingConsent(PrintManagerName, TemplateName, Subjects, FormSource)
	
	// Check the quantity of objects.
	If Subjects.Count() = 0 Then
		Return;
	EndIf;
	
	MessageText = ?(Subjects.Count() > 1, 
		NStr("en='Print forms are being generated...';ru='Выполняется формирование печатных форм...'"),
		NStr("en='Print form is being generated...';ru='Выполняется формирование печатной формы...'"));
	Status(MessageText);
	
	TemplateAndObjectData = PrintManagementServerCall.TemplatesAndDataObjectsForPrinting(PrintManagerName, TemplateName, Subjects);
	
	For Each Subject IN Subjects Do
		PrintAgreementOnSubjectPersonalDataProcessing(String(Subject.Initials) + String(Subject.Address) + String(Subject.PassportData), TemplateAndObjectData, TemplateName, TemplateAndObjectData.PrintFilesLocalDirectory);
	EndDo;
	
EndProcedure

&AtClient
Procedure PrintAgreementOnSubjectPersonalDataProcessing(SubjectKey, TemplateAndObjectData, TemplateName, PrintFilesLocalDirectory)
	
	TemplateType				= TemplateAndObjectData.Templates.TemplateTypes[TemplateName];
	TemplateBinaryData	= TemplateAndObjectData.Templates.TemplateBinaryData;
	Areas					= TemplateAndObjectData.Templates.AreaInfo;
	ObjectData = TemplateAndObjectData.Data[SubjectKey][TemplateName];
	
	Template = PrintManagementClient.InitializeOfficeDocumentTemplate(TemplateBinaryData[TemplateName], TemplateType, TemplateName);
	If Template = Undefined Then
		Return;
	EndIf;
	
	ClosePrintFormWindow = False;
	Try
		PrintForm = PrintManagementClient.InitializePrintForm(TemplateType, Template.TemplatePageSettings);
		If PrintForm = Undefined Then
			PrintManagementClient.ClearReferences(Template);
			Return;
		EndIf;
		
		// Output of common areas with parameters.
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["Title"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["NumberDate"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["Preamble"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["MainText"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["OperatorAttributes"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["SubjectAttributes"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		Area = PrintManagementClient.TemplateArea(Template, Areas[TemplateName]["Signature"]);
		PrintManagementClient.JoinAreaAndFillParameters(PrintForm, Area, ObjectData, False);
		
		PrintManagementClient.ShowDocument(PrintForm);
	Except
		CommonUseClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
		ClosePrintFormWindow = True;
	EndTry;
	
	PrintManagementClient.ClearReferences(PrintForm, ClosePrintFormWindow);
	PrintManagementClient.ClearReferences(Template);
	
EndProcedure

&AtClient
Procedure CheckFormFilling(Cancel)
	
	If AgreementPrintVariant = "OutputBySubjects" AND PersonalDataSubjects.Count() = 0 Then
		MessageText = NStr("en='Subjects of personal data are not selected.';ru='Субъекты персональных данных не выбраны.'");
		CommonUseClientServer.MessageToUser(MessageText, , "PersonalDataSubjects", , Cancel);
	EndIf;
	
EndProcedure

#EndRegion














