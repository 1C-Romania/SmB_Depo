
////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If (Parameters.FillingValues.Property("EnterpriseResourceKind")
		AND ValueIsFilled(Parameters.FillingValues.EnterpriseResourceKind))
		OR Parameters.Property("AvailabilityOfKind") Then
		
		Items.EnterpriseResourceKind.ReadOnly = True;
		
		If Parameters.Property("ValueEnterpriseResourceKind") Then
			Record.EnterpriseResourceKind = Parameters.ValueEnterpriseResourceKind;
		EndIf;
		
	ElsIf (Parameters.FillingValues.Property("EnterpriseResource")
		AND ValueIsFilled(Parameters.FillingValues.EnterpriseResource))
		OR Parameters.Property("ResourseAvailability") Then
		
		Items.EnterpriseResource.ReadOnly = True;
		
		If Record.EnterpriseResourceKind = Catalogs.EnterpriseResourcesKinds.AllResources Then
			Items.EnterpriseResourceKind.ReadOnly = True;
		EndIf;
		
	ElsIf Parameters.Property("AvailabilityAllResources")
		AND Record.EnterpriseResourceKind = Catalogs.EnterpriseResourcesKinds.AllResources Then
		
		Items.EnterpriseResourceKind.ReadOnly = True;
		
	ElsIf Parameters.CopyingValue <> Undefined 
		AND Parameters.CopyingValue.EnterpriseResourceKind = Catalogs.EnterpriseResourcesKinds.AllResources Then
		
		Items.EnterpriseResourceKind.ReadOnly = True;
		
	EndIf;
	
EndProcedure // OnCreateAtServer()

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_EnterpriseResourcesKinds");
	
EndProcedure // AfterWrite()



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
