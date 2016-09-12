
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
	SetPropertyTypes = PropertiesManagementService.SetPropertyTypes(Object.Ref);
	UseAdditAttributes = SetPropertyTypes.AdditionalAttributes;
	UseAdditInfo  = SetPropertyTypes.AdditionalInformation;
	
	If UseAdditAttributes AND UseAdditInfo Then
		Title = Object.Description + " " + NStr("en='(Additional attributes and information set)';ru='(Набор дополнительных реквизитов и сведений)'")
		
	ElsIf UseAdditAttributes Then
		Title = Object.Description + " " + NStr("en='(Additional attributes set)';ru='(Набор дополнительных реквизитов)'")
		
	ElsIf UseAdditInfo Then
		Title = Object.Description + " " + NStr("en='(Additional information set)';ru='(Набор дополнительных сведений)'")
	EndIf;
	
	If Not UseAdditAttributes AND Object.AdditionalAttributes.Count() = 0 Then
		Items.AdditionalAttributes.Visible = False;
	EndIf;
	
	If Not UseAdditInfo AND Object.AdditionalInformation.Count() = 0 Then
		Items.AdditionalInformation.Visible = False;
	EndIf;
	
EndProcedure

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
