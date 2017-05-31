// Finding first tabular part row, that agree with filter.
//
// Returning values:
//  Tabular part row - finded row,
//  Undefined        - if the row was not founded.
//
Function FindTabularPartRow(Val TabularPart, Val RowFilterStructure) Export 
	
	RowsArray = TabularPart.FindRows(RowFilterStructure);
	
	If RowsArray.Count() = 0 Then
		Return Undefined;
	Else
		Return RowsArray[0];
	EndIf;
	
EndFunction // FindTabularPartRow()
