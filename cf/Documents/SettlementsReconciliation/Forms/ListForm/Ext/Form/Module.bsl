
#Region FormCommandsHandlers

// Procedure form event handler OnCreateAtServer
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SmallBusinessServer.SetDesignDateColumn(List);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure //OnCreateAtServer()

//Predefined procedure OnOpen
//
&AtClient
Procedure OnOpen(Cancel)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	SmallBusinessClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
EndProcedure //OnOpen()

#EndRegion

#Region FormAttributesEventsHandlers

// Procedure - event handler "OnChange" field "CounterpartyFilter"
//
&AtClient
Procedure CounterpartyFilterOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

// Procedure - event handler "OnChange" field "ResponsibleFilter"
//
&AtClient
Procedure ResponsibleFilterOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
EndProcedure // ManagerFilterOnChange()

// Procedure - event handler "OnChange" field "StatusFilter"
//
&AtClient
Procedure StatusFilterOnChange(Item)
	
	SmallBusinessClientServer.SetListFilterItem(List, "Status", Status, ValueIsFilled(Status));
	
EndProcedure // StatusFilterOnChange()

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion













