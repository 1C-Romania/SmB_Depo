
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If PropertiesManagementService.AdditionalPropertyInUse(Parameters.Ref) Then
		
		Items.UserDialogs.CurrentPage = Items.ObjectIsUsed;
		Items.AllowEdit.DefaultButton = True;
		
		If Parameters.ThisIsAdditionalAttribute = True Then
			Items.Warnings.CurrentPage = Items.AdditionalAttributeWarning;
		Else
			Items.Warnings.CurrentPage = Items.AdditionalInformationWarning;
		EndIf;
	Else
		Items.UserDialogs.CurrentPage = Items.ObjectIsNotUsed;
		Items.OK.DefaultButton = True;
		
		If Parameters.ThisIsAdditionalAttribute = True Then
			Items.Explanations.CurrentPage = Items.AdditionalAttributesExplanation;
		Else
			Items.Explanations.CurrentPage = Items.AdditionalInformationExplanation;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure AllowEdit(Command)
	
	UnlockableAttributes = New Array;
	UnlockableAttributes.Add("ValueType");
	
	Close();
	
	ObjectsAttributesEditProhibitionClient.SetEnabledOfFormItems(
		FormOwner, UnlockableAttributes);
	
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
