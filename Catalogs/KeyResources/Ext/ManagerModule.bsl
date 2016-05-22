#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure fills choice data.
//
Procedure FillChoiceData(ChoiceData, Parameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EnterpriseResourcesKinds.EnterpriseResource AS EnterpriseResource,
	|	EnterpriseResourcesKinds.EnterpriseResource.Description AS EnterpriseResourceDescription,
	|	EnterpriseResourcesKinds.EnterpriseResource.Code AS EnterpriseResourceCode
	|FROM
	|	InformationRegister.EnterpriseResourcesKinds AS EnterpriseResourcesKinds
	|WHERE
	|	EnterpriseResourcesKinds.EnterpriseResourceKind = &EnterpriseResourceKind
	|
	|GROUP BY
	|	EnterpriseResourcesKinds.EnterpriseResource,
	|	EnterpriseResourcesKinds.EnterpriseResource.Description,
	|	EnterpriseResourcesKinds.EnterpriseResource.Code
	|
	|HAVING
	|	SubString(EnterpriseResourcesKinds.EnterpriseResource.Description, 1, &SubstringLength) LIKE &SearchString
	|
	|ORDER BY
	|	EnterpriseResourceDescription";
	
	Query.SetParameter("EnterpriseResourceKind", Parameters.FilterResourceKind);
	Query.SetParameter("SearchString", Parameters.SearchString);
	Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ChoiceData = New ValueList;
		Selection = Result.Select();
		While Selection.Next() Do
			PresentationOfChoice = TrimAll(Selection.EnterpriseResource) + " (" + TrimAll(Selection.EnterpriseResourceCode) + ")";
			ChoiceData.Add(Selection.EnterpriseResource, PresentationOfChoice);
		EndDo;
	EndIf;
		
EndProcedure // FillChoiceData()	

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Property("FilterResourceKind") Then
		
		FilterResourceKind = Parameters.FilterResourceKind;
		If ValueIsFilled(FilterResourceKind) Then
			
			StandardProcessing = False;
			FillChoiceData(ChoiceData, Parameters);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndIf