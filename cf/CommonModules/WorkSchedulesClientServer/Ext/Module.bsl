////////////////////////////////////////////////////////////////////////////////
// Subsystem "Work schedules".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Procedure shifts just edited row in the collection so that the rows of the collection remained orderly.
//
// Parameters:
// RowCollection - the array of rows, the collection data form, the table of values.
// OrderField - The field name of the collection item, which produces the ordering.
// CurrentRow - the edited collection row .
//
Procedure RestoreOrderRowsCollectionsAfterEditing(RowCollection, OrderField, CurrentRow) Export
	
	If RowCollection.Count() < 2 Then
		Return;
	EndIf;
	
	If TypeOf(CurrentRow[OrderField]) <> Type("Date") 
		AND Not ValueIsFilled(CurrentRow[OrderField]) Then
		Return;
	EndIf;
	
	IndexOfSource = RowCollection.IndexOf(CurrentRow);
	IndexOfResult = IndexOfSource;
	
	// Select the direction in which there is need to shift.
	Direction = 0;
	If IndexOfSource = 0 Then
		// down
		Direction = 1;
	EndIf;
	If IndexOfSource = RowCollection.Count() - 1 Then
		// up
		Direction = -1;
	EndIf;
	
	If Direction = 0 Then
		If RowCollection[IndexOfSource][OrderField] > RowCollection[IndexOfResult + 1][OrderField] Then
			// down
			Direction = 1;
		EndIf;
		If RowCollection[IndexOfSource][OrderField] < RowCollection[IndexOfResult - 1][OrderField] Then
			// up
			Direction = -1;
		EndIf;
	EndIf;
	
	If Direction = 0 Then
		Return;
	EndIf;
	
	If Direction = 1 Then
		// You need to shift until the value in the current row is more, than in the next.
		While IndexOfResult < RowCollection.Count() - 1 
			AND RowCollection[IndexOfSource][OrderField] > RowCollection[IndexOfResult + 1][OrderField] Do
			IndexOfResult = IndexOfResult + 1;
		EndDo;
	Else
		// You need to shift until the value in the current row is less, than in the previous.
		While IndexOfResult > 0 
			AND RowCollection[IndexOfSource][OrderField] < RowCollection[IndexOfResult - 1][OrderField] Do
			IndexOfResult = IndexOfResult - 1;
		EndDo;
	EndIf;
	
	RowCollection.Move(IndexOfSource, IndexOfResult - IndexOfSource);
	
EndProcedure

// Recreate a fixed compliance by inserting the specified value in it .
//
Procedure InsertFixedMap(FixedMap, Key, Value) Export
	
	Map = New Map(FixedMap);
	Map.Insert(Key, Value);
	FixedMap = New FixedMap(Map);
	
EndProcedure

// Remove a value from a fixed compliance by the specified key.
//
Procedure DeleteFromFixedMatch(FixedMap, Key) Export
	
	Map = New Map(FixedMap);
	Map.Delete(Key);
	FixedMap = New FixedMap(Map);
	
EndProcedure

#EndRegion
