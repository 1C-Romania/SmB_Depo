
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
		Title = Object.Description + " " + NStr("en='(Group of additional attribute and information sets)';ru='(Группа наборов дополнительных реквизитов и сведений)'")
		
	ElsIf UseAdditAttributes Then
		Title = Object.Description + " " + NStr("en='(Group of additional attributes sets)';ru='(Группа наборов дополнительных реквизитов)'")
		
	ElsIf UseAdditInfo Then
		Title = Object.Description + " " + NStr("en='(Additional information set group)';ru='(Группа наборов дополнительных сведений)'")
	EndIf;
	
EndProcedure

#EndRegion














