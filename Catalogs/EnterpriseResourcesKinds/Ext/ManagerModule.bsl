#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure fills choice data.
//
Procedure FillChoiceData(ChoiceData, Parameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EnterpriseResourcesKinds.Ref AS Ref,
	|	EnterpriseResourcesKinds.Description AS EnterpriseResourceDescription,
	|	EnterpriseResourcesKinds.Code AS EnterpriseResourceCode
	|FROM
	|	Catalog.EnterpriseResourcesKinds AS EnterpriseResourcesKinds
	|WHERE
	|	EnterpriseResourcesKinds.Ref <> &AllResources
	|
	|GROUP BY
	|	EnterpriseResourcesKinds.Ref,
	|	EnterpriseResourcesKinds.Description,
	|	EnterpriseResourcesKinds.Code
	|
	|HAVING
	|	SubString(EnterpriseResourcesKinds.Description, 1, &SubstringLength) LIKE &SearchString
	|
	|ORDER BY
	|	EnterpriseResourceDescription";
	
	Query.SetParameter("AllResources", Catalogs.EnterpriseResourcesKinds.AllResources);
	Query.SetParameter("SearchString", Parameters.SearchString);
	Query.SetParameter("SubstringLength", StrLen(Parameters.SearchString));
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		ChoiceData = New ValueList;
		Selection = Result.Select();
		While Selection.Next() Do
			PresentationOfChoice = TrimAll(Selection.Ref) + " (" + TrimAll(Selection.EnterpriseResourceCode) + ")";
			ChoiceData.Add(Selection.Ref, PresentationOfChoice);
		EndDo;
	EndIf;
		
EndProcedure // FillChoiceData()	

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	FillChoiceData(ChoiceData, Parameters);
	
EndProcedure

#EndIf