#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert("Import");
	
EndProcedure

#EndIf