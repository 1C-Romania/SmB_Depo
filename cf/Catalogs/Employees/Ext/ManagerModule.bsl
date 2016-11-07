#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Creates a new item of Employees catalog and returns its ref
//
// NewEmployeeData - (Structure) data of new item, where
//
// 	Key 		- Employees catalog attribute name;
// 	Value	= value which must be written in attribute;
//
// If failed to write, it returns Undefined;
Function CreateNewEmployee(NewEmployeeData) Export
	
	CatalogObject = Catalogs.Employees.CreateItem();
	FillPropertyValues(CatalogObject, NewEmployeeData);
	CatalogObject.DataExchange.Load = True;
	CatalogObject.Write();
	
	Return CatalogObject.Ref;
	
EndFunction // CreateNewEmployee()

Procedure SetMainResponsibleForUser(NewMainResponsible, User, UpdateSettingValue = False) Export
	
	// Set the setting if a responsible person is not assigned to the user
	MainResponsible = SmallBusinessReUse.GetValueByDefaultUser(User, "MainResponsible");
	If (ValueIsFilled(MainResponsible)
		AND UpdateSettingValue)
			OR Not ValueIsFilled(MainResponsible) Then
		
		SmallBusinessServer.SetUserSetting(NewMainResponsible, "MainResponsible", User);
		
	EndIf;
	
EndProcedure

#EndRegion

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
