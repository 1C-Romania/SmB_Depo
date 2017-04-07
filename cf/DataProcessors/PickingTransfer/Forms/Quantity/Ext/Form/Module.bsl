
// Service

&AtServer
Procedure SetEnabled(Parameters)
	
	CommonUseClientServer.SetFormItemProperty(Items, "Quantity",		"Enabled", Parameters.RequestQuantity);
	CommonUseClientServer.SetFormItemProperty(Items, "MeasurementUnit",	"Enabled", False);
	
EndProcedure

// Form

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Quantity			= Parameters.Quantity;
	MeasurementUnit	= Parameters.MeasurementUnit;
	
	SetEnabled(Parameters.SelectionSettingsCache);
	
EndProcedure

//Commands

&AtClient
Procedure OK(Command)
	
	Close(New Structure("Quantity, MeasurementUnit", Quantity, MeasurementUnit));
	
EndProcedure

// Form attributes




