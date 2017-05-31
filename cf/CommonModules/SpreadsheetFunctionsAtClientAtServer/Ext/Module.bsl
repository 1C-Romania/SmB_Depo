// It calculates the amount of the selected cells and returns its presentation.
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument - Table for which the cell amount is calculated.
//   SelectedAreas
//       - Undefined - When calling from the client this parameter will be automatically defined.
//       - Array - When calling from the server the areas precalculated
//           on the client using
//           ReportsClient function shall be transferred to this parameter.SelectedAreas(SpreadsheetDocument).
//
// Returns: 
//   String - Amount presentation for the selected cells.
//
// See also:
//   ReportsClient.SelectedAreas().
//
Function GetCellsAmount(Val SpreadsheetDocument, Val SelectedAreas) Export
	
	If SelectedAreas = Undefined Then
		#If Client Then
			SelectedAreas = SpreadsheetDocument.SelectedAreas;
		#Else
			Return NStr("en = 'Selected Areas parameter value is not specified.'");
		#EndIf
	EndIf;
	
	#If Client AND Not ThickClientOrdinaryApplication Then
		MarkedAreasNumber = SelectedAreas.Count();
		If MarkedAreasNumber = 0 Then
			Return ""; // There is no any number.
		ElsIf MarkedAreasNumber >= 100 Then
			Return "<"; // Server call is required.
		EndIf;
		NumberOfOutputCells = 0;
	#EndIf
	
	Amount = Undefined;
	CheckedCells = New Map;
	
	For Each SelectedArea IN SelectedAreas Do
		#If Client Then
			If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange") Then
				Continue;
			EndIf;
		#EndIf
		
		MarkedAreaTop = SelectedArea.Top;
		SelectedAreaBottom = SelectedArea.Bottom;
		MarkedAreaLeft = SelectedArea.Left;
		MarkedAreaRight = SelectedArea.Right;
		
		If MarkedAreaTop = 0 Then
			MarkedAreaTop = 1;
		EndIf;
		
		If SelectedAreaBottom = 0 Then
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If MarkedAreaLeft = 0 Then
			MarkedAreaLeft = 1;
		EndIf;
		
		If MarkedAreaRight = 0 Then
			MarkedAreaRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If SelectedArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			MarkedAreaTop = SelectedArea.Bottom;
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		MarkedAreaHeight = SelectedAreaBottom   - MarkedAreaTop;
		MarkedAreaWidth = MarkedAreaRight - MarkedAreaLeft;
		
		#If Client AND Not ThickClientOrdinaryApplication Then
			NumberOfOutputCells = NumberOfOutputCells + MarkedAreaWidth * MarkedAreaHeight;
			If NumberOfOutputCells >= 1000 Then
				Return "<"; // Server call is required.
			EndIf;
		#EndIf
		
		For ColumnNumber = MarkedAreaLeft To MarkedAreaRight Do
			For LineNumber = MarkedAreaTop To SelectedAreaBottom Do
				Cell = SpreadsheetDocument.Area(LineNumber, ColumnNumber, LineNumber, ColumnNumber);
				If CheckedCells.Get(Cell.Name) = Undefined Then
					CheckedCells.Insert(Cell.Name, True);
				Else
					Continue;
				EndIf;
				
				If Cell.Visible = True Then
					If Cell.AreaType <> SpreadsheetDocumentCellAreaType.Columns
						AND Cell.ContainsValue AND TypeOf(Cell.Value) = Type("Number") Then
						Number = Cell.Value;
					ElsIf ValueIsFilled(Cell.Text) Then
						Number = StringFunctionsClientServer.StringToNumber(Cell.Text);
					Else
						Continue;
					EndIf;
					If TypeOf(Number) = Type("Number") Then
						If Amount = Undefined Then
							Amount = Number;
						Else
							Amount = Amount + Number;
						EndIf;
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	If Amount = Undefined Then
		Return ""; // There is no any number.
	EndIf;
	
	Return Format(Amount, "NZ=0");
	
EndFunction
