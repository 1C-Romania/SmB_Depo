
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisObject, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure // BeforeWriteAtServer()

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties 
	If PropertiesManagementClient.ProcessAlerts(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Properties
&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_EditContentOfProperties()
	PropertiesManagementClient.EditContentOfProperties(ThisObject, Object.Ref);
EndProcedure
// End StandardSubsystems.Properties

#EndRegion


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
