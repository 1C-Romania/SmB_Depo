#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	
	Query = New Query;
	
	Query.SetParameter("SearchString", ?(Parameters.SearchString = Undefined, "", Parameters.SearchString) + "%");
	
	Query.Text =
	"SELECT
	|	IndividualsDocumentsKinds.Ref AS Ref
	|FROM
	|	Catalog.IndividualsDocumentsKinds AS IndividualsDocumentsKinds
	|WHERE
	|	Not IndividualsDocumentsKinds.DeletionMark
	|	AND IndividualsDocumentsKinds.Description LIKE &SearchString
	|
	|ORDER BY
	|	IndividualsDocumentsKinds.AdditionalOrderingAttribute";
	
	ChoiceData = New ValueList;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref);
	EndDo;
	
EndProcedure

#EndIf