#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure OnWrite(Cancel)
	
	AdditionalReportsAndDataProcessorsSaaS.SynchronisationValuesForConstants(Metadata.Name, Value);
	
EndProcedure

#EndIf