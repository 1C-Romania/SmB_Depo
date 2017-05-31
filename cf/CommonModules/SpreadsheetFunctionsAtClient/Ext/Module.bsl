// Creates description of the selected spreadsheet areas to be passed to the server.
//   Substitutes for
//   type SelectedSpreadsheetAreas when it is required to calculate a cell sum on the server without context.
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument - Table for which it is required to create description of selected cells.
//
// Returns: 
//   Array from Structure - description.
//       * Top  - Number - String number of the area upper border.
//       * Bottom   - Number - String number of the area bottom border.
//       * Left  - Number - Column number of the area upper border.
//       * Right - Number - Column number of the area bottom border.
//       * AreaType - SpreadsheetDocumentCellAreaType - Columns, Rectangle, Rows, Table.
//
// See also:
//   StandardSubsystemsClientServer.CellsAmount().
//   StandardSubsystemsServerCall.CellsAmount().
//
Function SelectedAreas(Val SpreadsheetDocument) Export
	Result = New Array;
	For Each SelectedArea IN SpreadsheetDocument.SelectedAreas Do
		If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		Structure = New Structure("Top, Bottom, Left, Right, AreaType");
		FillPropertyValues(Structure, SelectedArea);
		Result.Add(Structure);
	EndDo;
	Return Result;
EndFunction
