
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

// Procedure fills form attributes from parameters.
//
&AtServer
Procedure FillAttributesByParameters()
	
	If Parameters.Property("EmployeesList") Then
		EmployeesList.Clear();
		For Each ArrayRow IN Parameters.EmployeesList Do
			NewRow = EmployeesList.Add();
			FillPropertyValues(NewRow, ArrayRow);
		EndDo;
	EndIf;
	
EndProcedure // CheckIfFormWasModified()

// Procedure checks if the form was modified.
//
&AtClient
Procedure CheckIfFormWasModified()
	
	WereMadeChanges = False;
	
	If EmployeesListChanged Then
		WereMadeChanges = True;
	EndIf;
	
EndProcedure // CheckIfFormWasModified()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillAttributesByParameters();
	
	WereMadeChanges = False;
	EmployeesListChanged = False;
	
EndProcedure // OnCreateAtServer()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

// Procedure - event handler of clicking the OK button.
//
&AtClient
Procedure CommandOK(Command)
	
	CheckIfFormWasModified();
	
	StructureOfFormAttributes = New Structure;
	
	StructureOfFormAttributes.Insert("WereMadeChanges", WereMadeChanges);
	
	TabularSectionEmployeesList = New Array;
	For Each TSRow IN EmployeesList Do
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Show", TSRow.Show);
		TabularSectionRow.Insert("Employee", TSRow.Employee);
		TabularSectionEmployeesList.Add(TabularSectionRow);
	EndDo;
	StructureOfFormAttributes.Insert("EmployeesList", TabularSectionEmployeesList);
	
	Close(StructureOfFormAttributes);
	
EndProcedure // CommandOK()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF FORM ATTRIBUTES

// Procedure - OnChange event handler of the EmployeesListEmployee field.
//
&AtClient
Procedure EmployeesListEmployeeOnChange(Item)
	
	CurrentRow = Items.EmployeesList.CurrentData;
	CurrentRow.Show = True;
	
EndProcedure // EmployeesListEmployeeOnChange()

// Procedure - OnChange event handler of the EmployeesList list.
//
&AtClient
Procedure EmployeesListOnChange(Item)
	
	EmployeesListChanged = True;
	
EndProcedure // EmployeesListOnChange()
