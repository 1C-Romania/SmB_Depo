#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

//////////////////////////////////////////////////////////////////////////////
// PRINTING FORM TRAINING PROCEDURE

// Generate objects printing forms.
//
// Incoming:
//   ObjectsArray  - Array    - Ref array on objects which need to be printed.
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated tabular documents.
//   PrintErrors          - Values list  - Printing errors (value - ref to object, presentation - error
//                           text).
//   PrintObjects         - Values list  - Printing objects (value - ref to object, presentation - area
//                           name in which the object was displayed).
//   OutputParameters     - Structure    - Parameters of generated table documents.
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "PersonalDataProcessingConsent") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
						PrintFormsCollection,
						"PersonalDataProcessingConsent", NStr("en = 'Agreement on personal data processing'"),
						PrintOfAgreementOnPDtProcessing(PrintParameters.AgreementPrintData, PrintObjects), ,
						"DataProcessor.PersonalDataProcessingConsent.PF_MXL_PersonalDataProcessingConsent");
	EndIf;

EndProcedure

// Consent printing procedure on personal data processor.
//
Function PrintOfAgreementOnPDtProcessing(Subjects, PrintObjects) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PersonalDataProcessingConsent";
	
	TemplateName = "PersonalDataProcessingConsent";
	
	InscribingField = StringFunctionsClientServer.GenerateStringOfCharacters("_", 50);
	
	TemplateAreas = New Structure;
	TemplateAreas.Insert("Title");
	TemplateAreas.Insert("NumberDate");
	TemplateAreas.Insert("Preamble");
	TemplateAreas.Insert("P1_DataProcessorPurposesPNam");
	TemplateAreas.Insert("P2_ContentPNam");
	TemplateAreas.Insert("P3_InformationObtainingRight");
	TemplateAreas.Insert("P4_ValidityPeriod");
	TemplateAreas.Insert("P5_ActionsSPNam");
	TemplateAreas.Insert("P6_RecallRight");
	TemplateAreas.Insert("OperatorAttributes");
	TemplateAreas.Insert("SubjectAttributes");
	
	Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PersonalDataProcessingConsent.PF_MXL_PersonalDataProcessingConsent");

	// The same common data for any subject.
	SharedData = Subjects[0];
	
	// Common filling for all consent area subjects.
	For Each KeyAndValue IN TemplateAreas Do
		AreaName = KeyAndValue.Key;
		TemplateArea = Template.GetArea(AreaName);
		If AreaName = "NumberDate" Then
			TemplateArea.Parameters.ConformityDate = SharedData.ConformityDate;
		ElsIf AreaName = "Preamble" Then
			TemplateArea.Parameters.Company = ?(ValueIsFilled(SharedData.Company), SharedData.Company, InscribingField);
			TemplateArea.Parameters.ResponsibleForPersonalDataProcessing = ?(ValueIsFilled(SharedData.ResponsibleForPersonalDataProcessing), SharedData.ResponsibleForPersonalDataProcessing, InscribingField);
		ElsIf AreaName = "OperatorAttributes" Then
			TemplateArea.Parameters.Fill(SharedData);
		EndIf;
		TemplateAreas.Insert(AreaName, TemplateArea);
	EndDo;
	
	// Display forms for subjects
	FirstDocument = True;
	For Each Subject IN Subjects Do
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();	
		EndIf;
		FirstDocument = False;
		SpreadsheetDocument.Put(PrintOfAgreementOnSubjectPDtProcessing(Subject, TemplateAreas, InscribingField));
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

Function PrintOfAgreementOnSubjectPDtProcessing(Subject, TemplateAreas, InscribingField)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	For Each KeyAndValue IN TemplateAreas Do
		AreaName = KeyAndValue.Key;
		TemplateArea = KeyAndValue.Value;
		If AreaName = "Preamble" Then 
			TemplateArea.Parameters.Initials = ?(ValueIsFilled(Subject.Initials), Subject.Initials, InscribingField);
		ElsIf AreaName = "SubjectAttributes" Then
			TemplateArea.Parameters.Fill(Subject);
		EndIf;
		SpreadsheetDocument.Put(TemplateArea);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with templates of office documents.

Function GetPrintData(Val Subjects, Val TemplateNameArray) Export
	
	DataByAllObjects = New Map;
	
	For Each Subject IN Subjects Do
		ObjectDataByTemplates = New Map;
		For Each TemplateName IN TemplateNameArray Do
			ObjectDataByTemplates.Insert(TemplateName, Subject);
		EndDo;
		DataByAllObjects.Insert(String(Subject.Initials) + String(Subject.Address) + String(Subject.PassportData), ObjectDataByTemplates);
	EndDo;
	
	AreasInfo = New Map;
	TemplatesBinaryData = New Map;
	TemplateTypes = New Map;
	
	For Each TemplateName IN TemplateNameArray Do
		If TemplateName = "PersonalDataProcessorConsent(MSWord)" Then
			TemplatesBinaryData.Insert(TemplateName, PrintManagement.PrintedFormsTemplate("DataProcessor.PersonalDataProcessingConsent.PF_DOC_PersonalDataProcessingConsent"));
			TemplateTypes.Insert(TemplateName, "DOC");
		ElsIf TemplateName = "PersonalDataProcessorConsent(ODT)" Then
			TemplatesBinaryData.Insert(TemplateName, PrintManagement.PrintedFormsTemplate("DataProcessor.PersonalDataProcessingConsent.PF_ODT_PersonalDataProcessingConsent"));
			TemplateTypes.Insert(TemplateName, "ODT");
		EndIf;
		AreasInfo.Insert(TemplateName, GetAreasDescriptionOfOfficeDocumentTemplate());
	EndDo;
	
	Return New Structure("Data, Templates",
		DataByAllObjects,
		New Structure("AreaInfo, TemplateTypes, TemplateBinaryData",
			AreasInfo,
			TemplateTypes,
			TemplatesBinaryData));
	
EndFunction

Function GetAreasDescriptionOfOfficeDocumentTemplate()
	
	AreasInfo = New Structure;
	
	PrintManagement.AddAreaLongDesc(AreasInfo, "Title",			"Common");
	PrintManagement.AddAreaLongDesc(AreasInfo, "NumberDate",			"Common");
	PrintManagement.AddAreaLongDesc(AreasInfo, "Preamble",			"Common");
	PrintManagement.AddAreaLongDesc(AreasInfo, "MainText",		"Common");
	PrintManagement.AddAreaLongDesc(AreasInfo, "OperatorAttributes",	"Common");
	PrintManagement.AddAreaLongDesc(AreasInfo, "SubjectAttributes",	"Common");
	PrintManagement.AddAreaLongDesc(AreasInfo, "Signature",				"Common");
	
	Return AreasInfo;
	
EndFunction

#EndRegion

#EndIf