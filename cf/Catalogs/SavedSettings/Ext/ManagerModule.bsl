
Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	If SessionParameters.CurrentUser<>Data.Owner Then
		Presentation =  Data.Description  + " <" + Data.Owner + ">";
		StandardProcessing = False;
	EndIf;	
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Owner");
	Fields.Add("Description");

EndProcedure

