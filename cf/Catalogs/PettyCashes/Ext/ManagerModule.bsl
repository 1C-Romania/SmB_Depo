#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Gets the default petty cash for the company, or the only petty cash if the default petty cash is not specified.
//
Function GetPettyCashByDefault(Company = Undefined) Export

	PettyCashByDefault = Catalogs.PettyCashes.EmptyRef();
	
	If PettyCashByDefault.IsEmpty() And Company <> Undefined Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	PettyCashes.Ref AS PettyCashByDefault
		|FROM
		|	Catalog.Companies AS Companies
		|		INNER JOIN Catalog.PettyCashes AS PettyCashes
		|		ON Companies.PettyCashByDefault = PettyCashes.Ref
		|WHERE
		|	Companies.Ref = &Ref";
		
		Query.SetParameter("Ref", Company);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			PettyCashByDefault = Selection.PettyCashByDefault;
		EndIf;
		
	EndIf;
	
	If PettyCashByDefault.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 2
		|	PettyCashes.Ref AS PettyCashByDefault
		|FROM
		|	Catalog.PettyCashes AS PettyCashes
		|WHERE
		|	NOT PettyCashes.DeletionMark";
		
		Selection = Query.Execute().Select();
		If Selection.Count() = 1 И Selection.Next() Then
			PettyCashByDefault = Selection.PettyCashByDefault;
		EndIf;
		
	EndIf;
	
	Return PettyCashByDefault;

EndFunction

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