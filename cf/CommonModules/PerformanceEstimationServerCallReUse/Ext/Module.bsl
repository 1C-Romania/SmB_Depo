////////////////////////////////////////////////////////////////////////////////
// Subsystem "Performance estimation".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// The function determines whether you should perform measurements.
//
// Returns:
//  Boolean - True perform, False do not perform.
//
Function ExecutePerformanceMeasurements() Export
	
	SetPrivilegedMode(True);
	Return Constants.ExecutePerformanceMeasurements.Get();
	
EndFunction

// The function returns a reference to a key operation by name.
// If there is no key operation with such name in the directory, it creates a new item.
//
// Parameters:
//  KeyOperationName - String - name of the key operation.
//
// Returns:
// CatalogRef.KeyOperations
//
Function GetKeyOperationByName(KeyOperationName) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	               |	KeyOperations.Ref AS Ref
	               |FROM
	               |	Catalog.KeyOperations AS KeyOperations
	               |WHERE
	               |	KeyOperations.Name = &Name
	               |
	               |ORDER BY
	               |	Ref";
	
	Query.SetParameter("Name", KeyOperationName);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		KeyOperationReference = PerformanceEstimationServerCallFullAccess.CreateKeyOperation(KeyOperationName);
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		KeyOperationReference = Selection.Ref;
	EndIf;
	
	Return KeyOperationReference;
	
EndFunction

#EndRegion
