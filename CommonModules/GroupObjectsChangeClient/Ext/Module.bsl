////////////////////////////////////////////////////////////////////////////////
// Subsystem "Group object change".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Used for the opening of the form of objects group change.
//
// Parameters:
//  List - FormTable - list form item containing references to the objects being changed.
//
Procedure ChangeSelected(List) Export
	
	SelectedRows = List.SelectedRows;
	
	FormParameters = New Structure("ObjectsArray", New Array);
	
	For Each SelectedRow IN SelectedRows Do
		If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
			Continue;
		EndIf;
		
		CurrentRow = List.RowData(SelectedRow);
		
		If CurrentRow <> Undefined Then
			
			FormParameters.ObjectsArray.Add(CurrentRow.Ref);
			
		EndIf;
		
	EndDo;
	
	If FormParameters.ObjectsArray.Count() = 0 Then
		ShowMessageBox(, NStr("en='The command can not be run for the specified object.';ru='Команда не может быть выполнена для указанного объекта.'"));
		Return;
	EndIf;
		
	OpenForm("DataProcessor.GroupAttributeChange.Form", FormParameters);
	
EndProcedure

#EndRegion
