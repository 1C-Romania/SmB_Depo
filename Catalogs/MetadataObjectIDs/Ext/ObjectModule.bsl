#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Prevents invalid metadata object ID change.
// Executes subordinate node double data processor of distributed infobase.
//
Procedure BeforeWrite(Cancel)
	
	StandardSubsystemsReUse.CatalogMetadataObjectsIDsCheckUse();
	
	// Object registration mechanism disconnection.
	AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	// Object registration on all DIB nodes.
	For Each ExchangePlan IN StandardSubsystemsReUse.DIBExchangePlans() Do
		StandardSubsystemsServer.RegisterObjectInAllNodes(ThisObject, ExchangePlan);
	EndDo;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Catalogs.MetadataObjectIDs.CheckObjectsBeforeWriting(ThisObject);
	
EndProcedure

// Prevents deletion metadata object IDs which are not marked for deletion.
Procedure BeforeDelete(Cancel)
	
	StandardSubsystemsReUse.CatalogMetadataObjectsIDsCheckUse();
	
	// Object registration mechanism disconnection.
	// ID refs are deleted independently in all nodes
	// through deletion mark mechanism and marked object deletion.
	AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not DeletionMark Then
		Catalogs.MetadataObjectIDs.CallExceptionByError(
			NStr("en = 'Metadata object ID deletion from which
			           |attribute value ""Deletion mark"" is set False it is not valid.'"));
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
