#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Gets the default petty cash for the company, or the only petty cash if the default petty cash is not specified.
//
Function GetPettyCashByDefault(Company) Export

	PettyCashByDefault = Catalogs.PettyCashes.EmptyRef();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	PettyCashes.Ref AS PettyCashByDefault
	|FROM
	|	Catalog.Companies AS Companies
	|		INNER JOIN Catalog.PettyCashes AS PettyCashes
	|		ON Companies.PettyCashByDefault = PettyCashes.Ref
	|WHERE
	|	Companies.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 2
	|	PettyCashes.Ref AS PettyCashByDefault
	|FROM
	|	Catalog.PettyCashes AS PettyCashes
	|WHERE
	|	Not PettyCashes.DeletionMark";
	
	Query.SetParameter("Ref", Company);
	Result = Query.ExecuteBatch();
	
	If Not Result[0].IsEmpty() Then
		Selection = Result[0].Select();
	Else
		Selection = Result[1].Select();
	EndIf;
	
	If Selection.Count() = 1
		AND Selection.Next() Then
		
		PettyCashByDefault = Selection.PettyCashByDefault;
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