
&AtClient
Procedure CommandProcessing(ObjectReference, CommandExecuteParameters)
	
	If ObjectReference = Undefined Then 
		Return;
	EndIf;
	
	FormParameters = New Structure("ObjectReference", ObjectReference);
	OpenForm("CommonForm.ObjectRightsSettings", FormParameters, CommandExecuteParameters.Source);
	
EndProcedure



