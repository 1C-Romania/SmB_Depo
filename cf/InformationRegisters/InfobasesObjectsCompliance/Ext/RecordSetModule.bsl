#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	// Refuse from execution of object registration typical mechanism.
	AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	// Delete all nodes added after autoregistration if the autoregistration flag was enabled mistakenly.
	DataExchange.Recipients.Clear();
	
	// Fill property UniqueSourceIDAsString from source reference.
	If Count() > 0 Then
		
		If ThisObject[0].ObjectExportedByRef = True Then
			Return;
		EndIf;
		
		ThisObject[0]["UniqueSourceHandleAsString"] = String(ThisObject[0]["UniqueSourceHandle"].UUID());
		
	EndIf;
	
	If DataExchange.Load
		OR Not ValueIsFilled(Filter.InfobaseNode.Value)
		OR Not ValueIsFilled(Filter.UniqueReceiverHandle.Value)
		OR Not CommonUse.RefExists(Filter.InfobaseNode.Value) Then
		Return;
	EndIf;
	
	// Record set should be registered only at one node specified in filter.
	DataExchange.Recipients.Add(Filter.InfobaseNode.Value);
	
EndProcedure

#EndRegion

#EndIf