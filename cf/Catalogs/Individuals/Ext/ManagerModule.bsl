
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// The procedure fills in the array of individuals persons
//
Function IndividualDocumentByType(Period, Individual, DocumentKind = Undefined) Export
	
	IndividualsDocuments = New Array;
	DocumentData = New Structure("Individual, DocumentKind, Series, Number, IssueDate, ValidityPeriod, WhoIssued, DepartmentCode, IsIdentityDocument, Presentation");
	
	If Not ValueIsFilled(Individual) Then
		
		Return IndividualsDocuments;
		
	EndIf;
	
	If Not ValueIsFilled(Period) Then
		
		Period = CurrentSessionDate();
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	IndividualsDocumentsSliceLast.Ind AS Individual
	|	,IndividualsDocumentsSliceLast.DocumentKind AS DocumentKind
	|	,IndividualsDocumentsSliceLast.Series AS Series
	|	,IndividualsDocumentsSliceLast.Number AS Number
	|	,IndividualsDocumentsSliceLast.IssueDate AS IssueDate
	|	,IndividualsDocumentsSliceLast.ValidityPeriod AS ValidityPeriod
	|	,IndividualsDocumentsSliceLast.WhoIssued AS WhoIssued
	|	,IndividualsDocumentsSliceLast.DepartmentCode AS DepartmentCode
	|	,IndividualsDocumentsSliceLast.IsIdentityDocument AS IsIdentityDocument
	|	,IndividualsDocumentsSliceLast.Presentation AS Presentation
	|FROM
	|	InformationRegister.IndividualsDocuments.SliceLast(&Period, Ind = &Ind AND &SearchConditionByDocumentKind) AS IndividualsDocumentsSliceLast
	|
	|ORDER BY
	|	IssueDate DESC";
	
	Query.SetParameter("Period", Period);
	Query.SetParameter("Ind", Individual);
	
	If ValueIsFilled(DocumentKind) Then
		
		Query.Text = StrReplace(Query.Text, "&SearchConditionByDocumentKind", "DocumentKind = &DocumentKind");
		Query.SetParameter("DocumentKind", DocumentKind);
		
	Else
		
		Query.SetParameter("SearchConditionByDocumentKind", True); // select all documents
		
	EndIf;
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		FillPropertyValues(DocumentData, Selection);
		IndividualsDocuments.Add(DocumentData);
		
	EndDo;
	
	Return IndividualsDocuments;
	
EndFunction // DocumentIndividualsByKind()

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.PersonalDataProtection") Then
		PersonalDataProtectionModule = CommonUse.CommonModule("PersonalDataProtection");
		PersonalDataProtectionModule.AddConsentToPersonalDataProcessingPrintCommand(PrintCommands);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf