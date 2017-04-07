
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set the format for the current date: DF=H:mm
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure // OnCreateAtServer()

&AtServer
// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company		= Settings.Get("Company");
	Counterparty		= Settings.Get("Counterparty");
	Department	= Settings.Get("Department");
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	SmallBusinessClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure // OnLoadDataFromSettingsAtServer()

&AtClient
// Procedure - event handler OnChange of attribute Department.
// 
Procedure DepartmentOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Counterparty.
// 
Procedure CounterpartyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion