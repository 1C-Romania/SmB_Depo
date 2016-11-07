
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







// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
