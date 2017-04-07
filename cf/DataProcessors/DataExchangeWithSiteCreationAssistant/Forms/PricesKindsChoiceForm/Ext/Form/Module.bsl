
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPriceKindsList();
	
EndProcedure

&AtServer
Procedure FillPriceKindsList()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PriceKinds.Ref AS Value,
	|	PriceKinds.Description AS Presentation,
	|	FALSE AS Check
	|FROM
	|	Catalog.PriceKinds AS PriceKinds
	|WHERE
	|	(NOT PriceKinds.CalculatesDynamically)
	|	AND (NOT PriceKinds.Ref IN (&PriceKinds))
	|
	|UNION ALL
	|
	|SELECT
	|	PriceKinds.Ref,
	|	PriceKinds.Description,
	|	TRUE
	|FROM
	|	Catalog.PriceKinds AS PriceKinds
	|WHERE
	|	(NOT PriceKinds.CalculatesDynamically)
	|	AND PriceKinds.Ref IN(&PriceKinds)
	|
	|ORDER BY
	|	Presentation";
	
	Query.SetParameter("PriceKinds", Parameters.PriceKindsList);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewItem = PriceKindsList.Add();
		FillPropertyValues(NewItem, Selection);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CommandOK(Command)
	
	SelectedPriceKinds = New ValueList;
	
	For Each ItemOP IN PriceKindsList Do
		
		If ItemOP.Check Then
			
			NewItem = SelectedPriceKinds.Add();
			FillPropertyValues(NewItem, ItemOP);
			
		EndIf;
		
	EndDo;
	
	Close(SelectedPriceKinds);
	
EndProcedure